// Tests del control de tamao de letra: el panel manda sobre la vista
// compacta (que ajusta sola) y sobre la vista normal.
import 'package:appchords/models/song.dart';
import 'package:appchords/screens/song/widgets/compact_sections.dart';
import 'package:appchords/screens/song/widgets/compact_song_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const cuerpo = '''{start_of_verse: VERSO 1}
[G]Una linea del verso
{end_of_verse}

{start_of_chorus: CORO}
[C]Aleluya al Senor
{end_of_chorus}''';

/// Tamao de fuente con el que se est pintando un texto (null si no est).
double? tamanoDe(WidgetTester tester, String texto) {
  final encontrados = tester
      .widgetList<Text>(find.byType(Text))
      .where((t) => (t.data ?? '').contains(texto))
      .toList();
  if (encontrados.isEmpty) return null;
  return encontrados.first.style?.fontSize;
}

void main() {
  testWidgets('la vista compacta no se pasa del tamao elegido', (tester) async {
    tester.view.physicalSize = const Size(900, 1500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final song = Song(id: 's', title: 'T', key: 'C', body: cuerpo, structure: const ['VERSO 1', 'CORO']);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CompactSongView(song: song, lyricsOnly: false, semitones: 0, autoFit: true, maxFontSize: 14),
      ),
    ));
    await tester.pumpAndSettle();

    final t = tamanoDe(tester, 'linea del verso');
    expect(t, isNotNull);
    expect(t!, lessThanOrEqualTo(14));
    // Las secciones siguen saliendo una sola vez, con su etiqueta.
    expect(tamanoDe(tester, 'VERSO 1'), isNotNull);
  });

  testWidgets('sin auto-ajuste usa justo el tamao elegido', (tester) async {
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final song = Song(id: 's', title: 'T', key: 'C', body: cuerpo, structure: const ['VERSO 1', 'CORO']);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: CompactSongView(song: song, lyricsOnly: false, semitones: 0, autoFit: false, maxFontSize: 20),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(tamanoDe(tester, 'linea del verso'), 20);
    expect(tamanoDe(tester, 'Aleluya'), 20);
  });

  testWidgets('un tamao mayor pinta la letra ms grande', (tester) async {
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final song = Song(id: 's', title: 'T', key: 'C', body: cuerpo, structure: const ['VERSO 1', 'CORO']);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: CompactSongView(song: song, lyricsOnly: false, semitones: 0, autoFit: false, maxFontSize: 12),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    final pequeno = tamanoDe(tester, 'linea del verso');

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: CompactSongView(song: song, lyricsOnly: false, semitones: 0, autoFit: false, maxFontSize: 26),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    final grande = tamanoDe(tester, 'linea del verso');

    expect(pequeno, 12);
    expect(grande, 26);
  });

  test('las secciones nicas se calculan igual para las dos vistas', () {
    final song = Song(id: 's', title: 'T', key: 'C', body: cuerpo, structure: const ['CORO', 'VERSO 1', 'CORO']);
    final secs = compactSections(song);
    // Mismo catalogo que usa la pestaa Estructura.
    expect(secs.map((s) => s.label).toList(), ['CORO', 'VERSO 1']);
    expect(secs.first.repeats, 2);
    expect(secs.first.muestraRepeticion, isTrue);
  });
}
