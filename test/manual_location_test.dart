import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:rotasaude/app.dart';
import 'package:rotasaude/models/driving_route.dart';
import 'package:rotasaude/models/user_location_origin.dart';
import 'package:rotasaude/repositories/route_repository.dart';
import 'package:rotasaude/screens/home_screen.dart';
import 'package:rotasaude/screens/manual_location_picker_screen.dart';
import 'package:rotasaude/screens/map_screen.dart';
import 'package:rotasaude/services/location_onboarding_store.dart';
import 'package:rotasaude/services/user_location_session_store.dart';

import 'first_screen_test.dart';
import 'support/health_unit_fixtures.dart';

void main() {
  final manualPoint = LatLng(-16.70, -49.25);

  testWidgets('entrada manual não solicita permissão de GPS', (tester) async {
    final location = FakeLocationAccess();
    final store = MemoryUserLocationSessionStore();
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          locationAccess: location,
          sessionStore: store,
          mapBuilder: (context, origin) => Scaffold(
            body: Center(child: Text(origin.isManual ? 'Mapa manual' : 'GPS')),
          ),
        ),
      ),
    );

    expect(find.text('Escolher localização manualmente'), findsOneWidget);
    await tester.tap(find.text('Escolher localização manualmente'));
    await tester.pumpAndSettle();

    expect(location.requestCount, 0);
    expect(find.text('Confirmar este ponto'), findsOneWidget);

    await tester.longPressAt(tester.getCenter(find.byType(FlutterMap)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar este ponto'));
    await tester.pumpAndSettle();

    expect(find.text('Mapa manual'), findsOneWidget);
    final saved = await store.load();
    expect(saved?.isManual, isTrue);
    expect(location.requestCount, 0);
  });

  testWidgets('negação de GPS oferece escolha manual na Home', (tester) async {
    final location = FakeLocationAccess();
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          locationAccess: location,
          mapBuilder: (context, origin) => const Scaffold(body: Text('Mapa')),
        ),
      ),
    );

    await tester.tap(find.text('Usar minha localização'));
    await tester.pumpAndSettle();
    expect(find.text('Escolher localização manualmente'), findsOneWidget);
  });

  testWidgets('sessão manual não bloqueia ao retomar sem GPS', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;

    final location = FakeLocationAccess()
      ..permission = LocationPermission.denied;
    final onboarding = MemoryLocationOnboardingStore(accepted: true);
    final session = MemoryUserLocationSessionStore(
      origin: UserLocationOrigin.manual(manualPoint),
    );

    await tester.pumpWidget(
      RotaSaudeApp(
        locationAccess: location,
        onboardingStore: onboarding,
        sessionStore: session,
        unitRepository: FakeHealthUnitRepository(
          unitsByCity: {'Goiânia': goianiaUnits()},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Lista'), findsOneWidget);
    expect(find.text('Permita o acesso à localização'), findsNothing);
    expect(find.textContaining('Origem manual no mapa'), findsNothing);
    expect(find.text('Usar GPS do aparelho'), findsOneWidget);
    expect(location.checkCount, 0);
  });

  testWidgets('troca de manual para GPS atualiza aviso', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;

    final location = FakeLocationAccess()
      ..permission = LocationPermission.whileInUse;
    final session = MemoryUserLocationSessionStore(
      origin: UserLocationOrigin.manual(manualPoint),
    );

    await tester.pumpWidget(
      RotaSaudeApp(
        locationAccess: location,
        onboardingStore: MemoryLocationOnboardingStore(accepted: true),
        sessionStore: session,
        unitRepository: FakeHealthUnitRepository(
          unitsByCity: {'Goiânia': goianiaUnits()},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Usar GPS do aparelho'), findsOneWidget);
    await tester.tap(find.text('Usar GPS do aparelho'));
    await tester.pumpAndSettle();

    expect(find.text('Escolher ponto no mapa'), findsOneWidget);
    final saved = await session.load();
    expect(saved?.isDeviceGps, isTrue);
    expect(location.positionCount, greaterThanOrEqualTo(1));
  });

  testWidgets('rota de carro usa origem manual na consulta', (tester) async {
    final routeRepo = _TrackingRouteRepository();
    addTearDown(tester.view.resetPhysicalSize);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;

    await tester.pumpWidget(
      MaterialApp(
        home: MapScreen(
          userOrigin: UserLocationOrigin.manual(manualPoint),
          repository: FakeHealthUnitRepository(
            unitsByCity: {'Goiânia': goianiaUnits()},
          ),
          routeRepository: routeRepo,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Lista'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('UPA Exemplo Centro'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    final detailsAction = find.byTooltip('Ver detalhes de UPA Exemplo Centro');
    await tester.tap(detailsAction);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver opções de rota'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(routeRepo.lastOrigin, manualPoint);
  });

  testWidgets(
    'GPS desligado na Home abre picker e mapa principal após confirmar',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;

      final location = FakeLocationAccess()
        ..serviceEnabled = false
        ..positionError = const LocationServiceDisabledException();
      final session = MemoryUserLocationSessionStore();

      await tester.pumpWidget(
        RotaSaudeApp(
          locationAccess: location,
          onboardingStore: MemoryLocationOnboardingStore(),
          sessionStore: session,
          unitRepository: FakeHealthUnitRepository(
            unitsByCity: {'Goiânia': goianiaUnits()},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Escolher localização manualmente'), findsOneWidget);
      await tester.tap(find.text('Escolher localização manualmente'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Escolher no mapa'), findsOneWidget);
      expect(location.requestCount, 0);

      await tester.longPressAt(tester.getCenter(find.byType(FlutterMap)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Confirmar este ponto'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Lista'), findsOneWidget);
      expect(find.text('Ative a localização'), findsNothing);
      expect(find.textContaining('Origem manual no mapa'), findsNothing);
      expect(find.text('Usar GPS do aparelho'), findsOneWidget);
      final saved = await session.load();
      expect(saved?.isManual, isTrue);
      expect(saved?.coordinate.latitude, isNot(0));
      expect(location.positionCount, 0);
      expect(location.requestCount, 0);
    },
  );

  /// Como no aparelho: com o serviço desligado, `getCurrentPosition` lança.
  FakeLocationAccess gpsOffLocation() => FakeLocationAccess()
    ..permission = LocationPermission.whileInUse
    ..serviceEnabled = false
    ..positionError = const LocationServiceDisabledException();

  Future<void> pumpReturningAppWithGpsOff(
    WidgetTester tester,
    FakeLocationAccess location,
    MemoryUserLocationSessionStore session,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      RotaSaudeApp(
        locationAccess: location,
        onboardingStore: MemoryLocationOnboardingStore(accepted: true),
        sessionStore: session,
        unitRepository: FakeHealthUnitRepository(
          unitsByCity: {'Goiânia': goianiaUnits()},
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets(
    'bloqueio com GPS desligado: confirmar ponto manual abre o mapa principal',
    (tester) async {
      final location = gpsOffLocation();
      final session = MemoryUserLocationSessionStore();
      await pumpReturningAppWithGpsOff(tester, location, session);

      expect(find.text('Ative a localização'), findsOneWidget);
      // O último é o do overlay de bloqueio, por cima da tela de falha.
      await tester.tap(find.text('Escolher localização manualmente').last);
      await tester.pumpAndSettle();
      expect(find.text('Escolher no mapa'), findsOneWidget);

      final gpsAttemptsBeforeConfirm = location.positionCount;
      await tester.longPressAt(tester.getCenter(find.byType(FlutterMap)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Confirmar este ponto'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Ative a localização'), findsNothing);
      expect(
        find.text('Não conseguimos obter sua localização agora.'),
        findsNothing,
      );
      expect(find.text('Lista'), findsOneWidget);
      expect(find.textContaining('Origem manual no mapa'), findsNothing);
      expect(find.text('Usar GPS do aparelho'), findsOneWidget);
      final saved = await session.load();
      expect(saved?.isManual, isTrue);
      expect(location.requestCount, 0);
      expect(location.positionCount, gpsAttemptsBeforeConfirm);
    },
  );

  testWidgets('bloqueio com GPS desligado: cancelar mantém o bloqueio', (
    tester,
  ) async {
    final location = gpsOffLocation();
    final session = MemoryUserLocationSessionStore();
    await pumpReturningAppWithGpsOff(tester, location, session);

    await tester.tap(find.text('Escolher localização manualmente').last);
    await tester.pumpAndSettle();
    expect(find.text('Escolher no mapa'), findsOneWidget);

    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();

    expect(find.text('Escolher no mapa'), findsNothing);
    expect(find.text('Ative a localização'), findsOneWidget);
    expect(await session.load(), isNull);
  });

  testWidgets('picker exige confirmação explícita', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ManualLocationPickerScreen()),
    );
    await tester.pumpAndSettle();

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);

    await tester.longPressAt(tester.getCenter(find.byType(FlutterMap)));
    await tester.pumpAndSettle();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });
}

class _TrackingRouteRepository implements RouteRepository {
  LatLng? lastOrigin;

  @override
  Future<DrivingRoute> fetchDrivingRoute({
    required LatLng origin,
    required String unitId,
  }) async {
    lastOrigin = origin;
    return DrivingRoute(
      provider: 'osrm',
      mode: 'driving',
      unitId: unitId,
      distanceMeters: 5000,
      durationSeconds: 720,
      polyline: [origin, const LatLng(-16.68, -49.25)],
    );
  }

  @override
  void close() {}
}
