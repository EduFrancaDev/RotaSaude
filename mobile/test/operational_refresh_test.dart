import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:rotasaude/models/health_unit.dart';
import 'package:rotasaude/repositories/health_unit_parser.dart';
import 'package:rotasaude/models/user_location_origin.dart';
import 'package:rotasaude/screens/map_screen.dart';

import 'support/health_unit_fixtures.dart';

void main() {
  Position goianiaPosition() => Position(
    longitude: SearchArea.goiania.center.longitude,
    latitude: SearchArea.goiania.center.latitude,
    timestamp: DateTime(2026),
    accuracy: 10,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );

  testWidgets('reavalia leitura operacional após ultrapassar 30 minutos', (
    tester,
  ) async {
    var now = DateTime.utc(2026, 6, 1, 12, 0);
    final updatedAt = now.subtract(const Duration(minutes: 29));
    final unit = parseHealthUnit(
      unitJson(
        id: 'upa-tick',
        name: 'UPA Tick',
        operationalStatus: {
          ...statusJson(isDemo: true),
          'source_updated_at': updatedAt.toUtc().toIso8601String(),
          'received_at': updatedAt.toUtc().toIso8601String(),
        },
      ),
    );

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;

    await tester.pumpWidget(
      MaterialApp(
        home: MapScreen(
          userOrigin: UserLocationOrigin.fromGps(goianiaPosition()),
          now: () => now,
          operationalRefreshInterval: const Duration(milliseconds: 50),
          repository: FakeHealthUnitRepository(
            unitsByCity: {
              'Goiânia': [unit],
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('Lista'));
    await tester.pumpAndSettle();

    expect(find.text('20 min'), findsOneWidget);

    now = now.add(const Duration(minutes: 2));
    await tester.pump(const Duration(milliseconds: 60));

    expect(find.text('20 min'), findsNothing);
    expect(find.text('Espera sem atualização'), findsOneWidget);
  });
}
