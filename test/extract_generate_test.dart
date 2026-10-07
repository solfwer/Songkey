// Genera lib/cancionero_data.dart a partir de los PDF extraídos del zip.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

String _norm(String s) => s
    .toUpperCase()
    .replaceAll('Á', 'A')
    .replaceAll('É', 'E')
    .replaceAll('Í', 'I')
    .replaceAll('Ó', 'O')
    .replaceAll('Ú', 'U')
    .replaceAll('Ü', 'U')
    .replaceAll('Ñ', 'N')
    .trim();

final _headers = <String, String>{
  'INTRODUCCION': 'Intro',
  'INTRO': 'Intro',
  'VERSO': 'Verso',
  'ESTROFA': 'Verso',
  'CORO': 'Coro',
  'ESTRIBILLO': 'Coro',
  'PRECORO': 'Pre-coro',
  'PRE-CORO': 'Pre-coro',
  'PUENTE': 'Puente',
  'FINAL': 'Final',
  'TAG': 'Final',
  'OUTRO': 'Outro',
  'INTERLUDIO': 'Interludio',
  'INSTRUMENTAL': 'Instrumental',
};

String? _headerLine(String raw) {
  var t = raw.trim();
  if (t.isEmpty) return null;
  t = t.replaceAll(RegExp(r'[:\[\]()]'), '').trim();
  final u = _norm(t);
  for (final e in _headers.entries) {
    if (u.startsWith(e.key)) {
      final rest = u.substring(e.key.length).trim();
      final num = RegExp(r'^\d+').firstMatch(rest)?.group(0);
      if (e.key == 'VERSO' || e.key == 'ESTROFA') return 'Verso ${num ?? '1'}';
      if (e.key == 'CORO' || e.key == 'ESTRIBILLO') return num != null ? 'Coro $num' : 'Coro';
      return e.value;
    }
  }
  return null;
}

final _chordTok = RegExp(r'^\(?[A-G][#b]?(?:maj|min|m|M|dim|aug|sus|add|°|\+)?\d*(?:(?:sus|add|maj|b|#)\d+)*(?:\/[A-G][#b]?)?\)?$');

bool _isChordTok(String s) => _chordTok.hasMatch(s);

bool _isChordLine(String line) {
  final toks = line.trim().split(RegExp(r'\s+')).where((t) => t != '|').toList();
  return toks.isNotEmpty && toks.every(_isChordTok);
}

String _titleCase(String s) {
  return s.toLowerCase().split(' ').map((w) {
    if (w.isEmpty) return w;
    return w[0].toUpperCase() + w.substring(1);
  }).join(' ');
}

void main() {
  test('genera cancionero_data.dart', () {
    final dir = Platform.environment['CANCIONERO_DIR']!;
    final files = Directory(dir)
        .listSync()
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.pdf'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    final out = StringBuffer();
    out.writeln("// GENERADO AUTOMÁTICAMENTE — no editar a mano.");
    out.writeln("import 'models.dart';");
    out.writeln();
    out.writeln('List<Song> cancioneroSongs() => [');

    for (final f in files) {
      final name = f.uri.pathSegments.last;
      final num = RegExp(r'^(\d+)').firstMatch(name)?.group(1) ?? '000';
      var title = name.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '').replaceAll(RegExp(r'^\d+\s*-\s*'), '').trim();
      title = _titleCase(title);

      final doc = PdfDocument(inputBytes: Uint8List.fromList(f.readAsBytesSync()));
      var text = PdfTextExtractor(doc).extractText();
      doc.dispose();

      var lines = text.replaceAll('\r', '').split('\n');

      // Unir acordes partidos: línea que es solo '-' se pega a la anterior y a la siguiente
      final joined = <String>[];
      for (var i = 0; i < lines.length; i++) {
        var l = lines[i];
        if (l.trim() == '-') {
          if (joined.isNotEmpty) joined[joined.length - 1] = '${joined.last}-';
          continue;
        }
        if (joined.isNotEmpty && joined.last.trim().endsWith('-')) {
          joined[joined.length - 1] = joined.last + l.trim();
          continue;
        }
        // Unir acorde partido entre líneas: "C" + "#m ..." -> "C#m ..."
        if (joined.isNotEmpty && (l.trimLeft().startsWith('#') || (l.trimLeft().startsWith('b') && RegExp(r'[A-Gm]$').hasMatch(joined.last.trimRight())))) {
          joined[joined.length - 1] = joined.last.trimRight() + l.trimLeft();
          continue;
        }
        joined.add(l);
      }
      lines = joined;

      // Limpiar líneas de acordes con '|'
      lines = lines.map((l) {
        if (l.contains('|') && _isChordLine(l)) {
          return l.split('|').map((p) => p.trim()).where((p) => p.isNotEmpty).join('  ');
        }
        return l;
      }).toList();

      // Encabezado: primer encabezado; descarta líneas de basura y vacías
      var start = lines.indexWhere((l) => _headerLine(l) != null);
      if (start < 0) start = 0;
      final garbage = {':', '//', '"', ':"', '-', '|', '–', '—'};
      final bodyLines = <String>[];
      for (var i = start; i < lines.length; i++) {
        final trimmed = lines[i].trim();
        if (trimmed.isEmpty) continue;
        if (garbage.contains(trimmed)) continue;
        final h = _headerLine(lines[i]);
        bodyLines.add(h ?? trimmed);
      }
      final body = bodyLines.join('\n');

      // Tono: primer acorde de la primera línea de acordes
      String key = 'C';
      for (final l in body.split('\n')) {
        if (_isChordLine(l)) {
          final tok = l.trim().split(RegExp(r'\s+')).firstWhere(_isChordTok);
          final m = RegExp(r'^\(?([A-G][#b]?)(m|min)?').firstMatch(tok);
          if (m != null) {
            key = m.group(1)! + (m.group(2) != null ? 'm' : '');
            break;
          }
        }
      }

      out.writeln("  Song(id: 'c$num', title: ${jsonEncode(title)}, key: ${jsonEncode(key)}, body: ${jsonEncode(body)}),");
    }

    out.writeln('];');
    File('lib/cancionero_data.dart').writeAsStringSync(out.toString());
    print('Canciones generadas: ${files.length}');
  });
}
