// Mapeo de acordes a letra por posicin.
//
// Para cada acorde se toma su X (borde izquierdo) y se busca, en la linea de
// letra de debajo, el carcter cuya X es la ms cercana. El acorde se inserta
// justo delante de ese carcter: si cae dentro de una palabra se respeta el
// punto exacto (`frent[C#m]e`), y si se pasa del final se pone al final.
import '../../data/chord_parser.dart';
import '../../data/chordpro.dart';
import 'pdf_models.dart';

/// Un acorde con la X de su borde izquierdo.
typedef ChordAt = ({double x, String chord});

/// Acordes de una linea de acordes, en orden de lectura.
List<ChordAt> chordsOf(PdfLine line) {
  final out = <ChordAt>[];
  for (final w in line.words) {
    if (w.text.trim().isEmpty) continue;
    for (final part in w.text.split(_bars)) {
      final c = part.trim();
      if (c.isNotEmpty) out.add((x: w.left, chord: c));
    }
  }
  return out;
}

/// Separadores de una progresin de acordes: barras y guiones.
final _bars = RegExp(r'[|\-–—]');

/// ndice del carcter de [charX] ms cercano a [x]. Si [x] cae a la derecha
/// del ultimo carcter, devuelve `charX.length` (final de la linea).
int charIndexFor(double x, List<double> charX) {
  if (charX.isEmpty) return 0;
  if (x >= charX.last) return charX.length;
  if (x <= charX.first) return 0;
  var best = 0;
  var bestDist = double.infinity;
  for (var i = 0; i < charX.length; i++) {
    final d = (charX[i] - x).abs();
    // A igual distancia gana el caracter de la derecha: el acorde suena
    // delante de la silaba que viene despues.
    if (d <= bestDist) {
      bestDist = d;
      best = i;
    }
  }
  return best;
}

/// Coloca los acordes sobre la letra y devuelve la linea del modelo, con la
/// letra limpia (sin corchetes) y los acordes anclados a su carcter.
CpLine placeChordsOnLyric(List<ChordAt> chords, PdfLine lyric) {
  final text = lyric.text;
  if (chords.isEmpty) return CpLine.lyricLine(text);
  final xs = lyric.charX;

  final placements = <({int at, String chord})>[];
  final used = <int>{};
  for (final c in chords) {
    var at = charIndexFor(c.x, xs);
    // Si dos acordes caen en el mismo punto, el segundo se desplaza un
    // carcter a la derecha para que no se pisen.
    while (used.contains(at) && at < text.length) {
      at++;
    }
    used.add(at);
    placements.add((at: at, chord: c.chord));
  }
  placements.sort((a, b) => a.at.compareTo(b.at));
  return CpLine.lyricLine(text, [
    for (final p in placements) CpChord(p.at, p.chord),
  ]);
}

/// Linea solo de acordes: se convierte en progresin `[C#m] | [A] | [E]`.
CpLine chordOnlyLine(PdfLine line) {
  final bars = <String>[];
  for (final w in line.words) {
    for (final part in w.text.split(_bars)) {
      final c = part.trim();
      if (c.isNotEmpty) bars.add(c);
    }
  }
  return CpLine.barLine(bars);
}
