import json
from unittest import mock

from django.test import SimpleTestCase, override_settings

from apps.routing.exceptions import ProviderResponseError, ProviderUnavailable
from apps.routing.providers.osrm import OSRMRoutingProvider


class OSRMRoutingProviderTests(SimpleTestCase):
    def setUp(self):
        self.provider = OSRMRoutingProvider("https://router.project-osrm.org", timeout_seconds=5)

    def _mock_response(self, payload, status=200):
        body = json.dumps(payload).encode()

        class FakeHTTP:
            def __enter__(self):
                return self

            def __exit__(self, *args):
                return None

            def read(self):
                return body

        return FakeHTTP()

    @mock.patch("apps.routing.providers.osrm.urlopen")
    def test_success_returns_normalized_geometry_lon_lat(self, urlopen):
        urlopen.return_value = self._mock_response(
            {
                "code": "Ok",
                "routes": [
                    {
                        "distance": 5800.2,
                        "duration": 840.5,
                        "geometry": {
                            "type": "LineString",
                            "coordinates": [[-49.26, -16.68], [-49.264, -16.6862]],
                        },
                    }
                ],
            }
        )

        result = self.provider.route(
            origin_lat=-16.6869,
            origin_lon=-49.2648,
            dest_lat=-16.6862,
            dest_lon=-49.264,
            mode="driving",
        )

        self.assertEqual(result.provider, "osrm")
        self.assertEqual(result.mode, "driving")
        self.assertEqual(result.distance_meters, 5800.2)
        self.assertEqual(result.duration_seconds, 840.5)
        self.assertEqual(result.geometry["coordinates"][0], [-49.26, -16.68])
        called_url = urlopen.call_args[0][0].full_url
        self.assertIn("overview=full", called_url)
        self.assertIn("geometries=geojson", called_url)
        self.assertIn("steps=false", called_url)
        self.assertIn("-49.2648,-16.6869;-49.264,-16.6862", called_url)

    @mock.patch("apps.routing.providers.osrm.urlopen")
    def test_http_error_raises_unavailable(self, urlopen):
        import urllib.error

        urlopen.side_effect = urllib.error.HTTPError(None, 429, "", {}, None)
        with self.assertRaises(ProviderUnavailable):
            self.provider.route(
                origin_lat=-16.68,
                origin_lon=-49.26,
                dest_lat=-16.69,
                dest_lon=-49.27,
                mode="driving",
            )

    @mock.patch("apps.routing.providers.osrm.urlopen")
    def test_no_route_raises_response_error(self, urlopen):
        urlopen.return_value = self._mock_response({"code": "NoRoute", "routes": []})
        with self.assertRaises(ProviderResponseError):
            self.provider.route(
                origin_lat=-16.68,
                origin_lon=-49.26,
                dest_lat=-16.69,
                dest_lon=-49.27,
                mode="driving",
            )

    @override_settings(ROUTING_PROVIDER="google")
    def test_get_provider_unknown_raises(self):
        from django.core.exceptions import ImproperlyConfigured

        from apps.routing.services import get_routing_provider

        with self.assertRaises(ImproperlyConfigured):
            get_routing_provider()
