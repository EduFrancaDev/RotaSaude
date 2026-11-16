from django.test import TestCase
from django.urls import reverse

from apps.units.models import UnitOperationalStatus
from apps.units.tests.helpers import make_status, make_unit

Level = UnitOperationalStatus.AvailabilityLevel


class UnitListTests(TestCase):
    def setUp(self):
        self.url = reverse("v1:unit-list")

    def test_list_is_paginated_and_exposes_public_id(self):
        make_unit("upa-centro", services=["Pediatria", "Clínica geral"], phone="(62) 0000-0000")

        response = self.client.get(self.url)

        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertEqual(set(body), {"count", "next", "previous", "results"})
        self.assertEqual(body["count"], 1)
        unit = body["results"][0]
        self.assertEqual(unit["id"], "upa-centro")
        self.assertEqual(unit["city"], "Goiânia")
        self.assertEqual(unit["latitude"], -16.68)
        self.assertEqual(unit["longitude"], -49.26)
        self.assertEqual(unit["phone"], "(62) 0000-0000")
        self.assertEqual(unit["services"], ["Clínica geral", "Pediatria"])

    def test_page_size_is_configurable_and_capped(self):
        for i in range(3):
            make_unit(f"u{i}")

        body = self.client.get(self.url, {"page_size": 2}).json()

        self.assertEqual(body["count"], 3)
        self.assertEqual(len(body["results"]), 2)
        self.assertIsNotNone(body["next"])

    def test_inactive_units_are_hidden(self):
        make_unit("ativa")
        make_unit("inativa", is_active=False)

        ids = [u["id"] for u in self.client.get(self.url).json()["results"]]

        self.assertEqual(ids, ["ativa"])

    def test_filter_by_city_ignores_case(self):
        make_unit("go", city="Goiânia")
        make_unit("ap", city="Aparecida de Goiânia")

        body = self.client.get(self.url, {"city": "goiânia"}).json()

        self.assertEqual([u["id"] for u in body["results"]], ["go"])

    def test_filter_by_service(self):
        make_unit("a", services=["Pediatria", "Ortopedia"])
        make_unit("b", services=["Ortopedia"])
        make_unit("c", services=["Pediatria"])

        body = self.client.get(self.url, {"service": "pediatria"}).json()

        self.assertEqual(sorted(u["id"] for u in body["results"]), ["a", "c"])
        # O filtro não esconde os demais serviços da unidade.
        self.assertEqual(
            next(u for u in body["results"] if u["id"] == "a")["services"], ["Ortopedia", "Pediatria"]
        )

    def test_combined_filters(self):
        make_unit("a", city="Goiânia", services=["Pediatria"])
        make_unit("b", city="Aparecida de Goiânia", services=["Pediatria"])

        body = self.client.get(self.url, {"city": "Goiânia", "service": "Pediatria"}).json()

        self.assertEqual([u["id"] for u in body["results"]], ["a"])

    def test_unit_without_operational_data_has_null_fields(self):
        make_unit("upa-oeste")

        unit = self.client.get(self.url).json()["results"][0]

        self.assertIsNone(unit["operational_status"])
        self.assertIsNone(unit["last_operational_update_at"])

    def test_returns_latest_operational_status_by_source_time(self):
        unit = make_unit("upa-centro")
        make_status(unit, hour=8, people_waiting=50, availability_level=Level.LOW)
        make_status(unit, hour=12, people_waiting=10, estimated_wait_minutes=15, availability_level=Level.HIGH)
        # Chegou depois, mas a fonte a mediu antes: não pode substituir a mais recente.
        make_status(unit, hour=9, people_waiting=40, availability_level=Level.LOW)

        data = self.client.get(self.url).json()["results"][0]

        status = data["operational_status"]
        self.assertEqual(status["people_waiting"], 10)
        self.assertEqual(status["estimated_wait_minutes"], 15)
        self.assertEqual(status["availability_level"], "HIGH")
        self.assertEqual(data["last_operational_update_at"], status["source_updated_at"])
        self.assertTrue(status["source_updated_at"].startswith("2026-11-10T09:00:00"))  # 12h UTC em UTC-3
        self.assertIn("received_at", status)

    def test_partial_operational_data_is_preserved_as_null(self):
        unit = make_unit("parcial")
        make_status(unit, people_waiting=None, estimated_wait_minutes=None, availability_level=None)

        status = self.client.get(self.url).json()["results"][0]["operational_status"]

        self.assertIsNone(status["people_waiting"])
        self.assertIsNone(status["estimated_wait_minutes"])
        self.assertIsNone(status["availability_level"])

    def test_list_has_constant_query_count(self):
        for i in range(2):
            unit = make_unit(f"a{i}", services=["Pediatria", "Ortopedia"])
            make_status(unit, hour=8)
            make_status(unit, hour=9)

        with self.assertNumQueries(4):  # count + unidades + serviços + status
            self.client.get(self.url)

        for i in range(10):
            unit = make_unit(f"b{i}", services=["Pediatria", "Ortopedia"])
            make_status(unit, hour=8)
            make_status(unit, hour=9)

        with self.assertNumQueries(4):
            self.client.get(self.url)


class UnitDetailTests(TestCase):
    def test_detail_by_external_id(self):
        unit = make_unit("upa-centro", services=["Pediatria"], opening_hours="24 horas")
        make_status(unit, hour=10)

        response = self.client.get(reverse("v1:unit-detail", args=["upa-centro"]))

        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertEqual(body["id"], "upa-centro")
        self.assertEqual(body["opening_hours"], "24 horas")
        self.assertEqual(body["services"], ["Pediatria"])
        self.assertEqual(body["operational_status"]["people_waiting"], 5)

    def test_detail_does_not_accept_internal_uuid(self):
        unit = make_unit("upa-centro")

        response = self.client.get(reverse("v1:unit-detail", args=[str(unit.id)]))

        self.assertEqual(response.status_code, 404)

    def test_detail_without_operational_data(self):
        make_unit("upa-oeste")

        body = self.client.get(reverse("v1:unit-detail", args=["upa-oeste"])).json()

        self.assertIsNone(body["operational_status"])

    def test_unknown_or_inactive_unit_is_404(self):
        make_unit("inativa", is_active=False)

        self.assertEqual(self.client.get(reverse("v1:unit-detail", args=["nao-existe"])).status_code, 404)
        self.assertEqual(self.client.get(reverse("v1:unit-detail", args=["inativa"])).status_code, 404)


class PublicEndpointsAreReadOnlyTests(TestCase):
    def setUp(self):
        make_unit("upa-centro")
        self.urls = [
            reverse("v1:unit-list"),
            reverse("v1:unit-detail", args=["upa-centro"]),
            reverse("v1:service-list"),
        ]

    def test_write_methods_are_rejected(self):
        for url in self.urls:
            for method in ("post", "put", "patch", "delete"):
                with self.subTest(url=url, method=method):
                    response = getattr(self.client, method)(url, data={}, content_type="application/json")
                    self.assertEqual(response.status_code, 405)

    def test_nothing_was_created_or_changed(self):
        from apps.units.models import HealthUnit

        self.client.post(self.urls[0], data={"external_id": "x"}, content_type="application/json")
        self.client.delete(self.urls[1])

        self.assertEqual(list(HealthUnit.objects.values_list("external_id", flat=True)), ["upa-centro"])
