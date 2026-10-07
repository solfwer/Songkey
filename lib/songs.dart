
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

final _header = RegExp(
  r'^\s*[[{(]?\s*(coro|chorus|estribillo|pre-?coro|pre-?chorus|verso|verse|estrofa|puente|bridge|intro|outro|final|tag|interludio|instrumental)\s*(\d*)\s*[\]})]?\s*:?\s*$',
  caseSensitive: false,
);

final _chord = RegExp(
  r'^\(?[A-G][#b]?(?:maj|min|m|M|dim|aug|sus|add|°|\+)?\d*(?:(?:sus|add|maj|b|#)\d+)*(?:\/[A-G][#b]?)?\)?$',
);

bool isChord(String t) => _chord.hasMatch(t);

/// Reconoce líneas que actúan como encabezado de sección ("Verso 1", "Coro", etc.)
bool isSectionHeader(String line) => _header.hasMatch(line);

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
  final w = word.toLowerCase().replaceAll('-', '');
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
    final h = _header.firstMatch(line);
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
      if (next != null && next.trim().isNotEmpty && !isChordLine(next) && !_header.hasMatch(next)) {
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






