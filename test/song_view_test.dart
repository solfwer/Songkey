// Tests de las vistas de cancin: compacta (seccin nica con contador) y
// auto-ajuste (elige tamao/columnas, o reparte en pginas si no cabe).
import 'package:appchords/data/chord_parser.dart';
import 'package:appchords/models/song.dart';
import 'package:appchords/screens/song/widgets/compact_song_view.dart';
import 'package:appchords/screens/song/widgets/song_view.dart';
import 'package:appchords/screens/song/widgets/view_options_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

List<Section> _sections(int n) {
  final body = List.generate(n, (i) => 'Verso ${i + 1}\n[G]letra [C]de [D]prueba con texto algo largo para envolver\n[Am]otra linea').join('\n\n');
  return sectionsInOrder(body, null);
}

void main() {
  test('el tono se recuerda por cancin, no se comparte entre canciones', () {
    // Dentro de un setlist, cambiar el tono de una cancin no debe mover las
    // dems: cada una guarda su propia transposicin.
    final config = SongViewConfig(fontSize: 18);
    config.setShift('cancion-a', 2);
    expect(config.shiftFor('cancion-a'), 2);
    expect(config.shiftFor('cancion-b'), 0);
    config.setShift('cancion-b', -1);
    expect(config.shiftFor('cancion-a'), 2);
    expect(config.shiftFor('cancion-b'), -1);
  });

  testWidgets('vista compacta: cada seccion una sola vez con su contador', (tester) async {
    tester.view.physicalSize = const Size(400, 1500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const body = '{start_of_verse: VERSO 1}\n[G]Una linea del verso\n{end_of_verse}\n{start_of_chorus: CORO}\n[C]Aleluya al Senor\n{end_of_chorus}';
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: CompactSongView(
            song: Song(id: 's1', title: 'T', body: body, structure: const ['CORO', 'VERSO 1', 'CORO']),
            lyricsOnly: false,
            semitones: 0,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // El coro sale una sola vez, con su "x2".
    expect(find.text('CORO'), findsOneWidget);
    expect(find.text('x2'), findsOneWidget);
    expect(find.text('VERSO 1'), findsOneWidget);
  });

  testWidgets('auto-ajuste: cancin corta cabe en una sola pagina', (tester) async {
    tester.view.physicalSize = const Size(400, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 700,
          child: AutoFitSongBody(sections: _sections(2), lyricsOnly: false, semitones: 0, american: true),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(PageView), findsNothing);
  });

  testWidgets('auto-ajuste: cancin muy larga se reparte en varias pginas', (tester) async {
    tester.view.physicalSize = const Size(360, 420);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 360,
          height: 420,
          child: AutoFitSongBody(sections: _sections(30), lyricsOnly: false, semitones: 0, american: true),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(PageView), findsOneWidget);
  });
}
