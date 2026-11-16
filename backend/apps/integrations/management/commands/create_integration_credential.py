from django.core.management.base import BaseCommand, CommandError

from apps.integrations.models import IntegrationCredential
from apps.units.models import HealthUnit


class Command(BaseCommand):
    help = (
        "Emite uma chave de integração para uma unidade. A chave é impressa UMA vez no stdout "
        "(somente ela); os metadados vão para o stderr, o que permite TOKEN=$(...)."
    )

    def add_arguments(self, parser):
        parser.add_argument("unit_id", help="external_id da unidade (ex.: upa-centro)")
        parser.add_argument("--name", required=True, help="Identificação da credencial (ex.: 'Demo curl')")

    def handle(self, *args, **options):
        try:
            unit = HealthUnit.objects.get(external_id=options["unit_id"])
        except HealthUnit.DoesNotExist:
            raise CommandError(f"Unidade '{options['unit_id']}' não encontrada.")

        credential, token = IntegrationCredential.issue(unit, options["name"])
        self.stderr.write(
            f"Credencial {credential.key_prefix}… emitida para '{unit.external_id}'"
            f"{' (unidade DEMONSTRATIVA)' if unit.is_demo else ''}. "
            "A chave abaixo não poderá ser consultada novamente."
        )
        self.stdout.write(token)
