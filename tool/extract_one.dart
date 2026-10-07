// Extrae texto de un PDF y lo imprime (uso: dart run tool/extract_one.dart <path>)
import 'dart:io';
import 'dart:typed_data';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main(List<String> args) {
  final bytes = File(args[0]).readAsBytesSync();
  final doc = PdfDocument(inputBytes: Uint8List.fromList(bytes));
  final text = PdfTextExtractor(doc).extractText();
  print(text);
  doc.dispose();
}
