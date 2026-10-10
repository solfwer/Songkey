// Tests extra del parser: comentarios normales, acordes empatados y el
// formato cannico tal como lo escribe el serializador.
import 'package:appchords/data/chordpro.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('comentario que no es encabezado conserva sus acordes', () {
    // Un comentario cualquiera no es encabezado, pero sus acordes no deben
    // quedarse como texto plano entre corchetes.
    final song = ChordProParser().parse('{title: GRACIAS}\n\n{comment: NOTA DEL AUTOR: [Em] [D]}\n{start_of_verse: VERSO 1}\nHola [Em]mundo\n{end_of_verse}');
    final primera = song.sections.first.lines.single;
    expect(primera.lyric, 'NOTA DEL AUTOR:');
    expect(primera.chords.map((c) => c.chord).toList(), ['Em', 'D']);
    // Idempotente.
    final out = const ChordProSerializer().write(song);
    expect(const ChordProSerializer().write(ChordProParser().parse(out)), out);
  });

  test('varios acordes en la misma posicin mantienen su orden', () {
    final song = ChordProParser().parse('{start_of_verse: VERSO 1}\nfueg[Am]o[A/C#][Am/C][G/B]\n{end_of_verse}');
    expect(song.sections.single.lines.single.chords.map((c) => c.chord).toList(), ['Am', 'A/C#', 'Am/C', 'G/B']);
    final out = const ChordProSerializer().write(song);
    expect(out, contains('fueg[Am]o[A/C#][Am/C][G/B]'));
    expect(const ChordProSerializer().write(ChordProParser().parse(out)), out);
  });

  test('etiqueta con errata se recupera como seccin', () {
    // "INTRUDUCCIN" (le falta la C) se acepta como introduccin.
    final song = ChordProParser().parse('{comment: INTRUDUCCIÓN: [Em] [D]}\n{start_of_verse: VERSO 1}\nHola\n{end_of_verse}');
    expect(song.sections.first.directive, 'introduccion');
    expect(song.sections.first.lines.single.instrumental, isTrue);
  });
}
