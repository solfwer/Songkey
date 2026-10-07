// Importador de cancioneros PDF con alineación real de acordes.
//
// En lugar de extraer texto plano (que desordena los acordes), reconstruye las
// líneas visuales a partir de las coordenadas de cada palabra y ancla cada
// acorde a la palabra de la letra que está justo debajo, usando su posición X.
import 'dart:math';
import 'dart:typed_data';

import 'package:syncfusion_flutter_pdf/pdf.dart';

// ---------------------------------------------------------------------------
// Encabezados de sección
// ---------------------------------------------------------------------------

const _headerWords = <String, String>{
  'INTRODUCCION': 'Intro',
  'INTRO': 'Intro',
  'VERSO': 'Verso',
  'ESTROFA': 'Verso',
  'CORO': 'Coro',
  'ESTRIBILLO': 'Coro',
  'PRECORO': 'Pre-coro',
  'PRE-CORO': 'Pre-coro',
  'PUENTE': 'Puente',
  'BRIDGE': 'Puente',
  'FINAL': 'Final',
  'TAG': 'Final',
  'OUTRO': 'Outro',
  'INTERLUDIO': 'Interludio',
  'INSTRUMENTAL': 'Instrumental',
  'TRANSICION': 'Transición',
};

String _deaccent(String s) => s
    .toUpperCase()
    .replaceAll('Á', 'A')
    .replaceAll('É', 'E')
    .replaceAll('Í', 'I')
    .replaceAll('Ó', 'O')
    .replaceAll('Ú', 'U')
    .replaceAll('Ü', 'U')
    .replaceAll('Ñ', 'N');

final _headerRe = RegExp(
  r'^\s*[\[\(\{]?\s*(INTRODUCCION|INTRO|VERSO|ESTROFA|CORO|ESTRIBILLO|PRECORO|PRE-?CORO|PUENTE|BRIDGE|FINAL|TAG|OUTRO|INTERLUDIO|INSTRUMENTAL|TRANSICION)\s*(\d*)\s*[\]\)\}]?\s*:?\s*(.*)$',
);

({String label, String rest})? _matchHeader(String line) {
  final norm = _deaccent(line);
  final m = _headerRe.firstMatch(norm);
  if (m == null) return null;
  final base = _headerWords[m.group(1)!]!;
  final num = m.group(2) ?? '';
  final restNorm = (m.group(3) ?? '').trim();
  // Recuperar el texto original (con mayúsculas/minúsculas reales).
  final rest = restNorm.isEmpty ? '' : line.substring(line.length - restNorm.length);

  // Rechazar falsos positivos tipo "Coro de ángeles cantan": si sobra texto que
  // no es un acorde y no hay dos puntos, no es un encabezado.
  if (rest.trim().isNotEmpty && !norm.contains(':')) {
    final firstTok = rest.trim().split(RegExp(r'\s+')).firstWhere((t) => t.isNotEmpty, orElse: () => '');
    if (!_isChordTok(_cleanChord(firstTok))) return null;
  }

  final numbered = base == 'Verso' || base == 'Coro' || base == 'Pre-coro' || base == 'Transición';
  final String label;
  if (numbered) {
    label = num.isEmpty ? (base == 'Verso' ? 'Verso 1' : base) : '$base $num';
  } else {
    label = base;
  }
  return (label: label, rest: rest.trim());
}

// ---------------------------------------------------------------------------
// Detección de acordes
// ---------------------------------------------------------------------------

final _chordRe = RegExp(
  r'^\(?[A-G][#b]?(?:maj|min|m|M|dim|aug|sus|add|°|\+)?\d*(?:(?:sus|add|maj|b|#)\d+)*(?:\/[A-G][#b]?)?\)?$',
);

String _cleanChord(String raw) {
  var t = raw.trim();
  t = t.replaceAll(RegExp(r'^[\(\[\{]+'), '').replaceAll(RegExp(r'[\)\]\}]+$'), '');
  while (t.isNotEmpty && (t.endsWith(',') || t.endsWith('.') || t.endsWith(';'))) {
    t = t.substring(0, t.length - 1);
  }
  return t.trim();
}

bool _isChordTok(String raw) {
  final t = _cleanChord(raw);
  if (t.isEmpty) return false;
  return _chordRe.hasMatch(t);
}

