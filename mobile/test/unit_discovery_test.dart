import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:rotasaude/app.dart';
import 'package:rotasaude/models/health_unit.dart';
import 'package:rotasaude/repositories/health_unit_parser.dart';
import 'package:latlong2/latlong.dart';
import 'package:rotasaude/models/driving_route.dart';
import 'package:rotasaude/repositories/health_unit_repository.dart';
import 'package:rotasaude/repositories/route_repository.dart';
import 'package:rotasaude/models/user_location_origin.dart';
import 'package:rotasaude/screens/map_screen.dart';
import 'package:rotasaude/services/location_access.dart';
import 'package:rotasaude/services/location_onboarding_store.dart';
import 'package:rotasaude/services/user_location_session_store.dart';
import 'package:rotasaude/services/straight_line_distance.dart';

import 'support/health_unit_fixtures.dart';

void main() {
  FakeHealthUnitRepository goianiaRepository() =>
      FakeHealthUnitRepository(unitsByCity: {'Goiânia': goianiaUnits()});

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

  FakeRouteRepository fakeRouteRepository() => FakeRouteRepository();

  Future<void> openDiscovery(
    WidgetTester tester, {
    HealthUnitRepository? repository,
    RouteRepository? routeRepository,
    double textScale = 1,
    Size size = const Size(390, 844),
  }) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = size;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      MaterialApp(
        home: MapScreen(
          userOrigin: UserLocationOrigin.fromGps(goianiaPosition()),
          repository: repository ?? goianiaRepository(),
          routeRepository: routeRepository ?? fakeRouteRepository(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  Future<void> openList(WidgetTester tester) async {
    await tester.tap(find.text('Lista'));
    await tester.pumpAndSettle();
  }

  Future<void> toggleUnit(WidgetTester tester, String id) async {
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

  testWidgets('trocar de aba conserva o mapa e trocar de cidade o reenquadra', (
    tester,
  ) async {
    await openDiscovery(tester);

    MapController mapController() =>
        MapController.of(tester.element(find.byType(MarkerLayer)));

    const center = LatLng(-16.70, -49.28);
    mapController().moveAndRotate(center, 14, 30);
    await tester.pump();

    await openList(tester);
    await tester.tap(find.text('Comparar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mapa'));
    await tester.pumpAndSettle();

    expect(mapController().camera.center, center);
    expect(mapController().camera.zoom, 14);
    expect(mapController().camera.rotation, 30);

    await tester.tap(find.text('Buscando em Goiânia'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aparecida de Goiânia, GO'));
    await tester.pump();
    await tester.tap(find.text('Ver unidades em Aparecida de Goiânia'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mapa'));
    await tester.pumpAndSettle();
    expect(mapController().camera.center, SearchArea.aparecida.center);
    expect(mapController().camera.zoom, 13);
    expect(mapController().camera.rotation, 0);
  });

  testWidgets('Lista e Comparar conservam posições de rolagem distintas', (
    tester,
  ) async {
    await openDiscovery(
      tester,
      repository: FakeHealthUnitRepository(
        unitsByCity: {
          'Goiânia': [
            for (var index = 1; index <= 12; index++)
              parseHealthUnit(
                unitJson(
                  id: 'upa-$index',
                  name: 'Unidade ${index.toString().padLeft(2, '0')}',
                ),
              ),
          ],
        },
      ),
    );
    double position() => tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .pixels;
    await openList(tester);
    await toggleUnit(tester, 'upa-1');
    await toggleUnit(tester, 'upa-2');
    await tester.drag(find.byType(ListView), const Offset(0, -480));
    await tester.pumpAndSettle();
    final listPosition = position();
    expect(listPosition, greaterThan(0));

    await tester.tap(find.text('Comparar (2/2)'));
    await tester.pumpAndSettle();
    expect(position(), 0);
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    final comparePosition = position();
    expect(comparePosition, greaterThan(0));

    await openList(tester);
    expect(position(), listPosition);
    await tester.tap(find.text('Comparar (2/2)'));
    await tester.pumpAndSettle();
    expect(position(), comparePosition);
  });

  testWidgets('trocar de aba recolhe teclado e mantém a busca ativa', (
    tester,
  ) async {
    await openDiscovery(tester);
    await openList(tester);
    await tester.enterText(find.byType(TextField), 'Oeste');
    expect(tester.testTextInput.isVisible, isTrue);

    await tester.tap(find.text('Comparar'));
    await tester.pumpAndSettle();

    expect(tester.testTextInput.isVisible, isFalse);
    expect(find.text('Oeste'), findsOneWidget);
    expect(find.text('Selecionar unidades'), findsOneWidget);
    await tester.tap(find.text('Selecionar unidades'));
    await tester.pumpAndSettle();
    expect(find.text('UPA Exemplo Oeste'), findsOneWidget);
    expect(find.text('UPA Exemplo Centro'), findsNothing);
  });

  testWidgets('mapa informa origem manual e dados ilustrativos', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MapScreen(
          userOrigin: UserLocationOrigin.manual(SearchArea.goiania.center),
          repository: goianiaRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Saindo de Goiânia · ponto manual'),
      findsOneWidget,
    );
    expect(find.textContaining('Dados ilustrativos'), findsOneWidget);
  });

  testWidgets('arrastar card da UPA para baixo o oculta; outra UPA reabre', (
    tester,
  ) async {
    await openDiscovery(tester);

    const summaryKey = ValueKey('map-unit-summary-card');
    expect(find.byKey(summaryKey), findsOneWidget);

    await tester.drag(find.byKey(summaryKey), const Offset(0, 160));
    await tester.pumpAndSettle();

    expect(find.byKey(summaryKey), findsNothing);
    expect(find.text('Ver detalhes'), findsNothing);

    await tester.tap(
      find.bySemanticsLabel('UPA Exemplo Norte, Baixa disponibilidade'),
    );
    await tester.pump();

    expect(find.byKey(summaryKey), findsOneWidget);
    expect(find.text('UPA Exemplo Norte'), findsOneWidget);
  });

  testWidgets('mostra carregamento e depois as unidades da API', (
    tester,
  ) async {
    final pending = Completer<List<HealthUnit>>();
    await openDiscovery(tester, repository: _PendingRepository(pending));

    expect(find.text('Carregando unidades…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    pending.complete(goianiaUnits());
    await tester.pump();
    await tester.pump();

    expect(find.text('Carregando unidades…'), findsNothing);
    expect(find.text('UPA Exemplo Centro'), findsOneWidget);
  });

  testWidgets('consulta a API pela cidade da área e recarrega ao trocá-la', (
    tester,
  ) async {
    final repository = goianiaRepository();
    await openDiscovery(tester, repository: repository);
    expect(repository.requestedCities, ['Goiânia']);

    await tester.tap(find.text('Buscando em Goiânia'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aparecida de Goiânia, GO'));
    await tester.pump();
    await tester.tap(find.text('Ver unidades em Aparecida de Goiânia'));
    await tester.pumpAndSettle();

    expect(repository.requestedCities, ['Goiânia', 'Aparecida de Goiânia']);
  });

  testWidgets('selecionar Aparecida atualiza área e mostra estado vazio', (
    tester,
  ) async {
    await openDiscovery(tester);

    await tester.tap(find.text('Buscando em Goiânia'));
    await tester.pumpAndSettle();
    expect(find.text('Escolher cidade'), findsOneWidget);

    await tester.tap(find.text('Aparecida de Goiânia, GO'));
    await tester.pump();
    await tester.tap(find.text('Ver unidades em Aparecida de Goiânia'));
    await tester.pumpAndSettle();

    expect(find.text('Buscando em Aparecida de Goiânia'), findsOneWidget);
    expect(find.textContaining('Saindo de Goiânia'), findsOneWidget);
    expect(
      find.text('Nenhuma unidade cadastrada nesta cidade'),
      findsOneWidget,
    );
  });

  testWidgets('lista vazia da API é explicada na aba Lista', (tester) async {
    await openDiscovery(
      tester,
      repository: FakeHealthUnitRepository(unitsByCity: {'Goiânia': []}),
    );
    await openList(tester);

    expect(
      find.text('Nenhuma unidade cadastrada nesta cidade'),
      findsOneWidget,
    );
    expect(find.text('Trocar cidade'), findsOneWidget);
  });

  testWidgets('falha de conexão oferece nova tentativa que recupera', (
    tester,
  ) async {
    final repository = FakeHealthUnitRepository(
      unitsByCity: {'Goiânia': goianiaUnits()},
      failure: const HealthApiException(
        HealthApiFailureKind.connection,
        'sem rede',
      ),
    );
    await openDiscovery(tester, repository: repository);

    expect(find.text('Sem conexão com o servidor'), findsOneWidget);
    expect(find.text('UPA Exemplo Centro'), findsNothing);
    await openList(tester);
    expect(find.text('Sem conexão com o servidor'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);
    // Nenhum dado de exemplo toma o lugar da resposta que falhou.
    expect(find.text('UPA Exemplo Centro'), findsNothing);

    repository.failure = null;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Sem conexão com o servidor'), findsNothing);
    expect(find.text('UPA Exemplo Centro'), findsOneWidget);
    expect(repository.requestedCities, ['Goiânia', 'Goiânia']);
  });

  testWidgets('erro do servidor tem mensagem própria', (tester) async {
    await openDiscovery(
      tester,
      repository: FakeHealthUnitRepository(
        failure: const HealthApiException(
          HealthApiFailureKind.server,
          'HTTP 500',
          statusCode: 500,
        ),
      ),
    );

    expect(find.text('Serviço indisponível no momento'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);
  });

  testWidgets('filtro de atendimento e busca combinam na lista', (
    tester,
  ) async {
    await openDiscovery(tester);
    await openList(tester);

    await tester.tap(find.byTooltip('Filtrar por serviço'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pediatria').last);
    await tester.pumpAndSettle();

    expect(find.text('UPA Exemplo Centro'), findsOneWidget);
    expect(find.text('UPA Exemplo Oeste'), findsOneWidget);
    expect(find.text('UPA Exemplo Sul'), findsNothing);

    await tester.enterText(find.byType(TextField), 'Norte');
    await tester.pumpAndSettle();
    expect(find.text('Nenhuma unidade para este filtro'), findsOneWidget);
    expect(find.text('Remover filtro de Pediatria'), findsOneWidget);
  });

  testWidgets('ordenar por menor espera põe dados ausentes por último', (
    tester,
  ) async {
    await openDiscovery(tester);
    await openList(tester);

    await tester.tap(find.byTooltip('Ordenar unidades'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Menor espera').last);
    await tester.pumpAndSettle();

    double top(String name) => tester.getTopLeft(find.text(name)).dy;
    expect(top('UPA Exemplo Centro'), lessThan(top('UPA Exemplo Sul')));
    await tester.scrollUntilVisible(
      find.text('UPA Exemplo Norte'),
      160,
      scrollable: find.byType(Scrollable).first,
    );
    expect(top('UPA Exemplo Sul'), lessThan(top('UPA Exemplo Norte')));
    await tester.scrollUntilVisible(
      find.text('UPA Exemplo Oeste'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('UPA Exemplo Oeste'), findsOneWidget);
  });

  testWidgets('lista exibe contexto, espera e aviso demonstrativo', (
    tester,
  ) async {
    await openDiscovery(tester);
    await openList(tester);
    expect(find.text('Unidades de saúde'), findsOneWidget);
    expect(find.text('Buscando em Goiânia'), findsOneWidget);
    expect(find.textContaining('Dados ilustrativos'), findsWidgets);
    expect(find.text('20 min'), findsOneWidget);
    expect(find.textContaining('em linha reta'), findsWidgets);
    expect(find.text('Indisponível'), findsNothing);
  });

  testWidgets('lista e comparar mostram distância aproximada em linha reta', (
    tester,
  ) async {
    await openDiscovery(tester);
    await openList(tester);

    final centroKm = formatStraightLineDistanceValue(
      computeStraightLineDistanceKm(
        userPosition: SearchArea.goiania.center,
        unitPosition: goianiaUnits()
            .firstWhere((u) => u.id == 'upa-centro')
            .position,
      ),
    );
    expect(find.text('$centroKm em linha reta'), findsWidgets);
    expect(find.textContaining('em linha reta'), findsWidgets);
  });

  testWidgets('ordenar por proximidade respeita filtros', (tester) async {
    await openDiscovery(tester);
    await openList(tester);

    await tester.tap(find.byTooltip('Filtrar por serviço'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pediatria').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Ordenar unidades'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Proximidade').last);
    await tester.pumpAndSettle();

    double top(String name) => tester.getTopLeft(find.text(name)).dy;
    expect(top('UPA Exemplo Centro'), lessThan(top('UPA Exemplo Oeste')));
    expect(find.text('UPA Exemplo Sul'), findsNothing);
  });

  testWidgets('GPS indisponível mostra distância indisponível na lista', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MapScreen(
          userOrigin: UserLocationOrigin.fromGps(goianiaPosition()),
          userLocationAvailable: false,
          repository: goianiaRepository(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await openList(tester);

    expect(find.text(straightLineDistanceUnavailable), findsWidgets);
  });

  testWidgets('distâncias atualizam quando a posição do usuário muda', (
    tester,
  ) async {
    final repository = goianiaRepository();
    await openDiscovery(tester, repository: repository);
    await openList(tester);

    final centroAtCenter = formatStraightLineDistanceValue(
      computeStraightLineDistanceKm(
        userPosition: SearchArea.goiania.center,
        unitPosition: goianiaUnits()
            .firstWhere((u) => u.id == 'upa-centro')
            .position,
      ),
    );
    expect(find.text('$centroAtCenter em linha reta'), findsWidgets);

    final farPosition = Position(
      longitude: -49.35,
      latitude: -16.80,
      timestamp: DateTime(2026),
      accuracy: 10,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MapScreen(
          userOrigin: UserLocationOrigin.fromGps(farPosition),
          repository: repository,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await openList(tester);

    final centroWhenFar = formatStraightLineDistanceValue(
      computeStraightLineDistanceKm(
        userPosition: LatLng(farPosition.latitude, farPosition.longitude),
        unitPosition: goianiaUnits()
            .firstWhere((u) => u.id == 'upa-centro')
            .position,
      ),
    );
    expect(centroWhenFar, isNot(centroAtCenter));
    expect(find.text('$centroWhenFar em linha reta'), findsWidgets);
    expect(find.text('$centroAtCenter em linha reta'), findsNothing);
  });

  testWidgets('unidade com coordenada inválida permanece visível na lista', (
    tester,
  ) async {
    final invalid = HealthUnit(
      id: 'upa-invalid',
      name: 'UPA Coordenada inválida',
      address: 'Endereço',
      position: const LatLng(95, -49.26),
      services: const ['Clínica geral'],
      operationalData: null,
    );
    await openDiscovery(
      tester,
      repository: FakeHealthUnitRepository(
        unitsByCity: {
          'Goiânia': [...goianiaUnits(), invalid],
        },
      ),
    );
    await tester.pump();
    await tester.pump();
    await openList(tester);

    expect(find.text('5 unidades'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('UPA Coordenada inválida'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('UPA Coordenada inválida'), findsOneWidget);
    expect(find.text(straightLineDistanceUnavailable), findsWidgets);

    await tester.tap(find.byTooltip('Ordenar unidades'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Proximidade').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('UPA Coordenada inválida'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('UPA Coordenada inválida'), findsOneWidget);
  });

  testWidgets(
    'dados reais (não demonstrativos) não recebem aviso ilustrativo',
    (tester) async {
      final real = parseHealthUnit(
        unitJson(
          id: 'ubs-real',
          name: 'UBS Real',
          isDemo: false,
          operationalStatus: statusJson(isDemo: false),
        ),
      );
      await openDiscovery(
        tester,
        repository: FakeHealthUnitRepository(
          unitsByCity: {
            'Goiânia': [real],
          },
        ),
      );

      expect(find.textContaining('Dados ilustrativos'), findsNothing);
      await openList(tester);
      expect(find.textContaining('Dados ilustrativos'), findsNothing);
      expect(find.text('20 min'), findsOneWidget);
    },
  );

  testWidgets('leitura desatualizada não aparece como disponibilidade atual', (
    tester,
  ) async {
    final stale = parseHealthUnit(
      unitJson(
        id: 'upa-antiga',
        name: 'UPA Antiga',
        operationalStatus: statusJson(age: const Duration(hours: 5)),
      ),
    );
    final semantics = tester.ensureSemantics();
    await openDiscovery(
      tester,
      repository: FakeHealthUnitRepository(
        unitsByCity: {
          'Goiânia': [stale],
        },
      ),
    );

    expect(find.text('Alta disponibilidade'), findsNothing);
    expect(find.text('Dados desatualizados'), findsOneWidget);
    expect(
      find.bySemanticsLabel('UPA Antiga, Dados desatualizados'),
      findsOneWidget,
    );

    await openList(tester);
    expect(find.text('Espera sem atualização'), findsOneWidget);
    expect(find.text('20 min'), findsNothing);

    await tester.tap(find.byTooltip('Ver detalhes de UPA Antiga'));
    await tester.pumpAndSettle();
    expect(find.text('Espera sem atualização'), findsOneWidget);
    expect(find.textContaining('Última leitura'), findsOneWidget);
    expect(find.text('Ver rota'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('marcador selecionado é anunciado e não altera a comparação', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await openDiscovery(tester);
    final northMarker = find.bySemanticsLabel(
      'UPA Exemplo Norte, Baixa disponibilidade',
    );
    expect(
      tester
          .getSemantics(northMarker)
          .getSemanticsData()
          .flagsCollection
          .isSelected,
      Tristate.isFalse,
    );
    await tester.tap(northMarker);
    await tester.pump();
    expect(find.text('UPA Exemplo Norte'), findsOneWidget);
    expect(
      tester
          .getSemantics(northMarker)
          .getSemanticsData()
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
    );

    await openList(tester);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('unit-card-upa-norte')),
      160,
      scrollable: find.byType(Scrollable).first,
    );
    final toggle = find.descendant(
      of: find.byKey(const ValueKey('unit-card-upa-norte')),
      matching: find.byType(CheckboxListTile),
    );
    expect(tester.widget<CheckboxListTile>(toggle).value, isFalse);
    semantics.dispose();
  });

  testWidgets('voltar dos detalhes preserva busca, filtro, ordem e rolagem', (
    tester,
  ) async {
    final units = [
      for (var n = 1; n <= 10; n++)
        parseHealthUnit(
          unitJson(
            id: 'ubs-$n',
            name: 'UBS Pediátrica $n',
            services: ['Pediatria'],
            operationalStatus: statusJson(wait: n),
          ),
        ),
    ];
    await openDiscovery(
      tester,
      repository: FakeHealthUnitRepository(unitsByCity: {'Goiânia': units}),
    );
    await openList(tester);
    await tester.enterText(find.byType(TextField), 'ubs');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Filtrar por serviço'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pediatria').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Ordenar unidades'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Menor espera'));
    await tester.pumpAndSettle();

    final details = find.byTooltip('Ver detalhes de UBS Pediátrica 6');
    final list = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(details, 220, scrollable: list);
    await tester.pumpAndSettle();
    final position = tester.state<ScrollableState>(list).position.pixels;
    expect(position, greaterThan(0));
    await tester.tap(details);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver outras unidades'));
    await tester.pumpAndSettle();

    expect(tester.state<ScrollableState>(list).position.pixels, position);
    tester.state<ScrollableState>(list).position.jumpTo(0);
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'ubs',
    );
    expect(find.text('Menor espera'), findsOneWidget);
    expect(find.text('Pediatria'), findsWidgets);
  });

  testWidgets('detalhes mostram a unidade e a rota de carro calculada', (
    tester,
  ) async {
    await openDiscovery(tester);
    await openList(tester);
    await tester.tap(find.byTooltip('Ver detalhes de UPA Exemplo Centro'));
    await tester.pumpAndSettle();

    expect(find.text('UPA Exemplo Centro'), findsOneWidget);
    expect(find.text('Alta disponibilidade'), findsOneWidget);
    expect(find.text('20 min'), findsOneWidget);
    expect(find.text('18 aguardando'), findsOneWidget);
    final centroKm = formatStraightLineDistanceValue(
      computeStraightLineDistanceKm(
        userPosition: SearchArea.goiania.center,
        unitPosition: goianiaUnits()
            .firstWhere((u) => u.id == 'upa-centro')
            .position,
      ),
    );
    expect(find.text('$centroKm em linha reta'), findsOneWidget);

    expect(find.text('Funcionamento · 24 horas'), findsOneWidget);
    expect(
      find.text(
        'Dados ilustrativos do protótipo. Não representam a situação atual da unidade.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Ver rota'));
    await tester.pumpAndSettle();
    expect(find.text('Rota até a unidade'), findsOneWidget);
    expect(find.text('Calculando rota de carro…'), findsNothing);
    expect(find.text('3 min de carro · 1,5 km de trajeto'), findsOneWidget);
    expect(find.text('Rota calculada por test'), findsOneWidget);
    // Tempos e trajetos de exemplo não são reaproveitados.
    expect(find.text('14 min'), findsNothing);
    expect(find.text('29 min'), findsNothing);

    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();
    expect(find.text('Detalhes da unidade'), findsOneWidget);
  });

  testWidgets('compara duas unidades, substitui uma e indica falta de ônibus', (
    tester,
  ) async {
    await openDiscovery(tester, textScale: 2, size: const Size(320, 640));
    await openList(tester);
    await toggleUnit(tester, 'upa-centro');
    await toggleUnit(tester, 'upa-norte');
    await toggleUnit(tester, 'upa-oeste');
    final replacement = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('UPA Exemplo Norte'),
    );
    await tester.ensureVisible(replacement);
    await tester.pumpAndSettle();
    await tester.tap(replacement);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Comparar (2/2)'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('UPA Exemplo Oeste'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('UPA Exemplo Centro'), findsOneWidget);
    expect(find.text('UPA Exemplo Norte'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('Ônibus'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Ônibus'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ônibus'));
    await tester.pumpAndSettle();
    expect(
      find.text('Tempo de ônibus indisponível para estas unidades.'),
      findsOneWidget,
    );
    expect(find.text('Espera sem estimativa'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('detalhes da unidade Oeste omitem espera e liberam retorno', (
    tester,
  ) async {
    await openDiscovery(tester);
    await openList(tester);
    await tester.scrollUntilVisible(
      find.text('UPA Exemplo Oeste'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    final detailsAction = find.byTooltip('Ver detalhes de UPA Exemplo Oeste');
    await tester.ensureVisible(detailsAction);
    await tester.pumpAndSettle();
    await tester.tap(detailsAction);
    await tester.pumpAndSettle();

    expect(find.text('UPA Exemplo Oeste'), findsOneWidget);
    expect(find.text('Espera sem estimativa'), findsOneWidget);
    expect(find.text('Espera estimada'), findsNothing);
    expect(find.text('Ver outras unidades'), findsOneWidget);
    final oesteKm = formatStraightLineDistanceValue(
      computeStraightLineDistanceKm(
        userPosition: SearchArea.goiania.center,
        unitPosition: goianiaUnits()
            .firstWhere((u) => u.id == 'upa-oeste')
            .position,
      ),
    );
    expect(find.text('$oesteKm em linha reta'), findsOneWidget);
  });

  testWidgets(
    'detalhes sem dados operacionais mostram distância indisponível sem GPS',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MapScreen(
            userOrigin: UserLocationOrigin.fromGps(goianiaPosition()),
            userLocationAvailable: false,
            repository: goianiaRepository(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await openList(tester);
      await tester.scrollUntilVisible(
        find.text('UPA Exemplo Oeste'),
        220,
        scrollable: find.byType(Scrollable).first,
      );
      final detailsAction = find.byTooltip('Ver detalhes de UPA Exemplo Oeste');
      await tester.ensureVisible(detailsAction);
      await tester.pumpAndSettle();
      await tester.tap(detailsAction);
      await tester.pumpAndSettle();

      expect(find.text('Detalhes da unidade'), findsOneWidget);
      expect(find.text('Espera sem estimativa'), findsOneWidget);
      expect(
        find.descendant(
          of: find.ancestor(
            of: find.text('Espera sem estimativa'),
            matching: find.byType(Scaffold),
          ),
          matching: find.text(straightLineDistanceUnavailable),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('tela de disponibilidade expõe níveis com nomes acessíveis', (
    tester,
  ) async {
    await openDiscovery(tester);
    final semantics = tester.ensureSemantics();
    await tester.tap(
      find.byTooltip('Entenda os indicadores de disponibilidade'),
    );
    await tester.pumpAndSettle();

    for (final level in AvailabilityLevel.values) {
      expect(find.text(level.label), findsOneWidget);
      expect(find.bySemanticsLabel(level.label), findsOneWidget);
    }
    expect(
      find.textContaining('A avaliação de pacientes é feita pela triagem'),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('modo GPS mantém consulta sem serviço após troca de cidade', (
    tester,
  ) async {
    final access = _TestLocationAccess();
    await tester.pumpWidget(
      MaterialApp(
        home: RotaSaudeApp(
          locationAccess: access,
          onboardingStore: MemoryLocationOnboardingStore(accepted: true),
          sessionStore: MemoryUserLocationSessionStore(),
          unitRepository: FakeHealthUnitRepository(
            unitsByCity: {'Goiânia': goianiaUnits()},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Buscando em Goiânia'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aparecida de Goiânia, GO'));
    await tester.pump();
    await tester.tap(find.text('Ver unidades em Aparecida de Goiânia'));
    await tester.pumpAndSettle();

    access.serviceEnabled = false;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Unidades de saúde'), findsOneWidget);
    expect(find.textContaining('Saindo de'), findsNothing);
  });

  testWidgets('modo manual permanece sem bloqueio ao desligar GPS', (
    tester,
  ) async {
    final access = _TestLocationAccess()..serviceEnabled = false;
    final manual = UserLocationOrigin.manual(SearchArea.goiania.center);
    await tester.pumpWidget(
      MaterialApp(
        home: RotaSaudeApp(
          locationAccess: access,
          onboardingStore: MemoryLocationOnboardingStore(accepted: true),
          sessionStore: MemoryUserLocationSessionStore(origin: manual),
          unitRepository: FakeHealthUnitRepository(
            unitsByCity: {'Goiânia': goianiaUnits()},
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Lista'), findsOneWidget);
    expect(find.text('Ative a localização'), findsNothing);
    expect(find.textContaining('Origem manual no mapa'), findsNothing);
    expect(find.textContaining('ponto manual'), findsOneWidget);
  });
}

/// Repositório cuja consulta só termina quando o teste libera.
class FakeRouteRepository implements RouteRepository {
  @override
  Future<DrivingRoute> fetchDrivingRoute({
    required LatLng origin,
    required String unitId,
  }) async {
    return DrivingRoute(
      provider: 'test',
      mode: 'driving',
      unitId: unitId,
      distanceMeters: 1500,
      durationSeconds: 180,
      polyline: [origin, const LatLng(-16.6862, -49.264)],
    );
  }

  @override
  void close() {}
}

class _PendingRepository extends FakeHealthUnitRepository {
  _PendingRepository(this.pending);

  final Completer<List<HealthUnit>> pending;

  @override
  Future<List<HealthUnit>> fetchUnits({String? city}) => pending.future;
}

class _TestLocationAccess implements LocationAccess {
  bool serviceEnabled = true;

  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;

  @override
  Future<Position> getCurrentPosition() async => Position(
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

  @override
  Future<bool> isServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> requestPermission() async =>
      LocationPermission.whileInUse;

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;
}
