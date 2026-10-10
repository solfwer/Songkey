// Round-trip con un archivo real del cancionero (si est en el PC).
// El texto original se normaliza al formato cannico y, a partir de ah, la
// ida y vuelta texto -> modelo -> texto es estable (da el mismo resultado).
import 'dart:io';

import 'package:appchords/data/chord_parser.dart';
import 'package:appchords/data/chordpro.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const cancionero = r'C:\Users\josue\Downloads\cancionero_chordpro\word_revisado';

  test('cancion real (A Danzar): se normaliza y la ida y vuelta es estable', () {
    final file = File('$cancionero\\001_a_danzar.cho');
    if (!file.existsSync()) {
      // Sin el cancionero en el PC no se puede comprobar: se marca como ok.
      return;
    }
    final raw = file.readAsStringSync();
    final song = ChordProParser().parse(raw);
    final out = const ChordProSerializer().write(song);

    expect(song.meta.title, 'A DANZAR');
    expect(song.sections.map((s) => s.label).toList(), ['INTRODUCCIÓN:', 'VERSO 1', 'VERSO 2', 'PRE-CORO', 'CORO']);
    expect(song.sections.map((s) => s.kind).toList(), [
      SectionKind.intro,
      SectionKind.verse,
      SectionKind.verse,
      SectionKind.prechorus,
      SectionKind.chorus,
    ]);
    // El comentario de introduccin se vuelve seccin con su fila de acordes.
    expect(song.sections.first.lines.single.instrumental, isTrue);
    expect(song.sections.first.lines.single.bars, ['C#m', 'A', 'E', 'B']);

    // Segunda pasada: mismo texto (idempotente).
    expect(const ChordProSerializer().write(ChordProParser().parse(out)), out);
    // Y el texto cannico sigue teniendo las directivas del formato.
    expect(out, contains('{start_of_verse: VERSO 1}'));
    expect(out, contains('{end_of_verse}'));
    expect(out, contains('frent[C#m]e'));
  });
}
