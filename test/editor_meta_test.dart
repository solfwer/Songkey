// Tests del guardado: se respeta lo que escribe el usuario y solo se aaden
// las directivas de metadatos.
import 'package:appchords/data/store.dart';
import 'package:appchords/models/app_state.dart';
import 'package:appchords/models/song.dart';
import 'package:appchords/screens/song/song_editor_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('al guardar se escriben los metadatos como directivas', (tester) async {
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = Store();
    final cancion = Song(id: 'x1', title: 'Viejo', key: 'C', body: 'Verso 1\n[G]Hola');
    store.update((s) => AppState(groups: s.groups, songs: [...s.songs, cancion], setlists: s.setlists));

    await tester.pumpWidget(MaterialApp(home: SongEditorPage(store: store, song: cancion)));
    await tester.pumpAndSettle();

    // Autora y BPM desde la pestaa Datos.
    await tester.enterText(find.byType(TextField).at(1), 'Juan Prez');
    await tester.enterText(find.byType(TextField).at(3), '72');
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Guardar').last);
    await tester.pumpAndSettle();

    final song = store.state.songs.firstWhere((s) => s.id == 'x1');
    expect(song.author, 'Juan Prez');
    expect(song.bpm, 72);
    // Los metadatos van como directivas al principio.
    expect(song.body, contains('{title: Viejo}'));
    expect(song.body, contains('{artist: Juan Prez}'));
    expect(song.body, contains('{tempo: 72}'));
    // Y la letra que haba se conserva TAL CUAL (no se reescribe).
    expect(song.body, contains('Verso 1\n[G]Hola'));
  });

  testWidgets('un espacio dentro del corchete se guarda, no se deshace', (tester) async {
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = Store();
    final cancion = Song(id: 'x2', title: 'Con espacio', key: 'C', body: '{start_of_verse: VERSO 1}\n[G]Hola [C]mundo\n{end_of_verse}');
    store.update((s) => AppState(groups: s.groups, songs: [...s.songs, cancion], setlists: s.setlists));

    await tester.pumpWidget(MaterialApp(home: SongEditorPage(store: store, song: cancion)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Contenido'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ChordPro'));
    await tester.pumpAndSettle();

    // El usuario pone un espacio dentro del corchete.
    await tester.enterText(find.byType(TextField), '{start_of_verse: VERSO 1}\n[ G]Hola [ C ]mundo\n{end_of_verse}');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar').last);
    await tester.pumpAndSettle();

    final song = store.state.songs.firstWhere((s) => s.id == 'x2');
    // Se guarda con el espacio que puso (no vuelve a como estaba).
    expect(song.body, contains('[ G]Hola [ C ]mundo'));
    // Y el editor sigue mostrando lo mismo.
    expect(find.text('Guardado'), findsOneWidget);
  });

  testWidgets('las directivas de metadatos no se duplican al guardar dos veces', (tester) async {
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = Store();
    final cancion = Song(id: 'x3', title: 'Dos veces', key: 'D', body: '{title: Dos veces}\n{key: D}\n\n{start_of_verse: VERSO 1}\n[G]Hola\n{end_of_verse}');
    store.update((s) => AppState(groups: s.groups, songs: [...s.songs, cancion], setlists: s.setlists));

    await tester.pumpWidget(MaterialApp(home: SongEditorPage(store: store, song: cancion)));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Guardar').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar').last);
    await tester.pumpAndSettle();

    final body = store.state.songs.firstWhere((s) => s.id == 'x3').body;
    expect('{title:'.allMatches(body).length, 1);
    expect('{key:'.allMatches(body).length, 1);
    expect(body, contains('[G]Hola'));
  });
}
