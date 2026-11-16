import json
import logging
import urllib.error
import urllib.parse
import urllib.request
from urllib.request import urlopen

from apps.routing.exceptions import ProviderResponseError, ProviderUnavailable
from apps.routing.providers.base import RouteResult, RoutingProvider

logger = logging.getLogger(__name__)

OSRM_PROFILE = {"driving": "driving"}


class OSRMRoutingProvider(RoutingProvider):
    """Cliente do serviço Route do OSRM (GeoJSON, sem steps)."""

    def __init__(self, base_url: str, timeout_seconds: float, provider_name: str = "osrm"):
        self.base_url = base_url.rstrip("/")
        self.timeout_seconds = timeout_seconds
        self.provider_name = provider_name

    def route(self, *, origin_lat, origin_lon, dest_lat, dest_lon, mode):
        profile = OSRM_PROFILE.get(mode)
        if profile is None:
            raise ProviderResponseError(f"Modo não suportado pelo OSRM: {mode}")

        # Ordem OSRM: longitude,latitude
        path = f"{origin_lon},{origin_lat};{dest_lon},{dest_lat}"
        query = urllib.parse.urlencode(
            {"overview": "full", "geometries": "geojson", "steps": "false"}
        )
        url = f"{self.base_url}/route/v1/{profile}/{path}?{query}"

        request = urllib.request.Request(url, headers={"User-Agent": "RotaSaude/1.0 (routing)"})
        try:
            with urlopen(request, timeout=self.timeout_seconds) as response:
                payload = json.loads(response.read().decode("utf-8"))
        except urllib.error.HTTPError as exc:
            logger.warning("OSRM HTTP %s (sem coordenadas no log)", exc.code)
            raise ProviderUnavailable("O serviço de rotas está indisponível no momento.") from exc
        except urllib.error.URLError as exc:
            logger.warning("OSRM indisponível: %s", exc.reason)
            raise ProviderUnavailable("O serviço de rotas está indisponível no momento.") from exc
        except TimeoutError as exc:
            logger.warning("OSRM timeout após %ss", self.timeout_seconds)
            raise ProviderUnavailable("O serviço de rotas está indisponível no momento.") from exc

        if payload.get("code") != "Ok":
            code = payload.get("code", "desconhecido")
            logger.info("OSRM sem rota: code=%s", code)
            raise ProviderResponseError("Não foi possível calcular a rota para o destino informado.")

        try:
            route = payload["routes"][0]
            geometry = route["geometry"]
            distance = float(route["distance"])
            duration = float(route["duration"])
        except (KeyError, IndexError, TypeError, ValueError) as exc:
            logger.warning("OSRM resposta inesperada")
            raise ProviderResponseError("Resposta inválida do provedor de rotas.") from exc

        if geometry.get("type") != "LineString" or not isinstance(geometry.get("coordinates"), list):
            raise ProviderResponseError("Geometria da rota inválida.")

        return RouteResult(
            provider=self.provider_name,
            mode=mode,
            distance_meters=distance,
            duration_seconds=duration,
            geometry=geometry,
        )
