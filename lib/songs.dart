
class Segment {
  final String? chord;
  final String text;
  Segment({this.chord, this.text = ''});
}

typedef SongLine = List<Segment>;

enum SectionKind { verse, chorus, prechorus, bridge, intro, outro, ending, other }

class Section {
  final String id;
  final SectionKind kind;
  final String abbr;
  final String label;
  final List<SongLine> lines;
  Section({required this.id, required this.kind, required this.abbr, required this.label, required this.lines});
}

String _deaccent(String s) => s
    .toLowerCase()
    .replaceAll('á', 'a')
    .replaceAll('é', 'e')
    .replaceAll('í', 'i')
    .replaceAll('ó', 'o')
    .replaceAll('ú', 'u')
    .replaceAll('ü', 'u')
    .replaceAll('ñ', 'n');

final _header = RegExp(
  r'^\s*[[{(]?\s*(coro|chorus|estribillo|pre-?coro|pre-?chorus|verso|verse|estrofa|puente|bridge|intro|outro|final|tag|interludio|instrumental|transicion)\s*(\d*)\s*[\]})]?\s*:?\s*$',
);

final _chord = RegExp(
  r'^\(?[A-G][#b]?(?:maj|min|m|M|dim|aug|sus|add|°|\+)?\d*(?:(?:sus|add|maj|b|#)\d+)*(?:\/[A-G][#b]?)?\)?$',
);

bool isChord(String t) => _chord.hasMatch(t);

/// Reconoce líneas que actúan como encabezado de sección ("Verso 1", "Coro", etc.)
bool isSectionHeader(String line) => _header.hasMatch(_deaccent(line));

/// Desplazamiento en semitonos del tono `from` al tono `to` (ambas pueden ser menores, ej. "Bm").
int semitoneShift(String from, String to) {
  String norm(String n) => _flats[n] ?? n;
  int root(String k) {
    final m = RegExp(r'^([A-G][#b]?)').firstMatch(k.trim());
    return m == null ? -1 : _sharps.indexOf(norm(m.group(1)!));
  }
  final a = root(from);
  final b = root(to);
  if (a < 0 || b < 0) return 0;
  return b - a;
}

bool isChordLine(String line) {
  final toks = line.trim().split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
  return toks.isNotEmpty && toks.every(isChord);
}

({SectionKind kind, String abbr, String label}) headerInfo(String word, String num) {
  final w = word
      .toLowerCase()
      .replaceAll('-', '')
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ü', 'u')
      .replaceAll('ñ', 'n');
  final n = num;
  if (['coro', 'chorus', 'estribillo'].contains(w)) {
    return (kind: SectionKind.chorus, abbr: 'C$n', label: 'Coro $n');
  }
  if (w == 'precoro' || w == 'prechorus') {
    return (kind: SectionKind.prechorus, abbr: 'PC$n', label: 'Pre-coro $n');
  }
  if (['verso', 'verse', 'estrofa'].contains(w)) {
    return (kind: SectionKind.verse, abbr: 'V${n.isEmpty ? "1" : n}', label: 'Verso ${n.isEmpty ? "1" : n}');
  }
  if (['puente', 'bridge'].contains(w)) {
    return (kind: SectionKind.bridge, abbr: 'P$n', label: 'Puente $n');
  }
  if (w == 'intro') return (kind: SectionKind.intro, abbr: 'I', label: 'Intro');
  if (w == 'outro') return (kind: SectionKind.outro, abbr: 'O', label: 'Outro');
  if (w == 'final' || w == 'tag') return (kind: SectionKind.ending, abbr: 'F', label: 'Final');
  if (w == 'transicion') return (kind: SectionKind.other, abbr: 'T', label: 'Transición ${n.isEmpty ? "" : n}'.trim());
  if (w == 'instrumental') return (kind: SectionKind.other, abbr: 'Inst', label: 'Instrumental');
  if (w == 'interludio') return (kind: SectionKind.other, abbr: 'Int', label: 'Interludio');
  return (kind: SectionKind.other, abbr: w.substring(0, w.length < 2 ? w.length : 2).toUpperCase(), label: word);
}

SongLine mergeChordLine(String chords, String lyric) {
  final positions = <({int pos, String chord})>[];
  final re = RegExp(r'\S+');
  for (final m in re.allMatches(chords)) {
    positions.add((pos: m.start, chord: m.group(0)!));
  }
  final padded = lyric.padRight((positions.isNotEmpty ? positions.last.pos : 0) + 1, ' ');
  final segs = <Segment>[];
  if (positions.isNotEmpty && positions.first.pos > 0) {
    segs.add(Segment(text: padded.substring(0, positions.first.pos)));
  }
  for (var i = 0; i < positions.length; i++) {
    final p = positions[i];
    final end = i + 1 < positions.length ? positions[i + 1].pos : padded.length;
    segs.add(Segment(chord: p.chord, text: padded.substring(p.pos, end < p.pos ? p.pos : end)));
  }
  return segs;
}

