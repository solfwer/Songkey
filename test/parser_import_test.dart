import 'package:flutter_test/flutter_test.dart';

import 'package:appchords/data/chord_parser.dart';
import 'package:appchords/services/pdf_chordpro/pdf_to_chordpro_service.dart'
    show keyFromBody, suggestedKeyFromBody;

void main() {
  test('headerInfo reconoce Transición e Instrumental', () {
    expect(headerInfo('Transición', '1').label, 'Transición 1');
    expect(headerInfo('Instrumental', '').label, 'Instrumental');
    expect(isSectionHeader('Transición 1'), isTrue);
    expect(isSectionHeader('Instrumental'), isTrue);
    expect(isSectionHeader('Verso 2'), isTrue);
  });

  test('parseSong mezcla acordes inline en secciones', () {
    const body = 'Intro\nG  C\nVerso 1\n[G]Hola [C]mundo\n[C]Amén';
    final sections = parseSong(body);
    expect(sections.map((s) => s.label).toList(), ['Intro', 'Verso 1']);
    expect(sections.first.lines.first.first.chord, 'G');
    final verse = sections[1];
    expect(verse.lines.first.first.chord, 'G');
    final t = verse.lines.first.first.text;
    expect(t.contains('Hola'), isTrue);
    expect(verse.lines.last.first.chord, 'C');
    expect(verse.lines.last.first.text, 'Amén');
  });

  test('keyFromBody detecta la tonalidad del primer acorde', () {
    expect(keyFromBody('Intro\nC#m  A  E  B\nVerso 1\nAlgo'), 'C#m');
    expect(keyFromBody('Verso 1\nG  C\n[G]Hola [C]mundo'), 'G');
    expect(keyFromBody('Letra sin acordes'), 'C');
  });

  test('parseSong interpreta directivas ChordPro del cancionero', () {
    const body = '''{title: A DANZAR}

{comment: INTRODUCCIÓN: [C#m] | [A] | [E] | [B]}
{start_of_verse: VERSO 1}
Da un paso al frent[C#m]e
{end_of_verse}

{start_of_chorus: PRE-CORO}
[B]Si tu respiras tienes que adorar
{end_of_chorus}

{start_of_chorus: CORO}
A danz[C#m]ar del[A]ante de su pres[E]encia
[C#m] | [A] | [E] | [B]
{end_of_chorus}''';
    final sections = parseSong(body);
    expect(sections.map((s) => s.label).toList(), ['VERSO 1', 'PRE-CORO', 'CORO']);
    expect(sections[0].kind, SectionKind.verse);
    expect(sections[1].kind, SectionKind.prechorus);
    expect(sections[2].kind, SectionKind.chorus);
    // El comentario se conserva como línea con sus acordes.
    expect(sections[0].lines.first.first.text, 'INTRODUCCIÓN: ');
    // Las directivas no aparecen como texto en el cuerpo.
    for (final s in sections) {
      for (final l in s.lines) {
        expect(l.map((x) => x.text).join(), isNot(contains('start_of')));
        expect(l.map((x) => x.text).join(), isNot(contains('end_of')));
      }
    }
  });

  test('secciones repetidas por estructura usan la misma letra', () {
    // Una sección del cancionero con directivas se puede repetir sin duplicar.
    const body = '{start_of_chorus: CORO}\n[C]Aleluya\n{end_of_chorus}\n{start_of_verse: VERSO 1}\n[G]Algo\n{end_of_verse}';
    final ordered = sectionsInOrder(body, ['CORO', 'VERSO 1', 'CORO']);
    expect(ordered.map((s) => s.label).toList(), ['CORO', 'VERSO 1', 'CORO']);
    expect(ordered.length, 3);
    expect(ordered[2].lines.first.first.chord, 'C');
  });
}