/// Tokens de una línea, tratando `|` como separador.
List<String> _tokens(String text) {
  final out = <String>[];
  for (final part in text.split('|')) {
    for (final t in part.split(RegExp(r'\s+'))) {
      final c = _cleanChord(t);
      if (c.isNotEmpty) out.add(c);
    }
  }
  return out;
}

// ---------------------------------------------------------------------------
// Representación de líneas
// ---------------------------------------------------------------------------

class _Word {
  final String text;
  final double left;
  final double right;
  final bool space;
  final List<double> glyphLefts;
  _Word(this.text, this.left, this.right, this.space, [this.glyphLefts = const []]);
}

class _Line {
  final int page;
  final double top;
  final double left;
  final double right;
  final double fontSize;
  final String text;
  final List<({int idx, double x})> wordStarts;
  final List<_Word> words;

  _Line({
    required this.page,
    required this.top,
    required this.left,
    required this.right,
    required this.fontSize,
    required this.text,
    required this.wordStarts,
    required this.words,
  });

  bool chordOnly() {
    final toks = _tokens(text);
    return toks.isNotEmpty && toks.every(_isChordTok);
  }

  List<({double x, String chord})> chords() {
    final res = <({double x, String chord})>[];
    for (final w in words) {
      if (w.space) continue;
      for (final part in w.text.split('|')) {
        final c = _cleanChord(part);
        if (c.isNotEmpty && _isChordTok(c)) res.add((x: w.left, chord: c));
      }
    }
    return res;
  }

  /// Recorta puntuación inicial (":", "-", espacios...) y devuelve una nueva
  /// línea con los índices de palabra desplazados.
  _Line trimmedStart() {
    final m = RegExp(r'^[^A-Za-z0-9ÁÉÍÓÚÜÑáéíóúüñ]+').firstMatch(text);
    if (m == null) return this;
    final cut = m.end;
    return _Line(
      page: page,
      top: top,
      left: left,
      right: right,
      fontSize: fontSize,
      text: text.substring(cut).trimRight(),
      wordStarts: wordStarts.where((w) => w.idx >= cut).map((w) => (idx: w.idx - cut, x: w.x)).toList(),
      words: words,
    );
  }
}

class _Row {
  final List<String> headers = [];
  final List<({double x, String chord})> chords = [];
  _Line? lyric;
}

// ---------------------------------------------------------------------------
// Extracción
// ---------------------------------------------------------------------------

List<_Line> _readLines(PdfDocument doc) {
  final pageWidth = <int, double>{};
  for (var i = 0; i < doc.pages.count; i++) {
    pageWidth[i] = doc.pages[i].size.width;
  }
  final textLines = PdfTextExtractor(doc).extractTextLines();
  final result = <_Line>[];
  for (final l in textLines) {
    final raw = l.text;
    if (raw.trim().isEmpty) continue;
    if (RegExp(r'^\d{1,3}$').hasMatch(raw.trim())) continue; // número de página

    final words = <_Word>[];
    for (final w in l.wordCollection) {
      final wt = w.text.isEmpty ? w.glyphs.map((g) => g.text).join() : w.text;
      if (wt.isEmpty) continue;
      words.add(_Word(
        wt,
        w.bounds.left,
        w.bounds.right,
        wt.trim().isEmpty,
        w.glyphs.map((g) => g.bounds.left).toList(),
      ));
    }

    // Posición X de cada carácter, reconstruida sobre `l.text` (que conserva
    // los espacios aunque la colección de palabras venga fragmentada).
    final charX = List<double>.filled(raw.length, 0);
    var cursor = 0;
    for (final w in words) {
      if (w.text.isEmpty) continue;
      var idx = raw.indexOf(w.text, cursor);
      if (idx < 0) idx = cursor;
      if (w.glyphLefts.length == w.text.length) {
        for (var k = 0; k < w.text.length; k++) {
          if (idx + k < raw.length) charX[idx + k] = w.glyphLefts[k];
        }
      } else {
        final step = w.text.isEmpty ? 0.0 : (w.right - w.left) / w.text.length;
        for (var k = 0; k < w.text.length; k++) {
          if (idx + k < raw.length) charX[idx + k] = w.left + step * k;
        }
      }
      cursor = idx + w.text.length;
    }

    // Inicio de cada palabra real (delimitada por espacios) y su X.
    final starts = <({int idx, double x})>[];
    for (var i = 0; i < raw.length; i++) {
      if (raw[i].trim().isEmpty) continue;
      if (i == 0 || raw[i - 1].trim().isEmpty) {
        starts.add((idx: i, x: charX[i] > 0 ? charX[i] : l.bounds.left));
      }
    }

    final width = pageWidth[l.pageIndex] ?? 595;
    // Marca de agua / logo en el margen derecho con tipografía pequeña.
    if (l.fontSize <= 11.5 && raw.trim().length <= 8 && l.bounds.left > width * 0.8) {
      continue;
    }

    result.add(_Line(
      page: l.pageIndex,
      top: l.bounds.top,
      left: l.bounds.left,
      right: l.bounds.right,
      fontSize: l.fontSize,
      text: raw.trimRight(),
      wordStarts: starts,
      words: words,
    ));
  }
  result.sort(_compareLines);
  return result;
}

