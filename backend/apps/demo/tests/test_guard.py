import os
import subprocess
import sys
from pathlib import Path

from django.core.management.base import CommandError
from django.test import SimpleTestCase, TestCase, override_settings

from apps.demo.guard import DemoModeDisabled, demo_mode_enabled, require_demo_mode
from apps.demo.models import DemoReadingMark
from apps.demo.tests.helpers import run_command
from apps.units.models import UnitOperationalStatus
from apps.units.tests.helpers import make_unit

BACKEND_DIR = Path(__file__).resolve().parents[3]


class DemoModeGuardTests(SimpleTestCase):
    def test_disabled_by_default(self):
        self.assertFalse(demo_mode_enabled())
        with self.assertRaises(DemoModeDisabled):
            require_demo_mode()

    @override_settings(DEMO_MODE=True, DEBUG=True)
    def test_enabled_only_when_flag_and_debug(self):
        self.assertTrue(demo_mode_enabled())
        require_demo_mode()

    @override_settings(DEMO_MODE=True, DEBUG=False)
    def test_blocked_when_debug_is_off(self):
        self.assertFalse(demo_mode_enabled())

    @override_settings(DEMO_MODE=False, DEBUG=True)
    def test_flag_off_wins_over_debug(self):
        self.assertFalse(demo_mode_enabled())

    def _import_settings(self, **env):
        base = {k: v for k, v in os.environ.items() if not k.startswith("DEMO_") and k != "DJANGO_DEBUG"}
        return subprocess.run(
            [sys.executable, "-c", "import config.settings"],
            cwd=BACKEND_DIR,
            env={**base, **env},
            capture_output=True,
            text=True,
        )

    def test_settings_refuse_demo_mode_without_debug(self):
        result = self._import_settings(DEMO_MODE="true", DJANGO_DEBUG="false", DJANGO_SECRET_KEY="x")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("DEMO_MODE exige DJANGO_DEBUG=true", result.stderr)

    def test_settings_accept_demo_mode_with_debug(self):
        self.assertEqual(self._import_settings(DEMO_MODE="true", DJANGO_DEBUG="true").returncode, 0)

    def test_settings_default_is_off(self):
        result = self._import_settings(DJANGO_DEBUG="true")
        self.assertEqual(result.returncode, 0)


class WritingCommandsRequireDemoModeTests(TestCase):
    def setUp(self):
        self.unit = make_unit("upa-x", is_demo=True)

    def assert_nothing_written(self):
        self.assertEqual(UnitOperationalStatus.objects.count(), 0)
        self.assertEqual(DemoReadingMark.objects.count(), 0)

    def test_simulator_refuses_when_off(self):
        with self.assertRaisesMessage(CommandError, "Modo de demonstração desligado"):
            run_command("simulate_operational_status", "--unit", "upa-x", "--scenario", "low", "--once")
        self.assert_nothing_written()

    @override_settings(DEMO_MODE=True, DEBUG=False)
    def test_simulator_refuses_when_debug_is_off(self):
        with self.assertRaises(CommandError):
            run_command("simulate_operational_status", "--all", "--scenario", "low")
        self.assert_nothing_written()

    def test_seed_scenarios_refuses_when_off(self):
        with self.assertRaises(CommandError):
            run_command("seed_demo_scenarios")
        self.assert_nothing_written()
        self.assertEqual(self.unit.__class__.objects.count(), 1)

    def test_show_status_is_read_only_and_works_when_off(self):
        out, _ = run_command("show_demo_status")
        self.assertIn("DESLIGADO", out)
        self.assert_nothing_written()
