import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:rotasaude/app.dart';
import 'package:rotasaude/screens/home_screen.dart';
import 'package:rotasaude/services/location_access.dart';
import 'package:rotasaude/services/location_onboarding_store.dart';

void main() {
  Future<void> showHome(
    WidgetTester tester,
    FakeLocationAccess location,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          locationAccess: location,
          mapBuilder: (context, position) =>
              const Scaffold(body: Center(child: Text('Mapa de teste'))),
        ),
      ),
    );
  }

  testWidgets('não solicita permissão antes do toque', (tester) async {
    final location = FakeLocationAccess();
    await showHome(tester, location);

    expect(find.text('Onde você quer buscar atendimento?'), findsOneWidget);
    expect(
      find.text(
        'Encontre unidades, confira os serviços e compare o deslocamento '
        'antes de sair.',
      ),
      findsOneWidget,
    );
    expect(find.text('Usar minha localização'), findsOneWidget);
    expect(location.checkCount, 0);
    expect(location.requestCount, 0);
  });

  testWidgets('negação solicitável explica e permite tentar de novo', (
    tester,
  ) async {
    final location = FakeLocationAccess();
    await showHome(tester, location);

    await tester.tap(find.text('Usar minha localização'));
    await tester.pumpAndSettle();

    expect(location.requestCount, 1);
    expect(find.text('Permitir localização'), findsOneWidget);
    expect(
      find.textContaining('Precisamos da sua localização'),
      findsOneWidget,
    );
    expect(location.serviceCount, 0);

    location.requestResult = LocationPermission.whileInUse;
    await tester.tap(find.text('Permitir localização'));
    await tester.pumpAndSettle();
    expect(location.requestCount, 2);
    expect(find.text('Mapa de teste'), findsOneWidget);
  });

  testWidgets('permissão bloqueada abre ajustes e continua ao retornar', (
    tester,
  ) async {
    final location = FakeLocationAccess()
      ..permission = LocationPermission.deniedForever;
    await showHome(tester, location);

    await tester.tap(find.text('Usar minha localização'));
    await tester.pumpAndSettle();
    expect(find.text('Abrir permissões do app'), findsOneWidget);
    expect(
      find.text(
        'Para encontrar unidades próximas, permita o acesso à localização '
        'nas configurações do app.',
      ),
      findsOneWidget,
    );
    expect(location.requestCount, 0);

    await tester.tap(find.text('Abrir permissões do app'));
    await tester.pump();
    expect(location.appSettingsCount, 1);
    location.permission = LocationPermission.whileInUse;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.text('Mapa de teste'), findsOneWidget);
    expect(location.requestCount, 0);
  });

  testWidgets('bloqueio após solicitação abre permissões do app', (
    tester,
  ) async {
    final location = FakeLocationAccess()
      ..requestResult = LocationPermission.deniedForever;
    await showHome(tester, location);

    await tester.tap(find.text('Usar minha localização'));
    await tester.pumpAndSettle();

    expect(location.requestCount, 1);
    expect(find.text('Abrir permissões do app'), findsOneWidget);
    expect(location.positionCount, 0);
  });

  testWidgets('serviço desligado abre ajuste e continua ao retornar', (
    tester,
  ) async {
    final location = FakeLocationAccess()
      ..permission = LocationPermission.whileInUse
      ..serviceEnabled = false;
    await showHome(tester, location);

    await tester.tap(find.text('Usar minha localização'));
    await tester.pumpAndSettle();
    expect(find.text('Ativar localização'), findsOneWidget);
    expect(
      find.text(
        'A localização do celular está desligada. Ative-a para encontrar '
        'unidades próximas.',
      ),
      findsOneWidget,
    );
    expect(location.positionCount, 0);

    await tester.tap(find.text('Ativar localização'));
    await tester.pump();
    expect(location.locationSettingsCount, 1);
    location.serviceEnabled = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Mapa de teste'), findsOneWidget);
    expect(location.requestCount, 0);
  });

  testWidgets('retorno dos ajustes não solicita permissão em ciclo', (
    tester,
  ) async {
    final location = FakeLocationAccess()
      ..permission = LocationPermission.deniedForever;
    await showHome(tester, location);
    await tester.tap(find.text('Usar minha localização'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abrir permissões do app'));
    await tester.pump();

    location.permission = LocationPermission.denied;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Abrir permissões do app'), findsOneWidget);
    expect(location.requestCount, 0);
  });

  testWidgets('falha de posição oferece nova tentativa', (tester) async {
    final location = FakeLocationAccess()
      ..permission = LocationPermission.whileInUse
      ..positionError = TimeoutException('sem posição');
    await showHome(tester, location);

    await tester.tap(find.text('Usar minha localização'));
    await tester.pumpAndSettle();
    expect(find.text('Tentar novamente'), findsOneWidget);
    expect(find.textContaining('Não conseguimos obter'), findsOneWidget);

    location
      ..positionError = null
      ..pendingPosition = Completer<Position>();
    await tester.tap(find.text('Tentar novamente'));
    await tester.pump();
    expect(find.text('Obtendo localização…'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsNothing);

    location.pendingPosition!.complete(FakeLocationAccess.testPosition);
    await tester.pumpAndSettle();
    expect(find.text('Mapa de teste'), findsOneWidget);
  });

  testWidgets('carregamento bloqueia toques repetidos', (tester) async {
    final location = FakeLocationAccess()
      ..permission = LocationPermission.whileInUse
      ..pendingPosition = Completer<Position>();
    await showHome(tester, location);

    await tester.tap(find.text('Usar minha localização'));
    await tester.pump();
    expect(find.text('Obtendo localização…'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(location.positionCount, 1);

    location.pendingPosition!.complete(FakeLocationAccess.testPosition);
    await tester.pumpAndSettle();
    expect(find.text('Mapa de teste'), findsOneWidget);
  });

  testWidgets('revela o mapa em círculo somente após obter a posição', (
    tester,
  ) async {
    final location = FakeLocationAccess()
      ..permission = LocationPermission.whileInUse
      ..pendingPosition = Completer<Position>();
    await showHome(tester, location);
    await tester.tap(find.text('Usar minha localização'));
    await tester.pump();
    expect(find.byKey(const ValueKey('map-reveal')), findsNothing);

    location.pendingPosition!.complete(FakeLocationAccess.testPosition);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.byKey(const ValueKey('map-reveal')), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('Mapa de teste'), findsOneWidget);
    final route = ModalRoute.of(tester.element(find.text('Mapa de teste')));
    expect(route?.transitionDuration, const Duration(milliseconds: 800));
  });

  testWidgets('fonte maior e movimento reduzido permitem prosseguir', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final location = FakeLocationAccess()
      ..permission = LocationPermission.whileInUse;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 568),
            textScaler: TextScaler.linear(1.3),
            disableAnimations: true,
          ),
          child: HomeScreen(
            locationAccess: location,
            mapBuilder: (context, position) =>
                const Scaffold(body: Text('Mapa de teste')),
          ),
        ),
      ),
    );
    await tester.scrollUntilVisible(find.text('Usar minha localização'), 150);
    await tester.tap(find.text('Usar minha localização'));
    await tester.pumpAndSettle();

    expect(find.text('Mapa de teste'), findsOneWidget);
    expect(find.byKey(const ValueKey('map-reveal')), findsNothing);
    final route = ModalRoute.of(tester.element(find.text('Mapa de teste')));
    expect(route?.transitionDuration, Duration.zero);
    expect(tester.takeException(), isNull);
  });

  testWidgets('primeira entrada mostra a tela inicial', (tester) async {
    final location = FakeLocationAccess();
    final store = MemoryLocationOnboardingStore();

    await tester.pumpWidget(
      RotaSaudeApp(locationAccess: location, onboardingStore: store),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Onde você quer buscar atendimento?'), findsOneWidget);
    expect(store.accepted, isFalse);
  });

  testWidgets('aceitar a localização dispensa a tela inicial na próxima vez', (
    tester,
  ) async {
    final location = FakeLocationAccess()
      ..requestResult = LocationPermission.whileInUse;
    final store = MemoryLocationOnboardingStore();

    await tester.pumpWidget(
      RotaSaudeApp(locationAccess: location, onboardingStore: store),
    );
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('Usar minha localização'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));

    expect(store.accepted, isTrue);
    expect(find.text('Mapa'), findsOneWidget);
  });

  testWidgets('localização desligada depois da primeira vez bloqueia o app', (
    tester,
  ) async {
    final location = FakeLocationAccess()
      ..permission = LocationPermission.whileInUse
      ..serviceEnabled = false;
    final store = MemoryLocationOnboardingStore(accepted: true);

    await tester.pumpWidget(
      RotaSaudeApp(locationAccess: location, onboardingStore: store),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Onde você quer buscar atendimento?'), findsNothing);
    expect(find.text('Ative a localização'), findsOneWidget);

    await tester.tap(find.text('Ativar localização'));
    await tester.pump();
    expect(location.locationSettingsCount, 1);
  });

  testWidgets('retorno ao app permite tentar novamente após falha de posição', (
    tester,
  ) async {
    final location = FakeLocationAccess()
      ..permission = LocationPermission.whileInUse
      ..positionError = TimeoutException('sem posição');

    await tester.pumpWidget(
      RotaSaudeApp(
        locationAccess: location,
        onboardingStore: MemoryLocationOnboardingStore(accepted: true),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Não conseguimos obter sua localização agora.'),
      findsOneWidget,
    );
    expect(find.text('Tentar novamente'), findsOneWidget);
    expect(location.positionCount, 1);

    location
      ..positionError = null
      ..pendingPosition = Completer<Position>();
    await tester.tap(find.text('Tentar novamente'));
    await tester.pump();
    expect(find.text('Obtendo localização…'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsNothing);

    location.pendingPosition!.complete(FakeLocationAccess.testPosition);
    await tester.pumpAndSettle();

    expect(find.text('RotaSaúde'), findsOneWidget);
    expect(location.positionCount, 2);
  });
}

class FakeLocationAccess implements LocationAccess {
  static final testPosition = Position(
    latitude: -23.55,
    longitude: -46.63,
    timestamp: DateTime(2026),
    accuracy: 10,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );

  LocationPermission permission = LocationPermission.denied;
  LocationPermission requestResult = LocationPermission.denied;
  bool serviceEnabled = true;
  Object? positionError;
  Completer<Position>? pendingPosition;
  int checkCount = 0;
  int requestCount = 0;
  int serviceCount = 0;
  int positionCount = 0;
  int appSettingsCount = 0;
  int locationSettingsCount = 0;

  @override
  Future<LocationPermission> checkPermission() async {
    checkCount++;
    return permission;
  }

  @override
  Future<LocationPermission> requestPermission() async {
    requestCount++;
    permission = requestResult;
    return permission;
  }

  @override
  Future<bool> isServiceEnabled() async {
    serviceCount++;
    return serviceEnabled;
  }

  @override
  Future<Position> getCurrentPosition() async {
    positionCount++;
    if (positionError case final error?) throw error;
    return pendingPosition?.future ?? testPosition;
  }

  @override
  Future<bool> openAppSettings() async {
    appSettingsCount++;
    return true;
  }

  @override
  Future<bool> openLocationSettings() async {
    locationSettingsCount++;
    return true;
  }
}
