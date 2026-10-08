import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:appchords/screens/settings/legal_screen.dart';
import 'package:appchords/screens/settings/settings_screen.dart';
import 'package:appchords/data/store.dart';
import 'package:appchords/theme.dart';

void main() {
  testWidgets('Ajustes muestra la sección Legal y abre el aviso legal', (tester) async {
    final store = Store();
    await tester.pumpWidget(MaterialApp(theme: darkTheme(), home: Scaffold(body: SettingsScreen(store: store))));

    await tester.scrollUntilVisible(find.text('Aviso legal'), 100);
    expect(find.text('Legal'), findsOneWidget);
    await tester.tap(find.text('Aviso legal'));
    await tester.pumpAndSettle();

    expect(find.textContaining('pertenecen a sus respectivos autores'), findsOneWidget);
    expect(find.textContaining('legalContact'), findsNothing); // el placeholder no debe filtrarse sin interpolar
    expect(find.textContaining(legalContact), findsWidgets);
  });

  testWidgets('Política de privacidad declara que los datos son locales', (tester) async {
    final store = Store();
    await tester.pumpWidget(MaterialApp(theme: darkTheme(), home: Scaffold(body: SettingsScreen(store: store))));

    await tester.scrollUntilVisible(find.text('Política de privacidad'), 100);
    await tester.ensureVisible(find.text('Política de privacidad'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Política de privacidad'));
    await tester.pumpAndSettle();

    expect(find.textContaining('no exige cuenta en línea'), findsOneWidget);
    expect(find.textContaining('se almacenan exclusivamente en tu dispositivo'), findsOneWidget);
  });

  testWidgets('Acerca de abre con versión por defecto sin crashear', (tester) async {
    final store = Store();
    await tester.pumpWidget(MaterialApp(theme: darkTheme(), home: Scaffold(body: SettingsScreen(store: store))));

    await tester.scrollUntilVisible(find.text('Acerca de'), 100);
    await tester.ensureVisible(find.text('Acerca de'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Acerca de'));
    await tester.pumpAndSettle();

    // En tests PackageInfo no está disponible: se muestra el valor por defecto.
    expect(find.textContaining('© 2026 Songkey'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('LegalScreen: los temas traen documentos completos', () {
    const topics = LegalTopic.values;
    expect(topics.length, 2);
    expect(LegalTopic.aviso.title, 'Aviso legal');
    expect(LegalTopic.privacidad.title, 'Política de privacidad');
    expect(LegalTopic.aviso.body.length, greaterThan(5));
    expect(LegalTopic.privacidad.body.length, greaterThan(5));
  });
}