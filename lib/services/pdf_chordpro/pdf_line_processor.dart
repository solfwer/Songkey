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

  final leftTop = left.map((w) => w.top).reduce(math.min);
  final leftBottom = left.map((w) => w.bottom).reduce(math.max);
  final rightTop = right.map((w) => w.top).reduce(math.min);
  final rightBottom = right.map((w) => w.bottom).reduce(math.max);
  final overlap = math.min(leftBottom, rightBottom) - math.max(leftTop, rightTop);
  return overlap > 0 ? split : null;
}

/// Agrupa las palabras en líneas: página -> columna (la izquierda entera y
/// luego la derecha) -> fila. Dentro de cada línea, de izquierda a derecha.
List<PdfLine> groupLines(List<PdfWord> words, double splitX) {
  final lines = <PdfLine>[];
  final pages = words.map((w) => w.page).toSet().toList()..sort();
  for (final page in pages) {
    final pageWords = words.where((w) => w.page == page);
    for (final leftColumn in const [true, false]) {
      final column = pageWords.where((w) => (w.left < splitX) == leftColumn);
      lines.addAll(_groupColumn(column, page));
    }
  }
  // FIX: evitar que todos los acordes/letras de la izquierda se junten
  // antes que los de la derecha en canciones de 2 columnas.
  lines.sort((a, b) {
    final pageCmp = a.page.compareTo(b.page);
    if (pageCmp != 0) return pageCmp;
    // Ordenar por centro Y (fila) primero, luego por X (columna/izq)
    final yA = a.words.isNotEmpty ? (a.words.first.top + a.words.first.bottom) / 2 : 0;
    final yB = b.words.isNotEmpty ? (b.words.first.top + b.words.first.bottom) / 2 : 0;
    final yCmp = yA.compareTo(yB);
    if (yCmp != 0) return yCmp;
    final xA = a.words.isNotEmpty ? a.words.first.left : 0;
    final xB = b.words.isNotEmpty ? b.words.first.left : 0;
    return xA.compareTo(xB);
  });
  return lines;
}

List<PdfLine> _groupColumn(Iterable<PdfWord> words, int page) {
  final column = words.toList();
  if (column.isEmpty) return const [];
  final tolerance = _medianHeight(column) * lineGroupTolerance;
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
