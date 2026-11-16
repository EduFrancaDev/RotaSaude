from rest_framework.generics import ListAPIView

from apps.services.models import Service
from apps.services.serializers import ServiceSerializer


class ServiceListView(ListAPIView):
    """Lista os serviços cadastrados (somente leitura)."""

    queryset = Service.objects.all()
    serializer_class = ServiceSerializer
