from django.contrib import admin
from django.urls import include, path

from config.views import health

api_v1 = [
    path("health/", health, name="health"),
    path("", include("apps.units.urls")),
    path("", include("apps.services.urls")),
    path("", include("apps.integrations.urls")),
]

urlpatterns = [
    path("admin/", admin.site.urls),
    path("api/v1/", include((api_v1, "v1"))),
]