int _compareLines(_Line a, _Line b) {
  final c = a.page.compareTo(b.page);
  if (c != 0) return c;
  final t = a.top.compareTo(b.top);
  if (t != 0) return t;
  return a.left.compareTo(b.left);
}

/// Agrupa líneas que comparten la misma fila visual (mismo Y aproximado).
List<List<_Line>> _groupRows(List<_Line> lines) {
  final groups = <List<_Line>>[];
  for (final l in lines) {
    if (groups.isEmpty) {
      groups.add([l]);
      continue;
    }
    final g = groups.last;
    final ref = g.first;
    final tol = max(4.0, max(ref.fontSize, l.fontSize) * 0.55);
    if (ref.page == l.page && (l.top - ref.top).abs() <= tol) {
      g.add(l);
    } else {
      groups.add([l]);
    }
  }
  return groups;
}

// ---------------------------------------------------------------------------
// Importador principal
// ---------------------------------------------------------------------------

/// Extrae [title] y [body] ChordPro (con `[acorde]letra`) de un PDF de
/// cancionero, alineando cada acorde con la palabra que tiene debajo.
({String title, String body}) chordSheetFromPdf(
  Uint8List bytes, {
  String? fallbackTitle,
}) {
  final doc = PdfDocument(inputBytes: bytes);
  List<_Line> lines;
  try {
    lines = _readLines(doc);
  } finally {
    doc.dispose();
  }

  if (lines.isEmpty) {
    return (title: fallbackTitle ?? 'Canción', body: '');
  }

  // Título: la línea con mayor tipografía que no sea de acordes.
  String title = fallbackTitle ?? 'Canción';
  var bestFont = -1.0;
  _Line? titleLine;
  for (final line in lines) {
    final t = line.text.trim();
    if (t.length < 2) continue;
    if (line.chordOnly()) continue;
    if (line.fontSize >= bestFont) {
      bestFont = line.fontSize;
      title = t;
      titleLine = line;
    }
  }
  title = title.replaceAll(RegExp(r'\s+'), ' ').trim();

  bool isTitleLine(_Line l) =>
      titleLine != null && l.page == titleLine.page && l.top == titleLine.top && l.text.trim() == titleLine.text.trim();

  final groups = _groupRows(lines);
  final rows = <_Row>[];
  for (final g in groups) {
    final row = _Row();
    for (final line in g) {
      final h = _matchHeader(line.text);
      if (h != null) {
        row.headers.add(h.label);
        if (h.rest.isNotEmpty) {
          final toks = _tokens(h.rest);
          if (toks.isNotEmpty && toks.every(_isChordTok)) {
            final restStart = line.text.length - h.rest.length;
            final sub = line.text.substring(restStart);
            for (final tok in _tokens(sub)) {
              row.chords.add((x: line.wordStarts.isEmpty ? 0 : line.wordStarts.last.x, chord: tok));
            }
          } else if (toks.isNotEmpty && row.lyric == null) {
            final restStart = line.text.length - h.rest.length;
            row.lyric = _slice(line, restStart).trimmedStart();
          }
        }
        continue;
      }
      if (line.chordOnly()) {
        row.chords.addAll(line.chords());
        continue;
      }
      row.lyric ??= line.trimmedStart();
    }
    rows.add(row);
  }

  final out = <String>[];
  final pending = <({double x, String chord})>[];

  void flushPending() {
    if (pending.isEmpty) return;
    out.add(pending.map((c) => c.chord).join('  '));
    pending.clear();
  }

  for (final r in rows) {
    if (r.lyric != null) {
      if (isTitleLine(r.lyric!)) {
        // La línea del título no va en el cuerpo.
        continue;
      }
      out.addAll(r.headers);
      final text = _mergeChords(r.lyric!, pending);
      pending.clear();
      if (text.trim().isNotEmpty) out.add(text);
    } else {
      if (r.chords.isNotEmpty && r.headers.isNotEmpty) {
        // Acordes en la misma línea que el encabezado (ej. "INTRODUCCIÓN: E | G#m")
        out.addAll(r.headers);
        out.add(r.chords.map((c) => c.chord).join('  '));
      } else {
        if (r.chords.isNotEmpty) {
          flushPending();
          pending.addAll(r.chords);
        }
        out.addAll(r.headers);
      }
    }
  }
  flushPending();

  // Limpieza: encabezados/repeticiones consecutivas y líneas vacías.
  final clean = <String>[];
  for (final l in out) {
    final t = l.trim();
    if (t.isEmpty) continue;
    if (RegExp(r'^[\W_]+$').hasMatch(t)) continue; // solo signos
    if (clean.isNotEmpty && clean.last == t) continue;
    clean.add(t);
  }

  return (title: title, body: clean.join('\n'));
}

