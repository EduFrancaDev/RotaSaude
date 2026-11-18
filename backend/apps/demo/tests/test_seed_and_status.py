from datetime import timedelta

from django.core.management.base import CommandError
from django.test import TestCase
from django.urls import reverse
from django.utils import timezone

from apps.demo.models import DemoReadingMark
from apps.demo.profiles import PROFILES
from apps.demo.readings import CURRENT, MISSING, STALE, latest_reading, update_state
from apps.demo.tests.helpers import demo_mode_on, run_command
from apps.units.models import HealthUnit, UnitOperationalStatus
from apps.units.tests.helpers import make_status, make_unit

SEED = "seed_demo_scenarios"


@demo_mode_on
class SeedScenariosTests(TestCase):
    def counts(self):
        return (HealthUnit.objects.count(), UnitOperationalStatus.objects.count(), DemoReadingMark.objects.count())

    def state(self, external_id):
        unit = HealthUnit.objects.get(external_id=external_id)
        return update_state(latest_reading(unit))

    def test_prepares_every_role(self):
        run_command(SEED)

        self.assertEqual(set(HealthUnit.objects.values_list("external_id", flat=True)), set(PROFILES))
        self.assertTrue(all(u.is_demo for u in HealthUnit.objects.all()))
        scenarios = {
            ext: latest_reading(HealthUnit.objects.get(external_id=ext)).demo_mark.scenario
            for ext in ("upa-centro", "upa-sul", "upa-norte", "upa-nordeste")
        }
        self.assertEqual(scenarios, {"upa-centro": "low", "upa-sul": "moderate", "upa-norte": "high", "upa-nordeste": "critical"})
        self.assertEqual(self.state("upa-centro"), CURRENT)
        self.assertEqual(self.state("upa-leste"), STALE)  # informações desatualizadas
        self.assertEqual(self.state("upa-sudoeste"), MISSING)  # falha de atualização
        self.assertEqual(HealthUnit.objects.get(external_id="upa-oeste").operational_statuses.count(), 0)

    def test_is_idempotent(self):
        run_command(SEED)
        first = self.counts()

        out, _ = run_command(SEED)

        self.assertEqual(self.counts(), first)
        self.assertIn("já preparada", out)

    def test_failure_unit_had_good_data_before_failing(self):
        run_command(SEED)
        unit = HealthUnit.objects.get(external_id="upa-sudoeste")
        readings = list(unit.operational_statuses.order_by("source_updated_at"))
        self.assertEqual([r.demo_mark.scenario for r in readings], ["moderate", "unavailable"])
        self.assertTrue(all(r.source_updated_at <= timezone.now() for r in readings))

    def test_stale_unit_timestamps_are_past_and_old(self):
        run_command(SEED)
        unit = HealthUnit.objects.get(external_id="upa-leste")
        newest = latest_reading(unit)
        self.assertGreater(timezone.now() - newest.source_updated_at, timedelta(hours=2))

    def test_never_touches_non_demo_units(self):
        real = make_unit("hospital-real", is_demo=False, name="Hospital Real")
        make_status(real, hour=8)
        before_unit = HealthUnit.objects.filter(pk=real.pk).values().get()
        before_readings = list(UnitOperationalStatus.objects.filter(health_unit=real).values())

        run_command(SEED)
        run_command(SEED)

        self.assertEqual(HealthUnit.objects.filter(pk=real.pk).values().get(), before_unit)
        self.assertEqual(list(UnitOperationalStatus.objects.filter(health_unit=real).values()), before_readings)
        self.assertFalse(DemoReadingMark.objects.filter(status__health_unit=real).exists())

    def test_refuses_to_take_over_a_real_units_id(self):
        make_unit("upa-centro", is_demo=False, name="UPA Real")

        with self.assertRaisesMessage(CommandError, "NÃO demonstrativas"):
            run_command(SEED)

        self.assertEqual(self.counts(), (1, 0, 0))
        self.assertFalse(HealthUnit.objects.get().is_demo)

    def test_keeps_existing_readings_and_does_not_apply_absence_roles_over_them(self):
        run_command("seed_demo_units")
        oeste = HealthUnit.objects.get(external_id="upa-oeste")
        reading = UnitOperationalStatus.objects.create(
            health_unit=oeste, people_waiting=7, source_updated_at=timezone.now() - timedelta(minutes=1), is_demo=True)
        centro_seed_reading = HealthUnit.objects.get(external_id="upa-centro").operational_statuses.get()

        out, _ = run_command(SEED)

        self.assertEqual(oeste.operational_statuses.get(), reading)
        self.assertIn("mantida", out)
        # A leitura original do seed continua no histórico; o cenário entra por cima como nova leitura.
        centro = HealthUnit.objects.get(external_id="upa-centro")
        self.assertEqual(centro.operational_statuses.count(), 2)
        self.assertTrue(centro.operational_statuses.filter(pk=centro_seed_reading.pk).exists())

    def test_public_api_shows_the_prepared_scenarios(self):
        run_command(SEED)
        body = self.client.get(reverse("v1:unit-detail", args=["upa-nordeste"])).json()
        self.assertEqual(body["operational_status"]["availability_level"], "CRITICAL")
        self.assertEqual(body["operational_status"]["people_waiting"], 64)
        listing = self.client.get(reverse("v1:unit-list"), {"city": "Goiânia", "page_size": 100}).json()
        self.assertEqual(listing["count"], 7)


