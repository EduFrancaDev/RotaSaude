from unittest import mock

from django.core.cache import cache
from django.test import TestCase, override_settings

from apps.routing.exceptions import ProviderUnavailable
from apps.routing.providers.base import RouteResult
from apps.routing.services import _cache_key, fetch_route


class FetchRouteServiceTests(TestCase):
    def setUp(self):
        cache.clear()

    def test_cache_returns_without_second_provider_call(self):
        payload = {
            "provider": "osrm",
            "mode": "driving",
            "unit_id": "upa-centro",
            "distance_meters": 1.0,
            "duration_seconds": 1.0,
            "geometry": {"type": "LineString", "coordinates": []},
        }
        key = _cache_key(mode="driving", unit_id="upa-centro", origin_lat=-16.6869, origin_lon=-49.2648)
        cache.set(key, payload, timeout=60)

        with mock.patch("apps.routing.services.get_routing_provider") as get_provider:
            result = fetch_route(
                origin_lat=-16.6869,
                origin_lon=-49.2648,
                dest_lat=-16.6862,
                dest_lon=-49.264,
                unit_id="upa-centro",
                mode="driving",
            )

        self.assertEqual(result, payload)
        get_provider.assert_not_called()

    @mock.patch("apps.routing.services.get_routing_provider")
    def test_stores_result_in_cache(self, get_provider):
        get_provider.return_value.route.return_value = RouteResult(
            provider="osrm",
            mode="driving",
            distance_meters=100.0,
            duration_seconds=50.0,
            geometry={"type": "LineString", "coordinates": [[-49.0, -16.0]]},
        )
        cache.delete("routing:osrm:inflight")
        cache.delete("routing:osrm:last_call")

        fetch_route(
            origin_lat=-16.69,
            origin_lon=-49.27,
            dest_lat=-16.68,
            dest_lon=-49.26,
            unit_id="upa-sul",
            mode="driving",
        )

        key = _cache_key(mode="driving", unit_id="upa-sul", origin_lat=-16.69, origin_lon=-49.27)
        self.assertIsNotNone(cache.get(key))

    @override_settings(OSRM_MIN_REQUEST_INTERVAL=3600)
    @mock.patch("apps.routing.services.get_routing_provider")
    def test_outbound_spacing_blocks_back_to_back_calls(self, get_provider):
        get_provider.return_value.route.return_value = RouteResult(
            provider="osrm",
            mode="driving",
            distance_meters=1.0,
            duration_seconds=1.0,
            geometry={"type": "LineString", "coordinates": [[-49.0, -16.0]]},
        )
        cache.clear()
        fetch_route(
            origin_lat=-16.701,
            origin_lon=-49.271,
            dest_lat=-16.68,
            dest_lon=-49.26,
            unit_id="a",
            mode="driving",
        )
        with self.assertRaises(ProviderUnavailable):
            fetch_route(
                origin_lat=-16.702,
                origin_lon=-49.272,
                dest_lat=-16.68,
                dest_lon=-49.26,
                unit_id="b",
                mode="driving",
            )
