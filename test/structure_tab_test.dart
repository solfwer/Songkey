// Tests de la pestaa Estructura: dos paneles con las mismas secciones,
// donde de "Secciones" se aaden al "Orden actual".
import 'package:appchords/data/chord_parser.dart';
import 'package:appchords/data/store.dart';
import 'package:appchords/models/app_state.dart';
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

Future<Store> _abrir(WidgetTester tester, {List<String>? orden}) async {
  tester.view.physicalSize = const Size(900, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final store = Store();
  final cancion = Song(id: 'c', title: 'T', key: 'C', body: cuerpo, structure: orden);
  store.update((s) => AppState(groups: s.groups, songs: [...s.songs, cancion], setlists: s.setlists));
  await tester.pumpWidget(MaterialApp(home: SongEditorPage(store: store, song: cancion)));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Estructura'));
  await tester.pumpAndSettle();
  return store;
}

void main() {
  testWidgets('los dos paneles estn y el derecho tiene todas las secciones', (tester) async {
    await _abrir(tester, orden: const ['VERSO 1', 'CORO']);

    expect(find.text('Arma tu estructura'), findsOneWidget);
    expect(find.text('Estructura actual'), findsOneWidget);
    expect(find.text('Secciones'), findsOneWidget);
    // Orden: 2 apariciones con su x1.
    expect(find.text('x1'), findsNWidgets(2));
    // El panel derecho tiene las 4 secciones (el mismo catalogo).
    expect(find.text('4 en total'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('aadir una seccion del panel derecho la pone en el orden', (tester) async {
    await _abrir(tester, orden: const ['VERSO 1', 'CORO']);

    // El primer boton de aadir es de la primera seccion (INTRODUCCIN).
    await tester.tap(find.byIcon(Icons.add_circle_outline).first);
    await tester.pumpAndSettle();

    // Ahora hay 3 en el orden.
    expect(find.text('x1'), findsNWidgets(3));
  });

  testWidgets('se puede repetir una seccion que ya suena', (tester) async {
    await _abrir(tester, orden: const ['CORO']);

    // El panel derecho sigue teniendo el CORO: se puede volver a aadir.
    await tester.tap(find.byIcon(Icons.add_circle_outline).first);
    await tester.pumpAndSettle();
    expect(find.text('x1'), findsNWidgets(2));
  });

  testWidgets('subir las repeticiones cambia el x2', (tester) async {
    await _abrir(tester, orden: const ['VERSO 1', 'CORO']);
    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pumpAndSettle();
    expect(find.text('x2'), findsOneWidget);
  });

  testWidgets('el dialogo de crear seccion tiene lista de tipos', (tester) async {
    await _abrir(tester, orden: const ['VERSO 1']);

    await tester.tap(find.widgetWithIcon(OutlinedButton, Icons.add).last);
    await tester.pumpAndSettle();

    expect(find.text('Nueva seccion'), findsOneWidget);
    expect(find.text('Tipo de seccion'), findsOneWidget);
    // Se puede elegir entre los tipos de una cancion.
    await tester.tap(find.text('Verso'));
    await tester.pumpAndSettle();
    expect(find.text('Pre-coro'), findsOneWidget);
    expect(find.text('Puente'), findsOneWidget);
    expect(find.text('Interludio'), findsOneWidget);
    expect(find.text('Outro'), findsOneWidget);
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
    final secs = sectionsInOrder(cuerpo, ['VERSO 1', 'CORO', 'CORO']);
    expect(secs.map((s) => s.label).toList(), ['VERSO 1', 'CORO', 'CORO']);
  });
}
