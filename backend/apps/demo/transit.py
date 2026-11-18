"""Rota de ônibus SIMULADA para unidades demonstrativas.

Não usa Google Maps, OSRM nem qualquer API externa, e não representa transporte público real:
linhas, pontos e horários são fictícios e o traçado é esquemático (linhas retas). A rota é
sempre devolvida com `is_simulated: true` e um aviso explícito.

Regras do modelo (todas fictícias e fixas, para a demonstração ser reproduzível):
- caminhada: velocidade de 1,25 m/s (4,5 km/h), trajeto 30% maior que a linha reta;
- ônibus: 5 m/s (18 km/h, já contando paradas), trajeto 35% maior que a linha reta;
- pontos de embarque/desembarque: 12% da distância em linha reta a partir de cada ponta,
  limitado entre 150 m e 400 m;
- horários: cada linha fictícia sai a cada `headway` minutos em um minuto fixo da hora.
"""

import hashlib
import math
from dataclasses import dataclass
from datetime import timedelta

from django.utils import timezone

PROVIDER = "demo-simulated"
NOTICE = (
    "Dados simulados — demonstração acadêmica. Linha, pontos e horários são fictícios, não são "
    "oficiais e não servem para navegação."
)

# Região de cobertura: raio de Goiânia (o mesmo usado pelo app para sugerir a cidade).
COVERAGE_CENTER = (-16.6869, -49.2648)
COVERAGE_RADIUS_M = 35_000
MIN_STRAIGHT_LINE_M = 1_000

WALK_SPEED_MPS = 1.25
WALK_DETOUR = 1.3
BUS_SPEED_MPS = 5.0
BUS_DETOUR = 1.35
STOP_FRACTION = 0.12
STOP_MIN_M, STOP_MAX_M = 150, 400


@dataclass(frozen=True)
class DemoLine:
    code: str
    name: str
    headway_minutes: int  # divide 60
    offset_minute: int  # minuto da hora da primeira saída


# Códigos "DEMO-…" não correspondem a nenhuma linha real.
LINES = (
    DemoLine("DEMO-A1", "Linha A1", 15, 4),
    DemoLine("DEMO-B2", "Linha B2", 20, 9),
    DemoLine("DEMO-C3", "Linha C3", 30, 14),
)


class NoSimulatedRoute(Exception):
    """Não há rota de ônibus simulada para este pedido (mensagem segura para o usuário)."""


def haversine_m(lat1, lon1, lat2, lon2):
    radius = 6_371_000
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dphi, dlmb = p2 - p1, math.radians(lon2 - lon1)
    a = math.sin(dphi / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dlmb / 2) ** 2
    return 2 * radius * math.asin(math.sqrt(a))


def _within_coverage(lat, lon):
    return haversine_m(lat, lon, *COVERAGE_CENTER) <= COVERAGE_RADIUS_M


def _line_for(unit_id):
    # SHA-256 (e não `hash()`, que varia por processo) mantém a linha estável entre execuções.
    digest = hashlib.sha256(unit_id.encode()).digest()
    return LINES[digest[0] % len(LINES)]


def _point_along(origin, dest, meters, total):
    fraction = meters / total
    return (
        origin[0] + (dest[0] - origin[0]) * fraction,
        origin[1] + (dest[1] - origin[1]) * fraction,
    )


def _next_departure(at, line):
    """Primeira saída da linha em `at` ou depois (minutos cheios, relógio local)."""
    at = timezone.localtime(at)
    if at.second or at.microsecond:
        at = at.replace(second=0, microsecond=0) + timedelta(minutes=1)
    minute_of_day = at.hour * 60 + at.minute
    return at + timedelta(minutes=(line.offset_minute - minute_of_day) % line.headway_minutes)


def _stop(name, point):
    return {"name": name, "latitude": round(point[0], 6), "longitude": round(point[1], 6)}


def simulate_bus_route(*, unit_id, unit_is_demo, origin_lat, origin_lon, dest_lat, dest_lon, now=None):
    """Monta o payload da rota de ônibus simulada; levanta `NoSimulatedRoute` quando não há."""
    if not unit_is_demo:
        raise NoSimulatedRoute("Rota de ônibus simulada só existe para unidades demonstrativas.")
    if not (_within_coverage(origin_lat, origin_lon) and _within_coverage(dest_lat, dest_lon)):
        raise NoSimulatedRoute("Rota de ônibus simulada disponível apenas na região de Goiânia.")

    straight = haversine_m(origin_lat, origin_lon, dest_lat, dest_lon)
    if straight < MIN_STRAIGHT_LINE_M:
        raise NoSimulatedRoute("A unidade está muito próxima; não há rota de ônibus simulada para este trajeto.")

    origin, dest = (origin_lat, origin_lon), (dest_lat, dest_lon)
    stop_m = min(max(straight * STOP_FRACTION, STOP_MIN_M), STOP_MAX_M)
    boarding = _point_along(origin, dest, stop_m, straight)
    alighting = _point_along(origin, dest, straight - stop_m, straight)

    walk_distance = stop_m * WALK_DETOUR
    walk_seconds = walk_distance / WALK_SPEED_MPS
    ride_distance = (straight - 2 * stop_m) * BUS_DETOUR
    ride_seconds = ride_distance / BUS_SPEED_MPS

    line = _line_for(unit_id)
    start = now or timezone.now()
    at_stop = start + timedelta(seconds=walk_seconds)
    bus_departure = _next_departure(at_stop, line)
    bus_arrival = bus_departure + timedelta(seconds=ride_seconds)
    arrival = bus_arrival + timedelta(seconds=walk_seconds)

    def iso(value):
        return timezone.localtime(value).replace(microsecond=0).isoformat()

    return {
        "provider": PROVIDER,
        "mode": "bus",
        "unit_id": unit_id,
        "is_simulated": True,
        "simulation_notice": NOTICE,
        "route_id": f"demo-{unit_id}-{line.code.lower()}",
        "line": {"code": line.code, "name": line.name, "headway_minutes": line.headway_minutes},
        "boarding_stop": _stop("Ponto de embarque", boarding),
        "alighting_stop": _stop("Ponto de desembarque", alighting),
        "walk_to_stop_meters": round(walk_distance),
        "walk_to_stop_seconds": round(walk_seconds),
        "wait_seconds": round((bus_departure - at_stop).total_seconds()),
        "in_vehicle_seconds": round(ride_seconds),
        "walk_from_stop_meters": round(walk_distance),
        "walk_from_stop_seconds": round(walk_seconds),
        "departure_at": iso(start),
        "bus_departure_at": iso(bus_departure),
        "bus_arrival_at": iso(bus_arrival),
        "arrival_at": iso(arrival),
        "distance_meters": round(2 * walk_distance + ride_distance),
        "duration_seconds": round((arrival - start).total_seconds()),
        "geometry_kind": "schematic",
        # GeoJSON: [longitude, latitude]. Linhas retas entre os pontos, sem malha viária.
        "geometry": {
            "type": "LineString",
            "coordinates": [[p[1], p[0]] for p in (origin, boarding, alighting, dest)],
        },
    }
