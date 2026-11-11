from django.contrib import admin, messages

from apps.integrations.models import IntegrationCredential


@admin.register(IntegrationCredential)
class IntegrationCredentialAdmin(admin.ModelAdmin):
    """Emite e revoga chaves. A chave é exibida uma única vez, na mensagem após criar."""

    list_display = ["name", "health_unit", "key_prefix", "created_at", "revoked_at"]
    list_filter = ["revoked_at"]
    search_fields = ["name", "key_prefix", "health_unit__external_id", "health_unit__name"]
    list_select_related = ["health_unit"]
    fields = ["health_unit", "name", "key_prefix", "created_at", "revoked_at"]
    actions = ["revoke_selected"]

    def get_readonly_fields(self, request, obj=None):
        if obj is None:
            return ["key_prefix", "created_at", "revoked_at"]
        return self.fields  # depois de criada, só a ação "Revogar" altera a credencial

    def has_delete_permission(self, request, obj=None):
        return False  # preserva a trilha de auditoria; use a revogação

    def save_model(self, request, obj, form, change):
        if change:
            return
        token = obj.set_new_key()
        super().save_model(request, obj, form, change)
        self.message_user(
            request,
            f"Chave de integração (copie agora; não será exibida novamente): {token}",
            level=messages.WARNING,
        )

    @admin.action(description="Revogar credenciais selecionadas")
    def revoke_selected(self, request, queryset):
        for credential in queryset:
            credential.revoke()
        self.message_user(request, f"{queryset.count()} credencial(is) revogada(s).")
