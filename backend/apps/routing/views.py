import logging

from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.routing.exceptions import ProviderResponseError, ProviderUnavailable, RoutingError
from apps.routing.serializers import RouteQuerySerializer
from apps.routing.services import fetch_route
from apps.routing.throttling import RoutesRateThrottle
from apps.units.models import HealthUnit

logger = logging.getLogger(__name__)


class RouteView(APIView):
    """`GET /api/v1/routes/` — rota de carro até uma unidade (coordenadas da unidade no banco)."""

    throttle_classes = [RoutesRateThrottle]
    http_method_names = ["get", "head", "options"]

    def get(self, request):
        serializer = RouteQuerySerializer(data=request.query_params)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        unit = (
            HealthUnit.objects.filter(external_id=data["unit_id"], is_active=True)
            .only("external_id", "latitude", "longitude")
            .first()
        )
        if unit is None:
            return Response({"detail": "Unidade não encontrada."}, status=status.HTTP_404_NOT_FOUND)

        try:
            payload = fetch_route(
                origin_lat=data["origin_lat"],
                origin_lon=data["origin_lon"],
                dest_lat=unit.latitude,
                dest_lon=unit.longitude,
                unit_id=unit.external_id,
                mode=data["mode"],
            )
        except ProviderUnavailable as exc:
            logger.info("Rota indisponível unit_id=%s", unit.external_id)
            return Response({"detail": str(exc)}, status=status.HTTP_503_SERVICE_UNAVAILABLE)
        except ProviderResponseError as exc:
            logger.info("Rota rejeitada pelo provedor unit_id=%s", unit.external_id)
            return Response({"detail": str(exc)}, status=status.HTTP_502_BAD_GATEWAY)
        except RoutingError:
            logger.warning("Erro de roteamento unit_id=%s", unit.external_id)
            return Response(
                {"detail": "Não foi possível obter a rota no momento."},
                status=status.HTTP_502_BAD_GATEWAY,
            )
        except Exception:
            logger.exception("Erro inesperado na rota unit_id=%s", unit.external_id)
            return Response(
                {"detail": "Não foi possível obter a rota no momento."},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )

        return Response(payload)
