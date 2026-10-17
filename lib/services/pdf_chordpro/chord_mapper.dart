// Mapeo de acordes a letra por posición.
//
// Para cada acorde se toma su X (borde izquierdo) y se busca, en la línea de
// letra de debajo, el carácter cuya X es la más cercana. El acorde se inserta
// justo delante de ese carácter: si cae dentro de una palabra se respeta el
// punto exacto (`frent[C#m]e`), y si se pasa del final se pone al final.
//
// Cambios respecto a la versión anterior:
//   - charIndexFor usa también el borde DERECHO de la línea: un acorde sobre
//     la última letra ya no se va al final.
//   - Si el punto elegido es un espacio, el acorde se pasa a la letra
//     siguiente (`Santo [G]santo` en vez de `Santo[G] santo`).
//   - Orden estable cuando dos acordes terminan en el mismo índice
//     (List.sort de Dart no garantiza estabilidad).
//   - Si una "palabra" de acordes trae varios separados por barras
//     ("C|G"), cada uno usa su propia X en vez de la X de la palabra.
//   - El índice se limita al largo del texto (nunca fuera de rango).
//   - Los tokens que no parecen acordes (ej. "hola", "CORO:") se descartan.
import '../../data/chordpro.dart';
import 'line_classifier.dart';
import 'pdf_models.dart';

/// Un acorde con la X de su borde izquierdo.
typedef ChordAt = ({double x, String chord});

/// Separadores de una progresión de acordes: barras y guiones.
final _bars = RegExp(r'[|\-–—]');

/// Acordes de una línea de acordes, en orden de lectura.
List<ChordAt> chordsOf(PdfLine line) {
  final out = <ChordAt>[];
  for (final w in line.words) {
    final text = w.text;
    if (text.trim().isEmpty) continue;
    var pos = 0; // posición de la parte actual dentro de [text]
    for (final part in text.split(_bars)) {
      final lead = part.length - part.trimLeft().length;
      final c = part.trim();
      if (c.isNotEmpty && looksLikeChord(c)) {
        // Con glifos se usa la X exacta del primer carácter del acorde.
        final gl = w.glyphLefts;
        final idx = pos + lead;
        final x = (gl.length == text.length && idx < gl.length) ? gl[idx] : w.left;
        out.add((x: x, chord: c));
      }
      pos += part.length + 1; // +1 por el separador (un solo carácter)
    }
  }
  return out;
}

/// Índice del borde de carácter más cercano a [x].
///
/// [charX] son los bordes izquierdos de cada carácter. [endX] es el borde
/// derecho de la línea; con él, un acorde sobre la última letra se redondea
/// bien (a la última letra o al final, el que quede más cerca). Si [x] cae a
/// la derecha de todo, devuelve `charX.length` (final de la línea).
int charIndexFor(double x, List<double> charX, {double? endX}) {
  if (charX.isEmpty) return 0;
  final hasEnd = endX != null && endX > charX.last;
  final edges = hasEnd ? [...charX, endX] : charX;
  if (x <= edges.first) return 0;
  if (x >= edges.last) return charX.length;
  var best = 0;
  var bestDist = double.infinity;
  for (var i = 0; i < edges.length; i++) {
    final d = (edges[i] - x).abs();
    // A igual distancia gana el carácter de la derecha: el acorde suena
    // delante de la sílaba que viene después.
    if (d <= bestDist) {
      bestDist = d;
      best = i;
    }
  }
  return best > charX.length ? charX.length : best;
}

/// Coloca los acordes sobre la letra y devuelve la línea del modelo, con la
/// letra limpia (sin corchetes) y los acordes anclados a su carácter.
CpLine placeChordsOnLyric(List<ChordAt> chords, PdfLine lyric) {
  final text = lyric.text;
  if (chords.isEmpty) return CpLine.lyricLine(text);
  final xs = lyric.charX;

  // Borde derecho de la línea de letra.
  double? endX;
  for (final w in lyric.words) {
    if (endX == null || w.right > endX) endX = w.right;
  }

  final placements = <({int at, int order, String chord})>[];
  final used = <int>{};
  for (var i = 0; i < chords.length; i++) {
    final c = chords[i];
    var at = charIndexFor(c.x, xs, endX: endX);
    if (at > text.length) at = text.length;

    // Si cae en un espacio, el acorde pertenece a la palabra que sigue.
    while (at < text.length && text[at].trim().isEmpty) {
      at++;
    }

    // Si dos acordes caen en el mismo punto, el segundo se desplaza un
    // carácter a la derecha (saltando espacios) para que no se pisen.
    while (used.contains(at) && at < text.length) {
      at++;
      while (at < text.length && text[at].trim().isEmpty) {
        at++;
      }
    }
    used.add(at);
    placements.add((at: at, order: i, chord: c.chord));
  }

  // Orden estable: por posición y, si empatan, por orden de lectura.
  placements.sort((a, b) {
    final d = a.at.compareTo(b.at);
    return d != 0 ? d : a.order.compareTo(b.order);
  });

  return CpLine.lyricLine(text, [
    for (final p in placements) CpChord(p.at, p.chord),
  ]);
}

/// Línea solo de acordes: se convierte en progresión `[C#m] | [A] | [E]`.
CpLine chordOnlyLine(PdfLine line) {
  final bars = <String>[];
  for (final w in line.words) {
    final text = w.text;
    if (text.trim().isEmpty) continue;
    for (final part in text.split(_bars)) {
      final c = part.trim();
      if (c.isNotEmpty && looksLikeChord(c)) bars.add(c);
    }
  }
  return CpLine.barLine(bars);
}
