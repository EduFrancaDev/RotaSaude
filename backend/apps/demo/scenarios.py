"""Cenários de atendimento das UPAs demonstrativas.

Todos os números são FICTÍCIOS: não representam métricas clínicas nem tempos reais.
A espera é um valor fixo de cada cenário; ela NÃO é calculada a partir da quantidade de
pessoas (não existe fórmula entre os dois campos).
"""

from dataclasses import dataclass

from apps.units.models import UnitOperationalStatus

Level = UnitOperationalStatus.AvailabilityLevel


@dataclass(frozen=True)
class Scenario:
    key: str
    label: str
    people_waiting: int | None
    estimated_wait_minutes: int | None
    availability_level: str | None

    @property
    def values(self):
        return {
            "people_waiting": self.people_waiting,
            "estimated_wait_minutes": self.estimated_wait_minutes,
            "availability_level": self.availability_level,
        }


SCENARIOS = {
    scenario.key: scenario
    for scenario in (
        Scenario("low", "A · Movimento baixo", 8, 15, Level.HIGH),
        Scenario("moderate", "B · Movimento moderado", 27, 45, Level.MODERATE),
        Scenario("high", "C · Movimento elevado", 48, 80, Level.LOW),
        Scenario("critical", "D · Situação crítica", 64, 110, Level.CRITICAL),
        # Falha temporária de atualização: a fonte respondeu, mas sem nenhum valor (todos
        # nulos, como o contrato de integração permite). O app trata como dado indisponível.
        Scenario("unavailable", "Falha de atualização (sem valores)", None, None, None),
    )
}

# Cenários com movimento, sorteáveis em `--scenario random`.
RANDOM_POOL = ("low", "moderate", "high", "critical")

RANDOM = "random"
BASELINE = "baseline"  # cenário de partida de cada UPA (ver `profiles.py`)
CHOICES = (*SCENARIOS, RANDOM, BASELINE)
