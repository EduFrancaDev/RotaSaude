from datetime import timedelta

from django.core.cache import cache
from django.test import override_settings
from django.utils import timezone

from apps.integrations.models import IntegrationCredential
from apps.integrations.tests.helpers import IngestTestCase
from apps.units.models import UnitOperationalStatus
from apps.units.tests.helpers import make_unit


class UnitAuthorizationTests(IngestTestCase):
    def test_other_existing_and_unknown_units_get_identical_403(self):
        make_unit("upa-sul")

        other = self.post(self.payload(unit_id="upa-sul"))
        unknown = self.post(self.payload(unit_id="nao-existe"))

        self.assertEqual(other.status_code, 403)
        self.assertEqual(other.json(), unknown.json())
        self.assertFalse(UnitOperationalStatus.objects.exists())

    def test_unit_id_is_required(self):
        data = self.payload()
        del data["unit_id"]

        response = self.post(data)

        self.assertEqual(response.status_code, 400)
        self.assertIn("unit_id", response.json())

    def test_inactive_unit_is_rejected(self):
        self.unit.is_active = False
        self.unit.save()

        self.assertEqual(self.post().status_code, 403)


class ValidPayloadTests(IngestTestCase):
    def test_valid_reading_is_created(self):
        response = self.post()

        self.assertEqual(response.status_code, 201)
        body = response.json()
        self.assertEqual(body["result"], "created")
        self.assertTrue(body["is_latest"])
        status = body["operational_status"]
        self.assertEqual(
            (status["people_waiting"], status["estimated_wait_minutes"], status["availability_level"]),
            (18, 20, "HIGH"),
        )
        reading = UnitOperationalStatus.objects.get()
        self.assertEqual(reading.health_unit, self.unit)
        self.assertIsNotNone(reading.received_at)  # gerado pelo servidor

    def test_all_four_levels_are_accepted(self):
        for i, level in enumerate(["HIGH", "MODERATE", "LOW", "CRITICAL"]):
            with self.subTest(level=level):
                self.assertEqual(self.post(self.payload(minutes=i, availability_level=level)).status_code, 201)

    def test_zero_is_valid(self):
        response = self.post(self.payload(people_waiting=0, estimated_wait_minutes=0))

        self.assertEqual(response.status_code, 201)

    def test_null_fields_mean_unavailable_and_are_not_invented(self):
        response = self.post(
            self.payload(people_waiting=None, estimated_wait_minutes=None, availability_level=None)
        )

        self.assertEqual(response.status_code, 201)
        status = self.public_unit()["operational_status"]
        self.assertIsNone(status["people_waiting"])
        self.assertIsNone(status["estimated_wait_minutes"])
        self.assertIsNone(status["availability_level"])

    def test_partial_nulls_are_accepted(self):
        response = self.post(self.payload(estimated_wait_minutes=None))

        self.assertEqual(response.status_code, 201)
        self.assertEqual(response.json()["operational_status"]["people_waiting"], 18)
        self.assertIsNone(response.json()["operational_status"]["estimated_wait_minutes"])

    def test_omitted_data_field_is_rejected_not_treated_as_null(self):
        data = self.payload()
        del data["people_waiting"]

        response = self.post(data)

        self.assertEqual(response.status_code, 400)
        self.assertIn("people_waiting", response.json())

    def test_reading_from_real_unit_is_not_demo_and_from_demo_unit_is_demo(self):
        self.post()
        demo_unit = make_unit("upa-demo", is_demo=True)
        _, demo_token = IntegrationCredential.issue(demo_unit, "Demo")
        self.post(self.payload(unit_id="upa-demo"), token=demo_token)

        self.assertFalse(self.public_unit()["operational_status"]["is_demo"])
        demo = self.public_unit("upa-demo")
        self.assertTrue(demo["is_demo"] and demo["operational_status"]["is_demo"])


