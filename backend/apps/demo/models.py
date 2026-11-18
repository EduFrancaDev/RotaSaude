from django.db import models

from apps.units.models import UnitOperationalStatus


class DemoReadingMark(models.Model):
    """Marca uma leitura como gerada pelo simulador e registra o cenário aplicado.

    Fica em tabela própria para não alterar o contrato nem o esquema de `units`. A leitura
    em si é um `UnitOperationalStatus` comum (com `is_demo=True`) e imutável.
    """

    status = models.OneToOneField(
        UnitOperationalStatus,
        on_delete=models.CASCADE,
        related_name="demo_mark",
        verbose_name="leitura",
    )
    scenario = models.CharField("cenário", max_length=32)
    created_at = models.DateTimeField("criada em", auto_now_add=True)

    class Meta:
        verbose_name = "marca de leitura demonstrativa"
        verbose_name_plural = "marcas de leituras demonstrativas"

    def __str__(self):
        return f"{self.status} · {self.scenario}"
