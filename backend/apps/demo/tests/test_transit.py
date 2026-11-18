from datetime import datetime, timedelta
from unittest import mock

from django.core.cache import cache
from django.test import TestCase, override_settings
from django.urls import reverse
from django.utils import timezone

from apps.demo.tests.helpers import demo_mode_on
from apps.demo.transit import (
    COVERAGE_CENTER,
    COVERAGE_RADIUS_M,
    LINES,
    NoSimulatedRoute,
    haversine_m,
    simulate_bus_route,
)
from apps.units.tests.helpers import make_unit

ORIGIN = (-16.6869, -49.2648)  # centro de Goiânia
SUL = (-16.7100, -49.2590)
FIXED_NOW = timezone.make_aware(datetime(2026, 11, 18, 10, 2, 30))


def simulate(**overrides):
    args = dict(
        unit_id="upa-sul", unit_is_demo=True, origin_lat=ORIGIN[0], origin_lon=ORIGIN[1],
        dest_lat=SUL[0], dest_lon=SUL[1], now=FIXED_NOW,
    )
    args.update(overrides)
    return simulate_bus_route(**args)


class SimulatedBusRouteTests(TestCase):
    def test_marks_everything_as_simulated(self):
        route = simulate()
        self.assertTrue(route["is_simulated"])
        self.assertEqual(route["provider"], "demo-simulated")
        self.assertEqual(route["mode"], "bus")
        self.assertIn("Dados simulados — demonstração acadêmica", route["simulation_notice"])
        self.assertTrue(route["line"]["code"].startswith("DEMO-"))
        self.assertTrue(route["route_id"].startswith("demo-upa-sul-demo-"))
        self.assertEqual(route["geometry_kind"], "schematic")

    def test_times_are_consistent(self):
        route = simulate()
        parse = datetime.fromisoformat
        dep, bus_dep, bus_arr, arr = (parse(route[k]) for k in ("departure_at", "bus_departure_at", "bus_arrival_at", "arrival_at"))
        self.assertLess(dep, bus_dep)
        self.assertLess(bus_dep, bus_arr)
        self.assertLess(bus_arr, arr)
        parts = (route["walk_to_stop_seconds"], route["wait_seconds"], route["in_vehicle_seconds"], route["walk_from_stop_seconds"])
        self.assertAlmostEqual(sum(parts), route["duration_seconds"], delta=2)
        self.assertAlmostEqual((arr - dep).total_seconds(), route["duration_seconds"], delta=1)
        self.assertGreaterEqual(route["wait_seconds"], 0)
        self.assertLess(route["wait_seconds"], route["line"]["headway_minutes"] * 60)

    def test_bus_leaves_on_the_fictional_timetable(self):
        route = simulate()
        line = next(l for l in LINES if l.code == route["line"]["code"])
        minute = datetime.fromisoformat(route["bus_departure_at"]).minute
        self.assertEqual((minute - line.offset_minute) % line.headway_minutes, 0)

    def test_geometry_and_stops_are_plausible(self):
        route = simulate()
        coords = route["geometry"]["coordinates"]
        self.assertEqual(route["geometry"]["type"], "LineString")
        self.assertEqual(len(coords), 4)
        self.assertEqual(coords[0], [ORIGIN[1], ORIGIN[0]])  # GeoJSON: [lon, lat]
        self.assertEqual(coords[-1], [SUL[1], SUL[0]])
        for lon, lat in coords:
            self.assertLessEqual(haversine_m(lat, lon, *COVERAGE_CENTER), COVERAGE_RADIUS_M)
        walk = haversine_m(ORIGIN[0], ORIGIN[1], route["boarding_stop"]["latitude"], route["boarding_stop"]["longitude"])
        self.assertTrue(150 <= walk <= 400)

    def test_distance_covers_walks_and_ride(self):
        route = simulate()
        straight = haversine_m(*ORIGIN, *SUL)
        self.assertGreater(route["distance_meters"], straight)
        self.assertLess(route["distance_meters"], straight * 1.5)

    def test_is_deterministic(self):
        self.assertEqual(simulate(), simulate())
        self.assertEqual(simulate()["line"], simulate()["line"])

    def test_refuses_real_units_far_places_and_short_trips(self):
        with self.assertRaisesMessage(NoSimulatedRoute, "demonstrativas"):
            simulate(unit_is_demo=False)
        with self.assertRaisesMessage(NoSimulatedRoute, "região de Goiânia"):
            simulate(origin_lat=-23.55, origin_lon=-46.63)  # São Paulo
        with self.assertRaisesMessage(NoSimulatedRoute, "muito próxima"):
            simulate(origin_lat=SUL[0] + 0.001, origin_lon=SUL[1])


