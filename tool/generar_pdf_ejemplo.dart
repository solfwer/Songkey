// Herramienta: genera docs/ejemplo_pdf_valido.pdf, un PDF de muestra con el
// formato que la app (importador PDF -> ChordPro) espera recibir.
//
// Uso: dart run tool/generar_pdf_ejemplo.dart
//
// El PDF tiene:
//   - texto real (no escaneado), con fuentes Helvetica;
//   - acordes JUSTO ENCIMA de la letra, alineados por X sobre la silaba;
//   - encabezados de seccion reconocidos (INTRODUCCION:, VERSO 1, PRECORO,
//     CORO, PUENTE, FINAL);
//   - una progresion sola (INTRODUCCION, con barras '|') y un numero de
//     pagina que el importador debe filtrar solo.
//
// No requiere Flutter: escribe el PDF 1.4 a mano con las fuentes base
// Helvetica / Helvetica-Bold. La posicion X de cada acorde se calcula con la
// tabla de anchos de Helvetica (unidades por 1000), igual que haria un
// procesador de textos real.
import 'dart:io';
import 'dart:typed_data';

// Geometria de la pagina (carta, puntos PDF: Y crece hacia arriba).
const _pageW = 612.0;
const _pageH = 792.0;
const _left = 72.0; // margen izquierdo

// Tamanos de fuente.
const _titleSize = 18.0;
const _headerSize = 12.0;
const _chordSize = 11.0;
const _lyricSize = 12.0;

// Anchos de Helvetica regular (AFM, unidades /1000). Solo hacen falta los
// caracteres que usa la cancion; cualquier otro usa 556 (ancho medio).
const _widths = <String, int>{
  ' ': 278, '!': 278, '"': 355, '#': 556, "'": 191, '(': 333, ')': 333,
  ',': 278, '-': 333, '.': 278, '/': 278, ':': 278, ';': 278, '?': 556,
  '0': 556, '1': 556, '2': 556, '3': 556, '4': 556, '5': 556, '6': 556,
  '7': 556, '8': 556, '9': 556,
  'A': 667, 'B': 667, 'C': 722, 'D': 722, 'E': 667, 'F': 611, 'G': 778,
  'H': 722, 'I': 278, 'J': 500, 'K': 667, 'L': 556, 'M': 833, 'N': 722,
  'O': 778, 'P': 667, 'Q': 778, 'R': 722, 'S': 667, 'T': 611, 'U': 722,
  'V': 667, 'W': 944, 'X': 667, 'Y': 667, 'Z': 611,
  'a': 556, 'b': 556, 'c': 500, 'd': 556, 'e': 556, 'f': 278, 'g': 556,
  'h': 556, 'i': 222, 'j': 222, 'k': 500, 'l': 222, 'm': 833, 'n': 556,
  'o': 556, 'p': 556, 'q': 556, 'r': 333, 's': 500, 't': 278, 'u': 556,
  'v': 500, 'w': 722, 'x': 500, 'y': 500, 'z': 500,
  // Acentuadas (mismo ancho que su letra base).
  'á': 556, 'é': 556, 'í': 222, 'ó': 556, 'ú': 556, 'ü': 556, 'ñ': 556,
  'Á': 667, 'É': 667, 'Í': 278, 'Ó': 778, 'Ú': 722, 'Ñ': 778,
};

double _charWidth(String ch, double size) => (_widths[ch] ?? 556) / 1000 * size;

/// Ancho acumulado de un prefijo de [text] (para saber la X del carácter i).
double _xOfCharIndex(String text, int charIndex, double size, [double x0 = _left]) {
  var x = x0;
  for (var i = 0; i < charIndex && i < text.length; i++) {
    x += _charWidth(text[i], size);
  }
  return x;
}

/// Un texto con fuente, tamano y posicion (baseline, esquina inferior izquierda).
class _Text {
  final String font; // F1 = Helvetica, F2 = Helvetica-Bold, F3 = Courier
  final double size;
  final double x;
  final double y;
  final String s;
  const _Text(this.font, this.size, this.x, this.y, this.s);
}

final _texts = <_Text>[];

void _title(String s, double y) => _texts.add(_Text('F2', _titleSize, _left, y, s));
void _header(String s, double y) => _texts.add(_Text('F2', _headerSize, _left, y, s));
void _lyric(String s, double y) => _texts.add(_Text('F1', _lyricSize, _left, y, s));

/// Linea de acordes sobre una letra: cada acorde en su propia posicion X,
/// calculada para caer sobre el indice de caracter de la letra que tiene
/// debajo (misma cuenta que haria un editor de partituras).
void _chordsOver(String lyricText, List<(String, int)> chords, double y) {
  for (final (chord, charIndex) in chords) {
    final x = _xOfCharIndex(lyricText, charIndex, _lyricSize);
    _texts.add(_Text('F1', _chordSize, x, y, chord));
  }
}

