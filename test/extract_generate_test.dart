// Genera lib/cancionero_data.dart a partir de los PDF extraídos del zip.
// Usa el importador posicionado: alinea cada acorde con la palabra que tiene
// debajo usando las coordenadas X de la extracción.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:appchords/pdf_chord_import.dart';

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
    out.writeln('  // ignore_for_file: prefer_single_quotes, lines_longer_than_80_chars');

    var generated = 0;
    for (final f in files) {
      final name = f.uri.pathSegments.last;
      final num = RegExp(r'^(\d+)').firstMatch(name)?.group(1) ?? '000';
      String title;
      String body = '';
      try {
        final r = pdfToDraftFromBytes(
          Uint8List.fromList(f.readAsBytesSync()),
          fallbackTitle: name,
        );
        title = r.title;
        body = r.body;
      } catch (_) {
        title = name;
      }
      if (body.trim().isEmpty) {
        final base = name.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '').replaceAll(RegExp(r'^\d+\s*-\s*'), '').trim();
        title = _titleCase(base);
      }
      final key = keyFromBody(body);
      out.writeln("  Song(id: 'c$num', title: ${jsonEncode(title)}, key: ${jsonEncode(key)}, body: ${jsonEncode(body)}),");
      generated++;
    }

    out.writeln('];');
    File('lib/cancionero_data.dart').writeAsStringSync(out.toString());
    // ignore: avoid_print
    print('Canciones generadas: $generated');
  });
}