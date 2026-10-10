// Tests del editor visual y de la barra rpida de acordes.
import 'package:appchords/data/chord_parser.dart';
import 'package:appchords/screens/song/song_editor_page.dart';
import 'package:appchords/screens/song/widgets/chord_quick_bar.dart';
import 'package:appchords/screens/song/widgets/visual_chord_editor.dart';
import 'package:appchords/data/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('round-trip ChordPro <-> posiciones', () {
    test('convierte y reconstruye acordes inline', () {
      const body = 'Verso 1\n[Am]Hola [F]mundo\n[C]Otra [G]lnea';
      final parsed = chordProToPositioned(body);

      expect(parsed.lyricLines[0], 'Verso 1');
      final l1 = parsed.lyricLines[1];
      final l2 = parsed.lyricLines[2];
      expect(l1.contains('Hola') && l1.contains('mundo'), isTrue);
      expect(l2.contains('Otra') && l2.contains('lnea'), isTrue);

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

  testWidgets('VisualChordEditor renderiza la barra rpida de acordes', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: VisualChordEditor(
          initialBody: 'Verso 1\nHola mundo',
          songKey: 'C',
          onChanged: (_) {},
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(VisualChordEditor), findsOneWidget);
    // La barra est puesta y ensea cmo se usa.
    // La barra siempre dice en que linea se va a insertar (por defecto, la
    // primera con letra).
    expect(find.textContaining('Insertar en la linea'), findsWidgets);
    expect(find.text('[]'), findsOneWidget);
    expect(find.text('A mano'), findsOneWidget);
  });

  testWidgets('tocar una linea y luego un acorde lo inserta sin crashear', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: VisualChordEditor(
          initialBody: 'Verso 1\nHola mundo',
          songKey: 'C',
          onChanged: (_) {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Hola mundo'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // La barra pasa a decir en qu linea se inserta.
    expect(find.textContaining('Insertar en la linea'), findsOneWidget);

    // Se toca un acorde de la tonalidad y se coloca.
    await tester.tap(find.text('C'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // El chip del acorde aparece en la linea.
    expect(find.textContaining('Hola'), findsOneWidget);
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

  testWidgets('ChordQuickBar ensea los tres grupos de acordes', (tester) async {
    // Pantalla ancha para que quepan todos los grupos en la fila.
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ChordQuickBar(songKey: 'C', onPick: (_) {}, onManual: () {}),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('TONALIDAD'), findsOneWidget);
    expect(find.text('INVERSIONES'), findsOneWidget);
    expect(find.text('VARIANTES'), findsOneWidget);
    // Los acordes de la tonalidad estn todos.
    for (final c in ['C', 'Dm', 'Em', 'F', 'G', 'Am', 'Bdim']) {
      expect(find.text(c), findsOneWidget, reason: 'falta $c en la barra');
    }
    // Y las inversiones.
    for (final c in ['C/E', 'C/G', 'G/B']) {
      expect(find.text(c), findsOneWidget, reason: 'falta $c en la barra');
    }
  });
}
