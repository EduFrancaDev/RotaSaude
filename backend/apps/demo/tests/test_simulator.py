import os
import signal
import threading
from datetime import timedelta
from unittest import mock

from django.core.management.base import CommandError
from django.test import TestCase
from django.urls import reverse
from django.utils import timezone

from apps.demo.models import DemoReadingMark
from apps.demo.readings import DemoReadingError, append_demo_reading
from apps.demo.scenarios import SCENARIOS
from apps.demo.tests.helpers import demo_mode_on, run_command
from apps.units.models import HealthUnit, UnitOperationalStatus
from apps.units.tests.helpers import make_status, make_unit

SIMULATE = "simulate_operational_status"


@demo_mode_on
class ScenarioDefinitionTests(TestCase):
    def test_scenarios_match_the_specification(self):
        expected = {
            "low": (8, 15, "HIGH"),
            "moderate": (27, 45, "MODERATE"),
            "high": (48, 80, "LOW"),
            "critical": (64, 110, "CRITICAL"),
        }
        for key, values in expected.items():
            s = SCENARIOS[key]
            self.assertEqual((s.people_waiting, s.estimated_wait_minutes, s.availability_level), values)

    def test_update_failure_has_no_values(self):
        self.assertEqual(SCENARIOS["unavailable"].values, {
            "people_waiting": None, "estimated_wait_minutes": None, "availability_level": None})


