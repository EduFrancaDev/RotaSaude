from datetime import timedelta

from django.core.cache import cache
from django.test import TestCase
from django.urls import reverse
from django.utils import timezone

from apps.integrations.models import IntegrationCredential
from apps.units.tests.helpers import make_unit


class IngestTestCase(TestCase):
    """Base: unidade `upa-centro`, uma credencial válida e helpers de envio."""

    def setUp(self):
        cache.clear()  # zera os contadores do throttle
        self.url = reverse("v1:integration-operational-status")
        self.unit = make_unit("upa-centro")
        self.credential, self.token = IntegrationCredential.issue(self.unit, "Sistema de teste")
        # Instante base fixo no passado; leituras usam deslocamentos em minutos a partir dele.
        self.base = timezone.now().replace(microsecond=0) - timedelta(hours=1)

    def payload(self, minutes=0, **overrides):
        data = {
            "unit_id": "upa-centro",
            "people_waiting": 18,
            "estimated_wait_minutes": 20,
            "availability_level": "HIGH",
            "source_updated_at": (self.base + timedelta(minutes=minutes)).isoformat(),
        }
        data.update(overrides)
        return data

    def post(self, data=None, token="default", **extra):
        token = self.token if token == "default" else token
        headers = {"HTTP_AUTHORIZATION": f"Bearer {token}"} if token is not None else {}
        return self.client.post(
            self.url,
            data=self.payload() if data is None else data,
            content_type="application/json",
            **headers,
            **extra,
        )

    def public_unit(self, external_id="upa-centro"):
        return self.client.get(reverse("v1:unit-detail", args=[external_id])).json()
