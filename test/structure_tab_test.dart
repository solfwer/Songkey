// Tests de la pestaa Estructura (doble panel: orden actual + disponibles).
import 'package:appchords/data/chord_parser.dart';
import 'package:appchords/data/store.dart';
import 'package:appchords/models/song.dart';
import 'package:appchords/screens/song/song_editor_page.dart';
import 'package:appchords/screens/song/structure_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const cuerpo = '''{start_of_introduccion: INTRODUCCIN:}
[C] | [G]
{end_of_introduccion}

{start_of_verse: VERSO 1}
[G]Una linea del verso
{end_of_verse}

{start_of_chorus: CORO}
[C]Aleluya al Senor
{end_of_chorus}

{start_of_verse: VERSO 2}
[G]Segundo verso aqui
{end_of_verse}''';

void main() {
  testWidgets('la pestaa tiene los dos paneles', (tester) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = Store();
    await tester.pumpWidget(MaterialApp(
      home: SongEditorPage(store: store, song: Song(id: 'c', title: 'T', key: 'C', body: cuerpo, structure: const ['INTRODUCCIN:', 'VERSO 1', 'CORO', 'VERSO 2'])),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Estructura'));
    await tester.pumpAndSettle();

    expect(find.text('Arma tu estructura'), findsOneWidget);
    expect(find.text('Estructura actual'), findsOneWidget);
    expect(find.text('Disponibles'), findsOneWidget);
    // Las 4 secciones salen en el panel izquierdo, con su x1.
    expect(find.text('x1'), findsNWidgets(4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('una seccin que no suena sale en Disponibles', (tester) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = Store();
    await tester.pumpWidget(MaterialApp(
      home: SongEditorPage(store: store, song: Song(id: 'c', title: 'T', key: 'C', body: cuerpo, structure: const ['VERSO 1', 'CORO'])),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Estructura'));
    await tester.pumpAndSettle();

    // 2 en el orden y 2 disponibles.
    expect(find.text('x1'), findsNWidgets(2));
    expect(find.text('Estructura actual'), findsOneWidget);
    // El contador de disponibles dice 2.
    expect(find.text('2'), findsWidgets);
    expect(find.textContaining('Todas las secciones'), findsNothing);
  });

  testWidgets('tocar una disponible la aade al orden', (tester) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = Store();
    await tester.pumpWidget(MaterialApp(
      home: SongEditorPage(store: store, song: Song(id: 'c', title: 'T', key: 'C', body: cuerpo, structure: const ['VERSO 1', 'CORO'])),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Estructura'));
    await tester.pumpAndSettle();

    // El "VERSO 2" est disponible: se toca su botn de aadir.
    await tester.tap(find.byIcon(Icons.add_circle_outline).first);
    await tester.pumpAndSettle();
    // Ahora hay 3 en el orden.
    expect(find.text('x1'), findsNWidgets(3));
  });

  testWidgets('subir las repeticiones cambia el x2', (tester) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = Store();
    await tester.pumpWidget(MaterialApp(
      home: SongEditorPage(store: store, song: Song(id: 'c', title: 'T', key: 'C', body: cuerpo, structure: const ['VERSO 1', 'CORO'])),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Estructura'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pumpAndSettle();
    expect(find.text('x2'), findsOneWidget);
  });

  testWidgets('en pantalla estrecha los paneles se apilan', (tester) async {
    tester.view.physicalSize = const Size(400, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StructureTab(
          controller: TextEditingController(text: cuerpo),
          initialStructure: const ['VERSO 1', 'CORO'],
          onStructureChanged: (_) {},
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Arma tu estructura'), findsOneWidget);
    expect(find.text('Estructura actual'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('el orden de toque se guarda con las repeticiones', () {
    // Sin arreglo: una aparicin por seccin.
    final secs = sectionsInOrder(cuerpo, ['VERSO 1', 'CORO', 'CORO']);
    expect(secs.map((s) => s.label).toList(), ['VERSO 1', 'CORO', 'CORO']);
  });
}
