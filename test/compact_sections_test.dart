// Tests de las secciones nicas para la vista compacta.
import 'package:appchords/data/chord_parser.dart';
import 'package:appchords/models/song.dart';
import 'package:appchords/screens/song/widgets/compact_sections.dart';
import 'package:flutter_test/flutter_test.dart';

const cuerpo = '''Verso 1
[G]Una linea del verso
[G]Otra linea del verso

Coro
[C]Aleluya al Senor
[C]Gloria a el

Verso 2
[G]Segundo verso aqui

Puente
[Em]Solo un puente pequeno''';

void main() {
  group('sin arreglo', () {
    test('saca las secciones unicas en el orden del cuerpo', () {
      final secs = compactSectionsFrom(cuerpo, null);
      expect(secs.map((s) => s.label).toList(), ['Verso 1', 'Coro', 'Verso 2', 'Puente']);
      expect(secs.every((s) => s.repeats == 1), isTrue);
    });

    test('cada seccion aparece una sola vez', () {
      final secs = compactSectionsFrom(cuerpo, null);
      expect(secs.map((s) => s.label).toSet().length, secs.length);
    });
  });

  group('con arreglo y repeticiones', () {
    test('las secciones salen en el orden de su primera aparicion', () {
      final secs = compactSectionsFrom(cuerpo, ['Intro', 'Coro', 'Verso 1', 'Coro']);
      expect(secs.map((s) => s.label).toList(), ['Coro', 'Verso 1', 'Verso 2', 'Puente']);
    });

    test('cuenta las repeticiones del arreglo (x2)', () {
      final secs = compactSectionsFrom(cuerpo, ['Coro', 'Verso 1', 'Coro', 'Coro']);
      final coro = secs.firstWhere((s) => s.label == 'Coro');
      expect(coro.repeats, 3);
      expect(coro.muestraRepeticion, isTrue);
      // La letra no se duplica: sigue habiendo UNA sola seccion Coro.
      expect(secs.where((s) => s.label == 'Coro').length, 1);
      expect(coro.lines.length, 2);
    });

    test('una sola aparicion no lleva etiqueta de repeticion', () {
      final secs = compactSectionsFrom(cuerpo, ['Verso 1', 'Coro']);
      expect(secs.every((s) => !s.muestraRepeticion), isTrue);
    });

    test('las secciones que no estan en el arreglo van al final', () {
      final secs = compactSectionsFrom(cuerpo, ['Coro']);
      expect(secs.first.label, 'Coro');
      expect(secs.map((s) => s.label).toList(), ['Coro', 'Verso 1', 'Verso 2', 'Puente']);
      expect(secs[1].repeats, 0);
      expect(secs[1].enArreglo, isFalse);
    });

    test('una etiqueta del arreglo que ya no existe se ignora', () {
      final secs = compactSectionsFrom(cuerpo, ['Coro', 'Solo de gaitas']);
      expect(secs.map((s) => s.label).toList(), ['Coro', 'Verso 1', 'Verso 2', 'Puente']);
    });

    test('el arreglo no distingue maysculas ni acentos', () {
      final secs = compactSectionsFrom(cuerpo, ['CORO', 'verso 1']);
      expect(secs.map((s) => s.label).toList(), ['Coro', 'Verso 1', 'Verso 2', 'Puente']);
      expect(secs.first.repeats, 1);
    });

    test('una seccion sin encabezado (texto inicial) se respeta', () {
      final secs = compactSectionsFrom('Hola a todos\n\nCoro\n[C]Aleluya', ['Coro']);
      expect(secs.length, 2);
      expect(secs.last.label, 'Inicio');
      expect(secs.last.repeats, 0);
    });

    test('cancion sin letra no revienta', () {
      expect(compactSectionsFrom('', ['Coro']), isEmpty);
      expect(compactSectionsFrom('', null), isEmpty);
    });
  });

  group('sobre el modelo Song', () {
    test('compactSections lee body y structure', () {
      final song = Song(id: 'a', title: 'T', body: cuerpo, structure: const ['Coro', 'Verso 1', 'Coro']);
      final secs = compactSections(song);
      expect(secs.map((s) => s.label).toList(), ['Coro', 'Verso 1', 'Verso 2', 'Puente']);
      expect(secs.first.repeats, 2);
    });

    test('el total de repeticiones cuenta lo que suena', () {
      final secs = compactSectionsFrom(cuerpo, ['Coro', 'Verso 1', 'Coro']);
      // Coro x2 + Verso 1 + las dos que no estan en el arreglo.
      expect(totalRepeticiones(secs), 5);
    });
  });

  test('los tipos salen bien para pintar el color', () {
    const body = 'Intro\n[G]do re mi\n\nCoro\n[C]la la la\n\nPre-coro\n[Am]ni ni ni\n\nPuente\n[Em]pu pu';
    final secs = compactSectionsFrom(body, null);
    expect(secs[0].kind, SectionKind.intro);
    expect(secs[1].kind, SectionKind.chorus);
    expect(secs[2].kind, SectionKind.prechorus);
    expect(secs[3].kind, SectionKind.bridge);
  });
}
