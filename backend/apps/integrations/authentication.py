import logging

from rest_framework import authentication, exceptions, permissions

from apps.integrations.models import IntegrationCredential, hash_key

logger = logging.getLogger(__name__)

MAX_TOKEN_LENGTH = 200
INVALID_MESSAGE = "Credencial de integração inválida ou revogada."


class IntegrationPrincipal:
    """Identidade de uma chave de integração. Não é um usuário do Django e não tem permissões."""

    is_authenticated = True
    is_anonymous = False

    def __init__(self, credential):
        self.credential = credential

    def __str__(self):
        return f"integration:{self.credential.key_prefix}"


class IntegrationKeyAuthentication(authentication.BaseAuthentication):
    """`Authorization: Bearer <chave>`. Usada apenas nas views de integração."""

    def authenticate(self, request):
        header = authentication.get_authorization_header(request).decode("latin-1").split()
        if not header or header[0].lower() != "bearer":
            return None
        if len(header) != 2 or len(header[1]) > MAX_TOKEN_LENGTH:
            raise exceptions.AuthenticationFailed(INVALID_MESSAGE)

        credential = (
            IntegrationCredential.objects.select_related("health_unit")
            .filter(key_hash=hash_key(header[1]))
            .first()
        )
        if credential is None or not credential.is_active:
            # Nunca registra a chave recebida, nem parcialmente.
            logger.warning("Integração: autenticação recusada (chave desconhecida ou revogada)")
            raise exceptions.AuthenticationFailed(INVALID_MESSAGE)
        return IntegrationPrincipal(credential), credential

    def authenticate_header(self, request):
        return 'Bearer realm="integration"'


class IsIntegrationCredential(permissions.BasePermission):
    def has_permission(self, request, view):
        return isinstance(request.auth, IntegrationCredential)
