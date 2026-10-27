// PDF de dos columnas generado en memoria: comprueba que el reparto por
// columnas (detectColumnSplit + groupLines) lee la izquierda entera antes que
// la derecha y no mezcla palabras de las dos.
import 'dart:typed_data';

import 'package:appchords/services/pdf_chordpro/pdf_to_chordpro_service.dart';
import 'package:flutter_test/flutter_test.dart';

const _left = 72.0;
const _right = 320.0;

/// Texto en una posición absoluta de la página.
typedef _Text = ({String font, double size, double x, double y, String s});

_Text _t(String font, double size, double x, double y, String s) =>
    (font: font, size: size, x: x, y: y, s: s);

/// Página carta con dos columnas de (acorde / letra). Sin título que cruce el
/// hueco: el caso del título centrado a todo el ancho queda fuera de esto.
Uint8List _twoColumnPdf() {
  const pageW = 612.0, pageH = 792.0;
  final texts = <_Text>[
    _t('F2', 18, _left, 720, 'DOS COLUMNAS'),

    _t('F2', 12, _left, 690, 'VERSO 1'),
    _t('F1', 11, _left, 672, 'C'),
    _t('F1', 11, _left + 40, 672, 'G'),
    _t('F1', 12, _left, 656, 'Hola mundo de prueba'),
    _t('F1', 11, _left, 638, 'Am'),
    _t('F1', 11, _left + 40, 638, 'F'),
    _t('F1', 12, _left, 622, 'Otra linea distinta'),
    _t('F1', 11, _left, 604, 'C'),
    _t('F1', 12, _left, 588, 'Tercera linea de aqui'),

    _t('F2', 12, _right, 690, 'VERSO 2'),
    _t('F1', 11, _right, 672, 'D'),
    _t('F1', 11, _right + 40, 672, 'A'),
    _t('F1', 12, _right, 656, 'Segunda columna aqui'),
    _t('F1', 11, _right, 638, 'Em'),
    _t('F1', 11, _right + 40, 638, 'B'),
    _t('F1', 12, _right, 622, 'Y su letra tambien'),
    _t('F1', 11, _right, 604, 'D'),
    _t('F1', 12, _right, 588, 'Cierra la columna'),
  ];

  String esc(String s) => s.replaceAll(r'\', r'\\').replaceAll('(', r'\(').replaceAll(')', r'\)');
  final content = StringBuffer();
  for (final t in texts) {
    content.writeln('BT /${t.font} ${t.size} Tf ${t.x} ${t.y} Td (${esc(t.s)}) Tj ET');
  }
  final bytes = Uint8List.fromList(content.toString().codeUnits);

  final objects = <String>[
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 $pageW $pageH] '
        '/Resources << /Font << /F1 5 0 R /F2 6 0 R >> >> /Contents 4 0 R >>',
    '',
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>',
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold /Encoding /WinAnsiEncoding >>',
  ];

  final out = BytesBuilder();
  void add(String s) => out.add(s.codeUnits);

  add('%PDF-1.4\n');
  final offsets = <int>[];
  for (var i = 0; i < objects.length; i++) {
    offsets.add(out.length);
    if (i == 3) {
      add('4 0 obj\n<< /Length ${bytes.length} >>\nstream\n');
      out.add(bytes);
      add('\nendstream\nendobj\n');
    } else {
      add('${i + 1} 0 obj\n${objects[i]}\nendobj\n');
    }
  }
  final xref = out.length;
  add('xref\n0 ${objects.length + 1}\n');
  add('0000000000 65535 f \n');
  for (final off in offsets) {
    add('${off.toString().padLeft(10, '0')} 00000 n \n');
  }
  add('trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\n'
      'startxref\n$xref\n%%EOF\n');
  return out.toBytes();
}

/// Texto sin marcas de acorde, para comparar la letra.
String _plain(String chordPro) => chordPro.replaceAll(RegExp(r'\[[^\]]*\]'), '');

void main() {
  test('dos columnas: la izquierda entera antes que la derecha', () {
    final res = const PdfToChordProService().convert(_twoColumnPdf());
    final plain = _plain(res.chordPro);

    expect(res.title, 'DOS COLUMNAS');
    expect(res.columns, 2);

    // Todo lo de la izquierda (incluida su última línea) va antes que la
    // primera línea de la derecha.
    expect(plain.indexOf('Tercera linea de aqui'), greaterThan(-1));
    expect(plain.indexOf('Tercera linea de aqui'), lessThan(plain.indexOf('Segunda columna aqui')));

    expect(plain, contains('Hola mundo de prueba'));
    expect(plain, contains('Otra linea distinta'));
    expect(plain, contains('Y su letra tambien'));
    expect(plain, contains('Cierra la columna'));

    // Cada etiqueta abre su sección, en orden.
    expect(plain.indexOf('VERSO 1'), lessThan(plain.indexOf('VERSO 2')));
    expect(res.chordPro, contains('{start_of_verse: VERSO 2}'));
  });
}