class InvalidPayloadTests(IngestTestCase):
    def assert_rejected(self, data, field):
        response = self.post(data)
        self.assertEqual(response.status_code, 400, response.content)
        self.assertIn(field, response.json())
        self.assertFalse(UnitOperationalStatus.objects.exists())

    def test_negative_values(self):
        self.assert_rejected(self.payload(people_waiting=-1), "people_waiting")
        self.assert_rejected(self.payload(estimated_wait_minutes=-1), "estimated_wait_minutes")

    def test_non_integer_and_absurd_values(self):
        self.assert_rejected(self.payload(people_waiting="muitas"), "people_waiting")
        self.assert_rejected(self.payload(people_waiting=1.5), "people_waiting")
        self.assert_rejected(self.payload(people_waiting=True), "people_waiting")
        self.assert_rejected(self.payload(people_waiting=10**12), "people_waiting")
        self.assert_rejected(self.payload(estimated_wait_minutes=10**9), "estimated_wait_minutes")

    def test_unknown_availability_level(self):
        for bad in ["high", "EXCELLENT", "", 1]:
            with self.subTest(level=bad):
                self.assert_rejected(self.payload(availability_level=bad), "availability_level")

    def test_invalid_dates(self):
        for bad in ["ontem", "2026-13-45T10:00:00-03:00", 12345, "", None]:
            with self.subTest(value=bad):
                self.assert_rejected(self.payload(source_updated_at=bad), "source_updated_at")

    def test_date_without_timezone_is_rejected(self):
        naive = (self.base).replace(tzinfo=None).isoformat()
        self.assert_rejected(self.payload(source_updated_at=naive), "source_updated_at")
        self.assert_rejected(self.payload(source_updated_at="2026-11-11"), "source_updated_at")

    def test_future_date_beyond_tolerance_is_rejected(self):
        future = timezone.now() + timedelta(minutes=6)
        self.assert_rejected(self.payload(source_updated_at=future.isoformat()), "source_updated_at")

    def test_future_date_within_tolerance_is_accepted(self):
        near = timezone.now() + timedelta(minutes=4)

        self.assertEqual(self.post(self.payload(source_updated_at=near.isoformat())).status_code, 201)

    def test_other_timezone_offsets_are_normalized(self):
        sp = "2026-11-10T09:30:00-03:00"
        utc = "2026-11-10T12:30:00Z"
        self.assertEqual(self.post(self.payload(source_updated_at=sp)).status_code, 201)

        response = self.post(self.payload(source_updated_at=utc))  # mesmo instante

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["result"], "duplicate")

    def test_unknown_fields_are_rejected_including_personal_data(self):
        for extra in ({"patient_name": "Fulano"}, {"cpf": "000"}, {"received_at": "2020-01-01T00:00:00Z"}, {"is_demo": True}):
            with self.subTest(extra=list(extra)):
                response = self.post(self.payload(**extra))
                self.assertEqual(response.status_code, 400)
                self.assertIn(next(iter(extra)), response.json())
        self.assertFalse(UnitOperationalStatus.objects.exists())

    def test_non_object_and_non_json_bodies(self):
        self.assertEqual(self.post([1, 2, 3]).status_code, 400)
        form = self.client.post(self.url, data=self.payload(), HTTP_AUTHORIZATION=f"Bearer {self.token}")
        self.assertEqual(form.status_code, 415)


