import hashlib
import logging
import time

from django.conf import settings
from django.core.cache import cache
from django.core.exceptions import ImproperlyConfigured

from apps.routing.exceptions import ProviderUnavailable
from apps.routing.providers.osrm import OSRMRoutingProvider

logger = logging.getLogger(__name__)

CACHE_KEY_PREFIX = "routing:route:"
OSRM_LAST_CALL_KEY = "routing:osrm:last_call"
OSRM_INFLIGHT_KEY = "routing:osrm:inflight"


def get_routing_provider():
    """Seleciona o provedor conforme `ROUTING_PROVIDER` (preparado para futuros backends)."""
    name = settings.ROUTING_PROVIDER
    if name == "osrm":
        return OSRMRoutingProvider(
            base_url=settings.OSRM_BASE_URL,
            timeout_seconds=settings.OSRM_TIMEOUT_SECONDS,
        )
    # google: futuro GoogleRoutesProvider(settings.GOOGLE_ROUTES_API_KEY)
    raise ImproperlyConfigured(f"ROUTING_PROVIDER não suportado: {name!r}")


def _quantize(value: float, places: int = 5) -> float:
    """Agrupa origens próximas no cache sem persistir coordenadas em texto legível."""
    return round(value, places)


def _cache_key(*, mode: str, unit_id: str, origin_lat: float, origin_lon: float) -> str:
    raw = f"{mode}|{unit_id}|{_quantize(origin_lat)}|{_quantize(origin_lon)}"
    digest = hashlib.sha256(raw.encode()).hexdigest()[:32]
    return f"{CACHE_KEY_PREFIX}{digest}"


def _acquire_osrm_slot() -> None:
    """Evita rajadas ao servidor público: um outbound por vez e intervalo mínimo entre chamadas."""
    ttl = max(int(settings.OSRM_OUTBOUND_LOCK_TTL), 1)
    if not cache.add(OSRM_INFLIGHT_KEY, "1", timeout=ttl):
        raise ProviderUnavailable("O serviço de rotas está ocupado. Tente novamente em instantes.")

    try:
        min_interval = settings.OSRM_MIN_REQUEST_INTERVAL
        last = cache.get(OSRM_LAST_CALL_KEY)
        now = time.monotonic()
        if last is not None and (now - float(last)) < min_interval:
            raise ProviderUnavailable("O serviço de rotas está ocupado. Tente novamente em instantes.")
        cache.set(OSRM_LAST_CALL_KEY, now, timeout=3600)
    except ProviderUnavailable:
        cache.delete(OSRM_INFLIGHT_KEY)
        raise
    except Exception:
        cache.delete(OSRM_INFLIGHT_KEY)
        raise


def _release_osrm_slot() -> None:
    cache.delete(OSRM_INFLIGHT_KEY)


def fetch_route(*, origin_lat: float, origin_lon: float, dest_lat: float, dest_lon: float, unit_id: str, mode: str):
    """Consulta rota com cache de curta duração e proteção de concorrência ao provedor."""
    key = _cache_key(mode=mode, unit_id=unit_id, origin_lat=origin_lat, origin_lon=origin_lon)
    cached = cache.get(key)
    if cached is not None:
        return cached

    provider = get_routing_provider()
    try:
        _acquire_osrm_slot()
        try:
            result = provider.route(
                origin_lat=origin_lat,
                origin_lon=origin_lon,
                dest_lat=dest_lat,
                dest_lon=dest_lon,
                mode=mode,
            )
        finally:
            _release_osrm_slot()
    except ProviderUnavailable:
        raise
    except Exception:
        logger.exception("Falha inesperada no roteamento (unit_id=%s mode=%s)", unit_id, mode)
        raise

    payload = {
        "provider": result.provider,
        "mode": result.mode,
        "unit_id": unit_id,
        "distance_meters": result.distance_meters,
        "duration_seconds": result.duration_seconds,
        "geometry": result.geometry,
    }
    cache.set(key, payload, timeout=settings.ROUTING_CACHE_TTL)
    return payload
