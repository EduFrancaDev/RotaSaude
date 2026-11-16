import hashlib

from django.db import connection

from apps.integrations.models import IntegrationCredential
from apps.integrations.tests.helpers import IngestTestCase
from apps.units.models import UnitOperationalStatus
from apps.units.tests.helpers import make_unit


class AuthenticationTests(IngestTestCase):
    def test_valid_credential(self):
        response = self.post()

        self.assertEqual(response.status_code, 201)

    def test_missing_credential_is_401_with_challenge(self):
        response = self.post(token=None)

        self.assertEqual(response.status_code, 401)
        self.assertIn("Bearer", response.headers["WWW-Authenticate"])
        self.assertFalse(UnitOperationalStatus.objects.exists())

    def test_invalid_credential_is_401_and_does_not_echo_it(self):
        wrong = "rsi_" + "x" * 43

        response = self.post(token=wrong)

        self.assertEqual(response.status_code, 401)
        self.assertNotIn(wrong, response.content.decode())
        self.assertNotIn(self.token, response.content.decode())

    def test_revoked_credential_is_401_with_same_message_as_invalid(self):
        self.credential.revoke()

        revoked = self.post()
        invalid = self.post(token="rsi_invalida")

        self.assertEqual(revoked.status_code, 401)
        self.assertEqual(revoked.json(), invalid.json())
        self.assertFalse(UnitOperationalStatus.objects.exists())

    def test_wrong_scheme_and_malformed_headers_are_rejected(self):
        for header in ["Basic abc", "Bearer", f"Bearer {self.token} extra", "Bearer " + "a" * 500, self.token]:
            with self.subTest(header=header[:20]):
                response = self.client.post(
                    self.url, data=self.payload(), content_type="application/json", HTTP_AUTHORIZATION=header
                )
                self.assertEqual(response.status_code, 401)

    def test_other_units_credential_does_not_authenticate_for_this_unit(self):
        other = make_unit("upa-sul")
        _, other_token = IntegrationCredential.issue(other, "Outra")

        response = self.post(token=other_token)  # payload é de upa-centro

        self.assertEqual(response.status_code, 403)
        self.assertFalse(UnitOperationalStatus.objects.exists())

    def test_key_is_never_stored_in_clear_text(self):
        self.assertNotEqual(self.credential.key_hash, self.token)
        self.assertEqual(self.credential.key_hash, hashlib.sha256(self.token.encode()).hexdigest())
        self.assertTrue(self.token.startswith(self.credential.key_prefix))
        self.assertLess(len(self.credential.key_prefix), len(self.token))
        with connection.cursor() as cursor:
            cursor.execute("SELECT * FROM integrations_integrationcredential")
            stored = " ".join(str(v) for row in cursor.fetchall() for v in row)
        self.assertNotIn(self.token, stored)

    def test_keys_are_unique_and_long(self):
        _, other_token = IntegrationCredential.issue(self.unit, "Segunda")

        self.assertNotEqual(self.token, other_token)
        self.assertGreaterEqual(len(self.token), 40)

    def test_logs_never_contain_the_key(self):
        wrong = "rsi_" + "y" * 43
        with self.assertLogs("apps.integrations", level="INFO") as logs:
            self.post(token=wrong)
            self.post()

        output = "\n".join(logs.output)
        self.assertNotIn(wrong, output)
        self.assertNotIn(self.token, output)
        self.assertIn(self.credential.key_prefix, output)  # só o prefixo identifica a chave

    def test_revoke_sets_timestamp_once(self):
        self.credential.revoke()
        first = self.credential.revoked_at
        self.credential.revoke()

        self.assertFalse(self.credential.is_active)
        self.assertEqual(self.credential.revoked_at, first)
