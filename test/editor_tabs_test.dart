// Tests del refactor de pestaas del editor: Datos / Contenido / Estructura /
// Vista previa, y el selector de modo dentro de Contenido.
import 'package:appchords/data/chord_parser.dart';
import 'package:appchords/data/store.dart';
import 'package:appchords/screens/song/song_editor_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('el editor tiene las 4 pestaas nuevas', (tester) async {
    await tester.pumpWidget(MaterialApp(home: SongEditorPage(store: Store())));
    await tester.pumpAndSettle();

    for (final label in ['Datos', 'Contenido', 'Estructura', 'Vista previa']) {
      expect(find.text(label), findsOneWidget, reason: 'falta la pestaa $label');
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('Contenido permite elegir entre editor visual y ChordPro', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(home: SongEditorPage(store: Store())));
    await tester.pumpAndSettle();

    // Entrar en Contenido.
    await tester.tap(find.text('Contenido'));
    await tester.pumpAndSettle();

    // El selector est visible y por defecto est el editor visual.
    expect(find.text('Editor visual'), findsOneWidget);
    expect(find.text('ChordPro'), findsOneWidget);

    // Cambiar a ChordPro: aparece el campo de texto.
    await tester.tap(find.text('ChordPro'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsWidgets);
    expect(tester.takeException(), isNull);

    // Volver al visual sigue funcionando.
    await tester.tap(find.text('Editor visual'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('la vista previa muestra la cancion que se est editando', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: SongEditorPage(
        store: Store(),
        initialTitle: 'Prueba',
        initialBody: 'Verso 1\n[G]Hola [C]mundo\n\nCoro\n[C]Aleluya',
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Vista previa'));
    await tester.pumpAndSettle();
    // Se ven los encabezados de seccin y la letra.
    expect(find.text('VERSO 1'), findsOneWidget);
    expect(find.text('CORO'), findsOneWidget);
    expect(find.textContaining('Hola'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  test('el selector recuerda el ultimo modo elegido', () {
    final store = Store();
    expect(store.editorVisualMode, isTrue);
    store.setEditorVisualMode(false);
    expect(store.editorVisualMode, isFalse);
  });

  test('sectionsInOrder se usa en la vista previa con la estructura', () {
    const body = '{start_of_verse: VERSO 1}\nHola [G]mundo\n{end_of_verse}\n{start_of_chorus: CORO}\n[C]Aleluya\n{end_of_chorus}';
    final secs = sectionsInOrder(body, ['CORO', 'VERSO 1', 'CORO']);
    expect(secs.map((s) => s.label).toList(), ['CORO', 'VERSO 1', 'CORO']);
  });
}
