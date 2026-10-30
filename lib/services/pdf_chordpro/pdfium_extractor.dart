// Lee un PDF con PDFium (vía pdfrx) y devuelve la caja REAL de cada carácter.
//
// Es la única parte que depende del paquete `pdfrx`; todo lo demás
// (char_boxes.dart, el servicio) es Dart puro y se prueba aparte.
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import 'char_boxes.dart';

/// Texto de un PDF como cajas de caracteres + ancho de la primera página.
class PdfiumText {
  final List<PdfCharBox> chars;
  final double pageWidth;
  const PdfiumText(this.chars, this.pageWidth);
}

/// Extrae las cajas de caracteres de [bytes].
///
/// Devuelve null si no se puede (PDF dañado, escaneado sin texto, páginas
/// rotadas o plataforma sin soporte de PDFium): el llamador debe usar entonces
/// el extractor de respaldo.
Future<PdfiumText?> extractCharsWithPdfium(Uint8List bytes) async {
  PdfDocument? doc;
  try {
    doc = await PdfDocument.openData(bytes);
    final chars = <PdfCharBox>[];
    var pageWidth = 595.0;

    for (final page in doc.pages) {
      // Las cajas vienen en coordenadas de la página sin girar: con páginas
      // giradas las X/Y no coincidirían con lo que se ve.
      if (page.rotation.index != 0) return null;
      if (page.pageNumber == 1) pageWidth = page.width;

      final text = await page.loadText();
      //2lineas de error: final full = text.fullText; final rects = text.charRects;
      if (text == null) continue;

      final full = text.fullText;
      final rects = text.charRects;

      final n = math.min(full.length, rects.length);
      for (var i = 0; i < n; i++) {
        final r = rects[i];
        chars.add(PdfCharBox.fromPdfRect(
          ch: full[i],
          left: r.left,
          top: r.top,
          right: r.right,
          bottom: r.bottom,
          pageHeight: page.height,
          page: page.pageNumber - 1,
        ));
      }
    }

    // Un PDF escaneado (imagen) casi no trae texto.
    final visible = chars.where((c) => c.ch.trim().isNotEmpty).length;
    if (visible < 20) return null;
    return PdfiumText(chars, pageWidth);
  } catch (_) {
    return null;
  } finally {
    try {
      await doc?.dispose();
    } catch (_) {}
  }
}
