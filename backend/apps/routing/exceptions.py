class RoutingError(Exception):
    """Falha ao obter rota (provedor, rede ou resposta inválida)."""


class ProviderUnavailable(RoutingError):
    """Provedor indisponível, tempo esgotado ou limitado temporariamente."""


class ProviderResponseError(RoutingError):
    """Provedor respondeu, mas sem rota utilizável."""
