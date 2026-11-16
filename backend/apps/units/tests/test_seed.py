from datetime import datetime, timezone
from io import StringIO

from django.core.management import call_command
from django.test import TestCase
from django.urls import reverse

from apps.services.models import Service
from apps.units.models import HealthUnit, HealthUnitService, UnitOperationalStatus


def run_seed():
    out = StringIO()
    call_command("seed_demo_units", stdout=out)
    return out.getvalue()


class SeedDemoUnitsTests(TestCase):
    def counts(self):
        return (
            HealthUnit.objects.count(),
            Service.objects.count(),
            HealthUnitService.objects.count(),
            UnitOperationalStatus.objects.count(),
        )

    def test_creates_four_demo_units_with_original_ids(self):
        run_seed()

        ids = set(HealthUnit.objects.values_list("external_id", flat=True))
        self.assertEqual(ids, {"upa-centro", "upa-sul", "upa-norte", "upa-oeste"})
        self.assertTrue(all(u.is_demo and u.city == "Goiânia" for u in HealthUnit.objects.all()))
        self.assertEqual(Service.objects.count(), 3)
        self.assertEqual(HealthUnitService.objects.count(), 3 + 2 + 1 + 2)

    def test_preserves_original_fixture_data(self):
        run_seed()

        centro = HealthUnit.objects.get(external_id="upa-centro")
        self.assertEqual(centro.name, "UPA Exemplo Centro")
        self.assertEqual((centro.latitude, centro.longitude), (-16.6862, -49.2640))
        self.assertEqual(
            set(centro.services.values_list("name", flat=True)), {"Clínica geral", "Pediatria", "Ortopedia"}
        )
        status = centro.operational_statuses.get()
        self.assertEqual(
            (status.availability_level, status.estimated_wait_minutes, status.people_waiting), ("HIGH", 20, 18)
        )
        self.assertTrue(status.is_demo)

    def test_oeste_has_no_operational_data(self):
        run_seed()

        oeste = HealthUnit.objects.get(external_id="upa-oeste")
        self.assertFalse(oeste.operational_statuses.exists())
        body = self.client.get(reverse("v1:unit-detail", args=["upa-oeste"])).json()
        self.assertIsNone(body["operational_status"])
        self.assertTrue(body["is_demo"])

    def test_is_idempotent(self):
        run_seed()
        first = self.counts()

        output = run_seed()

        self.assertEqual(self.counts(), first)
        self.assertEqual(first, (4, 3, 8, 3))
        self.assertIn("0 unidade(s)", output)
        self.assertIn("0 leitura(s)", output)

    def test_reseed_restores_demo_fields_without_duplicating(self):
        run_seed()
        HealthUnit.objects.filter(external_id="upa-sul").update(name="Alterada")

        run_seed()

        self.assertEqual(HealthUnit.objects.get(external_id="upa-sul").name, "UPA Exemplo Sul")
        self.assertEqual(HealthUnit.objects.count(), 4)

    def test_reseed_does_not_override_newer_readings(self):
        run_seed()
        oeste = HealthUnit.objects.get(external_id="upa-oeste")
        UnitOperationalStatus.objects.create(
            health_unit=oeste,
            people_waiting=7,
            source_updated_at=datetime(2026, 11, 11, 9, 0, tzinfo=timezone.utc),
            is_demo=True,
        )

        run_seed()

        self.assertEqual(oeste.operational_statuses.count(), 1)
        body = self.client.get(reverse("v1:unit-detail", args=["upa-oeste"])).json()
        self.assertEqual(body["operational_status"]["people_waiting"], 7)

    def test_output_labels_data_as_demo(self):
        self.assertIn("DEMONSTRATIVO", run_seed())
