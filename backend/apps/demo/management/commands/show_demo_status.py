"""Exibe as UPAs demonstrativas e sua última leitura (somente leitura)."""

from django.core.management.base import BaseCommand, CommandError
from django.utils import timezone

from apps.demo.guard import demo_mode_enabled
from apps.demo.profiles import PROFILES
from apps.demo.readings import UPDATE_LABELS, demo_units, latest_reading, scenario_of, update_state
from apps.demo.scenarios import SCENARIOS
from apps.units.models import HealthUnit


def _fmt(value, suffix=""):
    return "—" if value is None else f"{value}{suffix}"


class Command(BaseCommand):
    help = "Lista as UPAs DEMONSTRATIVAS com a última leitura, o cenário e a situação da atualização."

    def add_arguments(self, parser):
        parser.add_argument("--unit", metavar="ID", help="Mostra só esta UPA.")
        parser.add_argument("--history", type=int, metavar="N", help="Com --unit, lista as N últimas leituras.")

    def handle(self, *args, **options):
        now = timezone.now()
        enabled = "ligado" if demo_mode_enabled() else "DESLIGADO (leitura apenas; simulações exigem DEMO_MODE=true)"
        self.stdout.write(f"Modo de demonstração: {enabled}\nDados fictícios — demonstração acadêmica.\n")

        if options["history"] is not None and not options["unit"]:
            raise CommandError("--history exige --unit.")

        units = demo_units()
        if options["unit"]:
            units = units.filter(external_id=options["unit"])
            if not units.exists():
                other = HealthUnit.objects.filter(external_id=options["unit"]).exists()
                raise CommandError(
                    f"{options['unit']} não é uma unidade demonstrativa ativa."
                    if other
                    else f"Unidade não encontrada: {options['unit']}."
                )
        if not units:
            self.stdout.write("Nenhuma UPA demonstrativa. Rode seed_demo_scenarios.")
            return

        for unit in units:
            reading = latest_reading(unit)
            state = update_state(reading, now)
            profile = PROFILES.get(unit.external_id)
            self.stdout.write(f"{unit.external_id} · {unit.name} · papel: {profile.role if profile else 'sem perfil'}")
            if reading is None:
                self.stdout.write("    sem leituras operacionais\n")
                continue
            key = scenario_of(reading)
            scenario = SCENARIOS[key].label if key in SCENARIOS else "sem marca (seed/integração)"
            age = int((now - reading.source_updated_at).total_seconds() // 60)
            at = timezone.localtime(reading.source_updated_at).strftime("%d/%m %H:%M")
            self.stdout.write(
                f"    cenário: {scenario}\n"
                f"    pessoas: {_fmt(reading.people_waiting)} · espera: {_fmt(reading.estimated_wait_minutes, ' min')}"
                f" · disponibilidade: {_fmt(reading.availability_level)}\n"
                f"    última leitura: {at} (há {age} min) · atualização: {UPDATE_LABELS[state]}\n"
            )
            if options["history"]:
                self._history(unit, options["history"])

    def _history(self, unit, limit):
        self.stdout.write("    histórico (mais recente primeiro):")
        readings = unit.operational_statuses.select_related("demo_mark").order_by("-source_updated_at")[:limit]
        for reading in readings:
            key = scenario_of(reading)
            at = timezone.localtime(reading.source_updated_at).strftime("%d/%m %H:%M:%S")
            self.stdout.write(
                f"      {at} · {key or 'sem marca'} · {_fmt(reading.people_waiting)} pessoas · "
                f"{_fmt(reading.estimated_wait_minutes, ' min')} · {_fmt(reading.availability_level)}"
            )
        self.stdout.write("")
