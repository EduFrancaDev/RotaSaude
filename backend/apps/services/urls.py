from django.urls import path

from apps.services.views import ServiceListView

urlpatterns = [
    path("services/", ServiceListView.as_view(), name="service-list"),
]
