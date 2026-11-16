import hashlib
import secrets
import uuid

from django.db import models
from django.utils import timezone

from apps.units.models import HealthUnit

KEY_PREFIX = "rsi_"


def hash_key(token):
    """SHA-256 da chave. A chave tem 256 bits aleatórios, então um hash rápido e sem sal é suficiente."""
    return hashlib.sha256(token.encode()).hexdigest()


class IntegrationCredential(models.Model):
    """Chave de API de um sistema de estabelecimento, válida somente para uma HealthUnit.

    O valor da chave nunca é armazenado: só seu hash e um prefixo curto para identificação.
    """

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    health_unit = models.ForeignKey(
        HealthUnit, on_delete=models.CASCADE, related_name="integration_credentials", verbose_name="unidade"
    )
    name = models.CharField("identificação", max_length=120, help_text="Ex.: sistema que usará a chave.")
    key_prefix = models.CharField("prefixo da chave", max_length=16, editable=False)
    key_hash = models.CharField(max_length=64, unique=True, editable=False)
    created_at = models.DateTimeField("criada em", auto_now_add=True)
    revoked_at = models.DateTimeField("revogada em", null=True, blank=True)

    class Meta:
        ordering = ["-created_at"]
        verbose_name = "credencial de integração"
        verbose_name_plural = "credenciais de integração"

    def __str__(self):
        return f"{self.name} ({self.key_prefix}…) → {self.health_unit.external_id}"

    @property
    def is_active(self):
        return self.revoked_at is None

    def revoke(self):
        if self.revoked_at is None:
            self.revoked_at = timezone.now()
            self.save(update_fields=["revoked_at"])

    def set_new_key(self):
        """Gera uma chave, guarda só prefixo e hash neste objeto (sem salvar) e devolve a chave."""
        token = KEY_PREFIX + secrets.token_urlsafe(32)
        self.key_prefix = token[:12]
        self.key_hash = hash_key(token)
        return token

    @classmethod
    def issue(cls, health_unit, name):
        """Cria a credencial e devolve `(credencial, chave)`. A chave só existe neste retorno."""
        credential = cls(health_unit=health_unit, name=name)
        token = credential.set_new_key()
        credential.save()
        return credential, token
