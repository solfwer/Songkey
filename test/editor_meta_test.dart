// Tests de los errores de sintaxis que detecta el parser y del guardado con
// metadatos como directivas.
import 'package:appchords/data/chordpro.dart';
import 'package:appchords/data/store.dart';
import 'package:appchords/screens/song/song_editor_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('el parser avisa de los errores de sintaxis con su lnea', () {
    final suelto = ChordProParser()..parse('{start_of_verse: VERSO 1}\nHola [Cmundo\n{end_of_verse}');
    expect(suelto.issues, isNotEmpty);
    expect(suelto.issues.first.line, 2);

    final raro = ChordProParser()..parse('{start_of_foobar: ALGO}\nHola\n');
    expect(raro.issues.single.message, contains('Directiva desconocida'));
    expect(raro.issues.single.line, 1);
  });

  test('una directiva desconocida no rompe el anlisis ni pierde la letra', () {
    final song = ChordProParser().parse('{start_of_foobar: ALGO}\nHola [C]mundo\n');
    expect(song.sections.single.lines.single.lyric, 'Hola mundo');
  });

  testWidgets('al guardar se escriben los metadatos como directivas', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = Store();
    await tester.pumpWidget(MaterialApp(
      home: SongEditorPage(
        store: store,
        initialTitle: 'Prueba de metadatos',
        initialBody: 'Verso 1\n[G]Hola [C]mundo\n\nCoro\n[C]Aleluya',
      ),
    ));
    await tester.pumpAndSettle();

    // Pestaa Datos: autor y BPM.
    await tester.enterText(find.byType(TextField).at(1), 'Juan Prez');
    await tester.enterText(find.byType(TextField).at(3), '72');
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Guardar').first);
    await tester.pumpAndSettle();

    final song = store.state.songs.firstWhere((s) => s.title == 'Prueba de metadatos');
    expect(song.author, 'Juan Prez');
    expect(song.bpm, 72);
    // El cuerpo queda en el formato cannico con los metadatos como directivas.
    expect(song.body, contains('{title: Prueba de metadatos}'));
    expect(song.body, contains('{artist: Juan Prez}'));
    expect(song.body, contains('{tempo: 72}'));
    expect(song.body, contains('{start_of_verse: VERSO 1}'));
    expect(song.body, contains('{start_of_chorus: CORO}'));
  });

  testWidgets('los metadatos de una cancin antigua rellenan la pestaa Datos', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = Store();
    await tester.pumpWidget(MaterialApp(
      home: SongEditorPage(
        store: store,
        song: store.state.songs.first,
      ),
    ));
    await tester.pumpAndSettle();
    // El ttulo de la cancin del seed aparece en el campo Ttulo.
    expect(find.text(store.state.songs.first.title), findsOneWidget);
  });
}
