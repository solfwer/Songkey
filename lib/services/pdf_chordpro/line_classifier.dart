// Clasificador de líneas del PDF: acordes / letra / encabezado / vacía.
//
// Reglas (las que pide el algoritmo):
//  * Una línea es de acordes si más del 70% de sus tokens parecen acordes.
//  * Los encabezados salen de un diccionario, aceptando variantes con y sin
//    tildes y con o sin número.
import 'dart:math' as math;

import 'pdf_models.dart';

/// Separadores que se descartan al trocear una línea en tokens.
final _separator = RegExp(r'[\s|–—]+');

/// Token que parece acorde: raíz A-G, #/b, calidad (m, maj7, sus4, add9,
/// dim, aug...), números y bajo con `/` (G/B, A/C#m).
final _chordToken = RegExp(
  r'^\(?[A-G][#b]?(?:maj|min|m|M|dim|aug|sus|add|°|\+)?\d*(?:\([^)]*\))?(?:\/[A-G][#b]?(?:maj|min|m|M|dim|aug|sus|add|°|\+)?\d*(?:\([^)]*\))?)?\)?$',
);

/// Proporción mínima de tokens-acorde para considerar la línea de acordes.
///
/// 0.7 permite reconocer líneas de acordes que traen algún token extra
/// (separador, número de compás, etc.) sin clasificarlas como letra.
const chordRatioThreshold = 0.7;

/// Palabras que son encabezado de sección. La clave va sin tildes ni guiones.
const Map<String, String> _headerWords = {
  'introduccion': 'introduccion',
  'intro': 'introduccion',
  'presentacion': 'introduccion',
  'presentation': 'introduccion', // inglés
  'verso': 'verse',
  'estrofa': 'verse',
  'verse': 'verse',
  'stanza': 'verse',          // inglés
  'precoro': 'chorus',
  'prechorus': 'chorus',      // inglés sin guion
  'pre coro': 'chorus',       // con espacio
  'pre chorus': 'chorus',     // inglés con espacio
  'pre-coro': 'chorus',       // con guion
  'pre-chorus': 'chorus',     // inglés con guion
  'coro': 'chorus',
  'estribillo': 'chorus',
  'chorus': 'chorus',
  'refrain': 'chorus',        // inglés
  'puente': 'bridge',
  'bridge': 'bridge',
  'interludio': 'instrumental',
  'instrumental': 'instrumental',
  'interlude': 'instrumental', // inglés
  'transicion': 'transicion',
  'transition': 'transicion', // inglés
  'final': 'final',
  'outro': 'final',
  'ending': 'final',
  'tag': 'final',
  'coda': 'final',            // coda musical
  'medley': 'medley',          // medley musical
};

/// Etiqueta canónica que se escribe en la directiva, para que el visor la
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
      return w == 'tag' ? 'TAG' : 'FINAL';
    case 'medley':
      return 'MEDLEY';
    default:
      return word.toUpperCase();
  }
}

/// Minúsculas sin tildes ni signos (para comparar palabras).
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

/// Trocea una línea en tokens, descartando los separadores (`|`, `-`, `—`) y
/// los adornos sin texto (`//`, `%`).
List<String> chordTokens(String text) => text
    .split(_separator)
    .map((t) => t.trim())
    .where((t) => t.isNotEmpty && RegExp(r'[A-Za-z0-9]').hasMatch(t))
    .toList();

/// true si el token parece un acorde.
bool looksLikeChord(String token) => _chordToken.hasMatch(token.trim());

/// Proporción de tokens que son acordes (0..1). 0 si no hay tokens.
double chordRatio(String text) {
  final toks = chordTokens(text);
  if (toks.isEmpty) return 0;
  final chords = toks.where(looksLikeChord).length;
  return chords / toks.length;
}

/// Reconoce un encabezado de sección.
///
/// Acepta `VERSO 1`, `Verso`, `INTRODUCCIÓN:`, `[Coro]`, `PRE-CORO:` y también
/// el encabezado pegado a la letra o precedido del acorde que el PDF pinta
/// encima: `CORO Fuimos rescatados`, `G TAG No nos cansaremos`.
HeaderMatch? matchHeader(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;

  final raw = trimmed.split(RegExp(r'\s+'));
  final words = raw.map(_trimWord).toList();
  // El acorde de encima del margen puede quedar antes de la etiqueta.
  var start = 0;
  while (start < words.length && start < _maxLeadingChords && looksLikeChord(words[start])) {
    start++;
  }

  for (var n = math.min(_maxHeaderWords, words.length - start); n >= 1; n--) {
    final label = words.sublist(start, start + n).join(' ');
    final directive = _headerWords[_plain(label)];
    if (directive == null) continue;

    var index = start + n;
    var number = '';
    if (index < words.length && RegExp(r'^\d{1,2}$').hasMatch(words[index])) {
      number = words[index];
      index++;
    }
    var repeat = '';
    if (index < words.length && RegExp(r'^x\d+$').hasMatch(words[index])) {
      repeat = words[index];
      index++;
    }
    final rest = raw.skip(index).join(' ');

    // Falso positivo tipo "Coro de ángeles cantan": si sobra texto que no es
    // una progresión de acordes y la etiqueta no va en mayúsculas, es letra.
    if (rest.isNotEmpty && !trimmed.contains(':')) {
      final toks = chordTokens(rest);
      final pareceProgresion = toks.isNotEmpty && toks.every(looksLikeChord);
      if (!pareceProgresion && !_isUpperLabel(label)) continue;
    }

    var outLabel = canonicalHeaderLabel(directive, label, number);
    if (repeat.isNotEmpty) outLabel = '$outLabel $repeat';
    return HeaderMatch(
      directive: directive,
      label: outLabel,
      rest: rest,
      wordCount: index,
    );
  }
  return null;
}

/// Cuántas palabras puede ocupar una etiqueta (`pre coro`, `versículo`...).
const int _maxHeaderWords = 3;

/// Acordes que se saltan antes de la etiqueta (el PDF los pinta encima).
const int _maxLeadingChords = 4;

/// Quita los adornos pegados a una palabra: `[Coro]`, `INTRO:`, `x2)`.
String _trimWord(String w) => w
    .replaceFirst(RegExp(r'^[\[\(\{<>]+'), '')
    .replaceFirst(RegExp(r'[\]\)\}>:.,;]+$'), '');

/// true si la etiqueta va en mayúsculas (`VERSO`, `CORO`), señal de que es un
/// rótulo y no la primera palabra de la letra.
bool _isUpperLabel(String w) => w == w.toUpperCase() && w != w.toLowerCase();

/// Clasifica una línea del PDF.
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

/// Clasifica una lista de líneas.
List<ClassifiedLine> classifyLines(List<PdfLine> lines) => lines.map(classifyLine).toList();