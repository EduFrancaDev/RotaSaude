from django.db.models import OuterRef, Prefetch, Subquery
from rest_framework.viewsets import ReadOnlyModelViewSet

from apps.services.models import Service
from apps.units.models import HealthUnit, UnitOperationalStatus
from apps.units.serializers import HealthUnitSerializer


def latest_status_queryset():
    """Uma linha por unidade: a leitura com `source_updated_at` mais recente.

    Evita carregar todo o histórico e funciona em uma única consulta extra.
    """
    newest_id = (
        UnitOperationalStatus.objects.filter(health_unit=OuterRef("health_unit"))
        .order_by("-source_updated_at", "-received_at")
        .values("id")[:1]
    )
    return UnitOperationalStatus.objects.filter(id=Subquery(newest_id))


class HealthUnitViewSet(ReadOnlyModelViewSet):
    """Consulta de unidades. `{id}` é o `external_id` público.

    Filtros da listagem: `?city=` (sem diferenciar maiúsculas) e `?service=` (nome do serviço).
    """

    serializer_class = HealthUnitSerializer
    lookup_field = "external_id"
    lookup_value_regex = "[^/]+"

    def get_queryset(self):
        queryset = (
            HealthUnit.objects.filter(is_active=True)
            .prefetch_related(
                Prefetch("services", queryset=Service.objects.order_by("name")),
                Prefetch("operational_statuses", queryset=latest_status_queryset(), to_attr="latest_status"),
            )
            .order_by("name")
        )
        if self.action == "list":
            city = self.request.query_params.get("city")
            service = self.request.query_params.get("service")
            if city:
                queryset = queryset.filter(city__iexact=city.strip())
            if service:
                queryset = queryset.filter(services__name__iexact=service.strip())
        return queryset
