// Tests del mapeo acorde -> carcter de la letra.
import 'package:appchords/data/chord_parser.dart';
import 'package:appchords/data/chordpro.dart';
import 'package:appchords/services/pdf_chordpro/chord_mapper.dart';
import 'package:appchords/services/pdf_chordpro/pdf_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Linea de letra con la X de cada carcter, para poder simular el PDF.
PdfLine lyric(String text, {double left = 0, double charWidth = 10}) {
  final xs = [for (var i = 0; i < text.length; i++) left + i * charWidth];
  return PdfLine(words: [
    PdfWord(text: text, left: left, top: 40, right: left + text.length * charWidth, bottom: 52, fontSize: 12, glyphLefts: xs),
  ]);
}

/// Linea de acordes: cada par "acorde@X".
PdfLine chords(String spec, {double top = 20, double charWidth = 10}) {
  final words = <PdfWord>[];
  var x = 0.0;
  for (final part in spec.split(' ')) {
    if (part.isEmpty) continue;
    final at = part.lastIndexOf('@');
    final text = at < 0 ? part : part.substring(0, at);
    final left = at < 0 ? x : double.parse(part.substring(at + 1));
    words.add(PdfWord(text: text, left: left, top: top, right: left + text.length * charWidth, bottom: top + 12, fontSize: 12));
    x = words.last.right + 12;
  }
  return PdfLine(words: words);
}

CpLine place(String chordSpec, String text, {double top = 20}) => placeChordsOnLyric(chordsOf(chords(chordSpec, top: top)), lyric(text));

void main() {
  group('charIndexFor', () {
    test('elige el caracter cuya X es la mas cercana', () {
      const xs = [0.0, 10.0, 20.0, 30.0];
      expect(charIndexFor(4, xs), 0);
      expect(charIndexFor(6, xs), 1);
      expect(charIndexFor(21, xs), 2);
      expect(charIndexFor(100, xs), xs.length);
      expect(charIndexFor(-5, xs), 0);
    });

    test('sin letra devuelve 0', () {
      expect(charIndexFor(50, const []), 0);
    });
  });

  group('acorde en medio de palabra', () {
    test('respeta el punto exacto (frent[C#m]e)', () {
      // "Da un paso al frente": el acorde va justo antes de la "e" final.
      // Cada caracter ocupa 10 unidades, as que la "e" final est en X=190.
      final line = place('C#m@186', 'Da un paso al frente');
      expect(line.lyric, 'Da un paso al frente');
      expect(line.chords.length, 1);
      expect(line.chords.single.chord, 'C#m');
      expect(line.lyric!.substring(line.chords.single.at), 'e');
    });

    test('acorde al principio de la linea', () {
      final line = place('C@0', 'Hola mundo');
      expect(line.chords.single.at, 0);
    });
  });

  group('acorde al final', () {
    test('si se pasa del final se pone al final de la linea', () {
      final line = place('C@999', 'Hola mundo');
      expect(line.chords.single.at, 'Hola mundo'.length);
    });

    test('acorde casi al final cae en el ultimo caracter', () {
      // 'Hola mundo' tiene 10 caracteres (X de 0 a 90); 85 cae en el ltimo.
      final line = place('G@85', 'Hola mundo');
      expect(line.chords.single.at, 'Hola mundo'.length - 1);
    });
  });

  group('varios acordes en la misma linea', () {
    test('se mantiene el orden y ninguno pisa a otro', () {
      final line = place('Am@0 F@40 C@120', 'Hola mundo de gracia');
      expect(line.chords.map((c) => c.chord).toList(), ['Am', 'F', 'C']);
      final ats = line.chords.map((c) => c.at).toList();
      expect(ats[0], lessThanOrEqualTo(ats[1]));
      expect(ats[1], lessThanOrEqualTo(ats[2]));
    });

    test('dos acordes en el mismo punto no se solapan', () {
      final line = place('Am@50 Am7@50', 'Hola mundo');
      expect(line.chords.length, 2);
      expect(line.chords[0].at != line.chords[1].at, isTrue);
    });
  });

  group('linea solo de acordes', () {
    test('se convierte en progresin con |', () {
      final line = chordOnlyLine(chords('C#m@0 | A@60 | E@120 | B@180'));
      expect(line.instrumental, isTrue);
      expect(line.bars, ['C#m', 'A', 'E', 'B']);
    });

    test('tambien con guiones', () {
      final line = chordOnlyLine(chords('F@0 - G@60 - Em@120'));
      expect(line.bars, ['F', 'G', 'Em']);
    });
  });

  group('ida y vuelta al formato canonico', () {
    test('texto -> modelo -> texto conserva los acordes donde estaban', () {
      final line = place('C#m@186', 'Da un paso al frente');
      final out = const ChordProSerializer().write(ChordProSong(sections: [CpSection(directive: 'verse', label: 'VERSO 1', kind: SectionKind.verse, lines: [line])]));
      expect(out, contains('frent[C#m]e'));
    });
  });
}
