// Importa el PDF de muestra de la canción "CIELO EN LA TIERRA" y compara el
// ChordPro resultante con el esperado (formato canónico de SongKey).
//
// El PDF se genera en memoria (no depende de archivos externos) con:
//   - título en mayúsculas (sin tamaño distinto) → {title:}, nunca un verso;
//   - INTRO x2 → progresión de compases [C#m] | [A] | [E] | [B];
//   - VERSO 1 y VERSO 2 con acordes colocados sobre su sílaba;
//   - CORO x2 con acordes;
//   - número de página (filtrado).
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:appchords/services/pdf_chordpro/pdf_to_chordpro_service.dart';

// ────────────────────────────────────────────────────────────────────────
// Generador mínimo de PDF 1.4 (Helvetica base, texto real, no escaneado).
// Y crece hacia ABAJO (origen arriba-izquierda), así que menor Y = más arriba.
// ────────────────────────────────────────────────────────────────────────
Uint8List _generateCieloPdf() {
  const pageW = 612.0, pageH = 792.0, left = 72.0;
  const titleSize = 18.0, headerSize = 12.0, chordSize = 11.0, lyricSize = 12.0;

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

  // Convierte una coordenada visual (mayor = más arriba) a la coordenada PDF que
  // usa Syncfusion (invierte el eje Y), para que el orden visual quede correcto.
  double _y(double pantallaY) => pageH - pantallaY;

  final texts = <({String font, double size, double x, double y, String s})>[];
  void _Text(String font, double size, double x, double y, String s) =>
      texts.add((font: font, size: size, x: x, y: y, s: s));

  void title(String s, double y) => _Text('F2', titleSize, left, _y(y), s);
  void header(String s, double y) => _Text('F2', headerSize, left, _y(y), s);
  void lyric(String s, double y) => _Text('F1', lyricSize, left, _y(y), s);

  void chordsOver(String lyricText, List<(String, int)> chords, double y) {
    for (final (chord, charIndex) in chords) {
      final x = xOfCharIndex(lyricText, charIndex, lyricSize);
      _Text('F1', chordSize, x, _y(y), chord);
    }
  }

  String esc(String s) => s.replaceAll(r'\', r'\\').replaceAll('(', r'\(').replaceAll(')', r'\)');

  // ── Contenido ──
  title('CIELO EN LA TIERRA', 70);

  header('INTRO x2', 110);
  _Text('F1', lyricSize, left, _y(130), 'C#m | A | E | B');

  header('VERSO 1', 170);
  const v1 = 'El cielo y la Tierra creó';
  chordsOver(v1, [('A', 0), ('Am7', 3), ('G', 14)], 190);
  lyric(v1, 210);

  header('VERSO 2', 250);
  const v2 = 'Y el hombre de polvo formó';
  chordsOver(v2, [('C', 0), ('Fmaj7', 5), ('G', 21)], 270);
  lyric(v2, 290);

  header('CORO x2', 330);
  const co = 'Cielo en la tierra cantaré';
  chordsOver(co, [('G', 0), ('D', 6), ('C#m', 12)], 350);
  lyric(co, 370);

  // Número de página (debe filtrarse).
  _Text('F1', 10.0, 560, _y(750), '1');

  // ── Construir PDF 1.4 ──
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

const expectedCho = '''{title: CIELO EN LA TIERRA}

{start_of_introduccion: INTRODUCCIÓN x2}
[C#m] | [A] | [E] | [B]
{end_of_introduccion}

{start_of_verse: VERSO 1}
[A]El [Am7]cielo y la [G]Tierra creó
{end_of_verse}

{start_of_verse: VERSO 2}
[C]Y el [Fmaj7]hombre de polvo [G]formó
{end_of_verse}

{start_of_chorus: CORO x2}
[G]Cielo [D]en la [C#m]tierra cantaré
{end_of_chorus}''';

void main() {
  late Uint8List pdfBytes;

  setUpAll(() {
    pdfBytes = _generateCieloPdf();
  });

  test('CIELO EN LA TIERRA se importa con secciones, acordes y compases correctos', () {
    final res = const PdfToChordProService().convert(pdfBytes);

    // ignore: avoid_print
    print('--- ChordPro result ---\n${res.chordPro}\n'
        'title=${res.title} key=${res.suggestedKey} cols=${res.columns}\n'
        'warnings=${res.warnings.map((w) => w.message).toList()}');

    expect(res.title, 'CIELO EN LA TIERRA');
    expect(res.columns, 1);

    // Título en mayúsculas: va en {title:}, nunca como verso.
    expect(res.chordPro, contains('{title: CIELO EN LA TIERRA}'));
    expect(res.chordPro, isNot(contains('{start_of_verse: CIELO EN LA TIERRA}')));
    expect(res.chordPro, isNot(contains('\nCIELO EN LA TIERRA\n')));

    // Secciones con etiqueta y repetición.
    expect(res.chordPro, contains('{start_of_introduccion: INTRODUCCIÓN x2}'));
    expect(res.chordPro, contains('{start_of_verse: VERSO 1}'));
    expect(res.chordPro, contains('{start_of_verse: VERSO 2}'));
    expect(res.chordPro, contains('{start_of_chorus: CORO x2}'));

    // Cierres correctos.
    expect(res.chordPro, contains('{end_of_introduccion}'));
    expect(res.chordPro, contains('{end_of_verse}'));
    expect(res.chordPro, contains('{end_of_chorus}'));

    // Intro sin letra: línea de compases.
    expect(res.chordPro, contains('[C#m] | [A] | [E] | [B]'));

    // Acordes colocados sobre la sílaba correcta.
    expect(res.chordPro, contains('[A]El [Am7]cielo y la [G]Tierra creó'));
    expect(res.chordPro, contains('[C]Y el [Fmaj7]hombre de polvo [G]formó'));
    expect(res.chordPro, contains('[G]Cielo [D]en la [C#m]tierra cantaré'));

    // Número de página filtrado.
    expect(res.chordPro, contains('cantaré'));
    expect(res.chordPro.contains('\n1\n'), isFalse);

    // Salida completa igual al esperado.
    expect(res.chordPro.trim(), expectedCho.trim());

    // Muy pocos (idealmente cero) avisos.
    expect(res.warnings.length, lessThanOrEqualTo(1));
  });
}
