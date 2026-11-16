from django.contrib import admin

from apps.units.models import HealthUnit, HealthUnitService, UnitOperationalStatus


class HealthUnitServiceInline(admin.TabularInline):
    model = HealthUnitService
    extra = 1


@admin.register(HealthUnit)
class HealthUnitAdmin(admin.ModelAdmin):
    list_display = ["name", "external_id", "city", "state", "is_active", "is_demo"]
    list_filter = ["is_active", "is_demo", "state", "city"]
    search_fields = ["name", "external_id", "address", "city"]
    inlines = [HealthUnitServiceInline]


@admin.register(UnitOperationalStatus)
class UnitOperationalStatusAdmin(admin.ModelAdmin):
    """Histórico preservado: leituras podem ser criadas, mas não editadas nem apagadas."""

    list_display = [
        "health_unit",
        "availability_level",
        "estimated_wait_minutes",
        "people_waiting",
        "source_updated_at",
        "received_at",
        "is_demo",
    ]
    list_filter = ["availability_level", "is_demo"]
    search_fields = ["health_unit__name", "health_unit__external_id"]
    date_hierarchy = "source_updated_at"
    list_select_related = ["health_unit"]

    def has_change_permission(self, request, obj=None):
        return False

    def has_delete_permission(self, request, obj=None):
        return False