SongLine parseInline(String line) {
  if (!line.contains('[')) return [Segment(text: line)];
  final matches = RegExp(r'\[([^\]]+)\]').allMatches(line).toList();
  final segs = <Segment>[];
  // text before first '['
  final firstIdx = line.indexOf('[');
  if (firstIdx > 0) segs.add(Segment(text: line.substring(0, firstIdx)));
  for (var i = 0; i < matches.length; i++) {
    final chord = matches[i].group(1)!;
    final start = matches[i].end;
    final end = i + 1 < matches.length ? matches[i + 1].start : line.length;
    segs.add(Segment(chord: chord, text: line.substring(start, end)));
  }
  return segs;
}

List<Section> parseSong(String raw) {
  final lines = raw.replaceAll('\r', '').split('\n');
  final sections = <Section>[];
  Section? cur;
  Section ensure() {
    if (cur == null) {
      cur = Section(id: 's0', kind: SectionKind.other, abbr: '•', label: 'Inicio', lines: []);
      sections.add(cur!);
    }
    return cur!;
  }

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final h = _header.firstMatch(_deaccent(line));
    if (h != null) {
      final info = headerInfo(h.group(1) ?? '', h.group(2) ?? '');
      cur = Section(
        id: 's${sections.length + 1}',
        kind: info.kind,
        abbr: info.abbr,
        label: info.label.trim(),
        lines: [],
      );
      sections.add(cur!);
      continue;
    }
    if (line.trim().isEmpty) {
      if (cur != null && cur!.lines.isNotEmpty) cur!.lines.add([]);
      continue;
    }
    final sec = ensure();
    if (isChordLine(line)) {
      final next = i + 1 < lines.length ? lines[i + 1] : null;
      if (next != null && next.trim().isNotEmpty && !isChordLine(next) && !_header.hasMatch(_deaccent(next))) {
        sec.lines.add(mergeChordLine(line, next));
        i++;
      } else {
        final toks = line.trim().split(RegExp(r'\s+'));
        sec.lines.add(toks.map((c) => Segment(chord: c, text: '  ')).toList());
      }
      continue;
    }
    sec.lines.add(parseInline(line));
  }
  for (final s in sections) {
    while (s.lines.isNotEmpty && s.lines.last.isEmpty) {
      s.lines.removeLast();
    }
  }
  return sections.where((s) => s.lines.isNotEmpty || s.kind != SectionKind.other).toList();
}

const _sharps = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
const _flats = {'Db': 'C#', 'Eb': 'D#', 'Gb': 'F#', 'Ab': 'G#', 'Bb': 'A#', 'Cb': 'B', 'Fb': 'E'};

String _shiftNote(String n, int st) {
  final idx = _sharps.indexOf(_flats[n] ?? n);
  if (idx < 0) return n;
  return _sharps[(idx + st + 120) % 12];
}

String transposeChord(String chord, int st) {
  if (st == 0) return chord;
  return chord.replaceAllMapped(RegExp(r'([A-G][#b]?)'), (m) => _shiftNote(m.group(1)!, st));
}

// ============================================================
// NUEVO: Modelo de acordes posicionados (para editor visual)
// ============================================================

/// Un acorde anclado a una posición absoluta en el texto plano de la canción.
/// `lineIndex` = índice de línea en el array de líneas de la canción (sin encabezados).
/// `charIndex` = índice de carácter en esa línea (0 = antes del primer carácter).
/// `chord` = símbolo del acorde, ej. "Am", "F#m7", "G/B".
class PositionedChord {
  final int lineIndex;
  final int charIndex;
  final String chord;
  PositionedChord({required this.lineIndex, required this.charIndex, required this.chord});

  PositionedChord copyWith({int? lineIndex, int? charIndex, String? chord}) =>
      PositionedChord(lineIndex: lineIndex ?? this.lineIndex, charIndex: charIndex ?? this.charIndex, chord: chord ?? this.chord);

  Map<String, dynamic> toJson() => {'line': lineIndex, 'char': charIndex, 'chord': chord};
  factory PositionedChord.fromJson(Map<String, dynamic> j) => PositionedChord(lineIndex: j['line'] as int, charIndex: j['char'] as int, chord: j['chord'] as String);

  @override
  bool operator ==(Object other) => other is PositionedChord && other.lineIndex == lineIndex && other.charIndex == charIndex && other.chord == chord;
  @override
  int get hashCode => Object.hash(lineIndex, charIndex, chord);
  @override
  String toString() => 'PositionedChord(line:$lineIndex, char:$charIndex, $chord)';
}

