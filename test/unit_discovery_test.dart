import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:rotasaude/app.dart';
import 'package:rotasaude/models/demo_health_unit.dart';
import 'package:rotasaude/screens/map_screen.dart';
import 'package:rotasaude/services/location_access.dart';
import 'package:rotasaude/services/location_onboarding_store.dart';
import 'package:rotasaude/theme/app_colors.dart';

void main() {
  Future<void> openDiscovery(WidgetTester tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      MaterialApp(
        home: MapScreen(
          position: Position(
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
          ),
        ),
      ),
    );
    await tester.pump();
  }

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
    expect(
      find.text('Nenhuma unidade nesta área do protótipo'),
      findsOneWidget,
    );
  });

  testWidgets('filtro de atendimento e busca combinam na lista', (
    tester,
  ) async {
    await openDiscovery(tester);
    await tester.tap(find.text('Lista'));
    await tester.pumpAndSettle();

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

  testWidgets('lista e comparação exibem contexto e aviso do protótipo', (
    tester,
  ) async {
    await openDiscovery(tester);
    await tester.tap(find.text('Lista'));
    await tester.pumpAndSettle();

    expect(find.text('Unidades próximas'), findsOneWidget);
    expect(find.text('4 unidades · Goiânia, GO'), findsOneWidget);
    expect(find.textContaining('Dados ilustrativos'), findsOneWidget);
    expect(find.text('5,8 km'), findsOneWidget);

    await tester.tap(find.text('Comparar'));
    await tester.pumpAndSettle();

    expect(find.text('Comparar unidades'), findsOneWidget);
    expect(find.textContaining('Dados ilustrativos'), findsOneWidget);
    expect(find.text('5,8 km'), findsWidgets);
  });

  testWidgets('busca na lista pode ser fechada sem digitar', (tester) async {
    await openDiscovery(tester);
    await tester.tap(find.text('Lista'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Buscar unidade'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byTooltip('Fechar busca'), findsOneWidget);

    await tester.tap(find.byTooltip('Fechar busca'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(find.byTooltip('Buscar unidade'), findsOneWidget);
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

    await tester.tap(find.text('Lista'));
    await tester.pumpAndSettle();
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

  testWidgets('detalhes e rota mantêm a unidade selecionada', (tester) async {
    await openDiscovery(tester);
    await tester.tap(find.text('Lista'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Ver detalhes de UPA Exemplo Centro'));
    await tester.pumpAndSettle();

    expect(find.text('UPA Exemplo Centro'), findsOneWidget);
    expect(
      find.text(
        'Dados ilustrativos do protótipo. Não representam a situação atual da unidade.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Ver opções de rota'));
    await tester.pumpAndSettle();
    expect(find.text('Rota até a unidade'), findsOneWidget);
    expect(find.text('UPA Exemplo Centro'), findsOneWidget);

    await tester.tap(find.text('Ônibus'));
    await tester.pumpAndSettle();
    expect(find.text('29 min'), findsOneWidget);
    expect(find.text('Linha ilustrativa 005 · 17 min'), findsOneWidget);
  });

  testWidgets('comparação troca o meio e mostra campos ausentes', (
    tester,
  ) async {
    await openDiscovery(tester);
    await tester.tap(find.text('Comparar'));
    await tester.pumpAndSettle();

    expect(find.text('14 min'), findsOneWidget);
    await tester.tap(find.text('Ônibus'));
    await tester.pumpAndSettle();
    expect(find.text('29 min'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('24 min'),
      220,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('24 min'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('18 min'),
      220,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('18 min'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('UPA Exemplo Oeste'),
      220,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('UPA Exemplo Oeste'), findsOneWidget);
    expect(find.text('Indisponível'), findsWidgets);
  });

  testWidgets('detalhes da unidade Oeste omitem espera e liberam retorno', (
    tester,
  ) async {
    await openDiscovery(tester);
    await tester.tap(find.text('Lista'));
    await tester.pumpAndSettle();
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
