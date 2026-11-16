from rest_framework import serializers

SUPPORTED_MODES = frozenset({"driving"})
UNSUPPORTED_PUBLIC_TRANSIT = frozenset({"transit", "bus", "public_transport", "walking", "cycling"})


class RouteQuerySerializer(serializers.Serializer):
    origin_lat = serializers.FloatField(min_value=-90, max_value=90)
    origin_lon = serializers.FloatField(min_value=-180, max_value=180)
    unit_id = serializers.CharField(max_length=64)
    mode = serializers.CharField(default="driving")

    def validate_mode(self, value):
        normalized = value.strip().lower()
        if normalized in UNSUPPORTED_PUBLIC_TRANSIT:
            raise serializers.ValidationError(
                "Modo de transporte público ainda não está disponível. Use mode=driving."
            )
        if normalized not in SUPPORTED_MODES:
            raise serializers.ValidationError(
                f"Modo não suportado: {value!r}. Apenas mode=driving está disponível."
            )
        return normalized
