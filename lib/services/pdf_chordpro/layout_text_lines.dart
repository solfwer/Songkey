// Líneas a partir del texto en "modo layout" del PDF.
//
// El texto en modo layout reproduce la página con espacios: la columna donde
// empieza cada palabra es (aprox.) su posición X. Esa columna es lo que dice
// sobre qué sílaba va cada acorde, así que NO se puede recortar ni colapsar.
//
// Dart puro (sin Flutter ni Syncfusion) para poder probarlo con texto a mano.
library;

import 'pdf_models.dart';

/// Convierte [text] (una página en modo layout) en líneas con columnas.
///
/// - Cada palabra lleva `left`/`right` = columna de inicio/fin y `glyphLefts`
///   = columna de cada carácter. Así el mapeador de acordes puede anclar cada
///   acorde a la letra que tiene debajo.
/// - `top`/`bottom` se dejan a 0: en este modo no hay coordenadas verticales y
///   el orden de las líneas es el del texto.
/// - Se mantiene `positioned: false` para que el servicio no intente agrupar
///   ni detectar columnas de página con estas coordenadas.
List<PdfLine> linesFromLayoutText(String text, {int page = 0}) {
  final out = <PdfLine>[];
  for (final raw in text.split('\n')) {
    // Sin trim: los espacios a la izquierda y entre palabras SON la posición.
    final line = raw.replaceAll('\r', '').replaceAll('\t', ' ');
    final clean = line.trim();
    if (clean.isEmpty) continue;
    if (RegExp(r'^\d{1,3}$').hasMatch(clean)) continue; // nº de página

    final words = <PdfWord>[
      for (final m in RegExp(r'\S+').allMatches(line))
        PdfWord(
          text: m.group(0)!,
          left: m.start.toDouble(),
          top: 0,
          right: m.end.toDouble(),
          bottom: 0,
          glyphLefts: [
            for (var k = 0; k < m.end - m.start; k++) (m.start + k).toDouble(),
          ],
          page: page,
        ),
    ];
    if (words.isEmpty) continue;
    out.add(PdfLine(words: words, page: page, positioned: false));
  }
  return out;
}