@demo_mode_on
class SimulateTests(TestCase):
    def setUp(self):
        self.centro = make_unit("upa-centro", is_demo=True)
        self.sul = make_unit("upa-sul", is_demo=True)
        self.oeste = make_unit("upa-oeste", is_demo=True)  # reservada
        self.real = make_unit("hospital-real", is_demo=False)

    def detail(self, unit_id):
        return self.client.get(reverse("v1:unit-detail", args=[unit_id])).json()

    def test_single_unit_critical_scenario_reaches_the_public_api(self):
        out, _ = run_command(SIMULATE, "--unit", "upa-centro", "--scenario", "critical", "--once")

        reading = self.centro.operational_statuses.get()
        self.assertEqual((reading.people_waiting, reading.estimated_wait_minutes, reading.availability_level), (64, 110, "CRITICAL"))
        self.assertTrue(reading.is_demo)
        self.assertEqual(reading.demo_mark.scenario, "critical")
        status = self.detail("upa-centro")["operational_status"]
        self.assertEqual(status["availability_level"], "CRITICAL")
        self.assertTrue(status["is_demo"])
        self.assertIn("DEMONSTRATIVO", out)

    def test_public_contract_is_unchanged(self):
        run_command(SIMULATE, "--unit", "upa-centro", "--scenario", "low")
        body = self.detail("upa-centro")
        self.assertEqual(
            set(body["operational_status"]),
            {"people_waiting", "estimated_wait_minutes", "availability_level", "source_updated_at", "received_at", "is_demo"},
        )
        self.assertNotIn("demo_mark", body)

    def test_all_covers_scenario_units_but_not_reserved_or_real(self):
        run_command(SIMULATE, "--all", "--scenario", "moderate", "--once")

        self.assertEqual(self.centro.operational_statuses.count(), 1)
        self.assertEqual(self.sul.operational_statuses.count(), 1)
        self.assertEqual(self.oeste.operational_statuses.count(), 0)
        self.assertEqual(self.real.operational_statuses.count(), 0)

    def test_explicit_unit_can_target_a_reserved_unit(self):
        run_command(SIMULATE, "--unit", "upa-oeste", "--scenario", "low")
        self.assertEqual(self.oeste.operational_statuses.count(), 1)

    def test_real_unit_is_refused_and_nothing_is_written(self):
        with self.assertRaisesMessage(CommandError, "não é uma unidade demonstrativa"):
            run_command(SIMULATE, "--unit", "hospital-real", "--scenario", "low")
        with self.assertRaises(CommandError):
            run_command(SIMULATE, "--unit", "upa-centro", "--unit", "hospital-real", "--scenario", "low")
        self.assertEqual(UnitOperationalStatus.objects.count(), 0)

    def test_unknown_unit(self):
        with self.assertRaisesMessage(CommandError, "não encontrada"):
            run_command(SIMULATE, "--unit", "nao-existe", "--scenario", "low")

    def test_inactive_unit_is_refused(self):
        HealthUnit.objects.filter(pk=self.centro.pk).update(is_active=False)
        with self.assertRaisesMessage(CommandError, "inativa"):
            run_command(SIMULATE, "--unit", "upa-centro", "--scenario", "low")

    def test_real_unit_is_untouched_even_with_readings(self):
        make_status(self.real, hour=9)
        before = list(UnitOperationalStatus.objects.filter(health_unit=self.real).values())

        run_command(SIMULATE, "--all", "--scenario", "critical")

        self.assertEqual(list(UnitOperationalStatus.objects.filter(health_unit=self.real).values()), before)

    def test_history_is_kept_and_timestamps_are_strictly_increasing(self):
        make_status(self.centro, hour=9)
        first = list(self.centro.operational_statuses.values())

        for scenario in ("low", "high", "critical"):
            run_command(SIMULATE, "--unit", "upa-centro", "--scenario", scenario)

        readings = list(self.centro.operational_statuses.order_by("source_updated_at"))
        self.assertEqual(len(readings), 4)
        # A leitura anterior segue idêntica (mesmo id e mesmos valores).
        self.assertEqual(
            list(UnitOperationalStatus.objects.filter(pk=first[0]["id"]).values()), first
        )
        stamps = [r.source_updated_at for r in readings]
        self.assertEqual(stamps, sorted(set(stamps)))
        self.assertLessEqual(stamps[-1], timezone.now() + timedelta(minutes=5))
        # A mais nova é a exibida pela API.
        self.assertEqual(self.detail("upa-centro")["operational_status"]["availability_level"], "CRITICAL")

    def test_back_to_back_runs_do_not_conflict(self):
        for _ in range(5):
            run_command(SIMULATE, "--unit", "upa-centro", "--scenario", "moderate")
        stamps = list(self.centro.operational_statuses.values_list("source_updated_at", flat=True))
        self.assertEqual(len(stamps), len(set(stamps)))
        self.assertEqual(DemoReadingMark.objects.count(), 5)

    def test_update_failure_scenario_writes_null_reading(self):
        run_command(SIMULATE, "--unit", "upa-centro", "--scenario", "unavailable")
        status = self.detail("upa-centro")["operational_status"]
        self.assertEqual(
            (status["people_waiting"], status["estimated_wait_minutes"], status["availability_level"]),
            (None, None, None),
        )

    def test_random_never_repeats_the_previous_scenario(self):
        seen = []
        for _ in range(12):
            run_command(SIMULATE, "--unit", "upa-centro", "--scenario", "random", "--seed", "7")
            seen.append(self.centro.operational_statuses.order_by("-source_updated_at").first().demo_mark.scenario)
        self.assertTrue(all(a != b for a, b in zip(seen, seen[1:])))
        self.assertTrue(set(seen) <= {"low", "moderate", "high", "critical"})

    def test_baseline_uses_each_units_starting_scenario(self):
        run_command(SIMULATE, "--all", "--scenario", "baseline")
        self.assertEqual(self.centro.operational_statuses.get().demo_mark.scenario, "low")
        self.assertEqual(self.sul.operational_statuses.get().demo_mark.scenario, "moderate")

    def test_baseline_refused_for_reserved_unit(self):
        with self.assertRaisesMessage(CommandError, "Nenhuma leitura foi gravada"):
            run_command(SIMULATE, "--unit", "upa-oeste", "--scenario", "baseline")
        self.assertEqual(self.oeste.operational_statuses.count(), 0)

    def test_latest_reading_slightly_in_the_future_is_followed_not_overridden(self):
        future = timezone.now() + timedelta(minutes=2)
        UnitOperationalStatus.objects.create(health_unit=self.centro, source_updated_at=future, people_waiting=1, is_demo=True)
        run_command(SIMULATE, "--unit", "upa-centro", "--scenario", "low")
        newest = self.centro.operational_statuses.order_by("-source_updated_at").first()
        self.assertEqual(newest.source_updated_at, future + timedelta(seconds=1))
        self.assertEqual(newest.people_waiting, 8)

    def test_latest_reading_far_in_the_future_blocks_the_write(self):
        UnitOperationalStatus.objects.create(
            health_unit=self.centro, source_updated_at=timezone.now() + timedelta(hours=1), is_demo=True)
        with self.assertRaises(CommandError):
            run_command(SIMULATE, "--unit", "upa-centro", "--scenario", "low")
        self.assertEqual(self.centro.operational_statuses.count(), 1)

    def test_explicit_timestamp_must_be_newer_than_history(self):
        make_status(self.centro, hour=9)
        old = self.centro.operational_statuses.get().source_updated_at - timedelta(hours=1)
        with self.assertRaises(DemoReadingError):
            append_demo_reading(self.centro, "low", source_updated_at=old)
        self.assertEqual(self.centro.operational_statuses.count(), 1)

    def test_a_failed_mark_rolls_back_the_reading(self):
        with mock.patch("apps.demo.readings.DemoReadingMark.objects.create", side_effect=RuntimeError("boom")):
            with self.assertRaises(RuntimeError):
                append_demo_reading(self.centro, "low")
        self.assertEqual(UnitOperationalStatus.objects.count(), 0)


