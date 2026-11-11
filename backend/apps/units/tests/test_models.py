from django.core.exceptions import ValidationError
from django.db import IntegrityError, transaction
from django.test import TestCase

from apps.services.models import Service
from apps.units.models import HealthUnit, HealthUnitService, UnitOperationalStatus
from apps.units.tests.helpers import make_status, make_unit


class OperationalStatusValidationTests(TestCase):
    def setUp(self):
        self.unit = make_unit()

    def build(self, **kwargs):
        return UnitOperationalStatus(
            health_unit=self.unit, source_updated_at="2026-11-10T10:00:00Z", **kwargs
        )

    def test_negative_people_waiting_is_invalid(self):
        with self.assertRaises(ValidationError) as ctx:
            self.build(people_waiting=-1).full_clean()
        self.assertIn("people_waiting", ctx.exception.message_dict)

    def test_negative_wait_minutes_is_invalid(self):
        with self.assertRaises(ValidationError) as ctx:
            self.build(estimated_wait_minutes=-5).full_clean()
        self.assertIn("estimated_wait_minutes", ctx.exception.message_dict)

    def test_database_rejects_negative_values(self):
        with self.assertRaises(IntegrityError), transaction.atomic():
            UnitOperationalStatus.objects.create(
                health_unit=self.unit, source_updated_at="2026-11-10T10:00:00Z", people_waiting=-1
            )
        with self.assertRaises(IntegrityError), transaction.atomic():
            UnitOperationalStatus.objects.create(
                health_unit=self.unit, source_updated_at="2026-11-10T10:00:00Z", estimated_wait_minutes=-1
            )

    def test_invalid_availability_level_is_rejected(self):
        with self.assertRaises(ValidationError) as ctx:
            self.build(availability_level="EXCELLENT").full_clean()
        self.assertIn("availability_level", ctx.exception.message_dict)

    def test_all_operational_values_may_be_null(self):
        self.build(people_waiting=None, estimated_wait_minutes=None, availability_level=None).full_clean()

    def test_zero_is_valid(self):
        self.build(people_waiting=0, estimated_wait_minutes=0).full_clean()

    def test_history_is_preserved(self):
        make_status(self.unit, hour=8)
        make_status(self.unit, hour=9)

        self.assertEqual(self.unit.operational_statuses.count(), 2)

    def test_database_rejects_two_readings_at_the_same_source_instant(self):
        make_status(self.unit, hour=8)

        with self.assertRaises(IntegrityError), transaction.atomic():
            make_status(self.unit, hour=8)

        other_unit = make_unit("outra")
        make_status(other_unit, hour=8)  # outra unidade pode ter o mesmo instante

    def test_received_at_is_generated_by_server(self):
        status = make_status(self.unit)

        self.assertIsNotNone(status.received_at)
        self.assertFalse(UnitOperationalStatus._meta.get_field("received_at").editable)


class HealthUnitConstraintTests(TestCase):
    def test_external_id_is_unique(self):
        make_unit("upa-centro")

        with self.assertRaises(IntegrityError), transaction.atomic():
            make_unit("upa-centro")

    def test_duplicate_unit_service_link_is_rejected(self):
        unit = make_unit("upa-centro")
        service = Service.objects.create(name="Pediatria")
        HealthUnitService.objects.create(health_unit=unit, service=service)

        with self.assertRaises(IntegrityError), transaction.atomic():
            HealthUnitService.objects.create(health_unit=unit, service=service)

    def test_service_name_is_unique(self):
        Service.objects.create(name="Pediatria")

        with self.assertRaises(IntegrityError), transaction.atomic():
            Service.objects.create(name="Pediatria")

    def test_invalid_coordinates_fail_validation(self):
        unit = HealthUnit(
            external_id="x", name="X", address="A", city="C", state="GO", latitude=120, longitude=-200
        )
        with self.assertRaises(ValidationError) as ctx:
            unit.full_clean()
        self.assertEqual({"latitude", "longitude"}, set(ctx.exception.message_dict))
