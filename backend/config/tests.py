from unittest import mock

from django.db.utils import OperationalError
from django.test import TestCase
from django.urls import reverse


class HealthCheckTests(TestCase):
    def test_health_ok(self):
        response = self.client.get(reverse("v1:health"))

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json(), {"status": "ok", "database": "ok"})

    def test_health_reports_database_failure(self):
        with mock.patch("config.views.connection.cursor", side_effect=OperationalError("down")):
            response = self.client.get(reverse("v1:health"))

        self.assertEqual(response.status_code, 503)
        self.assertEqual(response.json(), {"status": "error", "database": "unavailable"})

    def test_health_url_is_versioned(self):
        self.assertEqual(reverse("v1:health"), "/api/v1/health/")


class CorsTests(TestCase):
    def test_origin_not_listed_gets_no_cors_header(self):
        response = self.client.get(
            reverse("v1:service-list"), headers={"Origin": "https://evil.example"}
        )
        self.assertNotIn("Access-Control-Allow-Origin", response.headers)

    def test_listed_origin_is_allowed(self):
        with self.settings(CORS_ALLOWED_ORIGINS=["https://app.example"]):
            response = self.client.options(
                reverse("v1:service-list"),
                headers={"Origin": "https://app.example", "Access-Control-Request-Method": "GET"},
            )
        self.assertEqual(response.headers.get("Access-Control-Allow-Origin"), "https://app.example")
