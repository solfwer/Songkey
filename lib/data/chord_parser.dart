// Parser y utilidades de ChordPro: modelo de líneas/secciones, detección de
// acordes y de encabezados, transposición y soporte para el editor visual.

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
  r'^\s*[[{(]?\s*(coro|chorus|estribillo|pre-?coro|pre-?chorus|verso|verse|estrofa|puente|bridge|intro|outro|final|tag|interludio|instrumental|transicion|introduccion|presentacion)\s*(\d*)\s*[\]})]?\s*:?\s*$',
);

/// Directiva que abre sección: `{start_of_verse: VERSO 1}`. El texto tras los
/// dos puntos es la etiqueta tal cual del cancionero ("CORO", "PRE-CORO"...).
final _startOf = RegExp(
  r'^\s*\{\s*start(?:_of)?_([a-z_]+)\s*[:=]?\s*(.*?)\s*\}\s*$',
  caseSensitive: false,
);

/// `{end_of_verse}` y compañía: cierran sección, no aportan texto.
final _endOf = RegExp(r'^\s*\{\s*end(?:_of)?_[a-z_]+\s*\}\s*$', caseSensitive: false);

/// Comentario ChordPro: `{comment: ...}`, `{c: ...}`, `{gc: ...}`.
final _comment = RegExp(
  r'^\s*\{\s*(?:comment|c|comment_italic|gc|guitar_comment)\s*[:=]\s*(.*?)\s*\}\s*$',
  caseSensitive: false,
);

/// Directivas de metadatos (título, tono, tempo...) que no se dibujan.
final _metaDirective = RegExp(
  r'^\s*\{\s*(title|t|subtitle|st|key|k|artist|author|composer|album|tempo|bpm|capo|time|duration|footer|copyright|arranger|lyricist|meter|highlight|columns|new_page|np|songbook|transpose)\s*[:=].*\}\s*$',
  caseSensitive: false,
);

final _chord = RegExp(
  r'^\(?[A-G][#b]?(?:maj|min|m|M|dim|aug|sus|add|°|\+)?\d*(?:(?:sus|add|maj|b|#)\d+)*(?:\/[A-G][#b]?)?\)?$',
);

bool isChord(String t) => _chord.hasMatch(t);

/// Reconoce líneas que actúan como encabezado de sección ("Verso 1", "Coro", etc.)
/// y también las directivas ChordPro que abren sección (`{start_of_verse: VERSO 1}`).
bool isSectionHeader(String line) {
  if (_startOf.hasMatch(line.trim()) || _endOf.hasMatch(line.trim())) return true;
  // Metadatos y comentarios: tampoco se editan como letra.
  if (RegExp(r'^\\s*\\{\\s*[a-z_]+\\s*[:=]', caseSensitive: false).hasMatch(line)) return true;
  return _header.hasMatch(_deaccent(line));
}

/// true si la línea es una directiva ChordPro de apertura de sección.
bool isChordProSectionStart(String line) => _startOf.hasMatch(line.trim());

/// true si la línea es una directiva ChordPro que no se dibuja (metadatos,
/// cierres de sección, `{new_page}`...).
bool isChordProDirective(String line) {
  final l = line.trim();
  return _startOf.hasMatch(l) || _endOf.hasMatch(l) || _metaDirective.hasMatch(l) ||
      _comment.hasMatch(l) || RegExp(r'^\s*\{[a-z_]+\s*[:=]?.*\}\s*$', caseSensitive: false).hasMatch(l);
}

SectionKind _kindFromWord(String w) {
  final k = w.toLowerCase().replaceAll('-', '').replaceAll('_', '').replaceAll(' ', '');
  if (k.startsWith('prechorus')) return SectionKind.prechorus;
  if (k.contains('chorus') || k.contains('estribillo')) return SectionKind.chorus;
  if (k.contains('verse') || k.contains('estrofa')) return SectionKind.verse;
  if (k.contains('bridge') || k.contains('puente')) return SectionKind.bridge;
  if (k.contains('intro') || k.contains('presentacion')) return SectionKind.intro;
  if (k.contains('outro')) return SectionKind.outro;
  if (k.contains('final') || k.contains('ending') || k.contains('tag')) return SectionKind.ending;
  return SectionKind.other;
}

