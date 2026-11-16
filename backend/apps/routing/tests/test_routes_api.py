from unittest import mock

from django.core.cache import cache
from django.test import TestCase, override_settings
from django.urls import reverse

from apps.routing.exceptions import ProviderResponseError, ProviderUnavailable
from apps.units.tests.helpers import make_unit

ROUTE_PAYLOAD = {
    "provider": "osrm",
    "mode": "driving",
    "unit_id": "upa-centro",
    "distance_meters": 1200.0,
    "duration_seconds": 180.0,
    "geometry": {"type": "LineString", "coordinates": [[-49.26, -16.68], [-49.264, -16.6862]]},
}


class RouteAPITests(TestCase):
    def setUp(self):
        cache.clear()
        self.url = reverse("v1:route")
        make_unit("upa-centro", latitude=-16.6862, longitude=-49.264)

    def query(self, **params):
        defaults = {
            "origin_lat": -16.6869,
            "origin_lon": -49.2648,
            "unit_id": "upa-centro",
            "mode": "driving",
        }
        defaults.update(params)
        return self.client.get(self.url, defaults)

    @mock.patch("apps.routing.views.fetch_route", return_value=ROUTE_PAYLOAD)
    def test_success(self, fetch_route):
        response = self.query()

        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertEqual(body, ROUTE_PAYLOAD)
        fetch_route.assert_called_once()
        call = fetch_route.call_args.kwargs
        self.assertEqual(call["unit_id"], "upa-centro")
        self.assertAlmostEqual(call["dest_lat"], -16.6862)
        self.assertAlmostEqual(call["dest_lon"], -49.264)

    def test_invalid_coordinates(self):
        self.assertEqual(self.query(origin_lat=100).status_code, 400)
        self.assertEqual(self.query(origin_lon=200).status_code, 400)
        self.assertEqual(self.query(origin_lat="x").status_code, 400)

    def test_missing_params(self):
        response = self.client.get(self.url, {"unit_id": "upa-centro"})
        self.assertEqual(response.status_code, 400)

    def test_unit_not_found(self):
        response = self.query(unit_id="nao-existe")
        self.assertEqual(response.status_code, 404)

    def test_inactive_unit_not_found(self):
        make_unit("inativa", is_active=False)
        self.assertEqual(self.query(unit_id="inativa").status_code, 404)

    def test_transit_mode_explicit_error(self):
        response = self.query(mode="bus")
        self.assertEqual(response.status_code, 400)
        self.assertIn("transporte público", response.json()["mode"][0].lower())

    def test_unsupported_mode(self):
        response = self.query(mode="flying")
        self.assertEqual(response.status_code, 400)

    @mock.patch("apps.routing.views.fetch_route", side_effect=ProviderUnavailable("indisponível"))
    def test_provider_unavailable_503(self, _):
        self.assertEqual(self.query().status_code, 503)
        self.assertNotIn("traceback", self.query().content.decode().lower())

    @mock.patch("apps.routing.views.fetch_route", side_effect=ProviderResponseError("sem rota"))
    def test_provider_bad_route_502(self, _):
        self.assertEqual(self.query().status_code, 502)

    @mock.patch("apps.routing.views.fetch_route", side_effect=RuntimeError("segredo"))
    def test_internal_error_not_leaked(self, _):
        response = self.query()
        self.assertEqual(response.status_code, 500)
        self.assertNotIn("segredo", response.content.decode())

    def test_write_methods_not_allowed(self):
        self.assertEqual(self.client.post(self.url).status_code, 405)

    @override_settings(ROUTING_RATE_LIMIT="1/min")
    def test_throttle_returns_429(self):
        with mock.patch("apps.routing.views.fetch_route", return_value=ROUTE_PAYLOAD):
            self.assertEqual(self.query().status_code, 200)
            self.assertEqual(self.query().status_code, 429)
