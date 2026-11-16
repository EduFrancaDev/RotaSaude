from django.contrib.auth import get_user_model
from django.urls import reverse

from apps.integrations.tests.helpers import IngestTestCase
from apps.units.models import HealthUnit, UnitOperationalStatus


class ExistingEndpointsPermissionTests(IngestTestCase):
    """A chave de integração não ganha nenhum poder fora do endpoint de ingestão."""

    def bearer(self):
        return {"HTTP_AUTHORIZATION": f"Bearer {self.token}"}

    def test_public_endpoints_still_reject_writes_even_with_a_valid_key(self):
        urls = [
            reverse("v1:unit-list"),
            reverse("v1:unit-detail", args=["upa-centro"]),
            reverse("v1:service-list"),
        ]
        for url in urls:
            for method in ("post", "put", "patch", "delete"):
                with self.subTest(url=url, method=method):
                    response = getattr(self.client, method)(
                        url, data=self.payload(), content_type="application/json", **self.bearer()
                    )
                    self.assertEqual(response.status_code, 405)
        self.assertFalse(UnitOperationalStatus.objects.exists())
        self.assertEqual(HealthUnit.objects.count(), 1)

    def test_public_reads_ignore_the_key(self):
        anonymous = self.client.get(reverse("v1:unit-list")).json()
        with_key = self.client.get(reverse("v1:unit-list"), **self.bearer()).json()
        with_bad_key = self.client.get(reverse("v1:unit-list"), HTTP_AUTHORIZATION="Bearer invalida")

        self.assertEqual(anonymous, with_key)
        self.assertEqual(with_bad_key.status_code, 200)

    def test_health_check_unchanged(self):
        self.assertEqual(self.client.get(reverse("v1:health")).status_code, 200)

    def test_key_does_not_open_the_admin(self):
        for path in ["/admin/", "/admin/units/healthunit/", "/admin/integrations/integrationcredential/"]:
            with self.subTest(path=path):
                response = self.client.get(path, **self.bearer())
                self.assertEqual(response.status_code, 302)
                self.assertIn("/admin/login/", response["Location"])

    def test_ingest_endpoint_accepts_only_post(self):
        for method in ("get", "put", "patch", "delete"):
            with self.subTest(method=method):
                response = getattr(self.client, method)(self.url, **self.bearer())
                self.assertEqual(response.status_code, 405)

    def test_session_login_does_not_replace_the_key(self):
        user = get_user_model().objects.create_superuser("admin", password="senha-de-teste-123")
        self.client.force_login(user)

        response = self.post(token=None)

        self.assertEqual(response.status_code, 401)
