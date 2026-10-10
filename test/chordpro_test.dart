// Tests del modelo, parser y serializador ChordPro (formato cannico).
import 'package:appchords/data/chord_parser.dart';
import 'package:appchords/data/chordpro.dart';
import 'package:flutter_test/flutter_test.dart';

/// La cancin de referencia, en el formato cannico. El serializador debe
/// reproducirla EXACTAMENTE (ida y vuelta texto -> modelo -> texto).
const aDanzar = '''{title: A DANZAR}

{start_of_introduccion: INTRODUCCIÓN:}
[C#m] | [A] | [E] | [B]
{end_of_introduccion}

{start_of_verse: VERSO 1}
Da un paso al frent[C#m]e
Has algo diferent[C#m]e
Demos toda gloria a Jes[A]ús
{end_of_verse}

{start_of_chorus: PRE-CORO}
[B]Si tu respiras tienes que adorar
[A]Que nada te impida danzar
{end_of_chorus}

{start_of_chorus: CORO}
A danz[C#m]ar del[A]nte de su pres[E]encia
Su am[B]or es quien nos sust[C#m]enta
[C#m] | [A] | [E] | [B]
A danzar
{end_of_chorus}''';

void main() {
  group('ida y vuelta', () {
    test('texto -> modelo -> texto da el mismo resultado', () {
      final song = ChordProParser().parse(aDanzar);
      expect(const ChordProSerializer().write(song), aDanzar);
    });

    test('la cancin de referencia se interpreta con los tipos correctos', () {
      final song = ChordProParser().parse(aDanzar);
      expect(song.meta.title, 'A DANZAR');
      expect(song.sections.map((s) => s.label).toList(), ['INTRODUCCIÓN:', 'VERSO 1', 'PRE-CORO', 'CORO']);
      expect(song.sections.map((s) => s.kind).toList(), [
        SectionKind.intro,
        SectionKind.verse,
        SectionKind.prechorus,
        SectionKind.chorus,
      ]);
      // 4 secciones y la ltima tiene 5 lneas.
      expect(song.sections.length, 4);
      expect(song.sections.last.lines.length, 4);
    });

    test('los acordes quedan anclados a la slaba exacta', () {
      final song = ChordProParser().parse(aDanzar);
      final verso = song.sections[1];
      // "Da un paso al frent[C#m]e" -> el acorde va delante de la "e" final.
      final primera = verso.lines.first;
      expect(primera.lyric, 'Da un paso al frente');
      expect(primera.chords.length, 1);
      expect(primera.chords.first.at, primera.lyric!.length - 1);
      expect(primera.chords.first.chord, 'C#m');
    });

    test('las filas de acordes se guardan como instrumentales', () {
      final song = ChordProParser().parse(aDanzar);
      final intro = song.sections.first;
      expect(intro.lines.length, 1);
      expect(intro.lines.first.instrumental, isTrue);
      expect(intro.lines.first.bars, ['C#m', 'A', 'E', 'B']);
    });

    test('la fila de acordes de dentro del coro sigue siendo instrumental', () {
      final song = ChordProParser().parse(aDanzar);
      final coro = song.sections.last;
      expect(coro.lines[2].instrumental, isTrue);
      expect(coro.lines[2].bars, ['C#m', 'A', 'E', 'B']);
      expect(coro.lines[3].instrumental, isFalse);
      expect(coro.lines[3].lyric, 'A danzar');
    });
  });

  group('metadatos', () {
    test('se leen y se escriben las directivas de Datos', () {
      const src = '{title: Prueba}\n{artist: Alguien}\n{key: D}\n{tempo: 72}\n{time: 4/4}\n\n{start_of_verse: VERSO 1}\nHola\n{end_of_verse}';
      final song = ChordProParser().parse(src);
      expect(song.meta.title, 'Prueba');
      expect(song.meta.artist, 'Alguien');
      expect(song.meta.key, 'D');
      expect(song.meta.tempo, '72');
      expect(song.meta.time, '4/4');
      expect(const ChordProSerializer().write(song), src);
    });

    test('sin metadatos no se escribe ninguna directiva', () {
      const src = '{start_of_verse: VERSO 1}\nHola\n{end_of_verse}';
      expect(ChordProSerializer().write(ChordProParser().parse(src)), src);
    });
  });

  group('variantes que acepta el parser', () {
    test('formas cortas sov/eov, soc/eoc', () {
      final song = ChordProParser().parse('{sov: VERSO 1}\nHola\n{eov}\n\n{soc: CORO}\nLala\n{eoc}');
      expect(song.sections.map((s) => s.directive).toList(), ['verse', 'chorus']);
      expect(const ChordProSerializer().write(song), '{start_of_verse: VERSO 1}\nHola\n{end_of_verse}\n\n{start_of_chorus: CORO}\nLala\n{end_of_chorus}');
    });

    test('start_of_intro y maysculas/tildes', () {
      final song = ChordProParser().parse('{START_OF_INTRO: INTRODUCCION:}\nC  D\n{END_OF_INTRO}');
      expect(song.sections.single.directive, 'introduccion');
      expect(song.sections.single.kind, SectionKind.intro);
      // La fila de acordes se escribe siempre con `|` como separador.
      expect(const ChordProSerializer().write(song), '{start_of_introduccion: INTRODUCCION:}\n[C] | [D]\n{end_of_introduccion}');
    });

    test('encabezados en texto plano de las canciones antiguas', () {
      final song = ChordProParser().parse('Verso 1\nHola [C]mundo\n\nCoro\n[C]Aleluya');
      expect(song.sections.map((s) => s.label).toList(), ['VERSO 1', 'CORO']);
      expect(song.sections.map((s) => s.kind).toList(), [SectionKind.verse, SectionKind.chorus]);
      expect(song.sections.first.lines.first.lyric, 'Hola mundo');
      expect(song.sections.first.lines.first.chords.single.chord, 'C');
    });

    test('un comentario que es en realidad un encabezado se vuelve seccin', () {
      final song = ChordProParser().parse('{comment: INTRODUCCIÓN:}\n[C] | [G]');
      expect(song.sections.single.directive, 'introduccion');
      expect(song.sections.single.lines.single.instrumental, isTrue);
    });

    test('texto sin encabezados se conserva agrupado', () {
      final song = ChordProParser().parse('Hola [C]mundo');
      expect(song.sections.length, 1);
      expect(song.sections.single.lines.single.lyric, 'Hola mundo');
    });

    test('directivas de cierre desconocidas no rompen el anlisis', () {
      final song = ChordProParser().parse('{start_of_verse: VERSO 1}\nHola\n{end_of_verse}\n{cierre_raro}');
      expect(song.sections.length, 1);
    });
  });

  group('casos sucios que se normalizan', () {
    test('espacios de ms y etiquetas en minsculas', () {
      final song = ChordProParser().parse('{start_of_verse: verso   2}\nhola   [C]mundo   otra   vez\n{end_of_verse}');
      expect(song.sections.single.label, 'VERSO 2');
      expect(const ChordProSerializer().write(song), '{start_of_verse: VERSO 2}\nhola [C]mundo otra vez\n{end_of_verse}');
    });

    test('una palabra que parece acorde pegado a la letra NO se inventa como acorde', () {
      // "Cmundo" es una palabra normal: el parser no arriesga y la deja como
      // letra (solo se interpretan acordes entre corchetes o filas de acordes).
      final song = ChordProParser().parse('{start_of_verse: VERSO 1}\nHola Cmundo de prueba\n{end_of_verse}');
      final line = song.sections.single.lines.single;
      expect(line.lyric, 'Hola Cmundo de prueba');
      expect(line.chords, isEmpty);
    });

    test('una linea de acordes sin corchetes se vuelve progresin', () {
      final song = ChordProParser().parse('{start_of_introduccion: INTRO:}\nC  D  Em\n{end_of_introduccion}');
      final line = song.sections.single.lines.single;
      expect(line.instrumental, isTrue);
      expect(line.bars, ['C', 'D', 'Em']);
      expect(const ChordProSerializer().write(song), '{start_of_introduccion: INTRO:}\n[C] | [D] | [Em]\n{end_of_introduccion}');
    });

    test('un "A" suelto en la letra no se confunde con un acorde', () {
      final song = ChordProParser().parse('{start_of_verse: VERSO 1}\nA danzar delante de l\n{end_of_verse}');
      expect(song.sections.single.lines.single.chords, isEmpty);
    });

    test('voy a anyadir una linea vaca y no pasa nada', () {
      final song = ChordProParser().parse('{start_of_verse: VERSO 1}\nHola\n\n\n{end_of_verse}');
      expect(song.sections.single.lines.length, 1);
    });
  });

  group('modelo', () {
    test('copy es independiente (editar la copia no toca el original)', () {
      final song = ChordProParser().parse(aDanzar).copy();
      song.sections.last.lines.clear();
      final otra = ChordProParser().parse(aDanzar);
      expect(otra.sections.last.lines.length, 4);
    });

    test('el tipo de seccin se puede reconfigurar', () {
      // Cambiando las reglas, "chorus" + "PRE-CORO" podra ser coro normal.
      final song = ChordProParser(rules: const [KindRule('chorus', 'PRE-CORO', SectionKind.chorus), KindRule('chorus', null, SectionKind.chorus)]).parse(aDanzar);
      expect(song.sections[2].kind, SectionKind.chorus);
    });

    test('sin problemas en el anlisis de la cancin de referencia', () {
      final parser = ChordProParser();
      parser.parse(aDanzar);
      expect(parser.issues, isEmpty);
    });
  });
}
