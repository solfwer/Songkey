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

  // Sin coordenadas fiables (texto en modo layout): los acordes van al
  // principio de la línea, en orden de lectura.
  if (!lyric.positioned) {
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
  final used = <int>{};

  for (var i = 0; i < chords.length; i++) {
    final c = chords[i];
    var at = charIndexFor(c.x, charX, endX: endX);
    if (at > text.length) at = text.length;

    // Si cae al inicio (0) y la letra empieza inmediatamente, insertar
    // un espacio antes para que no queden pegados [D][G]Nos.
    if (at == 0 && text.isNotEmpty && text[0].trim().isNotEmpty) {
      // Dejar acorde en 0 pero asegurarnos de que haya separador visual en output
      // (el serializador maneja espaciado; aquí solo evitamos desplazamiento).
      at = 0;
    }

    // Si cae en un espacio, saltar todos los espacios consecutivos.
    if (at < text.length && text[at].trim().isEmpty) {
      while (at < text.length && text[at].trim().isEmpty) {
        at++;
      }
      if (at >= text.length) at = text.length - 1;
    }

    // Resolver colisiones: mantener posición lo más cerca posible,
    // sin desplazamiento excesivo a la derecha (evita que se junten
    // los acordes en la izquierda de la línea).
    var attempts = 0;
    while (used.contains(at) && at < text.length && attempts < text.length) {
      at++;
      attempts++;
    }
    // Si después de resolver colisiones caímos en un espacio, ajustar.
    if (at < text.length && text[at].trim().isEmpty) {
      var bestAt = at;
      var bestDist = double.infinity;
      for (var check = 0; check < text.length; check++) {
        if (!used.contains(check) && text[check].trim().isNotEmpty) {
          final dist = (check - at).abs().toDouble();
          if (dist < bestDist) {
            bestDist = dist;
            bestAt = check;
          }
        }
      }
      at = bestAt;
    }
    used.add(at);
    placements.add((at: at, chord: c.chord, order: i));
  }

  // Ordenar por posición y, si empatan, por orden de lectura (List.sort de
  // Dart no garantiza estabilidad, así que el desempate es explícito).
  placements.sort((a, b) {
    final d = a.at.compareTo(b.at);
    return d != 0 ? d : a.order.compareTo(b.order);
  });

  // FIX: evitar [D][G]Nos (acordes pegados a letra sin espacio inicial)
  var outText = text;
  var outPlacements = placements;
  if (outPlacements.isNotEmpty && outPlacements.first.at == 0 && text.isNotEmpty && text[0].trim().isNotEmpty) {
    outText = ' $text';
    outPlacements = [
      for (final p in outPlacements) (at: p.at + 1, chord: p.chord, order: p.order)
    ];
  }

  return CpLine.lyricLine(outText, [
    for (final p in outPlacements) CpChord(p.at, p.chord),
  ]);
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