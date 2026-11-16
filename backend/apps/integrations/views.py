import logging

from django.db import transaction
from rest_framework import exceptions, status
from rest_framework.parsers import JSONParser
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.integrations.authentication import IntegrationKeyAuthentication, IsIntegrationCredential
from apps.integrations.serializers import OperationalStatusInputSerializer
from apps.integrations.throttling import IntegrationRateThrottle
from apps.units.models import UnitOperationalStatus
from apps.units.serializers import OperationalStatusSerializer
from apps.units.views import latest_status_queryset

logger = logging.getLogger(__name__)

DATA_FIELDS = ("people_waiting", "estimated_wait_minutes", "availability_level")


def record_reading(unit, data):
    """Grava a leitura de forma idempotente. Retorna `(leitura, resultado)`.

    A restrição única (unidade, source_updated_at) garante, mesmo sob concorrência, uma única
    leitura por instante da fonte. Resultados: `created`, `duplicate` (mesmos valores) ou
    `conflict` (mesmo instante, valores diferentes; a leitura existente é preservada).
    """
    values = {field: data[field] for field in DATA_FIELDS}
    with transaction.atomic():
        reading, created = UnitOperationalStatus.objects.get_or_create(
            health_unit=unit,
            source_updated_at=data["source_updated_at"],
            # Não há "demo" próprio da integração: a marca vem da unidade, para que uma unidade
            # fictícia nunca seja apresentada com leituras como se fossem reais.
            defaults={**values, "is_demo": unit.is_demo},
        )
    if created:
        return reading, "created"
    same = all(getattr(reading, field) == value for field, value in values.items())
    return reading, "duplicate" if same else "conflict"


class OperationalStatusIngestView(APIView):
    """`POST /api/v1/integrations/operational-status/` — leitura operacional de uma unidade."""

    authentication_classes = [IntegrationKeyAuthentication]
    permission_classes = [IsIntegrationCredential]
    throttle_classes = [IntegrationRateThrottle]
    parser_classes = [JSONParser]
    http_method_names = ["post", "options"]

    def post(self, request):
        credential = request.auth
        serializer = OperationalStatusInputSerializer(data=request.data, context={"credential": credential})
        serializer.is_valid(raise_exception=True)

        unit = credential.health_unit
        if not unit.is_active:
            raise exceptions.PermissionDenied("Credencial não autorizada para esta unidade.")

        reading, result = record_reading(unit, serializer.validated_data)
        log_context = (unit.external_id, credential.key_prefix, reading.source_updated_at.isoformat())

        if result == "conflict":
            logger.warning("Integração: leitura conflitante unidade=%s chave=%s fonte=%s", *log_context)
            return Response(
                {
                    "detail": (
                        "Já existe uma leitura desta unidade com o mesmo source_updated_at e valores "
                        "diferentes. Leituras são imutáveis: envie a correção com um novo source_updated_at."
                    ),
                    "code": "conflicting_reading",
                    "existing": OperationalStatusSerializer(reading).data,
                },
                status=status.HTTP_409_CONFLICT,
            )

        latest = latest_status_queryset().filter(health_unit=unit).first()
        logger.info("Integração: leitura %s unidade=%s chave=%s fonte=%s", result, *log_context)
        return Response(
            {
                "result": result,
                "is_latest": latest is not None and latest.pk == reading.pk,
                "operational_status": OperationalStatusSerializer(reading).data,
            },
            status=status.HTTP_201_CREATED if result == "created" else status.HTTP_200_OK,
        )