@demo_mode_on
class PeriodicSimulationTests(TestCase):
    def setUp(self):
        self.centro = make_unit("upa-centro", is_demo=True)
        self.sul = make_unit("upa-sul", is_demo=True)

    def test_interval_runs_the_requested_cycles_and_stops(self):
        with mock.patch("threading.Event.wait", return_value=False) as wait:
            out, _ = run_command(SIMULATE, "--all", "--scenario", "random", "--interval", "60", "--iterations", "3", "--seed", "1")

        self.assertEqual(UnitOperationalStatus.objects.count(), 6)
        wait.assert_called_with(60)
        self.assertEqual(wait.call_count, 2)
        self.assertIn("encerrada após 3 ciclo(s)", out)

    def test_signal_stops_the_loop_after_the_current_cycle(self):
        original = signal.getsignal(signal.SIGINT)
        calls = {"n": 0}
        real_wait = threading.Event.wait

        def wait_then_interrupt(event, timeout=None):
            # Durante a espera entre ciclos, o usuário aperta Ctrl+C (handler do comando).
            calls["n"] += 1
            os.kill(os.getpid(), signal.SIGINT)
            return real_wait(event, 0)

        with mock.patch("threading.Event.wait", wait_then_interrupt):
            out, _ = run_command(SIMULATE, "--unit", "upa-centro", "--scenario", "low", "--interval", "60")

        self.assertEqual(calls["n"], 1)
        self.assertEqual(self.centro.operational_statuses.count(), 1)
        self.assertIn("encerrada após 1 ciclo(s)", out)
        self.assertIs(signal.getsignal(signal.SIGINT), original)  # handler restaurado

    def test_invalid_options(self):
        for args in (
            ["--interval", "1"],
            ["--iterations", "2"],
            ["--interval", "10", "--iterations", "0"],
            ["--once", "--interval", "10"],
        ):
            with self.assertRaises(CommandError, msg=args):
                run_command(SIMULATE, "--unit", "upa-centro", "--scenario", "low", *args)
        self.assertEqual(UnitOperationalStatus.objects.count(), 0)

    def test_target_is_required(self):
        with self.assertRaises(CommandError):
            run_command(SIMULATE, "--scenario", "low")
