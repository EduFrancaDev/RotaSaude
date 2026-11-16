import uuid

from django.core.validators import MaxValueValidator, MinValueValidator
from django.db import models

from apps.services.models import Service


class HealthUnit(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    external_id = models.CharField(
        "identificador público",
        max_length=64,
        unique=True,
        help_text="ID usado pelo aplicativo (ex.: 'upa-centro'). Não altere após publicado.",
    )
    name = models.CharField("nome", max_length=200)
    address = models.CharField("endereço", max_length=300)
    city = models.CharField("cidade", max_length=120, db_index=True)
    state = models.CharField("UF", max_length=2)
    latitude = models.FloatField(
        "latitude", validators=[MinValueValidator(-90), MaxValueValidator(90)]
    )
    longitude = models.FloatField(
        "longitude", validators=[MinValueValidator(-180), MaxValueValidator(180)]
    )
    phone = models.CharField("telefone", max_length=30, null=True, blank=True)
    opening_hours = models.CharField("horário de funcionamento", max_length=200, null=True, blank=True)
    is_active = models.BooleanField("ativa", default=True)
    is_demo = models.BooleanField(
        "dado demonstrativo",
        default=False,
        help_text="Cadastro fictício para demonstração; não representa um estabelecimento real.",
    )
    services = models.ManyToManyField(
        Service, through="HealthUnitService", related_name="health_units", verbose_name="serviços"
    )
    created_at = models.DateTimeField("criada em", auto_now_add=True)
    updated_at = models.DateTimeField("atualizada em", auto_now=True)

    class Meta:
        ordering = ["name"]
        verbose_name = "unidade de saúde"
        verbose_name_plural = "unidades de saúde"

    def __str__(self):
        return self.name


class HealthUnitService(models.Model):
    health_unit = models.ForeignKey(HealthUnit, on_delete=models.CASCADE, related_name="unit_services")
    service = models.ForeignKey(Service, on_delete=models.CASCADE, related_name="unit_services")

    class Meta:
        verbose_name = "serviço da unidade"
        verbose_name_plural = "serviços das unidades"
        constraints = [
            models.UniqueConstraint(
                fields=["health_unit", "service"], name="unique_health_unit_service"
            )
        ]

    def __str__(self):
        return f"{self.health_unit} – {self.service}"


class UnitOperationalStatus(models.Model):
    """Leitura operacional de uma unidade. Cada leitura é um registro novo (histórico)."""

    class AvailabilityLevel(models.TextChoices):
        HIGH = "HIGH", "Alta disponibilidade"
        MODERATE = "MODERATE", "Disponibilidade moderada"
        LOW = "LOW", "Baixa disponibilidade"
        CRITICAL = "CRITICAL", "Situação crítica"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    health_unit = models.ForeignKey(
        HealthUnit,
        on_delete=models.CASCADE,
        related_name="operational_statuses",
        verbose_name="unidade",
    )
    people_waiting = models.PositiveIntegerField("pessoas aguardando", null=True, blank=True)
    estimated_wait_minutes = models.PositiveIntegerField(
        "espera estimada (min)", null=True, blank=True
    )
    availability_level = models.CharField(
        "nível de disponibilidade",
        max_length=10,
        choices=AvailabilityLevel.choices,
        null=True,
        blank=True,
    )
    source_updated_at = models.DateTimeField("atualizado na fonte em")
    received_at = models.DateTimeField("recebido em", auto_now_add=True)
    is_demo = models.BooleanField(
        "dado demonstrativo",
        default=False,
        help_text="Leitura fictícia para demonstração; não é informação oficial nem atual.",
    )

    class Meta:
        ordering = ["-source_updated_at", "-received_at"]
        verbose_name = "status operacional"
        verbose_name_plural = "status operacionais"
        indexes = [
            models.Index(fields=["health_unit", "-source_updated_at"], name="opstatus_unit_latest_idx"),
        ]
        constraints = [
            # Uma leitura por instante da fonte: base da idempotência da integração.
            models.UniqueConstraint(
                fields=["health_unit", "source_updated_at"], name="unique_unit_source_reading"
            )
        ]

    def __str__(self):
        return f"{self.health_unit} @ {self.source_updated_at:%Y-%m-%d %H:%M}"
