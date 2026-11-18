import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:rotasaude/app.dart';
import 'package:rotasaude/models/driving_route.dart';
import 'package:rotasaude/models/health_unit.dart';
import 'package:rotasaude/models/user_location_origin.dart';
import 'package:rotasaude/repositories/health_unit_parser.dart';
import 'package:rotasaude/repositories/health_unit_repository.dart';
import 'package:rotasaude/repositories/route_repository.dart';
import 'package:rotasaude/screens/manual_location_picker_screen.dart';
import 'package:rotasaude/screens/map_screen.dart';
import 'package:rotasaude/screens/route_preview_screen.dart';
import 'package:rotasaude/screens/unit_details_screen.dart';
import 'package:rotasaude/services/location_onboarding_store.dart';
import 'package:rotasaude/services/user_location_session_store.dart';

import 'first_screen_test.dart' show FakeLocationAccess;
import 'support/health_unit_fixtures.dart';

void main() {
  const manualPoint = LatLng(-16.70, -49.25);

  Future<void> tap(WidgetTester tester, Finder target) async {
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'permissão negada permite filtrar Pediatria e abrir rota de unidade desatualizada',
    (tester) async {
      final location = FakeLocationAccess();
      final session = MemoryUserLocationSessionStore();
      final store = MemoryLocationOnboardingStore();
      final unit = parseHealthUnit(
        unitJson(
          id: 'upa-antiga',
          name: 'Unidade Pediátrica',
          services: ['Pediatria'],
          operationalStatus: statusJson(age: const Duration(hours: 2)),
        ),
      );
      final repository = FakeHealthUnitRepository(
        unitsByCity: {
          'Goiânia': [unit],
        },
      );
      await tester.pumpWidget(
        RotaSaudeApp(
          locationAccess: location,
          onboardingStore: store,
          sessionStore: session,
          unitRepository: repository,
        ),
      );
      await tester.pumpAndSettle();
      await tap(tester, find.text('Usar minha localização'));
      expect(find.text('Permitir localização'), findsOneWidget);

      await tap(tester, find.text('Escolher cidade'));
      await tester.enterText(find.byType(TextField), 'municipio inexistente');
      await tester.pumpAndSettle();
      expect(find.textContaining('Nenhuma cidade encontrada'), findsOneWidget);
      await tap(tester, find.text('Goiânia, GO'));
      await tap(tester, find.text('Ver unidades em Goiânia'));
      expect(find.text('Unidades de saúde'), findsOneWidget);
      expect(location.requestCount, 1);
      expect(location.positionCount, 0);
      expect(await session.load(), isNull);
      expect(await store.loadArea(), same(SearchArea.goiania));

      await tap(tester, find.byTooltip('Filtrar por serviço'));
      await tap(tester, find.text('Pediatria').last);
      await tap(tester, find.byTooltip('Ver detalhes de Unidade Pediátrica'));
      expect(find.text('Espera sem atualização'), findsOneWidget);
      expect(find.textContaining('Última leitura'), findsOneWidget);
      await tap(tester, find.text('Ver rota'));
      expect(find.text(unit.name), findsOneWidget);
      expect(find.text(unit.address), findsOneWidget);
      expect(find.text('Definir ponto de partida'), findsOneWidget);
      expect(location.requestCount, 1);
    },
  );

  testWidgets(
    'proximidade pede origem; GPS desligado permite definir ponto pelo mapa',
    (tester) async {
      final location = FakeLocationAccess()..serviceEnabled = false;
      final repository = FakeHealthUnitRepository(
        unitsByCity: {'Goiânia': goianiaUnits()},
      );
      await tester.pumpWidget(
        MaterialApp(
          home: MapScreen(
            userOrigin: null,
            initialArea: SearchArea.goiania,
            startInList: true,
            repository: repository,
            locationAccess: location,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tap(tester, find.byTooltip('Ordenar unidades'));
      await tap(tester, find.text('Proximidade'));
      await tap(tester, find.text('Usar minha localização'));
      expect(find.text('Ativar localização'), findsOneWidget);
      await tap(tester, find.text('Escolher ponto no mapa'));
      expect(find.text('Mova o mapa até o ponto de partida'), findsOneWidget);
      await tester.drag(find.byType(FlutterMap), const Offset(100, 35));
      await tester.pumpAndSettle();
      await tap(tester, find.text('Confirmar este ponto'));

      expect(find.text('Proximidade'), findsOneWidget);
      expect(find.textContaining('Saindo de Goiânia'), findsOneWidget);
      expect(location.requestCount, 0);
      expect(repository.requestedCities, ['Goiânia']);
    },
  );

  testWidgets(
    'o ponto manual confirmado corresponde ao pino central após mover o mapa',
    (tester) async {
      LatLng? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async =>
                    selected = await Navigator.of(context).push<LatLng>(
                      MaterialPageRoute(
                        builder: (_) => const ManualLocationPickerScreen(
                          initialCenter: manualPoint,
                        ),
                      ),
                    ),
                child: const Text('Escolher origem'),
              ),
            ),
          ),
        ),
      );
      await tap(tester, find.text('Escolher origem'));
      final attribution = tester.element(
        find.text('© OpenStreetMap contributors'),
      );
      expect(attribution.mounted, isTrue);
      final tile = tester.element(find.byType(TileLayer));
      await tester.drag(find.byType(FlutterMap), const Offset(180, 50));
      await tester.pumpAndSettle();
      final center = MapCamera.of(tile).center;
      expect(center, isNot(manualPoint));
      expect(selected, isNull);
      await tap(tester, find.text('Confirmar este ponto'));
      expect(selected, center);
    },
  );

  testWidgets(
    'serviços longos permanecem acessíveis com fonte ampliada e ações fixas',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      const lastService =
          'Acompanhamento pediátrico de doenças respiratórias crônicas';
      final unit = parseHealthUnit(
        unitJson(
          id: 'long',
          name: 'Centro Municipal de Atenção Especializada em Saúde Pediátrica',
          address: 'Rua das Palmeiras, 1825, esquina com Avenida das Nações, Setor Universitário, Goiânia',
          services: ['Atendimento em pediatria geral', lastService],
        ),
      );
      var routeTaps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: UnitDetailsScreen(
            unit: unit,
            straightLineKm: null,
            onRoute: () => routeTaps++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text(lastService),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text(lastService).hitTestable(), findsOneWidget);
      await tester.tap(find.text('Ver rota'));
      expect(routeTaps, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'rota sem origem mantém destino; falha permite tentar e abrir o mapa externo',
    (tester) async {
      final repository = _TrackingRouteRepository();
      final unit = goianiaUnits().first;
      var launchCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: RoutePreviewScreen(
            unit: unit,
            initialOrigin: null,
            routeRepository: repository,
            onChooseOrigin: () async => UserLocationOrigin.manual(manualPoint),
            openMaps: (destination) async {
              expect(destination.id, unit.id);
              launchCount++;
              return false;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(unit.name), findsOneWidget);
      expect(repository.lastOrigin, isNull);
      await tester.tap(find.text('Definir ponto de partida'));
      await tester.pump();
      expect(find.text(unit.address), findsOneWidget);
      expect(find.text('Calculando rota de carro…'), findsOneWidget);
      repository.response.completeError(
        const HealthApiException(HealthApiFailureKind.server, 'HTTP 503'),
      );
      await tester.pumpAndSettle();

      expect(find.text(unit.name), findsOneWidget);
      expect(find.text(unit.address), findsOneWidget);
      expect(find.textContaining('Roteamento indisponível'), findsOneWidget);
      expect(find.text('Alterar ponto de partida'), findsOneWidget);
      await tap(tester, find.text('Abrir no app de mapas'));
      expect(launchCount, 1);
      expect(
        find.textContaining('Não foi possível abrir um app de mapas'),
        findsOneWidget,
      );

      repository.response = Completer();
      await tester.tap(find.text('Tentar novamente'));
      await tester.pump();
      repository.response.complete(
        DrivingRoute(
          provider: 'osrm',
          mode: 'driving',
          unitId: unit.id,
          distanceMeters: 2900,
          durationSeconds: 240,
          polyline: [manualPoint, unit.position],
        ),
      );
      await tester.pumpAndSettle();
      expect(repository.lastOrigin, manualPoint);
      expect(find.text('4 min de carro · 2,9 km de trajeto'), findsOneWidget);
      expect(find.text('Abrir no app de mapas'), findsOneWidget);
    },
  );
}

class _TrackingRouteRepository implements RouteRepository {
  LatLng? lastOrigin;
  Completer<DrivingRoute> response = Completer();

  @override
  Future<DrivingRoute> fetchDrivingRoute({
    required LatLng origin,
    required String unitId,
  }) {
    lastOrigin = origin;
    return response.future;
  }

  @override
  void close() {}
}
