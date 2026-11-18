import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:rotasaude/models/health_unit.dart';
import 'package:rotasaude/repositories/health_unit_parser.dart';
import 'package:rotasaude/repositories/health_unit_repository.dart';
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

  Future<void> openList(
    WidgetTester tester,
    FakeHealthUnitRepository repository, {
    Duration dataRefresh = const Duration(milliseconds: 50),
  }) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      MaterialApp(
        home: MapScreen(
          userOrigin: UserLocationOrigin.fromGps(goianiaPosition()),
          operationalRefreshInterval: Duration.zero,
          dataRefreshInterval: dataRefresh,
          repository: repository,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('Lista'));
    await tester.pumpAndSettle();
  }

  HealthUnit unitWith(String id, String name, Map<String, dynamic>? status) =>
      parseHealthUnit(unitJson(id: id, name: name, operationalStatus: status));

  testWidgets('consulta novamente e exibe a nova leitura sem reabrir a tela', (
    tester,
  ) async {
    final repository = FakeHealthUnitRepository(
      unitsByCity: {
        'Goiânia': [
          unitWith('upa-a', 'UPA A', statusJson(level: 'HIGH', wait: 15)),
        ],
      },
    );
    await openList(tester, repository);
    expect(find.text('15 min'), findsOneWidget);

    // O simulador grava um cenário crítico; o app o recebe na próxima consulta.
    repository.unitsByCity = {
      'Goiânia': [
        unitWith(
          'upa-a',
          'UPA A',
          statusJson(level: 'CRITICAL', wait: 110, people: 64),
        ),
      ],
    };
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump();

    expect(find.text('15 min'), findsNothing);
    expect(find.text('110 min'), findsOneWidget);
    expect(repository.requestedCities.length, greaterThan(1));
  });

  testWidgets('falha ao atualizar mantém os dados e não mostra erro', (
    tester,
  ) async {
    final repository = FakeHealthUnitRepository(
      unitsByCity: {
        'Goiânia': [unitWith('upa-a', 'UPA A', statusJson(wait: 20))],
      },
    );
    await openList(tester, repository);

    repository.failure = const HealthApiException(
      HealthApiFailureKind.connection,
      'sem rede',
    );
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump();

    expect(find.text('20 min'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsNothing);
    expect(tester.takeException(), isNull);

    // Ao voltar a rede, a lista é atualizada.
    repository
      ..failure = null
      ..unitsByCity = {
        'Goiânia': [unitWith('upa-a', 'UPA A', statusJson(wait: 45))],
      };
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump();
    expect(find.text('45 min'), findsOneWidget);
  });

  testWidgets('intervalo zero desliga a atualização periódica', (tester) async {
    final repository = FakeHealthUnitRepository(
      unitsByCity: {
        'Goiânia': [unitWith('upa-a', 'UPA A', statusJson(wait: 20))],
      },
    );
    await openList(tester, repository, dataRefresh: Duration.zero);
    final before = repository.requestedCities.length;

    await tester.pump(const Duration(minutes: 5));

    expect(repository.requestedCities.length, before);
  });

  testWidgets('cenários simulados: crítico, desatualizado e falha de leitura', (
    tester,
  ) async {
    final repository = FakeHealthUnitRepository(
      unitsByCity: {
        'Goiânia': [
          unitWith(
            'upa-critica',
            'UPA Crítica',
            statusJson(level: 'CRITICAL', wait: 110, people: 64),
          ),
          unitWith(
            'upa-antiga',
            'UPA Antiga',
            statusJson(
              level: 'MODERATE',
              wait: 45,
              people: 27,
              age: const Duration(hours: 3),
            ),
          ),
          // Falha temporária: a fonte respondeu sem nenhum valor.
          unitWith(
            'upa-falha',
            'UPA Falha',
            statusJson(level: null, wait: null, people: null),
          ),
          unitWith('upa-vazia', 'UPA Vazia', null),
        ],
      },
    );
    await openList(tester, repository, dataRefresh: Duration.zero);

    expect(find.text('110 min'), findsOneWidget);
    // Leitura de 3 h: não é exibida como atual.
    expect(find.text('45 min'), findsNothing);
    expect(find.text('Espera sem atualização'), findsOneWidget);
    // Falha de leitura e unidade sem dados: sem estimativa inventada.
    expect(find.text('Espera sem estimativa'), findsNWidgets(2));
    // A interface não exibe aviso de simulação.
    expect(find.textContaining('Dados simulados'), findsNothing);

    // Detalhes: o cenário crítico mostra nível e pessoas; a falha, nenhum dado.
    await tester.tap(find.byTooltip('Ver detalhes de UPA Crítica'));
    await tester.pumpAndSettle();
    expect(find.text('Situação crítica'), findsOneWidget);
    expect(find.text('64 aguardando'), findsOneWidget);
    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Ver detalhes de UPA Falha'));
    await tester.pumpAndSettle();
    expect(find.text('Espera sem estimativa'), findsOneWidget);
    expect(find.textContaining('aguardando'), findsNothing);
    expect(
      find.text('Confirme o atendimento diretamente com a unidade.'),
      findsOneWidget,
    );
  });
}