@demo_mode_on
class ShowDemoStatusTests(TestCase):
    def test_lists_units_scenarios_and_update_state(self):
        run_command(SEED)

        out, _ = run_command("show_demo_status")

        for text in ("upa-centro", "A · Movimento baixo", "D · Situação crítica", "atualização: atual",
                     "atualização: desatualizada", "atualização: sem dados", "sem leituras operacionais",
                     "pessoas: 64", "espera: 110 min", "disponibilidade: CRITICAL"):
            self.assertIn(text, out)

    def test_excludes_real_units(self):
        make_unit("hospital-real", is_demo=False, name="Hospital Real")
        run_command(SEED)
        out, _ = run_command("show_demo_status")
        self.assertNotIn("hospital-real", out)

    def test_history_for_one_unit(self):
        run_command(SEED)
        run_command("simulate_operational_status", "--unit", "upa-centro", "--scenario", "critical")

        out, _ = run_command("show_demo_status", "--unit", "upa-centro", "--history", "5")

        self.assertIn("histórico", out)
        self.assertIn("critical", out)
        self.assertIn("low", out)
        self.assertNotIn("upa-sul", out)

    def test_marks_readings_without_scenario(self):
        run_command("seed_demo_units")
        out, _ = run_command("show_demo_status", "--unit", "upa-centro")
        self.assertIn("sem marca (seed/integração)", out)

    def test_errors(self):
        make_unit("hospital-real", is_demo=False)
        for args in (["--unit", "hospital-real"], ["--unit", "nada"], ["--history", "3"]):
            with self.assertRaises(CommandError, msg=args):
                run_command("show_demo_status", *args)

    def test_read_only(self):
        run_command(SEED)
        before = (UnitOperationalStatus.objects.count(), DemoReadingMark.objects.count())
        run_command("show_demo_status", "--unit", "upa-centro", "--history", "3")
        self.assertEqual((UnitOperationalStatus.objects.count(), DemoReadingMark.objects.count()), before)


class UpdateStateTests(TestCase):
    def test_classification_matches_the_app_rule(self):
        unit = make_unit("u", is_demo=True)
        now = timezone.now()
        make = lambda **kw: UnitOperationalStatus(health_unit=unit, **kw)  # noqa: E731

        self.assertEqual(update_state(None), MISSING)
        self.assertEqual(update_state(make(source_updated_at=now)), MISSING)  # todos os campos nulos
        self.assertEqual(update_state(make(source_updated_at=now - timedelta(minutes=29), people_waiting=1), now), CURRENT)
        self.assertEqual(update_state(make(source_updated_at=now - timedelta(minutes=31), people_waiting=1), now), STALE)
        self.assertEqual(update_state(make(source_updated_at=now + timedelta(minutes=10), people_waiting=1), now), STALE)
