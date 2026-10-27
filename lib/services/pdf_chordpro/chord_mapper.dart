// Mapeo de acordes a letra por coordenadas: la X de cada acorde se compara
// con la X de los caracteres de la letra y se ancla al más cercano.
import '../../data/chordpro.dart';
import 'line_classifier.dart';
import 'pdf_models.dart';

/// Un acorde con la X de su borde izquierdo.
typedef ChordAt = ({double x, String chord});

/// Separadores de una progresión de acordes: barras y guiones.

/// Acordes de una línea de acordes, en orden de lectura.
List<ChordAt> chordsOf(PdfLine line) {
  final out = <ChordAt>[];
  for (final w in line.words) {
    final text = w.text;
    if (text.trim().isEmpty) continue;
    var pos = 0;
    for (final part in text.split(RegExp(r'[|\-–—]'))) {
      final lead = part.length - part.trimLeft().length;
      final c = part.trim();
      if (c.isNotEmpty && looksLikeChord(c)) {
        final gl = w.glyphLefts;
        final idx = pos + lead;
        final x = (gl.length == text.length && idx < gl.length) ? gl[idx] : w.left;
        out.add((x: x, chord: c));
      }
      pos += part.length + 1;
    }
  }
  return out;
}

/// Coloca los acordes sobre la letra usando fracción dentro de la palabra.
/// Devuelve la línea del modelo, con la letra limpia y los acordes anclados.
CpLine placeChordsOnLyric(List<ChordAt> chords, PdfLine lyric) {
  final text = lyric.text;
  if (chords.isEmpty) return CpLine.lyricLine(text);
  if (text.isEmpty) return CpLine.lyricLine(text);

  // Sin ninguna coordenada (todo a 0): no hay forma de saber sobre qué sílaba
  // va cada acorde, así que van al principio, en orden de lectura.
  // OJO: el texto en modo layout NO entra aquí aunque `positioned` sea false,
  // porque sus palabras sí traen columnas (ver linesFromLayoutText).
  if (!lyric.positioned && !_hasColumns(lyric)) {
    return CpLine.lyricLine(text, [for (final c in chords) CpChord(0, c.chord)]);
  }

  // Mapear cada carácter de la letra a su X usando glyphLefts de las palabras.
  final charX = <double>[];
  for (var i = 0; i < lyric.words.length; i++) {
    final w = lyric.words[i];
    if (w.glyphLefts.length == w.text.length) {
      charX.addAll(w.glyphLefts);
    } else {
      final step = w.text.isEmpty ? 0.0 : w.width / w.text.length;
      for (var k = 0; k < w.text.length; k++) {
        charX.add(w.left + step * k);
      }
    }
    if (i + 1 < lyric.words.length) {
      charX.add(w.right);
    }
  }

  // Borde derecho de la última palabra.
  final endX = lyric.words.isNotEmpty ? lyric.words.last.right : null;

  final placements = <({int at, String chord, int order})>[];

  for (var i = 0; i < chords.length; i++) {
    final c = chords[i];
    var at = charIndexFor(c.x, charX, endX: endX);
    if (at > text.length) at = text.length;

    // Si cae justo en un espacio entre palabras, el acorde pertenece a la
    // sílaba que viene después (un solo carácter más allá: el texto separa las
    // palabras con UN espacio).
    if (at < text.length && text[at].trim().isEmpty) {
      while (at < text.length && text[at].trim().isEmpty) {
        at++;
      }
      if (at >= text.length) at = text.length - 1;
    }

    // IMPORTANTE: no se resuelven "colisiones" moviendo acordes. Antes, si dos
    // acordes caían en el mismo carácter, el segundo se empujaba a la derecha
    // o se buscaba "el carácter libre más cercano", y el acorde terminaba
    // sobre otra sílaba. Dos acordes en el mismo punto son válidos en ChordPro
    // (`[Bm][A]palabra`); se quedan donde estaban, en orden de lectura.
    placements.add((at: at, chord: c.chord, order: i));
  }

  // Ordenar por posición y, si empatan, por orden de lectura (List.sort de
  // Dart no garantiza estabilidad, así que el desempate es explícito).
  placements.sort((a, b) {
    final d = a.at.compareTo(b.at);
    return d != 0 ? d : a.order.compareTo(b.order);
  });

  // La letra se entrega tal cual: sin espacios añadidos que la cambien.
  return CpLine.lyricLine(text, [
    for (final p in placements) CpChord(p.at, p.chord),
  ]);
}

/// true si las palabras de [line] traen columnas/coordenadas X utilizables
/// (right > left). Las líneas "sin nada" tienen todo a 0.
bool _hasColumns(PdfLine line) => line.words.any((w) => w.right > w.left);

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
    if (d < bestDist || (d == bestDist && i > best)) {
      bestDist = d;
      best = i;
    }
  }
  return best > charX.length ? charX.length : best;
}

/// Línea solo de acordes: se convierte en progresión `[C#m] | [A] | [E]`.
CpLine chordOnlyLine(PdfLine line) {
  final bars = <String>[];
  for (final w in line.words) {
    final text = w.text;
    if (text.trim().isEmpty) continue;
    for (final part in text.split(RegExp(r'[|\-–—]'))) {
      final c = part.trim();
      if (c.isNotEmpty && looksLikeChord(c)) bars.add(c);
    }
  }
  return CpLine.barLine(bars);
}