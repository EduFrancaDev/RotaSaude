import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:rotasaude/models/driving_route.dart';
import 'package:rotasaude/models/health_unit.dart';
import 'package:rotasaude/models/transit_route.dart';
import 'package:rotasaude/models/user_location_origin.dart';
import 'package:rotasaude/repositories/health_unit_repository.dart';
import 'package:rotasaude/repositories/route_repository.dart';
import 'package:rotasaude/screens/map_screen.dart';
import 'package:rotasaude/screens/route_preview_screen.dart';
import 'package:rotasaude/widgets/unit_ui.dart';

import 'support/health_unit_fixtures.dart';
import 'support/route_fixtures.dart';

const _simulated = 'Dados simulados — demonstração acadêmica';

class _Routes implements RouteRepository {
  HealthApiException? busFailure;
  bool busNever = false;
  final busRequests = <String>[];
  var carRequests = 0;

  @override
  Future<DrivingRoute> fetchDrivingRoute({
    required LatLng origin,
    required String unitId,
  }) async {
    carRequests++;
    return DrivingRoute(
      provider: 'osrm',
      mode: 'driving',
      unitId: unitId,
      distanceMeters: 2900,
      durationSeconds: 240,
      polyline: [origin, const LatLng(-16.6862, -49.264)],
    );
  }

  @override
  Future<TransitRoute> fetchBusRoute({
    required LatLng origin,
    required String unitId,
  }) async {
    busRequests.add(unitId);
    if (busNever) await Completer<void>().future;
    if (busFailure case final error?) throw error;
    return busRoute(unitId: unitId);
  }

  @override
  void close() {}
}

