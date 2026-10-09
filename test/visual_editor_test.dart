import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:appchords/data/chord_parser.dart';
import 'package:appchords/screens/song/song_editor_page.dart';
import 'package:appchords/data/store.dart';
import 'package:appchords/screens/song/widgets/visual_chord_editor.dart';

void main() {
  group('round-trip ChordPro <-> posiciones', () {
    test('convierte y reconstruye acordes inline', () {
      const body = 'Verso 1\n[Am]Hola [F]mundo\n[C]Otra [G]línea';
      final parsed = chordProToPositioned(body);

      expect(parsed.lyricLines[0], 'Verso 1');
      final l1 = parsed.lyricLines[1];
      final l2 = parsed.lyricLines[2];
      expect(l1.contains('Hola') && l1.contains('mundo'), isTrue);
      expect(l2.contains('Otra') && l2.contains('línea'), isTrue);

      final am = parsed.chords.firstWhere((c) => c.chord == 'Am');
      expect(am.lineIndex, 1);
      expect(am.charIndex, 0);
      final f = parsed.chords.firstWhere((c) => c.chord == 'F');
      expect(f.charIndex >= 0, isTrue);

      final rebuilt = positionedToChordPro(parsed.lyricLines, parsed.chords);
      expect(rebuilt, body);
    });

    test('transpone acordes posicionados', () {
      final parsed = chordProToPositioned('[C]Hola [G]mundo');
      final up = transposePositioned(parsed.chords, 2);
      expect(up.map((c) => c.chord).toList(), ['D', 'A']);
    });
  });

  group('diatonicChords', () {
    test('Do mayor', () {
      final chords = diatonicChords('C');
      expect(chords.map((c) => c.symbol).toList(), ['C', 'Dm', 'Em', 'F', 'G', 'Am', 'Bdim']);
    });

    test('La menor', () {
      final chords = diatonicChords('Am');
      expect(chords.map((c) => c.symbol).toList(), ['Am', 'Bdim', 'C', 'Dm', 'Em', 'F', 'G']);
    });
  });

  testWidgets('VisualChordEditor renderiza y responde a llamadas', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: VisualChordEditor(
          initialBody: 'Verso 1\n[Am]Hola mundo',
          songKey: 'C',
          onChanged: (_) {},
        ),
      ),
    ));
    expect(find.text('Editor visual de acordes'), findsOneWidget);
    expect(find.byType(VisualChordEditor), findsOneWidget);
  });

  testWidgets('tocar una linea abre el selector de acordes sin crashear', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: VisualChordEditor(
          initialBody: 'Verso 1\nHola mundo',
          songKey: 'C',
          onChanged: (_) {},
        ),
      ),
    ));
    await tester.tap(find.text('Hola mundo'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Acordes de la tonalidad'), findsOneWidget);
  });

  testWidgets('SongEditorPage no desborda en pantalla angosta de telefono', (tester) async {
    tester.view.physicalSize = const Size(260, 560);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = Store();
    await tester.pumpWidget(MaterialApp(home: SongEditorPage(store: store)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
