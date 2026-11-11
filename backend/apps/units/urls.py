from rest_framework.routers import SimpleRouter

from apps.units.views import HealthUnitViewSet

router = SimpleRouter()
router.register("units", HealthUnitViewSet, basename="unit")

urlpatterns = router.urls