/// Abreviatura corta a partir de una etiqueta libre ("PRE-CORO" -> "PC",
/// "VERSO 2" -> "V2", "PUENTE" -> "PU").
String _abbrFrom(String label) {
  final num = RegExp(r'(\d+)\s*$').firstMatch(label)?.group(1) ?? '';
  final letters = label.replaceAll(RegExp(r'[^A-Za-zÁÉÍÓÚáéíóúÑñ]'), '');
  if (letters.isEmpty) return label.isEmpty ? '•' : label.substring(0, label.length < 3 ? label.length : 3);
  final base = letters.length <= 2 ? letters.toUpperCase() : letters.substring(0, 2).toUpperCase();
  return '$base$num';
}

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
  if (w == 'intro' || w == 'introduccion' || w == 'presentacion') return (kind: SectionKind.intro, abbr: 'I', label: 'Intro');
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
    var t = line.substring(start, end);
    segs.add(Segment(chord: chord, text: t));
  }
  return segs;
}

List<Section> parseSong(String raw) {
  final lines = raw.replaceAll('\r', '').split('\n');
  final sections = <Section>[];
  Section? cur;
  // Comentarios que aparecen antes de la primera sección: se quedan
  // "pendientes" y se pegan a la siguiente sección que se abra (así
  // "{comment: INTRODUCCIÓN: ...}" no genera una sección "Inicio" vacía).
  final pending = <SongLine>[];
  Section ensure() {
    if (cur == null) {
      cur = Section(id: 's0', kind: SectionKind.other, abbr: '•', label: 'Inicio', lines: []);
      sections.add(cur!);
    }
    return cur!;
  }

  /// Abre una sección nueva arrastrando los comentarios pendientes.
  Section open(SectionKind kind, String abbr, String label) {
    if (cur != null && cur!.lines.isNotEmpty) cur!.lines.add([]);
    cur = Section(id: 's${sections.length + 1}', kind: kind, abbr: abbr, label: label, lines: List.of(pending));
    pending.clear();
    sections.add(cur!);
    return cur!;
  }

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final h = _header.firstMatch(_deaccent(line));
    if (h != null) {
      final info = headerInfo(h.group(1) ?? '', h.group(2) ?? '');
      open(info.kind, info.abbr, info.label.trim());
      continue;
    }
    if (line.trim().isEmpty) {
      if (cur != null && cur!.lines.isNotEmpty) cur!.lines.add([]);
      continue;
    }
    final trimmed = line.trim();
    // Directivas ChordPro (el cancionero se guarda tal cual, en modo literal).
    if (_startOf.hasMatch(trimmed)) {
      final m = _startOf.firstMatch(trimmed)!;
      final label = (m.group(2) ?? '').trim();
      late SectionKind kind;
      late String abbr;
      if (label.isEmpty) {
        final info = headerInfo(m.group(1)!.replaceAll('_', ' '), '');
        kind = info.kind;
        abbr = info.abbr;
      } else {
        final hh = _header.firstMatch(_deaccent(label));
        if (hh != null) {
          final info = headerInfo(hh.group(1)!, hh.group(2) ?? '');
          kind = info.kind;
          abbr = info.abbr;
        } else {
          kind = _kindFromWord(m.group(1)!);
          abbr = _abbrFrom(label);
        }
      }
      open(kind, abbr, label);
      continue;
    }
    // Cierres y metadatos: no se dibujan.
    if (_endOf.hasMatch(trimmed) || _metaDirective.hasMatch(trimmed)) continue;
    final c = _comment.firstMatch(trimmed);
    if (c != null) {
      final text = (c.group(1) ?? '').trim();
      if (text.isNotEmpty) {
        final parsed = parseInline(text);
        if (cur != null) {
          cur!.lines.add(parsed);
        } else {
          pending.add(parsed);
        }
      }
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

/// Secciones en orden de interpretación ("mapa de toque"). Si [structure]
/// (encabezados, admite repeticiones) está definido, se reordenan/repten las
/// secciones canónicas del cuerpo; si no, se devuelve el orden del texto tal
/// cual. Un encabezado de la estructura que ya no exista en el texto se ignora.
List<Section> sectionsInOrder(String body, List<String>? structure) {
  final canon = parseSong(body);
  if (structure == null || structure.isEmpty) return canon;
  // ndice por nombre normalizado ("VERSO 1" y "Verso 1" son la misma seccin).
  String keyOf(String s) => _deaccent(s.trim()).replaceAll(RegExp(r'\s+'), ' ');
  final byKey = <String, Section>{};
  for (final s in canon) {
    byKey.putIfAbsent(keyOf(s.label), () => s);
  }
  final out = <Section>[];
  for (final h in structure) {
    final key = keyOf(h);
    final sec = key.isEmpty
        // Texto inicial sin encabezado guardado: la sección "Inicio" del parser.
        ? (canon.isNotEmpty && canon.first.label.trim() == 'Inicio' ? canon.first : null)
        : byKey[key];
    if (sec != null) out.add(sec);
  }
  return out.isEmpty ? canon : out;
}

const _sharps = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
const _flats = {'Db': 'C#', 'Eb': 'D#', 'Gb': 'F#', 'Ab': 'G#', 'Bb': 'A#', 'Cb': 'B', 'Fb': 'E'};

/// Los 24 tonos (mayores y menores) para selectores de tonalidad.
const twelveKeys = [
  'C', 'Cm', 'C#', 'C#m', 'D', 'Dm', 'D#', 'D#m',
  'E', 'Em', 'F', 'Fm', 'F#', 'F#m', 'G', 'Gm',
  'G#', 'G#m', 'A', 'Am', 'A#', 'A#m', 'B', 'Bm',
];

/// Nombres en notación latina (Do, Re, Mi...) para cada nota, con sus
/// alteraciones más habituales en castellano (Sib, Mib, Do#...).
const _latinRoots = {
  'C': 'Do', 'C#': 'Do#', 'Db': 'Reb', 'D': 'Re', 'D#': 'Re#', 'Eb': 'Mib',
  'E': 'Mi', 'F': 'Fa', 'F#': 'Fa#', 'Gb': 'Solb', 'G': 'Sol', 'G#': 'Sol#',
  'Ab': 'Lab', 'A': 'La', 'A#': 'La#', 'Bb': 'Sib', 'B': 'Si', 'Cb': 'Dob', 'Fb': 'Fab',
};

/// Convierte un acorde a notación latina: "G7" -> "Sol7", "Bm" -> "Sim", "F#m" -> "Fa#m".
String chordToLatin(String chord) => chord.replaceAllMapped(
      RegExp(r'([A-G][#b]?)'),
      (m) => _latinRoots[m.group(1)!] ?? m.group(1)!,
    );

/// Notación de visualización de un acorde según preferencia (americana o latina).
String notateChord(String chord, {bool american = true}) => american ? chord : chordToLatin(chord);

String _shiftNote(String n, int st) {
  final idx = _sharps.indexOf(_flats[n] ?? n);
  if (idx < 0) return n;
  return _sharps[(idx + st + 120) % 12];
}

/// Escritura canónica con sostenidos: "Eb" -> "D#", "Ab" -> "G#"...
/// También maneja tonos menores: "Bbm" -> "A#m", "Ebm" -> "D#m".
String sharpen(String note) {
  if (note.endsWith('m')) {
    final root = sharpen(note.substring(0, note.length - 1));
    return '${root}m';
  }
  return _flats[note] ?? note;
}

String transposeChord(String chord, int st) {
  if (st == 0) return chord;
  return chord.replaceAllMapped(RegExp(r'([A-G][#b]?)'), (m) => _shiftNote(m.group(1)!, st));
}

// ============================================================
// Modelo de acordes posicionados (para el editor visual)
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
/// Nota razon de un acorde, sin calidad ("Em" -> "E", "Bdim" -> "B").
String chordRootOf(String symbol) => symbol.replaceAll(RegExp(r'(m|dim|M|sus|add|maj|aug).*'), '').trim();

/// Inversiones habituales de la tonalidad: la tonica con su tercera y su
/// quinta en el bajo, y la dominante con la septima. Para C mayor da
/// C/E, C/G y G/B, que son las que mas se usan.
List<String> slashChords(String key) {
  final d = diatonicChords(key);
  if (d.length < 7) return [];
  final tonic = d[0].symbol;
  final dominant = d[4].symbol;
  final third = chordRootOf(d[2].symbol);
  final fifth = chordRootOf(d[4].symbol);
  final seventh = chordRootOf(d[6].symbol);
  return ['$tonic/$third', '$tonic/$fifth', '$dominant/$seventh'];
}

/// Los tres grupos de la barra rapida de acordes:
///  * scale: los acordes de la tonalidad (no hay que saberselos).
///  * slash: inversiones habituales.
///  * variants: variantes del acorde marcado (o de la tonica).
({List<String> scale, List<String> slash, List<String> variants}) quickBarChords(String key, {String? selected}) {
  final d = diatonicChords(key);
  final scale = [for (final c in d) c.symbol];
  final slash = slashChords(key);
  final base = (selected == null || selected.trim().isEmpty) ? (scale.isNotEmpty ? scale.first : key) : selected.trim();
  return (scale: scale, slash: slash, variants: commonExtensions(base));
}