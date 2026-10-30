// wordsFromChars: de cajas de caracteres (PDFium) a palabras con X real.
import 'package:appchords/services/pdf_chordpro/char_boxes.dart';
import 'package:flutter_test/flutter_test.dart';

/// Escribe [text] a 6 pt por letra desde [x], en la fila [y] (alto 9).
List<PdfCharBox> _run(String text, double x, double y, {int page = 0}) => [
      for (var i = 0; i < text.length; i++)
        PdfCharBox(ch: text[i], left: x + 6.0 * i, right: x + 6.0 * i + 5, top: y, bottom: y + 9, page: page),
    ];

void main() {
  test('separa palabras por el espacio y conserva la X de cada letra', () {
    // "Hola mundo" con un espacio real (hueco de 6 pt entre palabras)
    final chars = [..._run('Hola', 100, 50), ..._run('mundo', 130, 50)];
    final w = wordsFromChars(chars);
    expect(w.map((x) => x.text).toList(), ['Hola', 'mundo']);
    expect(w[0].glyphLefts, [100.0, 106.0, 112.0, 118.0]);
    expect(w[1].left, 130.0);
  });

  test('un espacio emitido por el PDF corta la palabra aunque el hueco sea pequeño', () {
    final chars = [
      ..._run('ab', 100, 50),
      const PdfCharBox(ch: ' ', left: 112, right: 114, top: 50, bottom: 50.02),
      ..._run('cd', 114, 50), // hueco de solo 1 pt tras la 'b' (que termina en 113)
    ];
    expect(wordsFromChars(chars).map((x) => x.text).toList(), ['ab', 'cd']);
  });

  test('letras de una misma palabra con huecos pequeños NO se parten', () {
    // hueco interletra de 2 pt (cajas ajustadas al glifo)
    final chars = [
      for (var i = 0; i < 6; i++)
        PdfCharBox(ch: 'humill'[i], left: 100 + 7.0 * i, right: 105 + 7.0 * i, top: 50, bottom: 59),
    ];
    expect(wordsFromChars(chars).map((x) => x.text).toList(), ['humill']);
  });

  test('acordes y letra quedan en filas distintas, con su X real', () {
    final chars = [
      ..._run('D', 148, 30),
      ..._run('Nos', 100, 44),
      ..._run('humillamos', 124, 44),
    ];
    final w = wordsFromChars(chars);
    expect(w.length, 3);
    final d = w.firstWhere((x) => x.text == 'D');
    final nos = w.firstWhere((x) => x.text == 'Nos');
    expect(d.top < nos.top, isTrue);
    expect(d.left, 148.0);
  });

  test('un acento alto no cambia de fila a su palabra', () {
    final chars = [
      ..._run('SE', 100, 50),
      // la Ñ trae una caja mas alta que sube 3 pt
      const PdfCharBox(ch: 'Ñ', left: 112, right: 117, top: 47, bottom: 59),
      ..._run('OR', 118, 50),
    ];
    expect(wordsFromChars(chars).map((x) => x.text).toList(), ['SEÑOR']);
  });

  test('ignora saltos de línea, espacios y cajas vacías', () {
    final chars = [
      ..._run('Hola', 100, 50),
      const PdfCharBox(ch: '\r', left: 0, right: 0, top: 0, bottom: 0),
      const PdfCharBox(ch: '\n', left: 0, right: 0, top: 0, bottom: 0),
      const PdfCharBox(ch: 'x', left: 200, right: 200, top: 50, bottom: 59), // ancho 0
    ];
    expect(wordsFromChars(chars).map((x) => x.text).toList(), ['Hola']);
  });

  test('cada página se procesa por separado', () {
    final chars = [..._run('uno', 100, 50, page: 0), ..._run('dos', 100, 50, page: 1)];
    final w = wordsFromChars(chars);
    expect(w.map((x) => '${x.page}:${x.text}').toList(), ['0:uno', '1:dos']);
  });

  test('fromPdfRect pasa de coordenadas PDF (origen abajo) a las del importador', () {
    final c = PdfCharBox.fromPdfRect(
      ch: 'D', left: 10, top: 700, right: 18, bottom: 691, pageHeight: 792,
    );
    expect(c.top, 92.0);
    expect(c.bottom, 101.0);
    expect(c.height, 9.0);
  });
}
