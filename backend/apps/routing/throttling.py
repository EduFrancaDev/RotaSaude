from django.conf import settings
from rest_framework.throttling import SimpleRateThrottle


class RoutesRateThrottle(SimpleRateThrottle):
    """Limite por cliente (IP) na API de rotas; complementa o controle outbound ao OSRM."""

    scope = "routes"

    def get_rate(self):
        return settings.ROUTING_RATE_LIMIT

    def get_cache_key(self, request, view):
        if request.user and request.user.is_authenticated:
            ident = request.user.pk
        else:
            ident = self.get_ident(request)
        return self.cache_format % {"scope": self.scope, "ident": ident}
