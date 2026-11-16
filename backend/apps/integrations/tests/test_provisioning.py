import hashlib
from io import StringIO

from django.contrib.auth import get_user_model
from django.core.management import CommandError, call_command
from django.test import TestCase
from django.urls import reverse

from apps.integrations.models import IntegrationCredential
from apps.units.tests.helpers import make_unit


class CreateCredentialCommandTests(TestCase):
    def run_command(self, *args):
        out, err = StringIO(), StringIO()
        call_command("create_integration_credential", *args, stdout=out, stderr=err)
        return out.getvalue().strip(), err.getvalue()

    def test_prints_key_once_on_stdout_only(self):
        make_unit("upa-centro", is_demo=True)

        token, err = self.run_command("upa-centro", "--name", "Demo curl")

        credential = IntegrationCredential.objects.get()
        self.assertTrue(token.startswith("rsi_"))
        self.assertEqual(credential.key_hash, hashlib.sha256(token.encode()).hexdigest())
        self.assertNotIn(token, err)
        self.assertIn(credential.key_prefix, err)
        self.assertIn("DEMONSTRATIVA", err)
        self.assertEqual(credential.health_unit.external_id, "upa-centro")

    def test_unknown_unit_fails_without_creating_anything(self):
        with self.assertRaises(CommandError):
            self.run_command("nao-existe", "--name", "X")

        self.assertFalse(IntegrationCredential.objects.exists())


class AdminTests(TestCase):
    def setUp(self):
        self.unit = make_unit("upa-centro")
        user = get_user_model().objects.create_superuser("admin", password="senha-de-teste-123")
        self.client.force_login(user)

    def test_admin_shows_key_once_and_stores_only_hash(self):
        response = self.client.post(
            reverse("admin:integrations_integrationcredential_add"),
            {"health_unit": str(self.unit.pk), "name": "Via admin"},
            follow=True,
        )

        credential = IntegrationCredential.objects.get()
        content = response.content.decode()
        self.assertIn("não será exibida novamente", content)
        token = content.split("copie agora; não será exibida novamente): ")[1].split("<")[0]
        self.assertTrue(token.startswith(credential.key_prefix))
        self.assertEqual(credential.key_hash, hashlib.sha256(token.encode()).hexdigest())

        again = self.client.get(reverse("admin:integrations_integrationcredential_changelist"))
        self.assertNotIn(token, again.content.decode())

    def test_revoke_action(self):
        credential, token = IntegrationCredential.issue(self.unit, "A revogar")

        self.client.post(
            reverse("admin:integrations_integrationcredential_changelist"),
            {"action": "revoke_selected", "_selected_action": [str(credential.pk)]},
        )

        credential.refresh_from_db()
        self.assertFalse(credential.is_active)

    def test_credentials_cannot_be_deleted_in_admin(self):
        credential, _ = IntegrationCredential.issue(self.unit, "Fixa")

        delete = self.client.post(
            reverse("admin:integrations_integrationcredential_delete", args=[credential.pk]), {"post": "yes"}
        )

        self.assertEqual(delete.status_code, 403)
        self.assertTrue(IntegrationCredential.objects.filter(pk=credential.pk).exists())
