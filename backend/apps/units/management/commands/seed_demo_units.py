"""Cadastra as unidades DEMONSTRATIVAS de Goiânia usadas pelo protótipo Flutter.

Os dados fictícios incluem IDs, nomes, endereços, coordenadas, serviços e horários.
O comando é idempotente.
"""

from django.core.management.base import BaseCommand
from django.db import transaction
from django.utils import timezone

from apps.services.models import Service
from apps.units.models import HealthUnit, HealthUnitService, UnitOperationalStatus

Level = UnitOperationalStatus.AvailabilityLevel

DEMO_UNITS = [
    {
        "external_id": "upa-centro",
        "name": "UPA Exemplo Centro",
        "address": "Rua Exemplo, 120 · Setor Central, Goiânia",
        "latitude": -16.6862,
        "longitude": -49.2640,
        "services": ["Clínica geral", "Pediatria", "Ortopedia"],
        "opening_hours": "24 horas",
        "status": {"availability_level": Level.HIGH, "estimated_wait_minutes": 20, "people_waiting": 18},
    },
    {
        "external_id": "upa-sul",
        "name": "UPA Exemplo Sul",
        "address": "Rua Exemplo, 250 · Setor Sul, Goiânia",
        "latitude": -16.7100,
        "longitude": -49.2590,
        "services": ["Clínica geral", "Ortopedia"],
        "opening_hours": "24 horas",
        "status": {"availability_level": Level.MODERATE, "estimated_wait_minutes": 40, "people_waiting": 32},
    },
    {
        "external_id": "upa-norte",
        "name": "UPA Exemplo Norte",
        "address": "Av. Exemplo, 400 · Setor Norte, Goiânia",
        "latitude": -16.6550,
        "longitude": -49.2640,
        "services": ["Clínica geral"],
        "opening_hours": "24 horas",
        "status": {"availability_level": Level.LOW, "estimated_wait_minutes": 65, "people_waiting": 54},
    },
    {
        # Cenário sem dados operacionais: nenhum status é criado.
        "external_id": "upa-oeste",
        "name": "UPA Exemplo Oeste",
        "address": "Av. Exemplo, 400 · Goiânia, GO",
        "latitude": -16.6865,
        "longitude": -49.2950,
        "services": ["Clínica geral", "Pediatria"],
        "opening_hours": "24 horas",
        "status": None,
    },
]


class Command(BaseCommand):
    help = "Cadastra as 4 unidades DEMONSTRATIVAS de Goiânia (idempotente)."

    @transaction.atomic
    def handle(self, *args, **options):
        created_units = 0
        created_statuses = 0

        for data in DEMO_UNITS:
            unit, created = HealthUnit.objects.update_or_create(
                external_id=data["external_id"],
                defaults={
                    "name": data["name"],
                    "address": data["address"],
                    "city": "Goiânia",
                    "state": "GO",
                    "latitude": data["latitude"],
                    "longitude": data["longitude"],
                    "opening_hours": data["opening_hours"],
                    "is_active": True,
                    "is_demo": True,
                },
            )
            created_units += created

            for service_name in data["services"]:
                service, _ = Service.objects.get_or_create(name=service_name)
                HealthUnitService.objects.get_or_create(health_unit=unit, service=service)

            status = data["status"]
            if status is None:
                continue
            # Só semeia unidades sem nenhuma leitura: nunca sobrepõe dados enviados pela integração
            # nem cria uma leitura "mais recente" por cima de uma já existente.
            if unit.operational_statuses.exists():
                continue
            UnitOperationalStatus.objects.create(
                health_unit=unit, source_updated_at=timezone.now(), is_demo=True, **status
            )
            created_statuses += 1

        self.stdout.write(
            self.style.SUCCESS(
                f"Seed DEMONSTRATIVO concluído: {created_units} unidade(s) e "
                f"{created_statuses} leitura(s) operacional(is) criadas. "
                "Dados fictícios, não oficiais."
            )
        )
