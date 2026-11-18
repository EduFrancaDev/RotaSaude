import os
import runpy
import signal
import threading
from datetime import timedelta
from pathlib import Path
from unittest import mock

from django.conf import settings
from django.core.management.base import CommandError
from django.db import OperationalError, connection, connections
from django.test import TestCase, override_settings
from django.urls import reverse
from django.utils import timezone

from apps.demo.autoupdate import LOCK_KEY
from apps.demo.readings import CURRENT, MISSING, STALE, append_demo_reading, latest_reading, scenario_of, update_state
from apps.demo.tests.helpers import demo_mode_on, run_command
from apps.units.models import HealthUnit, UnitOperationalStatus
from apps.units.tests.helpers import make_status, make_unit

AUTO = "run_demo_auto_update"
LOGGER = "apps.demo.autoupdate"
auto_on = override_settings(DEMO_MODE=True, DEBUG=True, DEMO_AUTO_UPDATE=True, DEMO_UPDATE_INTERVAL="60")


def lock_holders():
    with connection.cursor() as cursor:
        cursor.execute(
            "SELECT count(*) FROM pg_locks WHERE locktype = 'advisory' AND granted"
            " AND classid::bigint = %s AND objid::bigint = %s AND objsubid = 2",
            LOCK_KEY,
        )
        return cursor.fetchone()[0]


class SettingsDefaultsTests(TestCase):
    SETTINGS = Path(settings.BASE_DIR) / "config" / "settings.py"

    def load(self, **env):
        with mock.patch.dict(os.environ, {"DJANGO_SECRET_KEY": "test", **env}, clear=True):
            return runpy.run_path(str(self.SETTINGS))

    def test_auto_update_is_off_by_default(self):
        loaded = self.load()
        self.assertIs(loaded["DEMO_AUTO_UPDATE"], False)
        self.assertEqual(loaded["DEMO_UPDATE_INTERVAL"], "60")

    def test_invalid_interval_never_blocks_the_api_settings(self):
        loaded = self.load(DEMO_AUTO_UPDATE="true", DEMO_UPDATE_INTERVAL="abc")
        self.assertIs(loaded["DEMO_AUTO_UPDATE"], True)


class GuardTests(TestCase):
    def setUp(self):
        self.centro = make_unit("upa-centro", is_demo=True)

    @override_settings(DEMO_MODE=True, DEBUG=True, DEMO_AUTO_UPDATE=False)
    def test_disabled_exits_cleanly_without_writing(self):
        with mock.patch("threading.Event.wait") as wait, self.assertLogs(LOGGER, level="INFO") as logs:
            run_command(AUTO)
        wait.assert_not_called()
        self.assertEqual(UnitOperationalStatus.objects.count(), 0)
        self.assertIn("DEMO_AUTO_UPDATE=false", "\n".join(logs.output))

    def test_refused_outside_demo_mode(self):
        for overrides in (
            {"DEMO_MODE": False, "DEBUG": True},
            {"DEMO_MODE": True, "DEBUG": False},
            {"DEMO_MODE": False, "DEBUG": False},
        ):
            with override_settings(DEMO_AUTO_UPDATE=True, DEMO_UPDATE_INTERVAL="60", **overrides):
                with self.assertRaisesMessage(CommandError, "Modo de demonstração desligado", msg=overrides):
                    run_command(AUTO, "--iterations", "1")
        self.assertEqual(UnitOperationalStatus.objects.count(), 0)

    @auto_on
    def test_invalid_interval_is_refused(self):
        for value in ("abc", "", "4", "-60"):
            with override_settings(DEMO_UPDATE_INTERVAL=value), self.assertRaises(CommandError, msg=value):
                run_command(AUTO, "--iterations", "1")
        with self.assertRaises(CommandError):
            run_command(AUTO, "--iterations", "0")
        self.assertEqual(UnitOperationalStatus.objects.count(), 0)


