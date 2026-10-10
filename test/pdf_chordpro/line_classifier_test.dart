// Tests del clasificador de lneas del PDF (acordes / letra / encabezado).
import 'package:appchords/services/pdf_chordpro/line_classifier.dart';
import 'package:appchords/services/pdf_chordpro/pdf_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Construye una linea a partir de palabras "texto@X" separadas por espacios.
PdfLine line(String spec, {double top = 100, double fontSize = 12}) {
  final words = <PdfWord>[];
  var x = 0.0;
  for (final part in spec.split(' ')) {
    if (part.isEmpty) continue;
    final at = part.lastIndexOf('@');
    final text = at < 0 ? part : part.substring(0, at);
    final left = at < 0 ? x : double.parse(part.substring(at + 1));
    words.add(PdfWord(text: text, left: left, top: top, right: left + text.length * fontSize * 0.5, bottom: top + fontSize, fontSize: fontSize));
    x = words.last.right + fontSize * 0.3;
  }
  return PdfLine(words: words);
}

void main() {
  group('proporcion de acordes', () {
    test('linea sola de acordes da 1', () {
      expect(chordRatio('C#m  A  E  B'), 1.0);
      expect(chordRatio('C#m | A | E | B'), 1.0);
      expect(chordRatio('F  G  Em  Am'), 1.0);
    });

    test('linea de letra da 0', () {
      expect(chordRatio('Da un paso al frente'), 0.0);
    });

    test('letra con algun acorde suelto se queda por debajo del 80%', () {
      expect(chordRatio('Demos toda gloria a Jesus C'), lessThan(0.8));
    });

    test('acordes con bajo y calidades raras se reconocen', () {
      for (final c in ['C', 'C#m7', 'Gmaj7', 'Gsus4', 'F#m7(b5)', 'A/C#m', 'D/F#', 'Bbmaj7', 'Fadd9', 'Cdim', 'Eaug', 'Ab']) {
        expect(looksLikeChord(c), isTrue, reason: c);
      }
    });

    test('palabras normales no son acordes', () {
      for (final w in ['Hola', 'Jesus', 'Danzar', 'Coro', 'Amigo', 'Sol']) {
        expect(looksLikeChord(w), isFalse, reason: w);
      }
    });
  });

  group('encabezados', () {
    test('detecta los tipos del mapa canonico', () {
      expect(matchHeader('INTRODUCCION')!.directive, 'introduccion');
      expect(matchHeader('Intro')!.directive, 'introduccion');
      expect(matchHeader('VERSO 1')!.directive, 'verse');
      expect(matchHeader('Verso 2')!.directive, 'verse');
      expect(matchHeader('Estrofa 3')!.directive, 'verse');
      expect(matchHeader('PRE-CORO')!.directive, 'chorus');
      expect(matchHeader('Coro')!.directive, 'chorus');
      expect(matchHeader('Puente')!.directive, 'bridge');
      expect(matchHeader('Final')!.directive, 'final');
      expect(matchHeader('Outro')!.directive, 'final');
      expect(matchHeader('Interludio')!.directive, 'instrumental');
    });

    test('las etiquetas salen en el formato canonico', () {
      expect(matchHeader('VERSO 1')!.label, 'VERSO 1');
      expect(matchHeader('Verso')!.label, 'VERSO 1');
      expect(matchHeader('CORO')!.label, 'CORO');
      // PRE-CORO es pre-coro, con su color propio, no coro.
      expect(matchHeader('PRE-CORO')!.label, 'PRE-CORO');
      expect(matchHeader('PUENTE')!.label, 'PUENTE');
    });

    test('aguanta adornos, dos puntos y texto detras', () {
      expect(matchHeader('INTRODUCCION:')!.label, 'INTRODUCCIÓN');
      expect(matchHeader('[Coro]')!.directive, 'chorus');
      final conAcordes = matchHeader('INTRODUCCION: C#m A E B');
      expect(conAcordes!.directive, 'introduccion');
      expect(conAcordes.rest, 'C#m A E B');
    });

    test('no se confunde con letra que empieza igual', () {
      expect(matchHeader('Coro de angeles cantan'), isNull);
      expect(matchHeader('Verso que no es encabezado'), isNull);
      expect(matchHeader('Puente de la cancion'), isNull);
    });
  });

  group('clasificacion de lineas', () {
    test('linea de acordes', () {
      expect(classifyLine(line('C#m@0 A@60 E@120 B@180')).kind, LineKind.chords);
      expect(classifyLine(line('F – G – Em')).kind, LineKind.chords);
    });

    test('linea de letra', () {
      expect(classifyLine(line('Da un paso al frent@0 e', fontSize: 12)).kind, LineKind.lyric);
    });

    test('encabezado', () {
      expect(classifyLine(line('VERSO 1')).kind, LineKind.header);
      expect(classifyLine(line('INTRODUCCION: C#m A')).kind, LineKind.header);
    });

    test('vacia', () {
      expect(classifyLine(line('')).kind, LineKind.empty);
    });
  });
}
