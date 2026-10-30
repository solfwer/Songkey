// De cajas de caracteres (como las da PDFium) a palabras con posición real.
//
// Por qué existe: para el PDF de "Serviremos al Señor" Syncfusion devuelve
// coordenadas que NO corresponden a la página (texto con tamaño de fuente 1.0
// escalado por matriz: las filas de acordes y de letra salen fundidas y la X de
// cada acorde es inventada). PDFium (el motor de Chrome) sí da la caja real de
// cada carácter; con eso cada acorde queda exactamente sobre su sílaba.
//
// Dart puro (sin Flutter ni pdfrx): el adaptador que lee el PDF está aparte
// (pdfium_extractor.dart) y este archivo se puede probar con datos a mano.
library;

import 'dart:math' as math;

import 'pdf_models.dart';

/// Un carácter del PDF con su caja en coordenadas de página con origen ARRIBA
/// a la izquierda (Y crece hacia abajo, como en el resto del importador).
class PdfCharBox {
  final String ch;
  final double left;
  final double top;
  final double right;
  final double bottom;
  final int page;

  const PdfCharBox({
    required this.ch,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    this.page = 0,
  });

  double get width => right - left;
  double get height => bottom - top;
  double get centerY => (top + bottom) / 2;

  /// Pasa de coordenadas PDF (origen abajo-izquierda, `top > bottom`) a las del
  /// importador. [pageHeight] es el alto de la página en puntos.
  factory PdfCharBox.fromPdfRect({
    required String ch,
    required double left,
    required double top,
    required double right,
    required double bottom,
    required double pageHeight,
    int page = 0,
  }) =>
      PdfCharBox(
        ch: ch,
        left: left,
        top: pageHeight - top,
        right: right,
        bottom: pageHeight - bottom,
        page: page,
      );
}

/// Fracción de la altura mediana que puede separar los centros de dos
/// caracteres de la misma fila (acentos y letras con cola varían hasta ~3 pt;
/// dos filas distintas están a 12 pt o más).
const double charRowTolerance = 0.6;

/// Un hueco mayor que esta fracción del ancho mediano de un carácter separa
/// dos palabras. Las cajas de PDFium van ajustadas al glifo, así que entre
/// letras de una misma palabra queda hasta ~0.37 del ancho mediano (letras
/// estrechas como i, l, u), mientras que entre palabras hay al menos ~0.58.
const double charWordGap = 0.47;

/// Relación aproximada entre la altura de la caja de un glifo y el tamaño de la
/// fuente (la caja de PDFium es "ajustada" al glifo).
const double _glyphHeightToFontSize = 1.25;

/// Convierte [chars] (de una o varias páginas) en palabras con `left`/`right`
/// reales y la X de cada letra en `glyphLefts`.
///
/// - Espacios y saltos de línea no se usan como caracteres (los espacios de
///   PDFium tienen altura ~0, así que no sirven para ubicar la fila), pero sí
///   como señal: un espacio entre dos letras consecutivas corta la palabra.
///   Además se corta por el hueco entre letras ([charWordGap]).
/// - Las filas se forman por la posición vertical de los caracteres.
List<PdfWord> wordsFromChars(List<PdfCharBox> chars) {
  final byPage = <int, List<_Ch>>{};
  var spaceSeen = false;
  _Ch? prev;
  for (final c in chars) {
    if (c.ch.trim().isEmpty) {
      // Un espacio / salto entre dos letras visibles consecutivas.
      spaceSeen = true;
      continue;
    }
    if (c.width <= 0 || c.height <= 0) continue;
    final item = _Ch(c, spaceBefore: spaceSeen && prev != null && prev.box.page == c.page, prev: prev);
    byPage.putIfAbsent(c.page, () => []).add(item);
    prev = item;
    spaceSeen = false;
  }

  final out = <PdfWord>[];
  for (final page in byPage.keys.toList()..sort()) {
    out.addAll(_wordsOfPage(byPage[page]!, page));
  }
  return out;
}

/// Carácter visible + si había un espacio entre él y el anterior (en el orden
/// del PDF) y quién era ese anterior.
class _Ch {
  final PdfCharBox box;
  final bool spaceBefore;
  final _Ch? prev;
  _Ch(this.box, {required this.spaceBefore, required this.prev});
}

double _median(List<double> v) {
  final s = [...v]..sort();
  final n = s.length;
  return n.isOdd ? s[n ~/ 2] : (s[n ~/ 2 - 1] + s[n ~/ 2]) / 2;
}

List<PdfWord> _wordsOfPage(List<_Ch> items, int page) {
  if (items.isEmpty) return const [];
  final medH = _median([for (final c in items) c.box.height]);
  final medW = _median([for (final c in items) c.box.width]);
  final rowTol = medH * charRowTolerance;
  final gap = medW * charWordGap;

  // 1) Filas: por la posición vertical (centro) de cada carácter.
  final sorted = [...items]..sort((a, b) => a.box.centerY.compareTo(b.box.centerY));
  final rows = <List<_Ch>>[];
  var lastY = double.negativeInfinity;
  for (final c in sorted) {
    if (rows.isEmpty || c.box.centerY - lastY > rowTol) {
      rows.add([c]);
    } else {
      rows.last.add(c);
    }
    lastY = c.box.centerY;
  }

  // 2) Palabras de cada fila: de izquierda a derecha, cortando en los huecos.
  final words = <PdfWord>[];
  for (final row in rows) {
    row.sort((a, b) => a.box.left.compareTo(b.box.left));
    final rowFont = math.max(
      _median([for (final c in row) c.box.height]) * _glyphHeightToFontSize,
      6.0,
    );

    var current = <_Ch>[];
    void flush() {
      if (current.isEmpty) return;
      final boxes = [for (final c in current) c.box];
      words.add(PdfWord(
        text: boxes.map((c) => c.ch).join(),
        left: boxes.first.left,
        top: boxes.map((c) => c.top).reduce(math.min),
        right: boxes.map((c) => c.right).reduce(math.max),
        bottom: boxes.map((c) => c.bottom).reduce(math.max),
        fontSize: rowFont,
        // Una X por unidad de texto (un carácter Unicode puede ser 2 unidades
        // UTF-16): así glyphLefts.length == text.length, como espera el mapeador.
        glyphLefts: [
          for (final c in boxes)
            for (var k = 0; k < c.ch.length; k++) c.left,
        ],
        page: page,
      ));
      current = <_Ch>[];
    }

    for (final c in row) {
      if (current.isNotEmpty) {
        final last = current.last;
        final byGap = c.box.left - last.box.right > gap;
        // El espacio solo cuenta si separa justo a estas dos letras.
        final bySpace = c.spaceBefore && identical(c.prev, last);
        if (byGap || bySpace) flush();
      }
      current.add(c);
    }
    flush();
  }
  return words;
}
