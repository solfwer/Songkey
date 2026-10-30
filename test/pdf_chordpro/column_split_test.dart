// Regresión: acordes pegados al borde derecho de una canción de UNA columna no
// deben tomarse por una segunda columna (separaba el acorde de su línea), y
// con dos columnas reales el orden es izquierda entera -> derecha entera.
import 'package:appchords/services/pdf_chordpro/pdf_line_processor.dart';
import 'package:appchords/services/pdf_chordpro/pdf_models.dart';
import 'package:flutter_test/flutter_test.dart';

PdfWord _w(String t, double x, double y, {double w = 0}) => PdfWord(
      text: t,
      left: x,
      right: x + (w > 0 ? w : t.length * 6.0),
      top: y,
      bottom: y + 11,
    );

void main() {
  test('una columna con acordes al borde derecho NO se parte en dos', () {
    final words = <PdfWord>[];
    for (var r = 0; r < 6; r++) {
      final y = 100.0 + r * 30;
      words
        ..add(_w('D', 170, y))
        ..add(_w('G', 330, y))
        ..add(_w('Em', 470, y)) // al borde derecho: hueco antes de él
        ..add(_w('Nos humillamos delante de nuestro Dios por siempre', 100, y + 14, w: 280));
    }
    expect(detectColumnSplit(words, 612), isNull);
  });

  test('dos columnas reales: izquierda entera y luego derecha, sin mezclar', () {
    final words = <PdfWord>[];
    for (var r = 0; r < 4; r++) {
      final y = 100.0 + r * 30;
      words
        ..add(_w('C', 72, y))
        ..add(_w('Hola mundo de prueba izq$r', 72, y + 14, w: 170))
        ..add(_w('D', 330, y))
        ..add(_w('Segunda columna aqui der$r', 330, y + 14, w: 170));
    }
    final split = detectColumnSplit(words, 612);
    expect(split, isNotNull);

    final lines = groupLines(words, split!);
    final texts = lines.map((l) => l.text).toList();
    final lastLeft = texts.lastIndexWhere((t) => t.contains('izq'));
    final firstRight = texts.indexWhere((t) => t.contains('der'));
    expect(lastLeft, lessThan(firstRight));
    // Cada acorde sigue inmediatamente encima de su letra.
    for (var i = 0; i < lines.length; i += 2) {
      expect(lines[i].text.length, lessThan(3));
      expect(lines[i + 1].text.length, greaterThan(10));
    }
  });
}
