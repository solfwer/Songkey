import 'dart:typed_data';

import 'pdf_chord_import.dart';

/// Convierte un PDF de cancionero en un borrador (título + cuerpo ChordPro),
/// alineando los acordes con la palabra de la letra que tienen debajo.
Future<({String title, String body})> pdfToDraft(String fileName, Uint8List bytes) async {
  final base = fileName.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '').trim();
  return pdfToDraftFromBytes(bytes, fallbackTitle: base);
}