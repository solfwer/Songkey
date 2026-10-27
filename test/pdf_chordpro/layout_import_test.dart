// Regresion: importar un PDF cuyo texto sale en "modo layout" no debe juntar
// todos los acordes al principio de la linea (`[D][G]Nos humillamos...`).
//
// El texto es un fragmento de test/pdf_chordpro/fixtures/serviremos_al_senor.pdf
// (acordes en una fila, letra justo debajo, la columna marca la posicion).
import 'package:appchords/services/pdf_chordpro/layout_text_lines.dart';
import 'package:appchords/services/pdf_chordpro/pdf_to_chordpro_service.dart';
import 'package:flutter_test/flutter_test.dart';

const _layout = '''
                         SERVIREMOS         AL  SEÑOR
    INTRO: D | G //
                             D                  G
    VERSO   1      Nos  humillamos delante de nuestro Dios
                        Bm        A               G
                   Sacrificio agradable queremos ser
                              D                G
                   Hoy  renunciamos  a nuestra voluntad
''';

List<String> _bodyLines() {
  final lines = linesFromLayoutText(_layout);
  final out = const PdfToChordProService().buildFromLines(lines).chordPro;
  return out.split('\n').where((l) => l.isNotEmpty && !l.startsWith('{')).toList();
}

/// Letra de una linea ChordPro sin los [acordes].
String _lyric(String l) => l.replaceAll(RegExp(r'\[[^\]]+\]'), '');

/// Indices (en la letra limpia) donde esta cada acorde.
List<int> _positions(String l) {
  final out = <int>[];
  var removed = 0;
  for (final m in RegExp(r'\[[^\]]+\]').allMatches(l)) {
    out.add(m.start - removed);
    removed += m.end - m.start;
  }
  return out;
}

void main() {
  test('los acordes ya no se juntan todos al inicio de la linea', () {
    final body = _bodyLines();
    final verso1 = body.firstWhere((l) => _lyric(l).startsWith('Nos humillamos'));
    expect(verso1.startsWith('[D][G]'), isFalse);
    expect(_positions(verso1).toSet().length, 2); // D y G en sitios distintos
  });

  test('la letra queda intacta (sin espacios anadidos ni perdidos)', () {
    final body = _bodyLines();
    expect(body.map(_lyric), contains('Nos humillamos delante de nuestro Dios'));
    expect(body.map(_lyric), contains('Sacrificio agradable queremos ser'));
    expect(body.map(_lyric), contains('Hoy renunciamos a nuestra voluntad'));
  });

  test('se conservan todos los acordes y su orden de lectura', () {
    final body = _bodyLines();
    final chords = [
      for (final l in body.where((l) => _lyric(l).startsWith('Sacrificio')))
        ...RegExp(r'\[([^\]]+)\]').allMatches(l).map((m) => m.group(1)),
    ];
    expect(chords, ['Bm', 'A', 'G']);
  });

  test('un acorde mas a la derecha en la fila cae mas a la derecha en la letra', () {
    for (final l in _bodyLines().where((l) => RegExp(r'\[').hasMatch(l) && !l.contains('|'))) {
      final p = _positions(l);
      for (var i = 1; i < p.length; i++) {
        expect(p[i] >= p[i - 1], isTrue);
      }
    }
  });
}
