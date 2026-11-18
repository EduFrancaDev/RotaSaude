"""Geração de leituras operacionais demonstrativas.

Reutiliza `record_reading` da integração, que já garante idempotência e a restrição única
(unidade, `source_updated_at`). Leituras anteriores nunca são alteradas: cada execução
acrescenta um registro novo ao histórico.
"""

import random
from datetime import timedelta

from django.conf import settings
from django.db import transaction
from django.utils import timezone

from apps.demo.guard import require_demo_mode
from apps.demo.models import DemoReadingMark
from apps.demo.profiles import PROFILES
from apps.demo.scenarios import BASELINE, RANDOM, RANDOM_POOL, SCENARIOS
from apps.integrations.serializers import FUTURE_TOLERANCE
from apps.integrations.views import record_reading
from apps.units.models import HealthUnit, UnitOperationalStatus


class DemoReadingError(Exception):
    """A leitura demonstrativa não pôde ser gravada com segurança."""


def demo_units():
    """Somente unidades ativas marcadas como demonstrativas; as reais nunca entram."""
    return HealthUnit.objects.filter(is_demo=True, is_active=True).order_by("external_id")


def scenario_units():
    """UPAs alteradas por `--all` e pela atualização automática: as reservadas ficam de fora."""
    return [u for u in demo_units() if not (PROFILES.get(u.external_id) and PROFILES[u.external_id].reserved)]


def describe_reading(unit, scenario_key, reading):
    """Linha legível de uma leitura gravada, usada no terminal e nos logs do simulador."""
    at = timezone.localtime(reading.source_updated_at).strftime("%H:%M:%S")
    values = (
        "sem valores (falha de atualização)"
        if scenario_key == "unavailable"
        else f"{reading.people_waiting} pessoas · {reading.estimated_wait_minutes} min · {reading.availability_level}"
    )
    return f"[{at}] {unit.external_id:<13} {SCENARIOS[scenario_key].label} → {values} [DEMONSTRATIVO]"


def resolve_scenario(unit, requested, rng=None):
    """Traduz `random` e `baseline` no cenário concreto a gravar para a unidade."""
    if requested == BASELINE:
        profile = PROFILES.get(unit.external_id)
        if profile is None or profile.scenario is None:
            raise DemoReadingError(f"{unit.external_id} não tem cenário de partida (baseline).")
        return profile.scenario
    if requested == RANDOM:
        rng = rng or random.Random()
        last = (
            DemoReadingMark.objects.filter(status__health_unit=unit)
            .order_by("-status__source_updated_at")
            .values_list("scenario", flat=True)
            .first()
        )
        # Evita repetir o cenário anterior para que cada atualização seja perceptível.
        pool = [key for key in RANDOM_POOL if key != last]
        return rng.choice(pool)
    if requested not in SCENARIOS:
        raise DemoReadingError(f"Cenário desconhecido: {requested!r}.")
    return requested


def append_demo_reading(unit, scenario_key, *, source_updated_at=None, now=None):
    """Grava uma leitura demonstrativa nova e a marca com o cenário aplicado.

    Sem `source_updated_at`, usa o instante atual (ou o seguinte à leitura mais recente, se
    esta estiver à frente). Com ele, o instante deve ser posterior a qualquer leitura da
    unidade e não pode estar no futuro além da tolerância da integração.
    """
    require_demo_mode()
    scenario = SCENARIOS[scenario_key]
    now = now or timezone.now()

    with transaction.atomic():
        # Trava a linha da unidade: dois simuladores simultâneos não geram leituras conflitantes.
        locked = HealthUnit.objects.select_for_update().get(pk=unit.pk)
        if not locked.is_demo or not locked.is_active:
            raise DemoReadingError(f"{locked.external_id} não é uma unidade demonstrativa ativa.")

        latest = locked.operational_statuses.order_by("-source_updated_at").first()
        timestamp = _validated_timestamp(locked, latest, source_updated_at, now)

        reading, result = record_reading(locked, {**scenario.values, "source_updated_at": timestamp})
        if result != "created":
            raise DemoReadingError(f"Leitura já existente para {locked.external_id} em {timestamp}.")
        DemoReadingMark.objects.create(status=reading, scenario=scenario_key)
    return reading


def _validated_timestamp(unit, latest, requested, now):
    limit = now + FUTURE_TOLERANCE
    latest_at = latest.source_updated_at if latest else None
    if requested is None:
        timestamp = now
        if latest_at is not None and latest_at >= now:
            timestamp = latest_at + timedelta(seconds=1)
    else:
        timestamp = requested
        if latest_at is not None and timestamp <= latest_at:
            raise DemoReadingError(
                f"{unit.external_id}: o instante informado não é posterior à leitura mais recente."
            )
    if timestamp > limit:
        raise DemoReadingError(f"{unit.external_id}: leitura mais recente está no futuro; nada foi gravado.")
    return timestamp


# --- Classificação da atualização (mesma regra do app: atual / desatualizada / sem dados) ---

CURRENT = "current"
STALE = "stale"
MISSING = "missing"
UPDATE_LABELS = {CURRENT: "atual", STALE: "desatualizada", MISSING: "sem dados"}


def update_state(reading, now=None):
    if reading is None or (
        reading.people_waiting is None
        and reading.estimated_wait_minutes is None
        and reading.availability_level is None
    ):
        return MISSING
    now = now or timezone.now()
    age = now - reading.source_updated_at
    if age > timedelta(minutes=settings.DEMO_STALE_AFTER_MINUTES) or age < -FUTURE_TOLERANCE:
        return STALE
    return CURRENT


def latest_reading(unit) -> UnitOperationalStatus | None:
    return unit.operational_statuses.select_related("demo_mark").order_by("-source_updated_at", "-received_at").first()


def scenario_of(reading):
    """Chave do cenário aplicado, ou `None` para leituras sem marca (seed ou integração)."""
    mark = getattr(reading, "demo_mark", None) if reading is not None else None
    return mark.scenario if mark else None
