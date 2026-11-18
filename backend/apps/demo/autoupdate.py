"""Atualização automática das UPAs demonstrativas (comando `run_demo_auto_update`).

Roda em um processo próprio, separado da API: nada aqui é iniciado pelo Django, por views,
middleware ou na importação. Cada ciclo usa as mesmas regras de `simulate_operational_status`
(`resolve_scenario` + `append_demo_reading`) e só acrescenta leituras ao histórico.

- Só altera as UPAs de cenário (`scenario_units`). As reservadas a "sem dados", "desatualizada"
  e "falha de atualização" nunca são tocadas; as marcadas como `pinned` renovam o próprio
  cenário de partida em vez de sortear.
- Grava apenas a instância que detém o advisory lock do PostgreSQL. Outras ficam em espera e
  assumem se a ativa parar ou perder a conexão.
- Falhas (banco indisponível, erro inesperado) são registradas e o ciclo seguinte tenta de novo.
- SIGTERM e SIGINT terminam o ciclo em andamento, liberam a trava e encerram o processo.
"""

import logging
import os
import random
import signal
import threading
import time

from django.conf import settings
from django.db import connection

from apps.demo.guard import DemoModeDisabled, require_demo_mode
from apps.demo.profiles import PROFILES
from apps.demo.readings import (
    DemoReadingError,
    append_demo_reading,
    describe_reading,
    resolve_scenario,
    scenario_units,
)
from apps.demo.scenarios import BASELINE, RANDOM

logger = logging.getLogger(__name__)

MIN_INTERVAL_SECONDS = 5
# (classid, objid) do advisory lock que elege a instância ativa. Arbitrário, mas fixo.
LOCK_KEY = (725100, 1)


class AutoUpdateDisabled(Exception):
    """DEMO_AUTO_UPDATE está desligado: não há nada a fazer."""


class AutoUpdateConfigError(Exception):
    """A configuração não permite a atualização automática com segurança."""


def configured_interval() -> int:
    """Confere as condições de segurança e devolve o intervalo, em segundos."""
    if not settings.DEMO_AUTO_UPDATE:
        raise AutoUpdateDisabled("Atualização automática desligada (DEMO_AUTO_UPDATE=false).")
    try:
        require_demo_mode()
    except DemoModeDisabled as exc:
        raise AutoUpdateConfigError(f"DEMO_AUTO_UPDATE=true recusado. {exc}") from exc
    if connection.vendor != "postgresql":
        raise AutoUpdateConfigError("A atualização automática exige PostgreSQL.")

    raw = str(settings.DEMO_UPDATE_INTERVAL).strip()
    try:
        interval = int(raw)
    except ValueError:
        raise AutoUpdateConfigError(f"DEMO_UPDATE_INTERVAL inválido: {raw!r} (use segundos inteiros).") from None
    if interval < MIN_INTERVAL_SECONDS:
        raise AutoUpdateConfigError(f"DEMO_UPDATE_INTERVAL deve ser de pelo menos {MIN_INTERVAL_SECONDS} segundos.")
    return interval


def auto_scenario(unit) -> str:
    profile = PROFILES.get(unit.external_id)
    return BASELINE if profile is not None and profile.pinned else RANDOM


class AutoUpdateService:
    def __init__(self, interval, *, iterations=None, rng=None):
        self.interval = interval
        self.iterations = iterations
        self.rng = rng or random.Random()
        self.stop = threading.Event()
        self._holding = False
        self._standby = False

    def run(self) -> int:
        """Executa até SIGTERM/SIGINT (ou `iterations` ciclos) e devolve quantos ciclos rodaram."""
        previous = {sig: signal.signal(sig, self._on_signal) for sig in (signal.SIGINT, signal.SIGTERM)}
        logger.info("Atualização automática iniciada: cenário random a cada %ss (pid %s).", self.interval, os.getpid())
        cycles = 0
        try:
            while not self.stop.is_set():
                started = time.monotonic()
                self.tick()
                cycles += 1
                if self.iterations is not None and cycles >= self.iterations:
                    break
                self.stop.wait(max(0.0, self.interval - (time.monotonic() - started)))
        finally:
            self._release_lock()
            for sig, handler in previous.items():
                signal.signal(sig, handler)
        logger.info("Atualização automática encerrada após %s ciclo(s).", cycles)
        return cycles

    def tick(self) -> bool:
        """Um ciclo completo. Nunca propaga falhas; devolve se as leituras foram processadas."""
        try:
            if not self._acquire_lock():
                if not self._standby:
                    logger.warning("Outra instância do simulador está ativa; esta fica em espera.")
                self._standby = True
                return False
            if self._standby:
                logger.info("Trava obtida: esta instância passou a atualizar as UPAs.")
                self._standby = False
            self.run_cycle()
            return True
        except Exception:
            logger.exception("Falha no ciclo de atualização; nova tentativa em %ss.", self.interval)
            self._discard_broken_connection()
            return False

    def run_cycle(self) -> int:
        started = time.monotonic()
        units = scenario_units()
        if not units:
            logger.warning("Nenhuma UPA demonstrativa elegível. Rode seed_demo_scenarios.")
            return 0
        written = skipped = 0
        for unit in units:
            try:
                key = resolve_scenario(unit, auto_scenario(unit), self.rng)
                reading = append_demo_reading(unit, key)
            except DemoReadingError as exc:
                skipped += 1
                logger.warning("%s: ignorada — %s", unit.external_id, exc)
                continue
            written += 1
            logger.info("%s", describe_reading(unit, key, reading))
        logger.info(
            "Ciclo concluído: %s leitura(s) gravada(s), %s ignorada(s) em %.2fs.",
            written,
            skipped,
            time.monotonic() - started,
        )
        return written

    def _on_signal(self, signum, frame):
        logger.info("%s recebido; encerrando após o ciclo em andamento.", signal.Signals(signum).name)
        self.stop.set()

    def _acquire_lock(self) -> bool:
        # A trava é da sessão: se a conexão cair, ela some e precisa ser obtida de novo.
        with connection.cursor() as cursor:
            cursor.execute(
                "SELECT EXISTS (SELECT 1 FROM pg_locks WHERE locktype = 'advisory' AND granted"
                " AND pid = pg_backend_pid() AND classid::bigint = %s AND objid::bigint = %s AND objsubid = 2)",
                LOCK_KEY,
            )
            if not cursor.fetchone()[0]:
                cursor.execute("SELECT pg_try_advisory_lock(%s::integer, %s::integer)", LOCK_KEY)
                self._holding = cursor.fetchone()[0]
        return self._holding

    def _release_lock(self):
        if not self._holding or connection.connection is None:
            return
        try:
            with connection.cursor() as cursor:
                cursor.execute("SELECT pg_advisory_unlock(%s::integer, %s::integer)", LOCK_KEY)
        except Exception:
            logger.warning("Não foi possível liberar a trava; ela é descartada quando a conexão fechar.")
        self._holding = False

    def _discard_broken_connection(self):
        try:
            if connection.connection is not None and not connection.is_usable():
                self._holding = False
                connection.close()
        except Exception:
            logger.warning("Conexão com o banco descartada após falha.")
