// Tests de linesFromLayoutText: el texto en modo layout debe conservar la
// columna de cada palabra (de ahi sale la posicion de los acordes).
import 'package:appchords/services/pdf_chordpro/layout_text_lines.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('conserva la columna de cada palabra', () {
    final lines = linesFromLayoutText('   D     G\nNos humillamos');
    expect(lines.length, 2);
    expect(lines[0].words.map((w) => w.left).toList(), [3.0, 9.0]);
    expect(lines[1].words.map((w) => w.left).toList(), [0.0, 4.0]);
  });

  test('glyphLefts trae una columna por caracter', () {
    final w = linesFromLayoutText('  Hola').single.words.single;
    expect(w.glyphLefts, [2.0, 3.0, 4.0, 5.0]);
    expect(w.right, 6.0);
  });

  test('no recorta la sangria ni junta los espacios', () {
    final line = linesFromLayoutText('        C').single;
    expect(line.words.single.left, 8.0);
  });

  test('descarta lineas vacias y numeros de pagina', () {
    final lines = linesFromLayoutText('\n   \n12\nHola\n');
    expect(lines.length, 1);
    expect(lines.single.text, 'Hola');
  });

  test('sigue marcada como sin coordenadas de pagina y sin eje Y', () {
    final line = linesFromLayoutText('Hola').single;
    expect(line.positioned, isFalse);
    expect(line.top, 0);
    expect(line.bottom, 0);
  });

  test('la pagina se propaga', () {
    final line = linesFromLayoutText('Hola', page: 3).single;
    expect(line.page, 3);
    expect(line.words.single.page, 3);
  });
}
