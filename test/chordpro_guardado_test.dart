// Regresin: guardar desde el modo ChordPro (y desde cualquier pestaa).
import 'package:appchords/data/store.dart';
import 'package:appchords/models/app_state.dart';
import 'package:appchords/models/song.dart';
import 'package:appchords/screens/song/song_editor_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('editar en modo ChordPro y guardar conserva el texto', (tester) async {
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = Store();
    final cancion = Song(
      id: 'c1',
      title: 'Prueba',
      key: 'C',
      body: '{start_of_verse: VERSO 1}\n[G]Hola mundo\n{end_of_verse}',
      structure: const ['VERSO 1'],
    );
    await tester.pumpWidget(MaterialApp(home: SongEditorPage(store: store, song: cancion)));
    await tester.pumpAndSettle();

    // Contenido -> ChordPro.
    await tester.tap(find.text('Contenido'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ChordPro'));
    await tester.pumpAndSettle();

    // Escribir una letra nueva.
    await tester.enterText(
      find.byType(TextField),
      '{start_of_verse: VERSO 1}\n[C]Nueva letra [G]mia\n{end_of_verse}\n\n{start_of_chorus: CORO}\n[D]Coro nuevo\n{end_of_chorus}',
    );
    await tester.pumpAndSettle();

    // Guardar (el botn est en la barra inferior, fuera de las pestaas).
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar').last);
    await tester.pumpAndSettle();

    final song = store.state.songs.firstWhere((s) => s.id == 'c1');
    expect(song.body, contains('Nueva letra'));
    expect(song.body, contains('Coro nuevo'));
    expect(song.body, contains('{start_of_chorus: CORO}'));
    // El botn confirma que se ha guardado (y no cierra la pantalla).
    expect(find.text('Guardado'), findsOneWidget);
    expect(find.byType(SongEditorPage), findsOneWidget);
  });

  testWidgets('guardar desde la pestaa Datos tambin conserva la letra', (tester) async {
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = Store();
    final cancion = Song(id: 'c2', title: 'Otra', key: 'C', body: '{start_of_verse: VERSO 1}\n[G]Hola\n{end_of_verse}', structure: const ['VERSO 1']);
    // Se abre como una ruta para que haya a donde volver (botn atrs).
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SongEditorPage(store: store, song: cancion))),
                child: const Text('abrir editor'),
              ),
            ),
          )),
    ));
    await tester.tap(find.text('abrir editor'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Contenido'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ChordPro'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '{start_of_verse: VERSO 1}\n[C]Otra letra\n{end_of_verse}');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Datos'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar').last);
    await tester.pumpAndSettle();

    final song = store.state.songs.firstWhere((s) => s.id == 'c2');
    expect(song.body, contains('Otra letra'));
  });

  testWidgets('salir con cambios sin guardar avisa antes de perderlos', (tester) async {
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = Store();
    final cancion = Song(id: 'c3', title: 'Sin guardar', key: 'C', body: '{start_of_verse: VERSO 1}\n[G]Hola\n{end_of_verse}', structure: const ['VERSO 1']);
    store.update((s) => AppState(groups: s.groups, songs: [...s.songs, cancion], setlists: s.setlists));
    // Se abre como una ruta para que haya a donde volver (botn atrs).
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SongEditorPage(store: store, song: cancion))),
                child: const Text('abrir editor'),
              ),
            ),
          )),
    ));
    await tester.tap(find.text('abrir editor'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Contenido'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ChordPro'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '{start_of_verse: VERSO 1}\n[C]Texto que no se guarda\n{end_of_verse}');
    await tester.pumpAndSettle();

    // Botn atrs del sistema.
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Aparece el aviso y la cancin sigue igual.
    expect(find.text('Tienes cambios sin guardar'), findsOneWidget);
    final song = store.state.songs.firstWhere((s) => s.id == 'c3');
    expect(song.body, contains('[G]Hola'));
  });
}
