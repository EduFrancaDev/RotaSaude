from rest_framework import serializers

from apps.units.models import HealthUnit, UnitOperationalStatus


class OperationalStatusSerializer(serializers.ModelSerializer):
    class Meta:
        model = UnitOperationalStatus
        fields = [
            "people_waiting",
            "estimated_wait_minutes",
            "availability_level",
            "source_updated_at",
            "received_at",
            "is_demo",
        ]
        read_only_fields = fields


class HealthUnitSerializer(serializers.ModelSerializer):
    """Representação pública da unidade.

    Espera que a view tenha feito `prefetch_related` de `services` e do status mais
    recente em `latest_status` (veja `HealthUnitViewSet.get_queryset`).
    """

    id = serializers.CharField(source="external_id", read_only=True)
    services = serializers.SerializerMethodField()
    operational_status = serializers.SerializerMethodField()
    last_operational_update_at = serializers.SerializerMethodField()

    class Meta:
        model = HealthUnit
        fields = [
            "id",
            "name",
            "address",
            "city",
            "state",
            "latitude",
            "longitude",
            "phone",
            "opening_hours",
            "is_demo",
            "services",
            "operational_status",
            "last_operational_update_at",
        ]
        read_only_fields = fields

    def get_services(self, obj):
        return [service.name for service in obj.services.all()]

    def _latest_status(self, obj):
        return obj.latest_status[0] if obj.latest_status else None

    def get_operational_status(self, obj):
        status = self._latest_status(obj)
        return OperationalStatusSerializer(status).data if status else None

    def get_last_operational_update_at(self, obj):
        status = self._latest_status(obj)
        if status is None:
            return None
        return serializers.DateTimeField().to_representation(status.source_updated_at)
