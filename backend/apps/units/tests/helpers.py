from datetime import datetime, timezone

from apps.services.models import Service
from apps.units.models import HealthUnit, UnitOperationalStatus


def make_unit(external_id="unit-1", services=(), city="Goiânia", **kwargs):
    defaults = {
        "name": f"Unidade {external_id}",
        "address": "Rua de Teste, 1",
        "state": "GO",
        "latitude": -16.68,
        "longitude": -49.26,
    }
    defaults.update(kwargs)
    unit = HealthUnit.objects.create(external_id=external_id, city=city, **defaults)
    for name in services:
        service, _ = Service.objects.get_or_create(name=name)
        unit.services.add(service)
    return unit


def make_status(unit, hour=10, **kwargs):
    kwargs.setdefault("people_waiting", 5)
    kwargs.setdefault("estimated_wait_minutes", 30)
    kwargs.setdefault("availability_level", UnitOperationalStatus.AvailabilityLevel.MODERATE)
    return UnitOperationalStatus.objects.create(
        health_unit=unit,
        source_updated_at=datetime(2026, 11, 10, hour, 0, tzinfo=timezone.utc),
        **kwargs,
    )
