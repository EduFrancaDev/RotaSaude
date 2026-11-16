from django.urls import path

from apps.integrations.views import OperationalStatusIngestView

urlpatterns = [
    path(
        "integrations/operational-status/",
        OperationalStatusIngestView.as_view(),
        name="integration-operational-status",
    ),
]
