// Exportación y compartición de setlists: PDF con la lista de temas, tonos y
// banda invitada, reutilizado desde la vista de setlists y desde Ajustes.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../models/setlist.dart';
import '../models/song.dart';
import 'share_utils.dart';

/// PDF de un setlist: nombre, fecha, temas con tono/BPM y banda invitada.
Uint8List buildSetlistPdf(Setlist list, List<Song> songs) {
  final doc = PdfDocument();
  final page = doc.pages.add();
  final bold = PdfStandardFont(PdfFontFamily.helvetica, 20, style: PdfFontStyle.bold);
  final normal = PdfStandardFont(PdfFontFamily.helvetica, 12);
  final semiBold = PdfStandardFont(PdfFontFamily.helvetica, 14, style: PdfFontStyle.bold);

  page.graphics.drawString('Setlist: ${list.name}', bold, bounds: const Rect.fromLTWH(0, 0, 500, 40));
  page.graphics.drawString('Fecha: ${list.date}', normal, bounds: const Rect.fromLTWH(0, 30, 500, 20));

  var y = 70.0;
  for (var i = 0; i < list.songIds.length; i++) {
    final song = songs.where((s) => s.id == list.songIds[i]).firstOrNull;
    if (song == null) continue;
    final text =
        '${i + 1}. ${song.title}  —  Tono: ${song.key}${song.bpm != null ? "  ·  ${song.bpm} BPM" : ""}';
    page.graphics.drawString(text, normal, bounds: Rect.fromLTWH(0, y, 500, 24));
    y += 24;
  }

  if (list.members.isNotEmpty) {
    y += 24;
    page.graphics.drawString('Banda invitada:', semiBold, bounds: Rect.fromLTWH(0, y, 500, 24));
    y += 24;
    for (final m in list.members) {
      page.graphics.drawString('• ${m.name} (${m.role}) — ${m.status}', normal, bounds: Rect.fromLTWH(0, y, 500, 20));
      y += 20;
    }
  }

  final bytes = Uint8List.fromList(doc.saveSync());
  doc.dispose();
  return bytes;
}

/// Comparte el PDF de un setlist.
Future<void> shareSetlistPdf(BuildContext context, Setlist list, List<Song> songs) async {
  final origin = shareOrigin(context);
  try {
    final bytes = buildSetlistPdf(list, songs);
    final file = await tempPdfFile('${list.name}_setlist', bytes);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      text: 'Setlist "${list.name}" · ${list.date}',
      sharePositionOrigin: origin,
    );
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo exportar el setlist: $e')));
    }
  }
}