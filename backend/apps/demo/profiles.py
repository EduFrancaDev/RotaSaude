"""Papel de cada UPA demonstrativa no roteiro de apresentação.

As quatro UPAs de `seed_demo_units` continuam as mesmas; três UPAs fictícias extras
cobrem os cenários crítico, desatualizado e de falha de atualização. Coordenadas dentro
da área urbana de Goiânia; endereços genéricos, não reais.
"""

from dataclasses import dataclass


class Role:
    SCENARIO = "scenario"  # recebe leituras de um cenário de movimento
    NO_DATA = "no_data"  # permanece sem nenhuma leitura operacional
    STALE = "stale"  # última leitura antiga (informação desatualizada)
    UPDATE_FAILURE = "update_failure"  # leitura boa seguida de falha de atualização


@dataclass(frozen=True)
class DemoUnitProfile:
    external_id: str
    role: str
    scenario: str | None = None  # cenário de partida, quando o papel é SCENARIO

    @property
    def reserved(self) -> bool:
        """UPAs reservadas a demonstrar ausência de dados ficam fora de `--all`."""
        return self.role != Role.SCENARIO


PROFILES = {
    profile.external_id: profile
    for profile in (
        DemoUnitProfile("upa-centro", Role.SCENARIO, "low"),
        DemoUnitProfile("upa-sul", Role.SCENARIO, "moderate"),
        DemoUnitProfile("upa-norte", Role.SCENARIO, "high"),
        DemoUnitProfile("upa-nordeste", Role.SCENARIO, "critical"),
        DemoUnitProfile("upa-oeste", Role.NO_DATA),
        DemoUnitProfile("upa-leste", Role.STALE),
        DemoUnitProfile("upa-sudoeste", Role.UPDATE_FAILURE),
    )
}

# UPAs criadas por `seed_demo_scenarios` além das quatro de `seed_demo_units`.
EXTRA_UNITS = [
    {
        "external_id": "upa-nordeste",
        "name": "UPA Exemplo Nordeste",
        "address": "Av. Exemplo, 700 · Setor Nordeste, Goiânia",
        "latitude": -16.6600,
        "longitude": -49.2300,
        "services": ["Clínica geral", "Pediatria"],
    },
    {
        "external_id": "upa-leste",
        "name": "UPA Exemplo Leste",
        "address": "Rua Exemplo, 330 · Setor Leste, Goiânia",
        "latitude": -16.6800,
        "longitude": -49.2250,
        "services": ["Clínica geral", "Ortopedia"],
    },
    {
        "external_id": "upa-sudoeste",
        "name": "UPA Exemplo Sudoeste",
        "address": "Av. Exemplo, 910 · Setor Sudoeste, Goiânia",
        "latitude": -16.7150,
        "longitude": -49.2850,
        "services": ["Clínica geral"],
    },
]
