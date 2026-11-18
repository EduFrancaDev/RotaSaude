"""Prepara as UPAs demonstrativas para a apresentação (idempotente e não destrutivo).

Garante as 4 UPAs de `seed_demo_units` e 3 UPAs fictícias extras e dá a cada uma o seu papel:
movimento baixo/moderado/elevado/crítico, sem dados, informação desatualizada e falha de
atualização. Só acrescenta leituras a unidades ainda sem preparo; nunca altera nem apaga
leituras existentes.
"""

from datetime import timedelta
from io import StringIO

from django.core.management import call_command
from django.core.management.base import BaseCommand, CommandError
from django.db import transaction
from django.utils import timezone

from apps.demo.guard import DemoModeDisabled, require_demo_mode
from apps.demo.models import DemoReadingMark
from apps.demo.profiles import EXTRA_UNITS, PROFILES, Role
from apps.demo.readings import DemoReadingError, append_demo_reading
from apps.services.models import Service
from apps.units.models import HealthUnit, HealthUnitService

# Linha do tempo das UPAs com ausência de dados, relativa ao momento do preparo.
STALE_HISTORY = (("low", timedelta(hours=4)), ("moderate", timedelta(hours=3)))
FAILURE_HISTORY = (("moderate", timedelta(minutes=45)), ("unavailable", timedelta(minutes=5)))


class Command(BaseCommand):
    help = "Prepara os cenários das UPAs DEMONSTRATIVAS (idempotente; exige DEMO_MODE=true)."

    def handle(self, *args, **options):
        try:
            require_demo_mode()
        except DemoModeDisabled as exc:
            raise CommandError(str(exc)) from exc

        # Nunca assume um external_id que já pertence a uma unidade real.
        taken = list(
            HealthUnit.objects.filter(external_id__in=PROFILES, is_demo=False).values_list("external_id", flat=True)
        )
        if taken:
            raise CommandError(
                f"Já existem unidades NÃO demonstrativas com os IDs {', '.join(sorted(taken))}. Nada foi alterado."
            )

        report = []
        try:
            with transaction.atomic():
                call_command("seed_demo_units", stdout=StringIO())
                for data in EXTRA_UNITS:
                    self._ensure_extra_unit(data, report)
                for profile in PROFILES.values():
                    unit = HealthUnit.objects.get(external_id=profile.external_id)
                    report.append(self._prepare(unit, profile))
        except DemoReadingError as exc:
            raise CommandError(str(exc)) from exc

        for line in report:
            self.stdout.write(line)
        self.stdout.write(
            self.style.SUCCESS("Cenários DEMONSTRATIVOS preparados. Dados fictícios, não oficiais.")
        )

    def _ensure_extra_unit(self, data, report):
        unit, created = HealthUnit.objects.get_or_create(
            external_id=data["external_id"],
            defaults={
                "name": data["name"],
                "address": data["address"],
                "city": "Goiânia",
                "state": "GO",
                "latitude": data["latitude"],
                "longitude": data["longitude"],
                "opening_hours": "24 horas",
                "is_demo": True,
                "is_active": True,
            },
        )
        for service_name in data["services"]:
            service, _ = Service.objects.get_or_create(name=service_name)
            HealthUnitService.objects.get_or_create(health_unit=unit, service=service)
        if created:
            report.append(f"{unit.external_id}: unidade demonstrativa criada.")

    def _prepare(self, unit, profile):
        label = unit.external_id
        if profile.role == Role.NO_DATA:
            if unit.operational_statuses.exists():
                return f"{label}: sem dados (mantida; já possui leituras, que não foram alteradas)."
            return f"{label}: sem dados operacionais."

        if profile.role == Role.SCENARIO:
            if DemoReadingMark.objects.filter(status__health_unit=unit).exists():
                return f"{label}: já preparada (nenhuma leitura nova)."
            append_demo_reading(unit, profile.scenario)
            return f"{label}: cenário '{profile.scenario}' aplicado."

        # STALE e UPDATE_FAILURE só são montadas em unidades sem leituras: não há como inserir
        # histórico "antigo" sob uma leitura mais nova sem falsear a ordem.
        if unit.operational_statuses.exists():
            return f"{label}: já possui leituras (mantidas; papel '{profile.role}' não aplicado)."
        history = STALE_HISTORY if profile.role == Role.STALE else FAILURE_HISTORY
        now = timezone.now()
        for scenario_key, age in history:
            append_demo_reading(unit, scenario_key, source_updated_at=now - age, now=now)
        return f"{label}: papel '{profile.role}' montado ({len(history)} leituras)."
