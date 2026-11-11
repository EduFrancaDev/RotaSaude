from django.conf import settings
from rest_framework.throttling import SimpleRateThrottle

from apps.integrations.models import IntegrationCredential


class IntegrationRateThrottle(SimpleRateThrottle):
    """Limite de requisições por credencial (`INTEGRATION_RATE_LIMIT`, ex.: `60/min`).

    Usa o cache padrão do Django: é local a cada processo (veja o README).
    """

    scope = "integration"

    def get_rate(self):
        return settings.INTEGRATION_RATE_LIMIT

    def get_cache_key(self, request, view):
        if not isinstance(request.auth, IntegrationCredential):
            return None
        return self.cache_format % {"scope": self.scope, "ident": request.auth.pk}
