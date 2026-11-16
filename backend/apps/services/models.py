from django.db import models


class Service(models.Model):
    """Serviço de saúde oferecido por unidades (ex.: Pediatria)."""

    name = models.CharField("nome", max_length=120, unique=True)
    description = models.TextField("descrição", blank=True)

    class Meta:
        ordering = ["name"]
        verbose_name = "serviço"
        verbose_name_plural = "serviços"

    def __str__(self):
        return self.name
