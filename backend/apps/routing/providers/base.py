from abc import ABC, abstractmethod
from dataclasses import dataclass


@dataclass(frozen=True)
class RouteResult:
    """Resultado normalizado de um provedor de roteamento (independente da API externa)."""

    provider: str
    mode: str
    distance_meters: float
    duration_seconds: float
    geometry: dict  # GeoJSON LineString: coordinates em [longitude, latitude]


class RoutingProvider(ABC):
    """Contrato para provedores de rota (OSRM hoje; Google Routes no futuro)."""

    @abstractmethod
    def route(
        self,
        *,
        origin_lat: float,
        origin_lon: float,
        dest_lat: float,
        dest_lon: float,
        mode: str,
    ) -> RouteResult:
        raise NotImplementedError
