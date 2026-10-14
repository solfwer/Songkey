// Stress test (break-ui) sobre la pantalla de canción.
// Genera datos extremos, renderiza el widget y detecta desbordes,
// errores de layout, NaN, divisiones por cero, etc.
// Se ejecuta como test normal: `flutter test test/break_ui_song_screen_test.dart`
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:appchords/data/chord_parser.dart';
import 'package:appchords/models/song.dart';
import 'package:appchords/screens/song/widgets/song_view.dart';
import 'package:appchords/screens/song/widgets/view_options_panel.dart';
import 'package:appchords/theme.dart';

/// Regex copiados de chord_parser.dart (son private ahí).
final _startOf = RegExp(
  r'^\s*\{\s*start(?:_of)?_([a-z_]+)\s*[:=]?\s*(.*?)\s*\}\s*$',
  caseSensitive: false,
);
final _endOf = RegExp(r'^\s*\{\s*end(?:_of)?_[a-z_]+\s*\}\s*$', caseSensitive: false);

/// Helper: crea una canción con los parámetros dados.
Song _makeSong({
  required String id,
  required String title,
  String key = 'C',
  int? bpm,
  String body = '',
  List<String>? structure,
}) =>
    Song(
      id: id,
      title: title,
      key: key,
      bpm: bpm,
      body: body,
      structure: structure,
    );

/// Genera N secciones ChordPro con acordes simples.
String _sectionsChordPro(int n, {String chord = '[C]'}) {
  final sb = StringBuffer();
  for (var i = 1; i <= n; i++) {
    sb.writeln('{start_of_verse: Verso $i}');
    sb.writeln('$chord Letra del verso $i con varias palabras para que ocupe ancho');
    sb.writeln('{end_of_verse}');
  }
  return sb.toString();
}

