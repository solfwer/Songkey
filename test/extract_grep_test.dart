import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  test('busca bpm/tonalidad en los pdfs', () {
    final dir = Platform.environment['CANCIONERO_DIR']!;
    final files = Directory(dir).listSync().whereType<File>().take(40);
    for (final f in files) {
      final doc = PdfDocument(inputBytes: Uint8List.fromList(f.readAsBytesSync()));
      final text = PdfTextExtractor(doc).extractText();
      doc.dispose();
      for (final line in text.split('\n')) {
        final l = line.trim();
        if (RegExp(r'bpm|tempo|tonalidad|tono|compás|compas', caseSensitive: false).hasMatch(l)) {
          print('${f.path.split('\\').last} :: $l');
        }
      }
    }
  });
}