@auto_on
class PeriodicUpdateTests(TestCase):
    def setUp(self):
        self.centro = make_unit("upa-centro", is_demo=True)
        self.sul = make_unit("upa-sul", is_demo=True)
        self.nordeste = make_unit("upa-nordeste", is_demo=True)
        self.oeste = make_unit("upa-oeste", is_demo=True)  # reservada: sem dados
        self.real = make_unit("hospital-real", is_demo=False)

    def run_auto(self, iterations, *extra):
        with self.assertLogs(LOGGER, level="INFO") as logs:
            run_command(AUTO, "--iterations", str(iterations), *extra)
        return "\n".join(logs.output)

    def test_runs_at_the_configured_interval(self):
        with override_settings(DEMO_UPDATE_INTERVAL="45"), mock.patch("threading.Event.wait", return_value=False) as wait:
            log = self.run_auto(3, "--seed", "1")

        self.assertEqual(wait.call_count, 2)
        for call in wait.call_args_list:
            self.assertTrue(44 <= call.args[0] <= 45, call)
        self.assertEqual(self.centro.operational_statuses.count(), 3)
        self.assertEqual(self.sul.operational_statuses.count(), 3)
        self.assertIn("a cada 45s", log)
        self.assertEqual(log.count("Ciclo concluído: 3 leitura(s) gravada(s)"), 3)
        self.assertIn("encerrada após 3 ciclo(s)", log)

    def test_readings_are_persisted_with_random_scenarios_and_history_kept(self):
        make_status(self.centro, hour=9)
        before = list(UnitOperationalStatus.objects.filter(health_unit=self.centro).values())

        with mock.patch("threading.Event.wait", return_value=False):
            self.run_auto(6, "--seed", "3")

        readings = list(self.centro.operational_statuses.select_related("demo_mark").order_by("source_updated_at"))
        self.assertEqual(len(readings), 7)
        self.assertEqual(list(UnitOperationalStatus.objects.filter(pk=before[0]["id"]).values()), before)
        stamps = [r.source_updated_at for r in readings]
        self.assertEqual(stamps, sorted(set(stamps)))
        scenarios = [r.demo_mark.scenario for r in readings[1:]]
        self.assertTrue(set(scenarios) <= {"low", "moderate", "high", "critical"})
        self.assertTrue(all(a != b for a, b in zip(scenarios, scenarios[1:])))
        self.assertTrue(all(r.is_demo for r in readings[1:]))

    def test_reserved_pinned_and_real_units_keep_their_roles(self):
        make_status(self.real, hour=9)
        real_before = list(UnitOperationalStatus.objects.filter(health_unit=self.real).values())

        with mock.patch("threading.Event.wait", return_value=False):
            self.run_auto(4, "--seed", "5")

        self.assertEqual(self.oeste.operational_statuses.count(), 0)
        self.assertEqual(list(UnitOperationalStatus.objects.filter(health_unit=self.real).values()), real_before)
        pinned = set(self.nordeste.operational_statuses.values_list("demo_mark__scenario", flat=True))
        self.assertEqual(pinned, {"critical"})

    def test_api_contract_is_unchanged(self):
        with mock.patch("threading.Event.wait", return_value=False):
            self.run_auto(1)

        body = self.client.get(reverse("v1:unit-detail", args=["upa-centro"])).json()
        self.assertEqual(
            set(body["operational_status"]),
            {"people_waiting", "estimated_wait_minutes", "availability_level", "source_updated_at", "received_at", "is_demo"},
        )
        self.assertTrue(body["operational_status"]["is_demo"])
        self.assertNotIn("demo_mark", body)
        listing = self.client.get(reverse("v1:unit-list")).json()
        by_id = {u["id"]: u for u in listing["results"]}
        self.assertIsNone(by_id["upa-oeste"]["operational_status"])
        self.assertEqual(by_id["upa-nordeste"]["operational_status"]["availability_level"], "CRITICAL")

    def test_database_failure_is_logged_and_the_next_cycle_recovers(self):
        calls = {"n": 0}

        def flaky(unit, key, **kwargs):
            calls["n"] += 1
            if calls["n"] == 1:
                raise OperationalError("conexão perdida")
            return append_demo_reading(unit, key, **kwargs)

        with mock.patch("apps.demo.autoupdate.append_demo_reading", flaky), mock.patch(
            "threading.Event.wait", return_value=False
        ):
            log = self.run_auto(2)

        self.assertIn("Falha no ciclo de atualização", log)
        self.assertIn("conexão perdida", log)
        self.assertIn("encerrada após 2 ciclo(s)", log)
        self.assertEqual(self.centro.operational_statuses.count(), 1)
        self.assertEqual(self.sul.operational_statuses.count(), 1)

    def test_a_unit_that_cannot_be_updated_is_skipped_not_fatal(self):
        UnitOperationalStatus.objects.create(
            health_unit=self.sul, source_updated_at=timezone.now() + timedelta(hours=1), is_demo=True
        )
        with mock.patch("threading.Event.wait", return_value=False):
            log = self.run_auto(2)

        self.assertIn("upa-sul: ignorada", log)
        self.assertEqual(self.sul.operational_statuses.count(), 1)
        self.assertEqual(self.centro.operational_statuses.count(), 2)

    def test_no_units_yet_waits_instead_of_exiting(self):
        HealthUnit.objects.filter(is_demo=True).update(is_active=False)
        with mock.patch("threading.Event.wait", return_value=False):
            log = self.run_auto(2)
        self.assertEqual(log.count("Nenhuma UPA demonstrativa elegível"), 2)


