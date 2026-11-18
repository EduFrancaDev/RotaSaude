"""Simula leituras operacionais das UPAs DEMONSTRATIVAS.

Exemplos:
    python manage.py simulate_operational_status --unit upa-centro --scenario critical --once
    python manage.py simulate_operational_status --all --scenario moderate --once
    python manage.py simulate_operational_status --all --scenario random --interval 60

Cada execução acrescenta leituras novas ao histórico (nada é alterado ou apagado) e só atua
em unidades `is_demo`. O processo periódico é sempre iniciado manualmente; encerre com Ctrl+C
(SIGINT) ou SIGTERM, que terminam o ciclo em andamento antes de sair.
"""

import random
import signal
import threading

from django.core.management.base import BaseCommand, CommandError
from django.utils import timezone

from apps.demo.guard import DemoModeDisabled, require_demo_mode
from apps.demo.profiles import PROFILES
from apps.demo.readings import DemoReadingError, append_demo_reading, demo_units, resolve_scenario
from apps.demo.scenarios import BASELINE, CHOICES, SCENARIOS
from apps.units.models import HealthUnit

MIN_INTERVAL_SECONDS = 5


class Command(BaseCommand):
    help = "Gera leituras operacionais DEMONSTRATIVAS (exige DEMO_MODE=true; não toca em unidades reais)."

    def add_arguments(self, parser):
        target = parser.add_mutually_exclusive_group(required=True)
        target.add_argument("--unit", action="append", dest="units", metavar="ID", help="external_id da UPA (repetível).")
        target.add_argument(
            "--all",
            action="store_true",
            help="Todas as UPAs demonstrativas, exceto as reservadas a demonstrar ausência de dados "
            "(upa-oeste, upa-leste, upa-sudoeste), que só mudam com --unit.",
        )
        parser.add_argument(
            "--scenario",
            required=True,
            choices=CHOICES,
            help="low, moderate, high, critical, unavailable (falha de atualização), random "
            f"(sorteia entre os de movimento) ou {BASELINE} (cenário de partida de cada UPA).",
        )
        mode = parser.add_mutually_exclusive_group()
        mode.add_argument("--once", action="store_true", help="Uma única atualização (padrão).")
        mode.add_argument("--interval", type=int, metavar="SEGUNDOS", help="Repete a cada N segundos até Ctrl+C.")
        parser.add_argument("--iterations", type=int, metavar="N", help="Com --interval, para após N ciclos.")
        parser.add_argument("--seed", type=int, help="Semente do sorteio de `random` (reprodutível).")

    def handle(self, *args, **options):
        try:
            require_demo_mode()
        except DemoModeDisabled as exc:
            raise CommandError(str(exc)) from exc

        interval = options["interval"]
        if interval is not None and interval < MIN_INTERVAL_SECONDS:
            raise CommandError(f"--interval deve ser de pelo menos {MIN_INTERVAL_SECONDS} segundos.")
        if options["iterations"] is not None:
            if interval is None:
                raise CommandError("--iterations só faz sentido com --interval.")
            if options["iterations"] < 1:
                raise CommandError("--iterations deve ser pelo menos 1.")

        units = self._resolve_units(options)
        rng = random.Random(options["seed"])
        scenario = options["scenario"]

        if interval is None:
            written = self._cycle(units, scenario, rng)
            if written == 0:
                raise CommandError("Nenhuma leitura foi gravada.")
            return

        stop = threading.Event()
        previous = {sig: signal.signal(sig, lambda *_: stop.set()) for sig in (signal.SIGINT, signal.SIGTERM)}
        self.stdout.write(f"Simulação a cada {interval}s. Ctrl+C para encerrar.")
        try:
            cycles = 0
            while not stop.is_set():
                self._cycle(units, scenario, rng)
                cycles += 1
                if options["iterations"] is not None and cycles >= options["iterations"]:
                    break
                stop.wait(interval)
        finally:
            for sig, handler in previous.items():
                signal.signal(sig, handler)
        self.stdout.write(self.style.SUCCESS(f"Simulação encerrada após {cycles} ciclo(s)."))

    def _resolve_units(self, options):
        if options["all"]:
            units = [u for u in demo_units() if not (PROFILES.get(u.external_id) and PROFILES[u.external_id].reserved)]
            if not units:
                raise CommandError("Nenhuma UPA demonstrativa disponível. Rode seed_demo_scenarios primeiro.")
            return units

        units = []
        for external_id in dict.fromkeys(options["units"]):
            unit = HealthUnit.objects.filter(external_id=external_id).first()
            if unit is None:
                raise CommandError(f"Unidade não encontrada: {external_id}.")
            if not unit.is_demo:
                raise CommandError(f"{external_id} não é uma unidade demonstrativa; a simulação foi recusada.")
            if not unit.is_active:
                raise CommandError(f"{external_id} está inativa.")
            units.append(unit)
        return units

    def _cycle(self, units, requested, rng):
        written = 0
        for unit in units:
            try:
                key = resolve_scenario(unit, requested, rng)
                reading = append_demo_reading(unit, key)
            except DemoReadingError as exc:
                self.stderr.write(self.style.WARNING(f"{unit.external_id}: ignorada — {exc}"))
                continue
            written += 1
            scenario = SCENARIOS[key]
            at = timezone.localtime(reading.source_updated_at).strftime("%H:%M:%S")
            values = (
                "sem valores (falha de atualização)"
                if key == "unavailable"
                else f"{reading.people_waiting} pessoas · {reading.estimated_wait_minutes} min · {reading.availability_level}"
            )
            self.stdout.write(f"[{at}] {unit.external_id:<13} {scenario.label} → {values} [DEMONSTRATIVO]")
        return written