class BusRouteAPITests(TestCase):
    def setUp(self):
        cache.clear()
        self.url = reverse("v1:route")
        make_unit("upa-sul", latitude=SUL[0], longitude=SUL[1], is_demo=True)
        make_unit("hospital-real", latitude=SUL[0], longitude=SUL[1], is_demo=False)

    def query(self, **params):
        base = {"origin_lat": ORIGIN[0], "origin_lon": ORIGIN[1], "unit_id": "upa-sul", "mode": "bus"}
        base.update(params)
        return self.client.get(self.url, base)

    def test_demo_mode_off_keeps_the_existing_contract(self):
        for mode in ("bus", "transit", "public_transport"):
            response = self.query(mode=mode)
            self.assertEqual(response.status_code, 400)
            self.assertIn("transporte público", response.json()["mode"][0].lower())

    @override_settings(DEMO_MODE=True, DEBUG=False)
    def test_blocked_when_debug_is_off(self):
        self.assertEqual(self.query().status_code, 400)

    @demo_mode_on
    def test_bus_route_in_demo_mode(self):
        with mock.patch("apps.routing.views.fetch_route") as osrm:
            response = self.query()

        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertTrue(body["is_simulated"])
        self.assertEqual(body["unit_id"], "upa-sul")
        osrm.assert_not_called()  # nenhuma API externa

    @demo_mode_on
    def test_transit_alias_maps_to_bus(self):
        self.assertEqual(self.query(mode="transit").json()["mode"], "bus")

    @demo_mode_on
    def test_unsupported_modes_stay_unsupported(self):
        self.assertEqual(self.query(mode="walking").status_code, 400)
        self.assertEqual(self.query(mode="flying").status_code, 400)

    @demo_mode_on
    def test_no_bus_route_cases_return_404_with_message(self):
        real = self.query(unit_id="hospital-real")
        self.assertEqual(real.status_code, 404)
        self.assertIn("demonstrativas", real.json()["detail"])
        self.assertEqual(self.query(origin_lat=-23.55, origin_lon=-46.63).status_code, 404)
        self.assertEqual(self.query(unit_id="nao-existe").status_code, 404)

    @demo_mode_on
    def test_driving_is_untouched_in_demo_mode(self):
        payload = {"provider": "osrm", "mode": "driving", "unit_id": "upa-sul", "distance_meters": 1.0,
                   "duration_seconds": 1.0, "geometry": {"type": "LineString", "coordinates": [[-49.2, -16.7]]}}
        with mock.patch("apps.routing.views.fetch_route", return_value=payload) as osrm:
            response = self.query(mode="driving")

        self.assertEqual(response.json(), payload)
        self.assertEqual(osrm.call_args.kwargs["mode"], "driving")
        # Sem `mode`, o padrão continua sendo carro.
        with mock.patch("apps.routing.views.fetch_route", return_value=payload) as osrm:
            self.client.get(self.url, {"origin_lat": ORIGIN[0], "origin_lon": ORIGIN[1], "unit_id": "upa-sul"})
        self.assertEqual(osrm.call_args.kwargs["mode"], "driving")

    @demo_mode_on
    def test_throttle_still_applies(self):
        with override_settings(ROUTING_RATE_LIMIT="2/min"):
            cache.clear()
            codes = [self.query().status_code for _ in range(3)]
        self.assertEqual(codes, [200, 200, 429])
