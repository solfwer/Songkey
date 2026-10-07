import 'dart:typed_data';

import 'package:syncfusion_flutter_pdf/pdf.dart';

Future<({String title, String body})> pdfToDraft(String fileName, Uint8List bytes) async {
  final doc = PdfDocument(inputBytes: bytes);
  final text = PdfTextExtractor(doc).extractText().replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  final lines = text.split('\n');
  final first = lines.indexWhere((l) => l.trim().isNotEmpty);
  final title = first >= 0 && lines[first].trim().isNotEmpty
      ? lines[first].trim()
      : fileName.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
  final body = first >= 0 ? lines.skip(first + 1).join('\n').trim() : '';
  return (title: title, body: body);
}

