// Punto de entrada para importar un PDF desde la interfaz.
//
// Primero se intenta con PDFium (posición real de cada carácter: cada acorde
// queda exactamente sobre su sílaba). Si no se puede, se usa Syncfusion, que es
// el camino anterior.
//
// Syncfusion falla con ciertos PDF (texto con fuente de tamaño 1.0 escalada por
// matriz, como el de "Serviremos al Señor"): da coordenadas que no corresponden
// a la página y los acordes no se pueden ubicar.
import 'dart:typed_data';

import 'pdf_to_chordpro_service.dart';
import 'pdfium_extractor.dart';

/// Convierte un PDF a ChordPro (una canción).
Future<PdfConversion> importPdf(Uint8List bytes, {String? fallbackTitle}) async {
  const service = PdfToChordProService();
  final text = await extractCharsWithPdfium(bytes);
  if (text != null) {
    try {
      return service.convertFromChars(
        text.chars,
        pageWidth: text.pageWidth,
        fallbackTitle: fallbackTitle,
      );
    } catch (_) {
      // Si algo raro pasa al interpretar, se prueba con el camino anterior.
    }
  }
  return service.convertAsync(bytes, fallbackTitle: fallbackTitle);
}

/// Convierte un PDF a ChordPro (una conversión por canción detectada).
Future<List<PdfConversion>> importPdfAll(Uint8List bytes, {String? fallbackTitle}) async {
  const service = PdfToChordProService();
  final text = await extractCharsWithPdfium(bytes);
  if (text != null) {
    try {
      return service.convertAllFromChars(
        text.chars,
        pageWidth: text.pageWidth,
        fallbackTitle: fallbackTitle,
      );
    } catch (_) {}
  }
  return service.convertAllAsync(bytes, fallbackTitle: fallbackTitle);
}
