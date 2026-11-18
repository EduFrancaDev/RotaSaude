"""Controle do modo de demonstração.

O modo é opt-in (`DEMO_MODE=true`) e só vale com `DJANGO_DEBUG=true`. Nada neste app
roda na inicialização do Django: tudo é acionado por comandos de gerenciamento ou pela
requisição de rota de ônibus simulada.
"""

from django.conf import settings


class DemoModeDisabled(Exception):
    """O modo de demonstração está desligado ou bloqueado neste ambiente."""


def demo_mode_enabled() -> bool:
    # Avaliado a cada chamada (não no import) para respeitar `override_settings`.
    return bool(settings.DEMO_MODE and settings.DEBUG)


def require_demo_mode() -> None:
    if not demo_mode_enabled():
        raise DemoModeDisabled(
            "Modo de demonstração desligado. Defina DEMO_MODE=true com DJANGO_DEBUG=true "
            "(ele é bloqueado quando DJANGO_DEBUG=false)."
        )
