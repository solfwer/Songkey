// Geometría del PDF: palabras -> líneas, en Dart puro.
//
// Aquí no se decide nada de música (eso es cosa de line_classifier y
// chord_mapper): solo se ordenan las palabras por página, columna y fila para
// leer el documento en el mismo orden que lo leería una persona.
import 'dart:math' as math;

import 'pdf_models.dart';

/// Hueco mínimo (en puntos) entre columnas para partir la página en dos.
const double columnGapThresholdPt = 12;

/// Tolerancia vertical para agrupar palabras en una línea: fracción de la
/// altura mediana de las palabras de la columna.
const double lineGroupTolerance = 0.5;

/// Fracción mínima del texto (en caracteres) que debe tener CADA lado para que
/// el hueco cuente como separación de columnas. Evita tomar por columna unos
/// pocos acordes pegados al borde derecho de una canción de una sola columna.
const double columnMinTextShare = 0.2;

/// Filas distintas mínimas en cada lado para aceptar dos columnas.
const int columnMinRows = 3;

/// Banda de la página donde se busca el hueco entre columnas (25%..75%).
const double columnSearchStart = 0.25;
const double columnSearchEnd = 0.75;

/// Aplana todas las palabras de todas las líneas, conservando su página.
List<PdfWord> flattenWords(List<PdfLine> lines) => [
      for (final l in lines)
        for (final w in l.words)
          if (w.text.trim().isNotEmpty) w,
    ];

/// X donde cortar la página en dos columnas, o null si hay una sola.
///
/// Se miran los huecos reales (del `right` de una palabra al `left` de la
/// siguiente) y se elige el más ancho de la banda central. Un hueco de una
/// sola línea (un título centrado, palabras sueltas) no vale: hace falta que
/// haya palabras a ambos lados y que compartan altura.
double? detectColumnSplit(List<PdfWord> words, double pageWidth) {
  if (words.length < 6) return null;
  final minX = pageWidth * columnSearchStart;
  final maxX = pageWidth * columnSearchEnd;
  final sorted = [...words]..sort((a, b) => a.left.compareTo(b.left));

  var bestGap = 0.0;
  double? bestSplit;
  var maxRight = double.negativeInfinity;
  for (final w in sorted) {
    if (maxRight.isFinite) {
      final start = math.max(maxRight, minX);
      final end = math.min(w.left, maxX);
      if (end - start >= columnGapThresholdPt && end - start > bestGap) {
        bestGap = end - start;
        bestSplit = (start + end) / 2;
      }
    }
    maxRight = math.max(maxRight, w.right);
  }
  if (bestSplit == null) return null;
  final split = bestSplit;

  final left = words.where((w) => w.right <= split).toList();
  final right = words.where((w) => w.left >= split).toList();
  if (left.length < 3 || right.length < 3) return null;

  // Una columna real tiene una cantidad de texto comparable a la otra y varias
  // filas. Unos pocos acordes al borde derecho de una canción de UNA columna
  // (el hueco existe, pero casi no hay texto) no son una columna: partirlos
  // separa el acorde de su línea y lo deja huérfano.
  int chars(List<PdfWord> ws) =>
      ws.fold(0, (sum, w) => sum + w.text.trim().length);
  final total = chars(words);
  if (total == 0) return null;
  if (chars(left) < total * columnMinTextShare ||
      chars(right) < total * columnMinTextShare) {
    return null;
  }
  if (_rowCount(left) < columnMinRows || _rowCount(right) < columnMinRows) {
    return null;
  }

  final leftTop = left.map((w) => w.top).reduce(math.min);
  final leftBottom = left.map((w) => w.bottom).reduce(math.max);
  final rightTop = right.map((w) => w.top).reduce(math.min);
  final rightBottom = right.map((w) => w.bottom).reduce(math.max);
  final overlap = math.min(leftBottom, rightBottom) - math.max(leftTop, rightTop);
  return overlap > 0 ? split : null;
}

/// Agrupa las palabras en líneas: página -> columna (la izquierda entera y
/// luego la derecha) -> fila. Dentro de cada línea, de izquierda a derecha.
///
/// [tolerance] es la fracción de la altura mediana de las palabras que puede
/// separar dos palabras de la misma fila. Si el PDF da alturas infladas, con la
/// tolerancia por defecto la fila de acordes y la de letra se funden: bajarla
/// las separa.
List<PdfLine> groupLines(
  List<PdfWord> words,
  double splitX, {
  double tolerance = lineGroupTolerance,
}) {
  final lines = <PdfLine>[];
  final pages = words.map((w) => w.page).toSet().toList()..sort();
  for (final page in pages) {
    final pageWords = words.where((w) => w.page == page);
    for (final leftColumn in const [true, false]) {
      final column = pageWords.where((w) => (w.left < splitX) == leftColumn);
      lines.addAll(_groupColumn(column, page, tolerance));
    }
  }
  // IMPORTANTE: NO reordenar `lines` por Y aquí. El orden es página -> columna
  // (izquierda entera, luego derecha) -> fila. Mezclar las columnas por Y
  // intercala "acordes izq, acordes der, letra izq, letra der" y rompe la
  // pareja acorde/letra que busca el servicio (la línea siguiente).
  return lines;
}

List<PdfLine> _groupColumn(Iterable<PdfWord> words, int page, double factor) {
  final column = words.toList();
  if (column.isEmpty) return const [];
  final tolerance = _medianHeight(column) * factor;
  final sorted = [...column]..sort((a, b) {
      final t = _centerY(a).compareTo(_centerY(b));
      return t != 0 ? t : a.left.compareTo(b.left);
    });

  final lines = <PdfLine>[];
  var row = <PdfWord>[];
  double? rowY;
  for (final w in sorted) {
    final y = _centerY(w);
    if (rowY == null || (y - rowY).abs() <= tolerance) {
      row.add(w);
      rowY ??= y;
      continue;
    }
    lines.add(PdfLine(words: _sortedByX(row), page: page));
    row = [w];
    rowY = y;
  }
  if (row.isNotEmpty) lines.add(PdfLine(words: _sortedByX(row), page: page));
  return lines;
}

/// Número de filas distintas (por centro Y) de un grupo de palabras.
int _rowCount(List<PdfWord> words) {
  if (words.isEmpty) return 0;
  final tol = _medianHeight(words) * lineGroupTolerance;
  final ys = words.map(_centerY).toList()..sort();
  var rows = 1;
  var rowY = ys.first;
  for (final y in ys.skip(1)) {
    if (y - rowY > tol) {
      rows++;
      rowY = y;
    }
  }
  return rows;
}

List<PdfWord> _sortedByX(List<PdfWord> words) =>
    [...words]..sort((a, b) => a.left.compareTo(b.left));

double _centerY(PdfWord w) => (w.top + w.bottom) / 2;

/// Altura mediana de las palabras: la tolerancia de línea se mide con ella,
/// no con el tamaño de la primera palabra (que a veces es un acorde suelto).
double _medianHeight(List<PdfWord> words) {
  final heights = words.map((w) => w.height).toList()..sort();
  final mid = heights.length ~/ 2;
  final median = heights.length.isOdd
      ? heights[mid]
      : (heights[mid - 1] + heights[mid]) / 2;
  return math.max(median, 1);
}
