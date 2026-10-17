// Modelos del importador de PDF -> ChordPro.
//
// Todo lo de esta carpeta es Dart puro (sin Flutter ni dependencias de PDF):
// se puede probar con líneas construidas a mano, que es lo que hacen los tests.
library;

/// Una palabra tal como la da el PDF, con su rectángulo y su tamaño de fuente.
class PdfWord {
  final String text;
  final double left;
  final double top;
  final double right;
  final double bottom;
  final double fontSize;

  /// Posición X de cada carácter de [text] (si el extractor la pudo dar). Si
  /// viene vacía, se calcula a partes iguales entre [left] y [right].
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

/// Una línea del PDF: palabras que comparten fila (mismo Y aproximado).
class PdfLine {
  final List<PdfWord> words;
  final int page;

  const PdfLine({required this.words, this.page = 0});

  double get top => words.isEmpty ? 0 : words.map((w) => w.top).reduce((a, b) => a < b ? a : b);
  double get bottom => words.isEmpty ? 0 : words.map((w) => w.bottom).reduce((a, b) => a > b ? a : b);
  double get left => words.isEmpty ? 0 : words.map((w) => w.left).reduce((a, b) => a < b ? a : b);
  double get right => words.isEmpty ? 0 : words.map((w) => w.right).reduce((a, b) => a > b ? a : b);
  double get height => bottom - top;

  /// Texto de la línea (palabras separadas por UN espacio).
  String get text => words.map((w) => w.text).join(' ');

  bool get isEmpty => words.every((w) => w.text.trim().isEmpty);

  /// Tamaño de fuente medio (para la tolerancia de agrupación por Y).
  double get fontSize => words.isEmpty
      ? 12
      : words.map((w) => w.fontSize).reduce((a, b) => a + b) / words.length;

  /// Posición X de cada carácter de [text], en orden.
  ///
  /// INVARIANTE: `charX.length == text.length`. Como [text] separa las
  /// palabras con un solo espacio, aquí cada hueco entre palabras aporta una
  /// sola entrada (el borde izquierdo del espacio, donde termina la palabra
  /// anterior). Antes se añadían hasta 6 entradas por hueco y todos los
  /// acordes posteriores se desplazaban.
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
      if (i + 1 < words.length) out.add(w.right);
    }
    return out;
  }
}

/// Qué tipo de contenido tiene una línea.
enum LineKind {
  /// Solo acordes (`C#m | A | E`, `F G Em`).
  chords,

  /// Letra (puede llevar algún acorde suelto).
  lyric,

  /// Encabezado de sección (`VERSO 1`, `INTRODUCCIÓN:`...).
  header,

  /// Línea vacía o solo símbolos.
  empty,
}

/// Encabezado reconocido, con su directiva canónica y su etiqueta.
class HeaderMatch {
  final String directive;
  final String label;

  /// Texto que venía después del encabezado (suele ser una progresión).
  final String rest;
  const HeaderMatch({required this.directive, required this.label, this.rest = ''});
}

/// Una línea ya clasificada.
class ClassifiedLine {
  final PdfLine line;
  final LineKind kind;
  final HeaderMatch? header;
  const ClassifiedLine({required this.line, required this.kind, this.header});

  bool get isChords => kind == LineKind.chords;
  bool get isLyric => kind == LineKind.lyric;
  bool get isHeader => kind == LineKind.header;
}

/// Lo que el importador no tiene claro y se enseña al usuario para revisar.
enum WarningKind {
  /// El acorde no encuentra letra debajo.
  chordWithoutLyric,

  /// La línea no se sabe muy bien qué es.
  ambiguous,

  /// Se ha detectado mezcla de dos columnas.
  mixedColumn,

  /// No se ha podido detectar el título.
  noTitle,

  /// El PDF no tiene texto (escaneado o foto).
  noText,
}

class ImportWarning {
  final WarningKind kind;
  final int line;
  final String message;
  const ImportWarning(this.kind, this.line, this.message);

  @override
  String toString() => 'Línea $line: $message';
}
