// Regresion con los datos REALES de "Serviremos al Señor": las cajas de cada
// carácter tal como las entrega PDFium (fixtures/serviremos_al_senor.chars.json).
// Cada acorde debe quedar sobre la sílaba donde está en el PDF; antes salían
// todos juntos al principio de la línea (`[D][G]Nos humillamos...`).
import 'dart:convert';
import 'dart:io';

import 'package:appchords/services/pdf_chordpro/char_boxes.dart';
import 'package:appchords/services/pdf_chordpro/pdf_to_chordpro_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late String out;

  setUpAll(() {
    final d = jsonDecode(
      File('test/pdf_chordpro/fixtures/serviremos_al_senor.chars.json').readAsStringSync(),
    ) as Map;
    final chars = [
      for (final c in d['chars'] as List)
        PdfCharBox(
          ch: c['c'] as String,
          left: (c['l'] as num).toDouble(),
          top: (c['t'] as num).toDouble(),
          right: (c['r'] as num).toDouble(),
          bottom: (c['b'] as num).toDouble(),
          page: c['p'] as int,
        ),
    ];
    final width = ((d['pages'] as List).first['width'] as num).toDouble();
    final all = const PdfToChordProService().convertAllFromChars(
      chars,
      pageWidth: width,
      fallbackTitle: 'serviremos',
    );
    out = all.map((c) => c.chordPro).join('\n');
  });

  test('titulo y secciones', () {
    expect(out, contains('{title: SERVIREMOS AL SEÑOR}'));
    expect(out, contains('{start_of_verse: VERSO 1}'));
    expect(out, contains('{start_of_chorus: CORO}'));
    expect(out, contains('{start_of_verse: VERSO 2}'));
  });

  test('los acordes ya no se juntan al principio de la linea', () {
    expect(out.contains('[D][G]Nos'), isFalse);
    expect(out.contains('[Bm][A][G]Sacrificio'), isFalse);
  });

  test('cada acorde queda sobre su silaba real del PDF', () {
    expect(out, contains('Nos humil[D]lamos delante de nu[G]estro Dios'));
    expect(out, contains('Sacri[Bm]ficio agrad[A]able queremos s[G]er'));
    expect(out, contains('Hoy renun[D]ciamos a nuestra [G]voluntad'));
    expect(out, contains('Fuimos resca[D]tados del pecado'));
    expect(out, contains('Aunque venga pr[G]ueba o aflicción'));
  });

  test('la letra queda intacta (sin espacios dentro de las palabras)', () {
    final lyrics = out.replaceAll(RegExp(r'\[[^\]]+\]'), '');
    expect(lyrics, contains('Nos humillamos delante de nuestro Dios'));
    expect(lyrics, contains('Sacrificio agradable queremos ser'));
    expect(lyrics, contains('Serviremos al Señor, serviremos al Señor'));
    expect(lyrics.contains('h u m'), isFalse);
  });

  test('las filas solo de acordes se conservan', () {
    expect(out, contains('[D] | [G]'));
    expect(out, contains('[A] | [Bm] | [G] | [G]'));
  });
}