_Line _slice(_Line line, int start) {
  final s = start.clamp(0, line.text.length);
  return _Line(
    page: line.page,
    top: line.top,
    left: line.left,
    right: line.right,
    fontSize: line.fontSize,
    text: line.text.substring(s).trimRight(),
    wordStarts: line.wordStarts.where((w) => w.idx >= s).map((w) => (idx: w.idx - s, x: w.x)).toList(),
    words: line.words,
  );
}

String _mergeChords(_Line lyric, List<({double x, String chord})> chords) {
  if (chords.isEmpty) return lyric.text;
  final starts = lyric.wordStarts;
  final inserts = <int, List<String>>{};
  for (final c in chords) {
    int target = 0;
    if (starts.isNotEmpty) {
      var best = double.infinity;
      for (final s in starts) {
        final d = (s.x - c.x).abs();
        if (d < best) {
          best = d;
          target = s.idx;
        }
      }
    } else {
      target = lyric.text.length;
    }
    inserts.putIfAbsent(target.clamp(0, lyric.text.length), () => []).add(c.chord);
  }
  final sb = StringBuffer();
  for (var i = 0; i <= lyric.text.length; i++) {
    final list = inserts[i];
    if (list != null) {
      for (final ch in list) {
        sb.write('[$ch]');
      }
    }
    if (i < lyric.text.length) sb.write(lyric.text[i]);
  }
  return sb.toString();
}

/// Extrae [title] y [body] de los bytes de un PDF, con respaldo a texto plano
/// si la extracción posicionada no produce nada útil.
({String title, String body}) pdfToDraftFromBytes(Uint8List bytes, {String? fallbackTitle}) {
  try {
    final result = chordSheetFromPdf(bytes, fallbackTitle: fallbackTitle);
    if (result.body.trim().isNotEmpty) return result;
  } catch (_) {
    // cae al respaldo
  }
  final doc = PdfDocument(inputBytes: bytes);
  try {
    final text = PdfTextExtractor(doc).extractText(layoutText: true).replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
    final lines = text.split('\n');
    final first = lines.indexWhere((l) => l.trim().isNotEmpty);
    final title = fallbackTitle ?? (first >= 0 ? lines[first].trim() : 'Canción');
    final body = first >= 0 ? lines.skip(first + 1).join('\n').trim() : '';
    return (title: title, body: body);
  } finally {
    doc.dispose();
  }
}

/// Convierte un PDF de cancionero en un borrador (título + cuerpo ChordPro),
/// usando el nombre del archivo como título provisional.
Future<({String title, String body})> pdfToDraft(String fileName, Uint8List bytes) async {
  final base = fileName.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '').trim();
  return pdfToDraftFromBytes(bytes, fallbackTitle: base);
}

/// Detecta la tonalidad a partir del cuerpo (primer acorde de la primera línea
/// solo de acordes), ej. "C#m", "G", "Dm".
String keyFromBody(String body) {
  for (final l in body.split('\n')) {
    final toks = _tokens(l);
    if (toks.isEmpty || !toks.every(_isChordTok)) continue;
    final m = RegExp(r'^\(?([A-G][#b]?)(m|min)?').firstMatch(toks.first.trim());
    if (m != null) return m.group(1)! + (m.group(2) != null ? 'm' : '');
  }
  return 'C';
}