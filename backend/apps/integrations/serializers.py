from datetime import timedelta

from django.utils import timezone
from rest_framework import exceptions, serializers

from apps.units.models import UnitOperationalStatus

FUTURE_TOLERANCE = timedelta(minutes=5)
# Limites de sanidade da entrada (evitam estouro no banco e erros de unidade); não são regra clínica.
MAX_PEOPLE_WAITING = 100_000
MAX_WAIT_MINUTES = 7 * 24 * 60


class AwareDateTimeField(serializers.DateTimeField):
    """Exige timezone explícito: o DRF assumiria silenciosamente o fuso do servidor."""

    def enforce_timezone(self, value):
        if timezone.is_naive(value):
            raise serializers.ValidationError("Informe o fuso horário (ex.: 2026-11-11T09:30:00-03:00).")
        return value


class OperationalStatusInputSerializer(serializers.Serializer):
    """Leitura enviada pelo sistema do estabelecimento.

    Os quatro campos de dados são obrigatórios, mas aceitam `null` (dado indisponível):
    assim uma omissão acidental não vira, em silêncio, uma leitura vazia.
    Campos desconhecidos são rejeitados, o que impede o envio de informações adicionais
    (por exemplo, dados de pacientes).
    """

    unit_id = serializers.CharField(max_length=64)
    people_waiting = serializers.IntegerField(min_value=0, max_value=MAX_PEOPLE_WAITING, allow_null=True)
    estimated_wait_minutes = serializers.IntegerField(min_value=0, max_value=MAX_WAIT_MINUTES, allow_null=True)
    availability_level = serializers.ChoiceField(
        choices=UnitOperationalStatus.AvailabilityLevel.choices, allow_null=True
    )
    source_updated_at = AwareDateTimeField()

    def to_internal_value(self, data):
        if isinstance(data, dict):
            unknown = sorted(set(data) - set(self.fields))
            if unknown:
                raise serializers.ValidationError(
                    {name: "Campo não permitido." for name in unknown}
                )
        return super().to_internal_value(data)

    def validate_unit_id(self, value):
        credential = self.context["credential"]
        if value != credential.health_unit.external_id:
            # Mesma resposta para unidade inexistente e para unidade de outra credencial.
            raise exceptions.PermissionDenied("Credencial não autorizada para esta unidade.")
        return value

    def validate_source_updated_at(self, value):
        if value > timezone.now() + FUTURE_TOLERANCE:
            raise serializers.ValidationError("A data da leitura está no futuro.")
        return value
