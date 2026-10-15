// Verifica que el PDF de muestra se importa correctamente con el servicio real
// y produce el ChordPro esperado.
// El PDF se genera en setUpAll para no depender de archivos externos.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:appchords/services/pdf_chordpro/pdf_to_chordpro_service.dart';

// ────────────────────────────────────────────────────────────────────────
// Generador de PDF de prueba (versión mínima del script scripts/generar_pdf_ejemplo.dart)
// ────────────────────────────────────────────────────────────────────────
Uint8List _generateTestPdf() {
  // Geometría página carta (puntos PDF).
  const pageW = 612.0, pageH = 792.0, left = 72.0;
  const titleSize = 18.0, headerSize = 12.0, chordSize = 11.0, lyricSize = 12.0;

  // Anchos Helvetica regular (AFM, unidades/1000).
  const widths = <String, int>{
    ' ': 278, '!': 278, '"': 355, '#': 556, "'": 191, '(': 333, ')': 333,
    ',': 278, '-': 333, '.': 278, '/': 278, ':': 278, ';': 278, '?': 556,
    '0': 556, '1': 556, '2': 556, '3': 556, '4': 556, '5': 556, '6': 556,
    '7': 556, '8': 556, '9': 556,
    'A': 667, 'B': 667, 'C': 722, 'D': 722, 'E': 667, 'F': 611, 'G': 778,
    'H': 722, 'I': 278, 'J': 500, 'K': 667, 'L': 556, 'M': 833, 'N': 722,
    'O': 778, 'P': 667, 'Q': 778, 'R': 722, 'S': 667, 'T': 611, 'U': 722,
    'V': 667, 'W': 944, 'X': 667, 'Y': 667, 'Z': 611,
    'a': 556, 'b': 556, 'c': 500, 'd': 556, 'e': 556, 'f': 278, 'g': 556,
    'h': 556, 'i': 222, 'j': 222, 'k': 500, 'l': 222, 'm': 833, 'n': 556,
    'o': 556, 'p': 556, 'q': 556, 'r': 333, 's': 500, 't': 278, 'u': 556,
    'v': 500, 'w': 722, 'x': 500, 'y': 500, 'z': 500,
    'á': 556, 'é': 556, 'í': 222, 'ó': 556, 'ú': 556, 'ñ': 556, 'ü': 556,
    'Á': 667, 'É': 667, 'Í': 278, 'Ó': 778, 'Ú': 722, 'Ñ': 778,
  };

  double charWidth(String ch, double size) => (widths[ch] ?? 556) / 1000 * size;

  double xOfCharIndex(String text, int charIndex, double size, [double x0 = left]) {
    var x = x0;
    for (var i = 0; i < charIndex && i < text.length; i++) {
      x += charWidth(text[i], size);
    }
    return x;
  }

  // Usar record en lugar de clase para evitar conflicto con keyword 'class'
  final texts = <({String font, double size, double x, double y, String s})>[];
  _Text(String font, double size, double x, double y, String s) =>
      (font: font, size: size, x: x, y: y, s: s);

  void title(String s, double y) => texts.add(_Text('F2', titleSize, left, y, s));
  void header(String s, double y) => texts.add(_Text('F2', headerSize, left, y, s));
  void lyric(String s, double y) => texts.add(_Text('F1', lyricSize, left, y, s));

  void chordsOver(String lyricText, List<(String, int)> chords, double y) {
    for (final (chord, charIndex) in chords) {
      final x = xOfCharIndex(lyricText, charIndex, lyricSize);
      texts.add(_Text('F1', chordSize, x, y, chord));
    }
  }

  String esc(String s) => s.replaceAll(r'\', r'\\').replaceAll('(', r'\(').replaceAll(')', r'\)');

  // ─── Contenido ───
  title('A DANZAR', 720);

  header('INTRODUCCIÓN:', 680);
  texts.add(_Text('F3', lyricSize, left, 662, 'C#m | A | E | B'));

  header('VERSO 1', 630);
  const v1 = 'Señor, tú me amas para siempre';
  chordsOver(v1, [('C#m', 7), ('A', 13), ('E', 18), ('B', 23)], 610);
  lyric(v1, 588);
  const v2 = 'Tu gracia me alcanza y me levanta';
  chordsOver(v2, [('G', 3), ('C#m', 13), ('A', 27)], 568);
  lyric(v2, 546);

  header('PRECORO', 514);
  const pc = 'Levantamos las manos al cielo';
  chordsOver(pc, [('A', 0), ('Bsus4', 11)], 494);
  lyric(pc, 472);

  header('CORO', 440);
  const co = 'A danzar con toda mi fuerza';
  chordsOver(co, [('E', 0), ('B', 2), ('C#m', 9), ('A', 21)], 420);
  lyric(co, 398);

  header('PUENTE', 366);
  const pu = 'Todo es posible, todo lo podemos';
  chordsOver(pu, [('G', 0), ('D', 8), ('A', 17)], 346);
  lyric(pu, 324);

  header('FINAL', 292);
  lyric('Gracias, Señor', 272);

  // Número de página (debe filtrarse).
  texts.add(_Text('F1', 10.0, 560, 40, '1'));

  // ─── Construir PDF 1.4 ───
  final contentSb = StringBuffer();
  for (final t in texts) {
    contentSb.writeln('BT /${t.font} ${t.size} Tf ${t.x} ${t.y} Td (${esc(t.s)}) Tj ET');
  }
  final content = Uint8List.fromList(contentSb.toString().codeUnits);

  final objects = <String>[
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 $pageW $pageH] '
        '/Resources << /Font << /F1 5 0 R /F2 6 0 R /F3 7 0 R >> >> /Contents 4 0 R >>',
    '',
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>',
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold /Encoding /WinAnsiEncoding >>',
    '<< /Type /Font /Subtype /Type1 /BaseFont /Courier /Encoding /WinAnsiEncoding >>',
  ];

  final out = BytesBuilder();
  void add(String s) => out.add(s.codeUnits);

  add('%PDF-1.4\n');
  final offsets = <int>[];
  for (var i = 0; i < objects.length; i++) {
    offsets.add(out.length);
    if (i == 3) {
      add('4 0 obj\n<< /Length ${content.length} >>\nstream\n');
      out.add(content);
      add('\nendstream\nendobj\n');
    } else {
      add('${i + 1} 0 obj\n${objects[i]}\nendobj\n');
    }
  }
  final xrefOffset = out.length;
  add('xref\n0 ${objects.length + 1}\n');
  add('0000000000 65535 f \n');
  for (final off in offsets) {
    add('${off.toString().padLeft(10, '0')} 00000 n \n');
  }
  add('trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\n'
      'startxref\n$xrefOffset\n%%EOF\n');
  return out.toBytes();
}
// ────────────────────────────────────────────────────────────────────────