String _escape(String s) => s.replaceAll(r'\', r'\\').replaceAll('(', r'\(').replaceAll(')', r'\)');

/// Construye el contenido de la pagina (operadores de texto PDF).
Uint8List _contentStream() {
  final sb = StringBuffer();
  for (final t in _texts) {
    sb.writeln('BT /${t.font} ${t.size} Tf ${t.x} ${t.y} Td (${_escape(t.s)}) Tj ET');
  }
  return Uint8List.fromList(sb.toString().codeUnits);
}

/// Ensambla el PDF 1.4 completo con xref correcto (offsets en bytes).
Uint8List _buildPdf(Uint8List content) {
  final objects = <String>[
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 $_pageW $_pageH] '
        '/Resources << /Font << /F1 5 0 R /F2 6 0 R /F3 7 0 R >> >> /Contents 4 0 R >>',
    // El stream se anade aparte (longitud en bytes, no en caracteres).
    '',
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>',
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold /Encoding /WinAnsiEncoding >>',
    '<< /Type /Font /Subtype /Type1 /BaseFont /Courier /Encoding /WinAnsiEncoding >>',
  ];

  final out = BytesBuilder();
  void add(String s) => out.add(s.codeUnits);

  add('%PDF-1.4\n');
  final offsets = <int>[];
  for (var i = 0; i < objects.length; i++) {
    offsets.add(out.length);
    if (i == 3) {
      add('4 0 obj\n<< /Length ${content.length} >>\nstream\n');
      out.add(content);
      add('\nendstream\nendobj\n');
    } else {
      add('${i + 1} 0 obj\n${objects[i]}\nendobj\n');
    }
  }
  final xrefOffset = out.length;
  add('xref\n0 ${objects.length + 1}\n');
  add('0000000000 65535 f \n');
  for (final off in offsets) {
    add('${off.toString().padLeft(10, '0')} 00000 n \n');
  }
  add('trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\n'
      'startxref\n$xrefOffset\n%%EOF\n');
  return out.toBytes();
}

void main() {
  // --- Contenido de la cancion de ejemplo ---------------------------------
  // Cada linea de acordes se dibuja 22pt por encima de su letra.

  _title('A DANZAR', 720);

  _header('INTRODUCCIÓN:', 680);
  // Progresion sola con barras (Courier para el '|'); el importador la
  // convierte en [C#m] | [A] | [E] | [B].
  _texts.add(_Text('F3', _lyricSize, _left, 662, 'C#m | A | E | B'));

  _header('VERSO 1', 630);
  // "Señor, tú me amas para siempre"
  //                      ^tú=7  ^amas=13      ^para=18       ^siempre=23
  const v1 = 'Señor, tú me amas para siempre';
  _chordsOver(v1, [('C#m', 7), ('A', 13), ('E', 18), ('B', 23)], 610);
  _lyric(v1, 588);
  // "Tu gracia me alcanza y me levanta"
  //        ^gracia=3        ^alcanza=13            ^levanta=27
  const v2 = 'Tu gracia me alcanza y me levanta';
  _chordsOver(v2, [('G', 3), ('C#m', 13), ('A', 27)], 568);
  _lyric(v2, 546);

  _header('PRECORO', 514);
  // "Levantamos las manos al cielo"
  //  ^Levantamos=0        ^manos=11
  const pc = 'Levantamos las manos al cielo';
  _chordsOver(pc, [('A', 0), ('Bsus4', 11)], 494);
  _lyric(pc, 472);

  _header('CORO', 440);
  // "A danzar con toda mi fuerza"
  //  E=0 B=2        ^con=9               ^fuerza=21
  const co = 'A danzar con toda mi fuerza';
  _chordsOver(co, [('E', 0), ('B', 2), ('C#m', 9), ('A', 21)], 420);
  _lyric(co, 398);

  _header('PUENTE', 366);
  // "Todo es posible, todo lo podemos"
  //  ^Todo=0          ^posible=8             ^podemos=17
  const pu = 'Todo es posible, todo lo podemos';
  _chordsOver(pu, [('G', 0), ('D', 8), ('A', 17)], 346);
  _lyric(pu, 324);

  _header('FINAL', 292);
  _lyric('Gracias, Señor', 272);

  // Numero de pagina (el importador lo debe filtrar por ser solo digitos).
  _texts.add(_Text('F1', 10.0, 560, 40, '1'));

  final pdf = _buildPdf(_contentStream());
  final out = File('docs/ejemplo_pdf_valido.pdf');
  out.parent.createSync(recursive: true);
  out.writeAsBytesSync(pdf);
  stdout.writeln('PDF generado: ${out.path} (${pdf.length} bytes)');
}