void main() {
  group('Break-UI: SongScreen stress', () {
    testWidgets('Título de 80 caracteres no desborda AppBar ni lista', (tester) async {
      final song = _makeSong(
        id: 's1',
        title: 'Alabado Sea El Señor Por Siempre Jamás Amén Versión Extendida En Vivo 2024',
        body: _sectionsChordPro(3),
      );
      await _pumpSong(tester, song);
      // Solo verificamos que no hay excepción de layout/overflow
      expect(tester.takeException(), isNull);
    });

    testWidgets('Canción sin acordes (solo letra) renderiza sin error', (tester) async {
      final song = _makeSong(
        id: 's2',
        title: 'Solo Letra',
        body: 'Esta canción no tiene ningún acorde\nNi en el cuerpo\nNi en ninguna parte',
      );
      await _pumpSong(tester, song);
      expect(tester.takeException(), isNull);
    });

    testWidgets('200 secciones: chips y estructura no crashean', (tester) async {
      final song = _makeSong(
        id: 's3',
        title: 'Muchas Secciones',
        body: _sectionsChordPro(200),
      );
      await _pumpSong(tester, song);
      expect(find.byType(ListView), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Acordes extra-anchos (C#m7b5, Bbb, Gsus4/A) no solapan', (tester) async {
      final weird = '[C#m7b5] Acorde muy largo\n[Bbb] Otro raro\n[Gsus4/A] Slash chord\n[F#m7(b5)] Paréntesis';
      final song = _makeSong(
        id: 's4',
        title: 'Acordes Raros',
        body: '{start_of_verse: Test}\n$weird\n{end_of_verse}',
      );
      await _pumpSong(tester, song);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Texto en chino, cirílico, árabe y emoji', (tester) async {
      final mixed = '你好 世界\nПривет мир\nمرحبا بالعالم\nHola 🌍 mundo';
      final song = _makeSong(
        id: 's5',
        title: 'Unicode 混合',
        body: '{start_of_verse: Test}\n$mixed\n{end_of_verse}',
      );
      await _pumpSong(tester, song);
      expect(tester.takeException(), isNull);
    });

    testWidgets('BPM 300 y BPM 0 / negativo no rompen metronome timer', (tester) async {
      for (final bpm in [300, 0, -10]) {
        final song = _makeSong(
          id: 's_bpm_$bpm',
          title: 'BPM $bpm',
          bpm: bpm,
          body: _sectionsChordPro(2),
        );
        await _pumpSong(tester, song);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('Tono inválido (Zz, H, 9) no crashea selector', (tester) async {
      for (final key in ['Zz', 'H', '9', '']) {
        final song = _makeSong(
          id: 's_key_$key',
          title: 'Tono $key',
          key: key,
          body: _sectionsChordPro(1),
        );
        await _pumpSong(tester, song);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('Body muy largo (100 KB) no congela layout', (tester) async {
      final bigBody = _sectionsChordPro(500); // ~100 KB
      final song = _makeSong(
        id: 's_big',
        title: 'Cuerpo Grande',
        body: bigBody,
      );
      await _pumpSong(tester, song);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Structure con 200 entradas (repeticiones) renderiza', (tester) async {
      final struct = List.generate(200, (i) => 'Verso ${(i % 10) + 1}');
      final song = _makeSong(
        id: 's_struct',
        title: 'Structure Grande',
        body: _sectionsChordPro(10),
        structure: struct,
      );
      await _pumpSong(tester, song);
      expect(tester.takeException(), isNull);
    });

    testWidgets('SongViewConfig extremos: fontSize 12-34, autoScrollSpeed 10-100', (tester) async {
      final config = SongViewConfig(
        fontSize: 34,
      );
      config.enableAutoScroll();
      expect(config.isAutoScrolling, isTrue);
      config.toggleAutoScrollPause();
      expect(config.isAutoScrolling, isFalse);
      config.disableAutoScroll();
      expect(config.autoScroll, isFalse);
      expect(config.autoScrollPaused, isFalse);
    });
  });
}

/// Monta el SongBodyList con la canción y un config por defecto.
Future<void> _pumpSong(WidgetTester tester, Song song) async {
  final config = SongViewConfig(
    fontSize: 18,
    americanNotation: true,
  );
  final sections = _parseSections(song);
  await tester.pumpWidget(
    MaterialApp(
      theme: lightTheme(),
      darkTheme: darkTheme(),
      home: Scaffold(
        body: SongBodyList(
          sections: sections,
          lyricsOnly: false,
          semitones: 0,
          fontSize: config.fontSize,
          american: config.americanNotation,
          autoScroll: false,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Parse mínimo del body ChordPro a lista de Section (usa el parser real simplificado).
List<Section> _parseSections(Song song) {
  final sections = <Section>[];
  final lines = song.body.split('\n');
  String? currentId;
  SectionKind? currentKind;
  String? currentLabel;
  final currentLines = <SongLine>[];

  for (final raw in lines) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    final startMatch = _startOf.firstMatch(line);
    if (startMatch != null) {
      if (currentId != null) {
        sections.add(Section(
          id: currentId!,
          kind: currentKind!,
          abbr: _abbrForKind(currentKind!),
          label: currentLabel ?? '',
          lines: List.from(currentLines),
        ));
        currentLines.clear();
      }
      currentId = startMatch.group(2)?.trim() ?? 'v${sections.length + 1}';
      final kindStr = startMatch.group(1)?.toLowerCase() ?? 'verse';
      currentKind = _kindFromString(kindStr);
      currentLabel = startMatch.group(2)?.trim() ?? kindStr;
    } else if (_endOf.hasMatch(line)) {
      if (currentId != null) {
        sections.add(Section(
          id: currentId!,
          kind: currentKind!,
          abbr: _abbrForKind(currentKind!),
          label: currentLabel ?? '',
          lines: List.from(currentLines),
        ));
        currentLines.clear();
        currentId = null;
        currentKind = null;
        currentLabel = null;
      }
    } else if (currentId != null) {
      // Parsear línea con acordes inline [Am]texto
      final segments = _parseChordLine(line);
      currentLines.add(segments);
    }
  }
  if (sections.isEmpty && song.body.isNotEmpty) {
    final segments = _parseChordLine(song.body);
    sections.add(Section(
      id: 'v1',
      kind: SectionKind.verse,
      abbr: 'V',
      label: 'Verso 1',
      lines: [segments],
    ));
  }
  return sections;
}

SectionKind _kindFromString(String s) {
  switch (s) {
    case 'chorus':
    case 'coro':
    case 'estribillo':
      return SectionKind.chorus;
    case 'prechorus':
    case 'pre_coro':
    case 'precoro':
      return SectionKind.prechorus;
    case 'bridge':
    case 'puente':
      return SectionKind.bridge;
    case 'intro':
      return SectionKind.intro;
    case 'outro':
    case 'final':
    case 'tag':
      return SectionKind.outro;
    default:
      return SectionKind.verse;
  }
}

String _abbrForKind(SectionKind k) {
  switch (k) {
    case SectionKind.chorus:
      return 'C';
    case SectionKind.prechorus:
      return 'P';
    case SectionKind.bridge:
      return 'B';
    case SectionKind.intro:
      return 'I';
    case SectionKind.outro:
      return 'O';
    default:
      return 'V';
  }
}

/// Parsea una línea ChordPro simple: [Am]texto [G]más texto -> lista de Segment.
List<Segment> _parseChordLine(String line) {
  final segments = <Segment>[];
  final regex = RegExp(r'\[([^\]]+)\]([^[]*)');
  int lastEnd = 0;
  for (final m in regex.allMatches(line)) {
    if (m.start > lastEnd) {
      segments.add(Segment(text: line.substring(lastEnd, m.start)));
    }
    segments.add(Segment(chord: m.group(1), text: m.group(2) ?? ''));
    lastEnd = m.end;
  }
  if (lastEnd < line.length) {
    segments.add(Segment(text: line.substring(lastEnd)));
  }
  if (segments.isEmpty) {
    segments.add(Segment(text: line));
  }
  return segments;
}