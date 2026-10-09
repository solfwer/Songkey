import 'package:flutter_test/flutter_test.dart';

import 'package:appchords/data/chord_parser.dart';
import 'package:appchords/services/pdf_import.dart';

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
}