/// Convierte el cuerpo ChordPro (con `[Ac]letra`) a:
/// - `lyricLines`: solo la letra, una String por línea (sin acordes).
/// - `chords`: lista de PositionedChord con posiciones absolutas.
({List<String> lyricLines, List<PositionedChord> chords}) chordProToPositioned(String body) {
  final rawLines = body.replaceAll('\r', '').split('\n');
  final lyricLines = <String>[];
  final chords = <PositionedChord>[];
  int lyricLineIdx = -1;

  for (final raw in rawLines) {
    final h = _header.firstMatch(_deaccent(raw));
    if (h != null) {
      // Encabezado de sección -> lo guardamos como línea especial con prefijo
      lyricLines.add(raw.trim());
      lyricLineIdx++;
      continue;
    }
    if (raw.trim().isEmpty) {
      lyricLines.add('');
      lyricLineIdx++;
      continue;
    }
    // Línea de acordes sola (formato antiguo: línea de acordes sobre línea de letra)
    // La detectamos porque TODOS los tokens son acordes (sin '[')
    if (isChordLine(raw) && !raw.contains('[')) {
      // Esta línea se funde con la siguiente en parseSong, aquí la ignoramos porque
      // la información de acordes ya está en la línea de letra siguiente (parseInline).
      // Pero por si acaso, la saltamos.
      continue;
    }
    // Línea normal (puede tener acordes inline [Am]letra)
    lyricLineIdx++;
    final inline = parseInline(raw);
    final buffer = StringBuffer();
    int charPos = 0;
    for (final seg in inline) {
      if (seg.chord != null) {
        chords.add(PositionedChord(lineIndex: lyricLineIdx, charIndex: charPos, chord: seg.chord!));
      }
      buffer.write(seg.text);
      charPos += seg.text.length;
    }
    lyricLines.add(buffer.toString());
  }
  return (lyricLines: lyricLines, chords: chords);
}

/// Reconstruye cuerpo ChordPro a partir de líneas de letra + acordes posicionados.
String positionedToChordPro(List<String> lyricLines, List<PositionedChord> chords) {
  final chordsByLine = <int, List<PositionedChord>>{};
  for (final c in chords) {
    chordsByLine.putIfAbsent(c.lineIndex, () => []).add(c);
  }
  for (final list in chordsByLine.values) {
    list.sort((a, b) => a.charIndex.compareTo(b.charIndex));
  }
  final out = <String>[];
  for (var i = 0; i < lyricLines.length; i++) {
    final line = lyricLines[i];
    final chs = chordsByLine[i] ?? [];
    if (chs.isEmpty) {
      out.add(line);
      continue;
    }
    // Reinsertar acordes en orden inverso para no desplazar índices
    var modified = line;
    for (var j = chs.length - 1; j >= 0; j--) {
      final c = chs[j];
      final idx = c.charIndex.clamp(0, modified.length);
      modified = '${modified.substring(0, idx)}[${c.chord}]${modified.substring(idx)}';
    }
    out.add(modified);
  }
  return out.join('\n');
}

/// Transpone todos los acordes posicionados.
List<PositionedChord> transposePositioned(List<PositionedChord> chords, int semitones) {
  if (semitones == 0) return chords;
  return chords.map((c) => c.copyWith(chord: transposeChord(c.chord, semitones))).toList();
}

/// Acordes diatónicos para una tonalidad dada.
/// Devuelve lista de (grado, símbolo, nombre) para mayor/menor.
List<({String degree, String symbol, String name})> diatonicChords(String key) {
  final isMinor = key.endsWith('m') || key.endsWith('min');
  final root = isMinor ? key.substring(0, key.length - (key.endsWith('min') ? 3 : 1)) : key;
  final rootIdx = _sharps.indexOf(_flats[root] ?? root);
  if (rootIdx < 0) return [];

  // Intervalos desde la tónica para cada grado (en semitonos)
  final majorIntervals = [0, 2, 4, 5, 7, 9, 11]; // I, ii, iii, IV, V, vi, vii°
  final minorIntervals = [0, 2, 3, 5, 7, 8, 10]; // i, ii°, III, iv, v, VI, VII
  final majorQualities = ['', 'm', 'm', '', '', 'm', 'dim'];
  final minorQualities = ['m', 'dim', '', 'm', 'm', '', ''];
  final degrees = ['I', 'ii', 'iii', 'IV', 'V', 'vi', 'vii°'];
  final degreesMinor = ['i', 'ii°', 'III', 'iv', 'v', 'VI', 'VII'];

  final intervals = isMinor ? minorIntervals : majorIntervals;
  final qualities = isMinor ? minorQualities : majorQualities;
  final degLabels = isMinor ? degreesMinor : degrees;

  return List.generate(7, (i) {
    final noteIdx = (rootIdx + intervals[i]) % 12;
    final note = _sharps[noteIdx];
    final qual = qualities[i];
    return (degree: degLabels[i], symbol: '$note$qual', name: '$note$qual');
  });
}

/// Extensiones comunes para añadir al panel (V7, sus4, add9, etc.)
List<String> commonExtensions(String baseChord) {
  final rootMatch = RegExp(r'^([A-G][#b]?)').firstMatch(baseChord);
  if (rootMatch == null) return [];
  final root = rootMatch.group(1)!;
  final isMinor = baseChord.contains('m') && !baseChord.contains('M');
  final ext = <String>[];
  // Séptimas
  ext.add(isMinor ? '${root}m7' : '${root}7');
  ext.add(isMinor ? '${root}m6' : '${root}6');
  ext.add('${root}sus4');
  ext.add('${root}sus2');
  ext.add('${root}add9');
  if (!isMinor) ext.add('${root}maj7');
  return ext;
}






