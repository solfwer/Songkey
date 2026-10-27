// Exportación y compartición de setlists: PDF con la portada (índice de temas,
// tonos y banda invitada) seguida de cada canción completa — título, tono y
// secciones con acordes y letra — lista para imprimir.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../data/chord_parser.dart';
import '../models/setlist.dart';
import '../models/song.dart';
import 'share_utils.dart';

/// Dibuja [text] con saltos de línea por ancho. Devuelve el nuevo Y.
double _drawWrapped(PdfPage page, String text, PdfFont font, double x, double y, double maxWidth, double lineGap) {
  final words = text.split(' ');
  var line = '';
  for (final w in words) {
    final trial = line.isEmpty ? w : '$line $w';
    if (font.measureString(trial).width > maxWidth && line.isNotEmpty) {
      page.graphics.drawString(line, font, bounds: Rect.fromLTWH(x, y, maxWidth, lineGap + 8));
      y += lineGap;
      line = w;
    } else {
      line = trial;
    }
  }
  if (line.isNotEmpty) {
    page.graphics.drawString(line, font, bounds: Rect.fromLTWH(x, y, maxWidth, lineGap + 8));
    y += lineGap;
  }
  return y;
}

/// PDF de un setlist en su tono original: portada con índice y banda invitada
/// + las canciones completas del setlist (acordes y letra).
Uint8List buildSetlistPdf(Setlist list, List<Song> songs) {
  final doc = PdfDocument();
  try {
    var page = doc.pages.add();
    const margin = 40.0;
    final maxWidth = page.size.width - margin * 2;

    final titleFont = PdfStandardFont(PdfFontFamily.helvetica, 20, style: PdfFontStyle.bold);
    final subtitleFont = PdfStandardFont(PdfFontFamily.helvetica, 12, style: PdfFontStyle.bold);
    final songTitleFont = PdfStandardFont(PdfFontFamily.helvetica, 16, style: PdfFontStyle.bold);
    final labelFont = PdfStandardFont(PdfFontFamily.helvetica, 12, style: PdfFontStyle.bold);
    final chordFont = PdfStandardFont(PdfFontFamily.helvetica, 10, style: PdfFontStyle.bold);
    final lyricFont = PdfStandardFont(PdfFontFamily.helvetica, 12);
    final normalFont = PdfStandardFont(PdfFontFamily.helvetica, 12);

    var y = 32.0;

    void breakPage() {
      page = doc.pages.add();
      y = 32.0;
    }

    // Portada: nombre, fecha e índice de temas.
    page.graphics.drawString('Setlist: ${list.name}', titleFont, bounds: Rect.fromLTWH(margin, y, maxWidth, 30));
    y += 32;
    page.graphics.drawString('Fecha: ${list.date}', subtitleFont, bounds: Rect.fromLTWH(margin, y, maxWidth, 18));
    y += 26;

    for (var i = 0; i < list.songIds.length; i++) {
      final song = songs.where((s) => s.id == list.songIds[i]).firstOrNull;
      if (song == null) continue;
      final text = '${i + 1}. ${song.title}  —  Tono: ${song.key}${song.bpm != null ? '  ·  ${song.bpm} BPM' : ''}';
      page.graphics.drawString(text, normalFont, bounds: Rect.fromLTWH(margin, y, maxWidth, 20));
      y += 22;
    }

    if (list.members.isNotEmpty) {
      y += 12;
      page.graphics.drawString('Banda invitada:', subtitleFont, bounds: Rect.fromLTWH(margin, y, maxWidth, 20));
      y += 20;
      for (final m in list.members) {
        page.graphics.drawString('• ${m.name} (${m.role}) — ${m.status}', normalFont, bounds: Rect.fromLTWH(margin, y, maxWidth, 18));
        y += 18;
      }
    }

    // Canciones completas del setlist.
    for (var i = 0; i < list.songIds.length; i++) {
      final song = songs.where((s) => s.id == list.songIds[i]).firstOrNull;
      if (song == null) continue;
      if (y > 300) breakPage(); // canción nueva en página fresca si queda poco espacio
      y += 30;
      page.graphics.drawString('${i + 1}. ${song.title.toUpperCase()}', songTitleFont, bounds: Rect.fromLTWH(margin, y, maxWidth, 24));
      y += 26;
      page.graphics.drawString(
        'Tono: ${song.key}${song.bpm != null ? '  ·  ${song.bpm} BPM' : ''}',
        subtitleFont,
        bounds: Rect.fromLTWH(margin, y, maxWidth, 18),
      );
      y += 24;

      for (final sec in sectionsInOrder(song.body, song.structure)) {
        if (y > 740) breakPage();
        page.graphics.drawString(sec.label.toUpperCase(), labelFont, bounds: Rect.fromLTWH(margin, y, maxWidth, 18));
        y += 20;
        for (final line in sec.lines) {
          if (y > 790) breakPage();
          if (line.isEmpty) {
            y += 10;
            continue;
          }
          final hasChords = line.any((x) => x.chord != null);
          final lyric = line.map((x) => x.text).join().trimRight();
          if (!hasChords) {
            y = _drawWrapped(page, lyric, lyricFont, margin, y, maxWidth, 17);
          } else {
            // Fila de acordes anclada a la misma columna que su sílaba.
            final chordRow = StringBuffer();
            var pos = 0;
            for (final seg in line) {
              while (chordRow.length < pos) {
                chordRow.write(' ');
              }
              if (seg.chord != null) chordRow.write(seg.chord!);
              pos += seg.text.length;
            }
            y = _drawWrapped(page, chordRow.toString().trimRight(), chordFont, margin, y, maxWidth, 13);
            y = _drawWrapped(page, lyric, lyricFont, margin, y, maxWidth, 17);
          }
        }
        y += 4;
      }
    }

    return Uint8List.fromList(doc.saveSync());
  } finally {
    doc.dispose();
  }
}

/// Comparte el PDF de un setlist.
Future<void> shareSetlistPdf(BuildContext context, Setlist list, List<Song> songs) async {
  final origin = shareOrigin(context);
  try {
    final bytes = buildSetlistPdf(list, songs);
    final file = await tempPdfFile('${list.name}_setlist', bytes);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/pdf')],
        text: 'Setlist "${list.name}" · ${list.date}',
        sharePositionOrigin: origin,
      ),
    );
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo exportar el setlist: $e')));
    }
  }
}