void main() {
  const origin = LatLng(-16.6869, -49.2648);

  Future<void> openPreview(
    WidgetTester tester,
    _Routes routes, {
    HealthUnit? unit,
    UserLocationOrigin? initialOrigin,
    bool withOrigin = true,
  }) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      MaterialApp(
        home: RoutePreviewScreen(
          unit: unit ?? goianiaUnits().first,
          initialOrigin: withOrigin ? UserLocationOrigin.manual(origin) : null,
          routeRepository: routes,
          onChooseOrigin: () async => UserLocationOrigin.manual(origin),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('prévia de rota: carro e ônibus', () {
    testWidgets('carro é o padrão e o ônibus só é consultado ao escolher', (
      tester,
    ) async {
      final routes = _Routes();
      await openPreview(tester, routes);

      expect(find.text('4 min de carro · 2,9 km de trajeto'), findsOneWidget);
      expect(routes.busRequests, isEmpty);

      await tester.tap(find.text('Ônibus'));
      await tester.pumpAndSettle();

      expect(routes.busRequests, ['upa-centro']);
      expect(find.text('Rota de ônibus'), findsOneWidget);
      expect(find.text('4 min de carro · 2,9 km de trajeto'), findsNothing);
    });

    testWidgets('ônibus mostra aviso de simulação, horários e etapas', (
      tester,
    ) async {
      final routes = _Routes();
      await openPreview(tester, routes);
      await tester.tap(find.text('Ônibus'));
      await tester.pumpAndSettle();

      final route = busRoute();
      String clock(DateTime value) => formatClockTime(value);

      expect(find.text(_simulated), findsNothing);
      expect(
        find.text('26 min de ônibus · 3,5 km de trajeto'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Saída às ${clock(route.departureAt)} · chegada às ${clock(route.arrivalAt)}',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Caminhe 412 m (6 min) até Ponto de embarque',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Espere 6 min · Linha A1 sai às ${clock(route.busDepartureAt)}',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          '9 min de ônibus até Ponto de desembarque, chegada às ${clock(route.busArrivalAt)}',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'até a unidade, chegada às ${clock(route.arrivalAt)}',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('não são oficiais'), findsNothing);
      // Rota simulada não é apresentada como "calculada por" um provedor real.
      expect(find.textContaining('Rota calculada por'), findsNothing);
    });

    testWidgets('alternar de volta ao carro não refaz as consultas', (
      tester,
    ) async {
      final routes = _Routes();
      await openPreview(tester, routes);
      await tester.tap(find.text('Ônibus'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Carro'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ônibus'));
      await tester.pumpAndSettle();

      expect(routes.carRequests, 1);
      expect(routes.busRequests, hasLength(1));
      expect(find.text('Rota de ônibus'), findsOneWidget);
    });

    testWidgets('mostra carregamento do ônibus', (tester) async {
      final routes = _Routes()..busNever = true;
      await openPreview(tester, routes);
      await tester.tap(find.text('Ônibus'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Calculando rota de ônibus…'), findsOneWidget);
      expect(find.text(_simulated), findsNothing);
    });

    testWidgets('servidor sem demonstração (400): transporte indisponível', (
      tester,
    ) async {
      final routes = _Routes()
        ..busFailure = const HealthApiException(
          HealthApiFailureKind.client,
          'HTTP 400',
          statusCode: 400,
        );
      await openPreview(tester, routes);
      await tester.tap(find.text('Ônibus'));
      await tester.pumpAndSettle();

      expect(
        find.text('Transporte público indisponível neste servidor.'),
        findsOneWidget,
      );
      expect(find.text('Tentar novamente'), findsOneWidget);
      // O carro segue funcionando.
      await tester.tap(find.text('Carro'));
      await tester.pumpAndSettle();
      expect(find.text('4 min de carro · 2,9 km de trajeto'), findsOneWidget);
    });

    testWidgets('rota ausente (404) informa e permite tentar de novo', (
      tester,
    ) async {
      final routes = _Routes()
        ..busFailure = const HealthApiException(
          HealthApiFailureKind.client,
          'HTTP 404',
          statusCode: 404,
        );
      await openPreview(tester, routes);
      await tester.tap(find.text('Ônibus'));
      await tester.pumpAndSettle();

      expect(
        find.text('Não há rota de ônibus para este trajeto.'),
        findsOneWidget,
      );

      routes.busFailure = null;
      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();
      expect(find.textContaining('min de ônibus ·'), findsOneWidget);
      expect(routes.busRequests, hasLength(2));
    });

    testWidgets('sem origem, o ônibus pede o ponto de partida', (tester) async {
      final routes = _Routes();
      await openPreview(tester, routes, withOrigin: false);
      await tester.tap(find.text('Ônibus'));
      await tester.pumpAndSettle();

      expect(
        find.text('Defina de onde você vai sair para calcular o trajeto.'),
        findsOneWidget,
      );
      expect(routes.busRequests, isEmpty);

      await tester.tap(find.text('Definir ponto de partida'));
      await tester.pumpAndSettle();
      expect(routes.busRequests, ['upa-centro']);
      expect(find.textContaining('min de ônibus ·'), findsOneWidget);
    });

    testWidgets('textos longos não estouram com fonte grande', (tester) async {
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      final routes = _Routes();
      await openPreview(tester, routes);
      await tester.tap(find.text('Ônibus'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('comparação: ônibus simulado', () {
    Future<_Routes> openComparison(WidgetTester tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.physicalSize = const Size(390, 1200);
      tester.view.devicePixelRatio = 1;
      final routes = _Routes();
      await tester.pumpWidget(
        MaterialApp(
          home: MapScreen(
            userOrigin: UserLocationOrigin.manual(origin),
            repository: FakeHealthUnitRepository(
              unitsByCity: {'Goiânia': goianiaUnits()},
            ),
            routeRepository: routes,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text('Lista'));
      await tester.pumpAndSettle();
      for (final id in ['upa-centro', 'upa-sul']) {
        final card = find.byKey(ValueKey('unit-card-$id'));
        await tester.scrollUntilVisible(
          card,
          180,
          scrollable: find.byType(Scrollable).first,
        );
        final toggle = find.descendant(
          of: card,
          matching: find.byType(CheckboxListTile),
        );
        await tester.ensureVisible(toggle);
        await tester.pumpAndSettle();
        await tester.tap(toggle);
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Comparar (2/2)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ônibus'));
      await tester.pumpAndSettle();
      return routes;
    }

    testWidgets('calcula o tempo de ônibus sob demanda', (tester) async {
      final routes = await openComparison(tester);
      expect(routes.busRequests, isEmpty);
      expect(find.text(_simulated), findsNothing);

      await tester.tap(find.text('Calcular tempos de ônibus'));
      await tester.pumpAndSettle();

      expect(routes.busRequests, unorderedEquals(['upa-centro', 'upa-sul']));
      expect(find.text('26 min'), findsNWidgets(2));
      expect(find.text('Calcular tempos de ônibus'), findsNothing);
      expect(routes.carRequests, 0);
    });

    testWidgets('falha do ônibus não afeta o carro e permite repetir', (
      tester,
    ) async {
      final routes = await openComparison(tester);
      routes.busFailure = const HealthApiException(
        HealthApiFailureKind.client,
        'HTTP 400',
        statusCode: 400,
      );

      await tester.tap(find.text('Calcular tempos de ônibus'));
      await tester.pumpAndSettle();

      expect(
        find.text('Tempo de ônibus indisponível para estas unidades.'),
        findsOneWidget,
      );
      expect(find.text('Tentar calcular novamente'), findsOneWidget);

      await tester.tap(find.text('Carro'));
      await tester.pumpAndSettle();
      expect(
        find.text('Tempo de ônibus indisponível para estas unidades.'),
        findsNothing,
      );
      expect(find.text('Calcular tempos de carro'), findsOneWidget);
    });
  });
}