@auto_on
class ConcurrencyAndShutdownTests(TestCase):
    def setUp(self):
        self.centro = make_unit("upa-centro", is_demo=True)
        self.other = connections.create_connection("default")

    def tearDown(self):
        self.other.close()

    def hold_lock_elsewhere(self, sql="SELECT pg_advisory_lock(%s, %s)"):
        with self.other.cursor() as cursor:
            cursor.execute(sql, LOCK_KEY)

    def test_second_instance_stays_on_standby_and_takes_over(self):
        self.hold_lock_elsewhere()
        waits = {"n": 0}

        def release_after_first_wait(event, timeout=None):
            waits["n"] += 1
            if waits["n"] == 2:
                self.hold_lock_elsewhere("SELECT pg_advisory_unlock(%s, %s)")
            return False

        with mock.patch("threading.Event.wait", release_after_first_wait), self.assertLogs(LOGGER, level="INFO") as logs:
            run_command(AUTO, "--iterations", "4")

        log = "\n".join(logs.output)
        self.assertEqual(log.count("Outra instância do simulador está ativa"), 1)
        self.assertIn("Trava obtida", log)
        # Ciclos 1 e 2 em espera (nada gravado); 3 e 4 gravam.
        self.assertEqual(self.centro.operational_statuses.count(), 2)
        self.assertEqual(lock_holders(), 0)

    def test_lock_is_released_after_a_normal_run(self):
        with mock.patch("threading.Event.wait", return_value=False), self.assertLogs(LOGGER, level="INFO"):
            run_command(AUTO, "--iterations", "2")
        self.assertEqual(lock_holders(), 0)
        self.assertEqual(self.centro.operational_statuses.count(), 2)

    def test_sigterm_finishes_the_cycle_restores_handlers_and_releases_the_lock(self):
        originals = {sig: signal.getsignal(sig) for sig in (signal.SIGINT, signal.SIGTERM)}
        real_wait = threading.Event.wait
        calls = {"n": 0}

        def wait_then_terminate(event, timeout=None):
            calls["n"] += 1
            os.kill(os.getpid(), signal.SIGTERM)
            return real_wait(event, 0)

        with mock.patch("threading.Event.wait", wait_then_terminate), self.assertLogs(LOGGER, level="INFO") as logs:
            run_command(AUTO)

        log = "\n".join(logs.output)
        self.assertEqual(calls["n"], 1)
        self.assertEqual(self.centro.operational_statuses.count(), 1)
        self.assertIn("SIGTERM recebido", log)
        self.assertIn("encerrada após 1 ciclo(s)", log)
        self.assertEqual({sig: signal.getsignal(sig) for sig in originals}, originals)
        self.assertEqual(lock_holders(), 0)


@demo_mode_on
@override_settings(DEMO_AUTO_UPDATE=True, DEMO_UPDATE_INTERVAL="60")
class PresentationScenariosTests(TestCase):
    def test_special_states_survive_the_automatic_update(self):
        run_command("seed_demo_scenarios")
        leste_before = latest_reading(HealthUnit.objects.get(external_id="upa-leste"))
        sudoeste_before = latest_reading(HealthUnit.objects.get(external_id="upa-sudoeste"))
        movement = ("upa-centro", "upa-sul", "upa-norte")
        counts_before = {
            external_id: UnitOperationalStatus.objects.filter(health_unit__external_id=external_id).count()
            for external_id in movement
        }

        with mock.patch("threading.Event.wait", return_value=False), self.assertLogs(LOGGER, level="INFO"):
            run_command(AUTO, "--iterations", "3", "--seed", "2")

        def latest(external_id):
            return latest_reading(HealthUnit.objects.get(external_id=external_id))

        self.assertEqual(update_state(latest("upa-oeste")), MISSING)
        self.assertEqual(latest("upa-leste").pk, leste_before.pk)
        self.assertEqual(update_state(latest("upa-leste")), STALE)
        self.assertEqual(latest("upa-sudoeste").pk, sudoeste_before.pk)
        self.assertEqual(scenario_of(latest("upa-sudoeste")), "unavailable")
        nordeste = latest("upa-nordeste")
        self.assertEqual((scenario_of(nordeste), update_state(nordeste)), ("critical", CURRENT))
        for external_id in movement:
            unit = HealthUnit.objects.get(external_id=external_id)
            self.assertEqual(unit.operational_statuses.count(), counts_before[external_id] + 3, external_id)
            self.assertEqual(update_state(latest(external_id)), CURRENT)
