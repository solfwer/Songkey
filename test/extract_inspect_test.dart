// Genera un extracto de texto de un PDF para inspeccionar su formato.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  test('extrae texto de un pdf', () {
    final dir = Platform.environment['CANCIONERO_DIR']!;
    final f = File('$dir\\001 - A DANZAR.pdf');
    final doc = PdfDocument(inputBytes: Uint8List.fromList(f.readAsBytesSync()));
    print(PdfTextExtractor(doc).extractText());
    doc.dispose();
  });
}
