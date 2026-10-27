// Tests de la geometría del PDF: reparto en columnas y agrupación en líneas.
//
// Se prueban con palabras sintéticas (sin PDF), que es justo lo que permite
// separar esta parte de syncfusion.
import 'package:appchords/services/pdf_chordpro/pdf_line_processor.dart';
import 'package:appchords/services/pdf_chordpro/pdf_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Palabra de 6 pt por carácter, para poder razonar las coordenadas a mano.
PdfWord w(String text, double left, double top, {int page = 0, double height = 12}) => PdfWord(
      text: text,
      left: left,
      top: top,
      right: left + text.length * 6,
      bottom: top + height,
      fontSize: height,
      page: page,
    );

const pageWidth = 612.0;

void main() {
  group('detectColumnSplit', () {
    test('una columna no se parte', () {
      final words = [
        for (var i = 0; i < 8; i++) ...[
          w('C#m', 72, 92.0 + i * 20),
          w('letra de la linea', 72, 100.0 + i * 20),
        ],
      ];
      expect(detectColumnSplit(words, pageWidth), isNull);
    });

    test('dos columnas: corta por el hueco, no por dentro de una columna', () {
      final words = [
        for (var i = 0; i < 6; i++) ...[
          w('izquierda uno', 72, 100.0 + i * 20), // 72..150
          w('derecha uno', 320, 100.0 + i * 20), // 320..386
        ],
      ];
      final split = detectColumnSplit(words, pageWidth);
      expect(split, isNotNull);
      expect(split, inInclusiveRange(150, 320));
    });

    test('no depende del orden en que lleguen las palabras', () {
      final words = [
        for (var i = 0; i < 6; i++) ...[
          w('izquierda uno', 72, 100.0 + i * 20),
          w('derecha uno', 320, 100.0 + i * 20),
        ],
      ];
      expect(detectColumnSplit(words.reversed.toList(), pageWidth), detectColumnSplit(words, pageWidth));
    });

    test('un hueco menor de 12 pt no es columna', () {
      final words = [
        for (var i = 0; i < 6; i++) ...[
          w('izquierda', 72, 100.0 + i * 20), // 72..126
          w('derecha', 130, 100.0 + i * 20), // 130..172: hueco de 4 pt
        ],
      ];
      expect(detectColumnSplit(words, pageWidth), isNull);
    });

    test('con dos o menos palabras a un lado no es columna', () {
      final words = [
        for (var i = 0; i < 8; i++) w('izquierda uno', 72, 100.0 + i * 20), // 72..150
        w('derecha', 320, 100),
        w('derecha', 320, 140),
      ];
      expect(detectColumnSplit(words, pageWidth), isNull);
    });

    test('un título centrado sobre el texto no es una columna', () {
      final words = [
        // Cuerpo alineado a la izquierda, de arriba abajo.
        for (var i = 0; i < 6; i++) w('letra de la linea', 72, 130.0 + i * 20), // 72..180
        // Título centrado, por encima (no comparte altura con el cuerpo).
        w('LA', 240, 60),
        w('CASA', 270, 60),
        w('NUEVA', 312, 60),
      ];
      expect(detectColumnSplit(words, pageWidth), isNull);
    });

    test('pocas palabras en total no se parten', () {
      expect(detectColumnSplit([w('a', 72, 100), w('b', 320, 100)], pageWidth), isNull);
    });
  });

  group('groupLines', () {
    test('la columna izquierda entera va antes que la derecha', () {
      final words = [
        w('izq 1', 72, 100),
        w('izq 2', 72, 140),
        w('izq 3', 72, 180),
        w('der 1', 320, 100),
        w('der 2', 320, 140),
        w('der 3', 320, 180),
      ];
      final lines = groupLines(words, 300);
      expect(lines.map((l) => l.text).toList(), [
        'izq 1',
        'izq 2',
        'izq 3',
        'der 1',
        'der 2',
        'der 3',
      ]);
    });

    test('agrupa por centro vertical con tolerancia de media altura', () {
      // Centros 106 y 109 (3 pt de diferencia): misma línea.
      // El de abajo, centro 136: línea nueva.
      final words = [
        w('mundo', 120, 103),
        w('Hola', 72, 100),
        w('otra', 72, 130),
      ];
      final lines = groupLines(words, 300);
      expect(lines.map((l) => l.text).toList(), ['Hola mundo', 'otra']);
    });

    test('dentro de la línea ordena por X aunque lleguen desordenadas', () {
      final words = [w('mundo', 120, 100), w('Hola', 72, 100)];
      expect(groupLines(words, 300).single.text, 'Hola mundo');
    });

    test('las líneas de la misma altura en columnas distintas no se mezclan', () {
      final words = [w('izquierda', 72, 100), w('derecha', 320, 100)];
      final lines = groupLines(words, 300);
      expect(lines.map((l) => l.text).toList(), ['izquierda', 'derecha']);
    });

    test('respeta el orden de páginas', () {
      final words = [w('pagina dos', 72, 100, page: 1), w('pagina uno', 72, 100)];
      final lines = groupLines(words, 300);
      expect(lines.map((l) => l.text).toList(), ['pagina uno', 'pagina dos']);
      expect(lines.map((l) => l.page).toList(), [0, 1]);
    });

    test('no inventa líneas con lista vacía', () {
      expect(groupLines(const [], 300), isEmpty);
    });
  });
}
