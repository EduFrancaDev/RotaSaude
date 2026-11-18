"""Serviço de atualização automática das UPAs DEMONSTRATIVAS.

    python manage.py run_demo_auto_update

Processo de longa duração, separado da API (no Compose, o serviço `simulator`). Exige
DEMO_AUTO_UPDATE=true, DEMO_MODE=true e DJANGO_DEBUG=true; o intervalo vem de
DEMO_UPDATE_INTERVAL. Com DEMO_AUTO_UPDATE=false, registra que está desligado e sai com
sucesso (código 0), para não ser reiniciado em laço. Encerre com SIGTERM ou Ctrl+C.
"""

import logging
import random

from django.core.management.base import BaseCommand, CommandError

from apps.demo.autoupdate import AutoUpdateConfigError, AutoUpdateDisabled, AutoUpdateService, configured_interval

logger = logging.getLogger("apps.demo.autoupdate")


class Command(BaseCommand):
    help = "Atualiza periodicamente as UPAs DEMONSTRATIVAS (exige DEMO_AUTO_UPDATE, DEMO_MODE e DJANGO_DEBUG)."

    def add_arguments(self, parser):
        parser.add_argument("--iterations", type=int, metavar="N", help="Encerra após N ciclos (verificações).")
        parser.add_argument("--seed", type=int, help="Semente do sorteio de `random` (reprodutível).")

    def handle(self, *args, **options):
        iterations = options["iterations"]
        if iterations is not None and iterations < 1:
            raise CommandError("--iterations deve ser pelo menos 1.")
        try:
            interval = configured_interval()
        except AutoUpdateDisabled as exc:
            logger.info("%s Nada a fazer; encerrando.", exc)
            return
        except AutoUpdateConfigError as exc:
            raise CommandError(str(exc)) from exc

        AutoUpdateService(interval, iterations=iterations, rng=random.Random(options["seed"])).run()
