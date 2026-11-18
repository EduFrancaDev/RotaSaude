from io import StringIO

from django.core.management import call_command
from django.test import override_settings

# O runner de testes força DEBUG=False; o modo de demonstração exige ambos.
demo_mode_on = override_settings(DEMO_MODE=True, DEBUG=True)


def run_command(name, *args):
    out, err = StringIO(), StringIO()
    call_command(name, *args, stdout=out, stderr=err)
    return out.getvalue(), err.getvalue()
