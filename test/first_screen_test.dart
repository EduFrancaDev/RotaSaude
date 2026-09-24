import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rotasaude/app.dart';
import 'package:rotasaude/screens/home_screen.dart';

void main() {
  testWidgets('Começar abre a escolha manual de cidade', (tester) async {
    await tester.pumpWidget(const RotaSaudeApp());

    expect(find.text('Saúde mais perto\nde você.'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Começar'), 200);
    await tester.tap(find.text('Começar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Onde você quer buscar atendimento?'), findsOneWidget);
    final saveButton = find.widgetWithText(FilledButton, 'Usar esta cidade');
    expect(tester.widget<FilledButton>(saveButton).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'Campinas');
    await tester.pump();
    expect(tester.widget<FilledButton>(saveButton).onPressed, isNotNull);

    await tester.tap(saveButton);
    await tester.pump();
    expect(find.text('Cidade escolhida'), findsOneWidget);
    expect(
      find.text(
        'A consulta às unidades ainda não está disponível nesta versão.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('tela pequena com fonte maior permite rolar sem animação', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            textScaler: TextScaler.linear(1.3),
            disableAnimations: true,
          ),
          child: HomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(find.text('Começar'), 150);
    expect(find.text('Começar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
