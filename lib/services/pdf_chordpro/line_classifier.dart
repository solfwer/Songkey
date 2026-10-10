// Clasificador de lneas del PDF: acordes / letra / encabezado / vaca.
//
// Reglas (las que pide el algoritmo):
//  * Una lnea es de acordes si ms del 80% de sus tokens parecen acordes.
//  * Los encabezados salen de un diccionario, aceptando variantes con y sin
//    tildes y con o sin nmero.
import '../../data/chord_parser.dart';
import 'pdf_models.dart';

/// Separadores que se descartan al trocear una lnea en tokens.
final _separator = RegExp(r'[\s|–—]+');

/// Token que parece acorde: razon A-G, #/b, calidad (m, maj7, sus4, add9,
/// dim, aug...), nmeros y bajo con `/` (G/B, A/C#m).
final _chordToken = RegExp(
  r'^\(?[A-G][#b]?(?:maj|min|m|M|dim|aug|sus|add|°|\+)?\d*(?:\([^)]*\))?(?:\/[A-G][#b]?(?:maj|min|m|M|dim|aug|sus|add|°|\+)?\d*(?:\([^)]*\))?)?\)?$',
);

/// Proporcin mnima de tokens-acorde para considerar la lnea de acordes.
const chordRatioThreshold = 0.8;

/// Palabras que son encabezado de seccin. La clave va sin tildes ni guiones.
const Map<String, String> _headerWords = {
  'introduccion': 'introduccion',
  'intro': 'introduccion',
  'presentacion': 'introduccion',
  'verso': 'verse',
  'estrofa': 'verse',
  'verse': 'verse',
  'precoro': 'chorus',
  'prechorus': 'chorus',
  'coro': 'chorus',
  'estribillo': 'chorus',
  'chorus': 'chorus',
  'puente': 'bridge',
  'bridge': 'bridge',
  'interludio': 'instrumental',
  'instrumental': 'instrumental',
  'transicion': 'transicion',
  'final': 'final',
  'outro': 'final',
  'ending': 'final',
  'tag': 'final',
};

/// Etiqueta cannica que se escribe en la directiva, para que el visor la
/// pinte con el color que toca (PRE-CORO es pre-coro, no coro).
String canonicalHeaderLabel(String directive, String word, String number) {
  final w = _plain(word);
  final n = number;
  switch (directive) {
    case 'introduccion':
      return 'INTRODUCCIÓN';
    case 'verse':
      return 'VERSO ${n.isEmpty ? '1' : n}';
    case 'chorus':
      return (w == 'precoro' || w == 'prechorus') ? 'PRE-CORO' : 'CORO';
    case 'bridge':
      return 'PUENTE';
    case 'instrumental':
      return 'INSTRUMENTAL';
    case 'transicion':
      return 'TRANSICIÓN';
    case 'final':
      return 'FINAL';
    default:
      return word.toUpperCase();
  }
}

/// Minsculas sin tildes ni signos (para comparar palabras).
String _plain(String s) => s
    .toLowerCase()
    .replaceAll('á', 'a')
    .replaceAll('é', 'e')
    .replaceAll('í', 'i')
    .replaceAll('ó', 'o')
    .replaceAll('ú', 'u')
    .replaceAll('ü', 'u')
    .replaceAll('ñ', 'n')
    .replaceAll(RegExp('[^a-z0-9]'), '');

/// Trocea una lnea en tokens, descartando los separadores (`|`, `-`, `-`).
List<String> chordTokens(String text) => text
    .split(_separator)
    .map((t) => t.trim())
    .where((t) => t.isNotEmpty)
    .toList();

/// true si el token parece un acorde.
bool looksLikeChord(String token) => _chordToken.hasMatch(token.trim());

/// Proporcin de tokens que son acordes (0..1). 0 si no hay tokens.
double chordRatio(String text) {
  final toks = chordTokens(text);
  if (toks.isEmpty) return 0;
  final chords = toks.where(looksLikeChord).length;
  return chords / toks.length;
}

/// Reconoce un encabezado de seccin al principio de la lnea.
/// Acepta `VERSO 1`, `Verso`, `INTRODUCCIN:`, `[Coro]`, `PRE-CORO:`...
HeaderMatch? matchHeader(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;
  // Se quitan los adornos de alrededor: [], (), {}, :, -
  final m = RegExp(r'^[\[\(\{<\s]*([A-Za-zÁÉÍÓÚÜÑáéíóúüñ]+(?:-[A-Za-zÁÉÍÓÚÜÑáéíóúüñ]+)*)\s*(\d*)\s*[\]\)\}>]?\s*:?\s*(.*)$').firstMatch(trimmed);
  if (m == null) return null;
  final word = m.group(1)!;
  final number = m.group(2) ?? '';
  final rest = (m.group(3) ?? '').trim();
  final directive = _headerWords[_plain(word)];
  if (directive == null) return null;
  // Falso positivo tipo "Coro de ángeles cantan": si sobra texto que no es
  // una progresin de acordes y no haba dos puntos, no es encabezado.
  if (rest.isNotEmpty && !trimmed.contains(':')) {
    final toks = chordTokens(rest);
    final pareceProgresion = toks.isNotEmpty && toks.every(looksLikeChord);
    if (!pareceProgresion) return null;
  }
  return HeaderMatch(directive: directive, label: canonicalHeaderLabel(directive, word, number), rest: rest);
}

/// Clasifica una lnea del PDF.
ClassifiedLine classifyLine(PdfLine line) {
  if (line.isEmpty || line.text.trim().isEmpty) {
    return ClassifiedLine(line: line, kind: LineKind.empty);
  }
  final header = matchHeader(line.text);
  if (header != null) {
    return ClassifiedLine(line: line, kind: LineKind.header, header: header);
  }
  if (chordRatio(line.text) >= chordRatioThreshold) {
    return ClassifiedLine(line: line, kind: LineKind.chords);
  }
  return ClassifiedLine(line: line, kind: LineKind.lyric);
}

/// Clasifica una lista de lneas.
List<ClassifiedLine> classifyLines(List<PdfLine> lines) => lines.map(classifyLine).toList();
