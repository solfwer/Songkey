import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:appchords/models/app_state.dart';
import 'package:appchords/models/song.dart';
import 'package:appchords/screens/song/song_screen.dart';
import 'package:appchords/services/song_export.dart';
import 'package:appchords/data/store.dart';
import 'package:appchords/theme.dart';

AppState _stateWithSong([String body = 'Verso 1\n[Am]Hola [F]mundo\n[G]Otra línea con más texto para que envuelva\n\nCoro\n[C]Lalalala\n']) {
  return AppState(
    groups: const [],
    songs: [Song(id: 's1', title: 'Canción de prueba', author: 'Autor', key: 'C', body: body)],
    setlists: const [],
  );
}

void main() {
  Future<void> openDrawer(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
  }

  Finder drawerScrollable() =>
      find.descendant(of: find.byType(Drawer), matching: find.byType(Scrollable));

  Future<void> reveal(WidgetTester tester, Finder target) async {
    await tester.scrollUntilVisible(target, 80, scrollable: drawerScrollable());
    await tester.pumpAndSettle();
  }

  testWidgets('SongScreen abre el panel de opciones sin desbordar en pantalla angosta', (tester) async {
    tester.view.physicalSize = const Size(260, 560);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = Store()..state = _stateWithSong();
    await tester.pumpWidget(MaterialApp(theme: darkTheme(), home: SongScreen(store: store, songId: 's1')));
    expect(tester.takeException(), isNull);

    await openDrawer(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Opciones de pantalla'), findsOneWidget);
    expect(find.text('Acordes'), findsWidgets);
    expect(find.text('Solo letra'), findsOneWidget);

    await reveal(tester, find.text('Compartir letra'));
    expect(find.text('Compartir letra'), findsOneWidget);
    expect(find.text('Exportar PDF'), findsOneWidget);
    expect(find.text('Editar letra y acordes'), findsOneWidget);
    expect(find.text('Eliminar'), findsOneWidget);
  });

  test('songToPlainText ancla los acordes sobre su palabra', () {
    final song = Song(id: 's1', title: 'Test', key: 'C', body: 'Verso 1\n[Am]Hola [F]mundo\n[C]En tono');
    final text = songToPlainText(song);
    final lines = text.split('\n');
    // La fila de acordes debe estar alineada: 'Am' sobre 'Hola', 'F' sobre 'mundo'.
    final chordLine = lines.firstWhere((l) => l.contains('Am'));
    final lyricLine = lines[lines.indexOf(chordLine) + 1];
    expect(chordLine.indexOf('Am') >= 0, isTrue);
    expect(chordLine.indexOf('F') >= 0, isTrue);
    expect(lyricLine.contains('Hola'), isTrue);
    expect(lyricLine.contains('mundo'), isTrue);
  });

  test('songToPlainText transpone los acordes', () {
    final song = Song(id: 's1', title: 'Test', key: 'C', body: 'Verso 1\n[C]Hola [G]mundo');
    final text = songToPlainText(song, semitones: 2);
    expect(text, contains('Tono: D'));
    expect(text, contains('D'));
    expect(text, contains('[A]'.replaceAll('[', '').replaceAll(']', '')));
    expect(text.contains('C '), isFalse);
  });

  test('songToPlainText lyricsOnly omite la fila de acordes', () {
    final song = Song(id: 's1', title: 'Test', key: 'C', body: 'Verso 1\n[Am]Hola [F]mundo');
    final text = songToPlainText(song, lyricsOnly: true);
    expect(text, isNot(contains('Am')));
    expect(text.contains('Hola') && text.contains('mundo'), isTrue);
  });
}