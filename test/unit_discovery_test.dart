import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:rotasaude/app.dart';
import 'package:rotasaude/models/health_unit.dart';
import 'package:rotasaude/repositories/health_unit_parser.dart';
import 'package:latlong2/latlong.dart';
import 'package:rotasaude/models/driving_route.dart';
import 'package:rotasaude/repositories/health_unit_repository.dart';
import 'package:rotasaude/repositories/route_repository.dart';
import 'package:rotasaude/screens/map_screen.dart';
import 'package:rotasaude/services/location_access.dart';
import 'package:rotasaude/services/location_onboarding_store.dart';
import 'package:rotasaude/theme/app_colors.dart';

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
  }) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      MaterialApp(
        home: MapScreen(
          position: goianiaPosition(),
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

    await tester.tap(find.text('Goiânia, GO'));
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

    await tester.tap(find.text('Goiânia, GO'));
    await tester.pumpAndSettle();
    expect(find.text('Escolher localização'), findsOneWidget);

    await tester.tap(find.text('Aparecida de Goiânia, GO'));
    await tester.pump();
    await tester.tap(find.text('Ver unidades em Aparecida de Goiânia'));
    await tester.pumpAndSettle();

    expect(find.text('Aparecida de Goiânia, GO'), findsOneWidget);
    expect(find.text('Nenhuma unidade cadastrada nesta área'), findsOneWidget);
  });

  testWidgets('lista vazia da API é explicada na aba Lista', (tester) async {
    await openDiscovery(
      tester,
      repository: FakeHealthUnitRepository(unitsByCity: {'Goiânia': []}),
    );
    await openList(tester);

    expect(find.text('Nenhuma unidade cadastrada nesta área'), findsOneWidget);
    expect(find.text('Escolher localização'), findsOneWidget);
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

    await tester.tap(find.text('Todos').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pediatria').last);
    await tester.pumpAndSettle();

    expect(find.text('UPA Exemplo Centro'), findsOneWidget);
    expect(find.text('UPA Exemplo Oeste'), findsOneWidget);
    expect(find.text('UPA Exemplo Sul'), findsNothing);

    await tester.tap(find.byTooltip('Buscar unidade'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Norte');
    await tester.pumpAndSettle();
    expect(find.text('Nenhuma unidade encontrada'), findsOneWidget);
  });

  testWidgets('ordenar por menor espera põe dados ausentes por último', (
    tester,
  ) async {
    await openDiscovery(tester);
    await openList(tester);

    await tester.tap(find.text('Destaque'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Menor espera').last);
    await tester.pumpAndSettle();

    double top(String name) => tester.getTopLeft(find.text(name)).dy;
    expect(top('UPA Exemplo Centro'), lessThan(top('UPA Exemplo Sul')));
    expect(top('UPA Exemplo Sul'), lessThan(top('UPA Exemplo Norte')));
    await tester.scrollUntilVisible(
      find.text('UPA Exemplo Oeste'),
      220,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('UPA Exemplo Oeste'), findsOneWidget);
  });

  testWidgets('lista e comparação exibem contexto e aviso demonstrativo', (
    tester,
  ) async {
    await openDiscovery(tester);
    await openList(tester);

    expect(find.text('Unidades próximas'), findsOneWidget);
    expect(find.text('4 unidades · Goiânia, GO'), findsOneWidget);
    expect(find.textContaining('Dados ilustrativos'), findsOneWidget);
    expect(find.text('20 min'), findsOneWidget);
    // A API não fornece distância nem rota: nenhum valor fixo é exibido.
    expect(find.text('5,8 km'), findsNothing);
    expect(find.text('— km'), findsWidgets);

    await tester.tap(find.text('Comparar'));
    await tester.pumpAndSettle();

    expect(find.text('Comparar unidades'), findsOneWidget);
    expect(find.textContaining('Dados ilustrativos'), findsOneWidget);
    expect(find.text('5,8 km'), findsNothing);
    expect(find.text('Indisponível'), findsWidgets);
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
      expect(find.text('Alta disponibilidade'), findsOneWidget);
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
    expect(find.text('Dados desatualizados'), findsOneWidget);
    expect(find.text('20 min'), findsNothing);

    await tester.tap(find.byTooltip('Ver detalhes de UPA Antiga'));
    await tester.pumpAndSettle();
    expect(find.text('Dados temporariamente indisponíveis'), findsOneWidget);
    expect(find.textContaining('Última atualização recebida'), findsOneWidget);
    expect(find.text('Ver opções de rota'), findsNothing);
    semantics.dispose();
  });

  testWidgets('seleção no mapa é refletida no cartão correspondente', (
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
      220,
      scrollable: find.byType(Scrollable).last,
    );
    final card = tester.widget<Card>(
      find.byKey(const ValueKey('unit-card-upa-norte')),
    );
    final shape = card.shape! as RoundedRectangleBorder;
    expect(shape.side.color, AppColors.blue);
    final selectedSemantics = tester.getSemantics(
      find.descendant(
        of: find.byKey(const ValueKey('unit-card-upa-norte')),
        matching: find.byWidgetPredicate(
          (widget) => widget is Semantics && widget.properties.selected == true,
        ),
      ),
    );
    expect(
      selectedSemantics.getSemanticsData().flagsCollection.isSelected,
      Tristate.isTrue,
    );
    semantics.dispose();
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
    expect(find.text('18'), findsOneWidget);
    expect(find.text('Funcionamento · 24 horas'), findsOneWidget);
    expect(
      find.text(
        'Dados ilustrativos do protótipo. Não representam a situação atual da unidade.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Ver opções de rota'));
    await tester.pumpAndSettle();
    expect(find.text('Rota até a unidade'), findsOneWidget);
    expect(find.text('Calculando rota de carro…'), findsNothing);
    expect(find.text('3 min'), findsOneWidget);
    expect(find.text('1,5 km'), findsOneWidget);
    expect(find.text('Rota calculada por test · modo driving'), findsOneWidget);
  // Tempos e trajetos de exemplo não são reaproveitados.
    expect(find.text('14 min'), findsNothing);
    expect(find.text('29 min'), findsNothing);

    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();
    expect(find.text('Detalhes da unidade'), findsOneWidget);
  });

  testWidgets('comparação troca o meio e mostra campos ausentes', (
    tester,
  ) async {
    await openDiscovery(tester);
    await tester.tap(find.text('Comparar'));
    await tester.pumpAndSettle();

    expect(find.text('Carro'), findsWidgets);
    expect(find.text('Indisponível'), findsWidgets);
    expect(find.text('14 min'), findsNothing);
    await tester.tap(find.text('Ônibus'));
    await tester.pumpAndSettle();
    expect(find.text('Ônibus'), findsWidgets);
    expect(find.text('29 min'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('UPA Exemplo Oeste'),
      220,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('UPA Exemplo Oeste'), findsOneWidget);
    expect(find.text('Dados operacionais indisponíveis'), findsOneWidget);
  });

  testWidgets('detalhes da unidade Oeste omitem espera e liberam retorno', (
    tester,
  ) async {
    await openDiscovery(tester);
    await openList(tester);
    await tester.scrollUntilVisible(
      find.text('UPA Exemplo Oeste'),
      220,
      scrollable: find.byType(Scrollable).last,
    );
    final detailsAction = find.byTooltip('Ver detalhes de UPA Exemplo Oeste');
    await tester.ensureVisible(detailsAction);
    await tester.pumpAndSettle();
    await tester.tap(detailsAction);
    await tester.pumpAndSettle();

    expect(find.text('UPA Exemplo Oeste'), findsOneWidget);
    expect(find.text('Dados temporariamente indisponíveis'), findsOneWidget);
    expect(find.text('Espera estimada'), findsNothing);
    expect(find.text('Ver outras unidades'), findsOneWidget);
  });

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
      find.textContaining('não representam classificação clínica'),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets(
    'localização do aparelho continua obrigatória após cidade manual',
    (tester) async {
      final access = _TestLocationAccess();
      await tester.pumpWidget(
        MaterialApp(
          home: RotaSaudeApp(
            locationAccess: access,
            onboardingStore: MemoryLocationOnboardingStore(accepted: true),
            unitRepository: FakeHealthUnitRepository(
              unitsByCity: {'Goiânia': goianiaUnits()},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Goiânia, GO'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aparecida de Goiânia, GO'));
      await tester.pump();
      await tester.tap(find.text('Ver unidades em Aparecida de Goiânia'));
      await tester.pumpAndSettle();

      access.serviceEnabled = false;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(find.text('Ative a localização'), findsOneWidget);
    },
  );
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
      polyline: [
        origin,
        const LatLng(-16.6862, -49.264),
      ],
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
