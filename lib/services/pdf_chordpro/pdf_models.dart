// Modelos del importador de PDF -> ChordPro.
//
// Todo lo de esta carpeta es Dart puro (sin Flutter ni dependencias de PDF):
// se puede probar con lneas construidas a mano, que es lo que hacen los tests.
library;

/// Una palabra tal como la da el PDF, con su rectngulo y su tamao de fuente.
class PdfWord {
  final String text;
  final double left;
  final double top;
  final double right;
  final double bottom;
  final double fontSize;

  /// Posicin X de cada carcter de [text] (si el extractor la pudo dar). Si
  /// viene vaca, se calcula a partes iguales entre [left] y [right].
  final List<double> glyphLefts;

  const PdfWord({
    required this.text,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    this.fontSize = 12,
    this.glyphLefts = const [],
  });

  double get width => right - left;
  double get height => bottom - top;
}

/// Una lnea del PDF: palabras que comparten fila (mismo Y aproximado).
class PdfLine {
  final List<PdfWord> words;
  final int page;

  const PdfLine({required this.words, this.page = 0});

  double get top => words.isEmpty ? 0 : words.map((w) => w.top).reduce((a, b) => a < b ? a : b);
  double get bottom => words.isEmpty ? 0 : words.map((w) => w.bottom).reduce((a, b) => a > b ? a : b);
  double get left => words.isEmpty ? 0 : words.map((w) => w.left).reduce((a, b) => a < b ? a : b);
  double get right => words.isEmpty ? 0 : words.map((w) => w.right).reduce((a, b) => a > b ? a : b);
  double get height => bottom - top;

  /// Texto de la lnea (palabras separadas por un espacio).
  String get text => words.map((w) => w.text).join(' ');

  bool get isEmpty => words.every((w) => w.text.trim().isEmpty);

  /// Tamao de fuente medio (para la tolerancia de agrupacin por Y).
  double get fontSize => words.isEmpty
      ? 12
      : words.map((w) => w.fontSize).reduce((a, b) => a + b) / words.length;

  /// Posicin X estimada de cada carcter del texto de la lnea, en orden.
  /// Los espacios entre palabras se interpolan con el hueco real.
  List<double> get charX {
    final out = <double>[];
    for (var i = 0; i < words.length; i++) {
      final w = words[i];
      if (w.glyphLefts.length == w.text.length) {
        out.addAll(w.glyphLefts);
      } else {
        final step = w.text.isEmpty ? 0.0 : w.width / w.text.length;
        for (var k = 0; k < w.text.length; k++) {
          out.add(w.left + step * k);
        }
      }
      // Hueco hasta la palabra siguiente.
      if (i + 1 < words.length) {
        final gap = words[i + 1].left - w.right;
        final steps = gap > 0 ? (gap / (w.fontSize * 0.28)).round().clamp(1, 6) : 1;
        for (var s = 0; s < steps; s++) {
          out.add(w.right + gap * (s + 1) / steps);
        }
      }
    }
    return out;
  }
}

/// Qu tipo de contenido tiene una lnea.
enum LineKind {
  /// Solo acordes (`C#m | A | E`, `F G Em`).
  chords,

  /// Letra (puede llevar algn acorde suelto).
  lyric,

  /// Encabezado de seccin (`VERSO 1`, `INTRODUCCIN:`...).
  header,

  /// Lnea vacia o slo smbolos.
  empty,
}

/// Encabezado reconocido, con su directiva cannica y su etiqueta.
class HeaderMatch {
  final String directive;
  final String label;

  /// Texto que vena despus del encabezado (suele ser una progresin).
  final String rest;
  const HeaderMatch({required this.directive, required this.label, this.rest = ''});
}

/// Una lnea ya clasificada.
class ClassifiedLine {
  final PdfLine line;
  final LineKind kind;
  final HeaderMatch? header;
  const ClassifiedLine({required this.line, required this.kind, this.header});

  bool get isChords => kind == LineKind.chords;
  bool get isLyric => kind == LineKind.lyric;
  bool get isHeader => kind == LineKind.header;
}

/// Lo que el importador no tiene claro y se ensea al usuario para revisar.
enum WarningKind {
  /// El acorde no encuentra letra debajo.
  chordWithoutLyric,

  /// La lnea no se sabe muy bien qu es.
  ambiguous,

  /// Se ha detectado mezcla de dos columnas.
  mixedColumn,

  /// No se ha podido detectar el ttulo.
  noTitle,
}

class ImportWarning {
  final WarningKind kind;
  final int line;
  final String message;
  const ImportWarning(this.kind, this.line, this.message);

  @override
  String toString() => 'Lnea $line: $message';
}