class IdempotencyAndOrderingTests(IngestTestCase):
    def test_identical_resend_does_not_duplicate(self):
        first = self.post()
        second = self.post()

        self.assertEqual((first.status_code, second.status_code), (201, 200))
        self.assertEqual(second.json()["result"], "duplicate")
        self.assertEqual(second.json()["operational_status"], first.json()["operational_status"])
        self.assertEqual(UnitOperationalStatus.objects.count(), 1)

    def test_same_timestamp_with_different_values_is_409_and_keeps_original(self):
        self.post()

        response = self.post(self.payload(people_waiting=99, availability_level="CRITICAL"))

        self.assertEqual(response.status_code, 409)
        self.assertEqual(response.json()["code"], "conflicting_reading")
        self.assertEqual(response.json()["existing"]["people_waiting"], 18)
        self.assertEqual(UnitOperationalStatus.objects.count(), 1)
        reading = UnitOperationalStatus.objects.get()
        self.assertEqual((reading.people_waiting, reading.availability_level), (18, "HIGH"))
        self.assertEqual(self.public_unit()["operational_status"]["people_waiting"], 18)

    def test_null_versus_value_at_same_timestamp_is_a_conflict(self):
        self.post()

        response = self.post(self.payload(people_waiting=None))

        self.assertEqual(response.status_code, 409)

    def test_newer_reading_becomes_the_public_latest(self):
        self.post()

        response = self.post(self.payload(minutes=10, people_waiting=5, availability_level="LOW"))

        self.assertEqual(response.status_code, 201)
        self.assertTrue(response.json()["is_latest"])
        status = self.public_unit()["operational_status"]
        self.assertEqual((status["people_waiting"], status["availability_level"]), (5, "LOW"))

    def test_older_reading_is_stored_but_never_presented_as_latest(self):
        self.post(self.payload(minutes=10, people_waiting=5, availability_level="LOW"))

        response = self.post(self.payload(minutes=0, people_waiting=40, availability_level="HIGH"))

        self.assertEqual(response.status_code, 201)
        self.assertFalse(response.json()["is_latest"])
        self.assertEqual(UnitOperationalStatus.objects.count(), 2)
        public = self.public_unit()
        self.assertEqual(public["operational_status"]["people_waiting"], 5)
        self.assertEqual(public["last_operational_update_at"], public["operational_status"]["source_updated_at"])

    def test_history_is_preserved_in_order_of_arrival_independent_of_source_time(self):
        for minutes, people in [(0, 10), (20, 30), (10, 20)]:
            self.post(self.payload(minutes=minutes, people_waiting=people))

        readings = UnitOperationalStatus.objects.order_by("source_updated_at")
        self.assertEqual([r.people_waiting for r in readings], [10, 20, 30])
        self.assertEqual(self.public_unit()["operational_status"]["people_waiting"], 30)

    def test_received_at_is_server_time_not_source_time(self):
        before = timezone.now()
        self.post(self.payload(minutes=-600))
        reading = UnitOperationalStatus.objects.get()

        self.assertGreaterEqual(reading.received_at, before)
        self.assertLess(reading.source_updated_at, before - timedelta(hours=5))

    def test_each_unit_keeps_its_own_history(self):
        other = make_unit("upa-sul")
        _, other_token = IntegrationCredential.issue(other, "Sul")

        self.post()
        self.post(self.payload(unit_id="upa-sul", people_waiting=1), token=other_token)  # mesmo instante

        self.assertEqual(UnitOperationalStatus.objects.count(), 2)
        self.assertEqual(self.public_unit("upa-sul")["operational_status"]["people_waiting"], 1)
        self.assertEqual(self.public_unit()["operational_status"]["people_waiting"], 18)


class ThrottleTests(IngestTestCase):
    @override_settings(INTEGRATION_RATE_LIMIT="2/min")
    def test_limit_is_per_credential(self):
        other = make_unit("upa-sul")
        _, other_token = IntegrationCredential.issue(other, "Sul")

        statuses = [self.post(self.payload(minutes=i)).status_code for i in range(3)]
        limited = self.post(self.payload(minutes=3))
        unaffected = self.post(self.payload(unit_id="upa-sul"), token=other_token)

        self.assertEqual(statuses, [201, 201, 429])
        self.assertEqual(limited.status_code, 429)
        self.assertIn("Retry-After", limited.headers)
        self.assertEqual(unaffected.status_code, 201)
        self.assertEqual(UnitOperationalStatus.objects.filter(health_unit=self.unit).count(), 2)

    @override_settings(INTEGRATION_RATE_LIMIT="1/min")
    def test_invalid_credentials_do_not_consume_a_valid_credentials_quota(self):
        self.post(token="rsi_invalida")
        self.post(token="rsi_invalida")

        self.assertEqual(self.post().status_code, 201)
        cache.clear()
