from django.conf import settings
from django.utils import timezone
from django.utils.functional import cached_property
from rest_framework import serializers

from apps.demo.profiles import PROFILES
from apps.demo.scenarios import RANDOM_POOL, SCENARIOS
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

    @cached_property
    def _simulation_minute(self):
        return timezone.now().replace(second=0, microsecond=0)

    def to_representation(self, instance):
        data = super().to_representation(instance)
        if not settings.DEMO_API_QUEUE_SIMULATION or not instance.is_demo:
            return data

        profile = PROFILES.get(instance.external_id)
        if profile is None or profile.reserved:
            return data

        minute = self._simulation_minute
        scenario = profile.scenario
        if not profile.pinned:
            offset = RANDOM_POOL.index(scenario)
            cycle = int(minute.timestamp()) // 60
            scenario = RANDOM_POOL[(cycle + offset) % len(RANDOM_POOL)]

        reading = UnitOperationalStatus(
            **SCENARIOS[scenario].values,
            source_updated_at=minute,
            received_at=minute,
            is_demo=True,
        )
        status = OperationalStatusSerializer(reading).data
        data["name"] = f"{instance.name} (dados simulados)"
        data["operational_status"] = status
        data["last_operational_update_at"] = status["source_updated_at"]
        return data

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
