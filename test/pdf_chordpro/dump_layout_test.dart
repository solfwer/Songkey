// Diagnóstico: vuelca lo que Syncfusion extrae de un PDF, para calibrar la
// posición de los acordes. NO cambia nada de la app.
//
// Uso (desde la raíz del proyecto):
//   Windows (PowerShell):
//     $env:DUMP_PDF='test/pdf_chordpro/fixtures/serviremos_al_senor.pdf'; flutter test test/pdf_chordpro/dump_layout_test.dart
//   Mac/Linux:
//     DUMP_PDF=test/pdf_chordpro/fixtures/serviremos_al_senor.pdf flutter test test/pdf_chordpro/dump_layout_test.dart
//
// Crea el archivo `dump_layout.txt` en la raíz del proyecto. Envíamelo.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  test('volcar layout y geometria del PDF', () {
    final path = Platform.environment['DUMP_PDF'] ??
        'test/pdf_chordpro/fixtures/serviremos_al_senor.pdf';
    final doc = PdfDocument(inputBytes: File(path).readAsBytesSync());
    final extractor = PdfTextExtractor(doc);
    final out = StringBuffer();

    out.writeln('PDF: $path  paginas=${doc.pages.count}');
    for (var p = 0; p < doc.pages.count; p++) {
      out.writeln('\n===== PAGINA $p: ancho=${doc.pages[p].size.width} =====');

      // 1) Texto en modo layout. Los espacios se ven como "·" para contar columnas.
      out.writeln('--- layoutText (espacios = ·) ---');
      final text = extractor.extractText(
        startPageIndex: p,
        endPageIndex: p,
        layoutText: true,
      );
      for (final l in text.split('\n')) {
        if (l.trim().isEmpty) continue;
        out.writeln(l.replaceAll('\r', '').replaceAll(' ', '·'));
      }
    }

    // 2) Geometria real: cada palabra con su X y la X de cada letra.
    out.writeln('\n===== GEOMETRIA (extractTextLines) =====');
    for (final l in extractor.extractTextLines()) {
      out.writeln('\n[pag ${l.pageIndex}] fontSize=${l.fontSize}');
      for (final w in l.wordCollection) {
        final gl = w.glyphs.map((g) => g.bounds.left.toStringAsFixed(1)).join(',');
        out.writeln(
          '  "${w.text}"  L=${w.bounds.left.toStringAsFixed(1)} '
          'R=${w.bounds.right.toStringAsFixed(1)} '
          'T=${w.bounds.top.toStringAsFixed(1)} '
          'B=${w.bounds.bottom.toStringAsFixed(1)}  glifosX=[$gl]',
        );
      }
    }

    doc.dispose();
    File('dump_layout.txt').writeAsStringSync(out.toString());
    // ignore: avoid_print
    print('Listo: dump_layout.txt (${out.length} caracteres)');
  });
}