void main() {
  late Uint8List pdfBytes;

  setUpAll(() {
    pdfBytes = _generateTestPdf();
  });

  test('el PDF de ejemplo se convierte a ChordPro', () {
    final res = const PdfToChordProService().convert(pdfBytes);

    // ignore: avoid_print
    print('--- ChordPro result ---\n${res.chordPro}\n'
        'title=${res.title} key=${res.suggestedKey} cols=${res.columns}\n'
        'warnings=${res.warnings.map((w) => w.message).toList()}');

    expect(res.title, 'A DANZAR');
    expect(res.columns, 1);
    expect(res.chordPro, contains('{start_of_verse: VERSO 1}'));
    expect(res.chordPro, contains('{start_of_chorus: CORO}'));
    expect(res.chordPro, contains('{start_of_bridge: PUENTE}'));
    // Progresión de la introducción como progresión de barras.
    expect(res.chordPro, contains('[C#m] | [A] | [E] | [B]'));
    // Acordes colocados sobre la sílaba correcta de la letra.
    expect(res.chordPro.contains('Se[C#m]ñor') || res.chordPro.contains('[C#m]tú'),
        isTrue);
    // El número de página se filtra.
    expect(res.chordPro, contains('Gracias, Señor'));
    expect(res.chordPro.contains('\n1'), isFalse);
  });
}