// Ayudantes de exportación/compartición: texto legible y PDF de canciones y
// setlists, reutilizados desde la vista de canción, los setlists y Ajustes.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'models.dart';
import 'setlist_export.dart';
import 'songs.dart';

String _safeName(String s) =>
    s.replaceAll(RegExp(r'[\\/:*?"<>|]'), '').replaceAll(RegExp(r'\s+'), '_').trim().isEmpty
        ? 'export'
        : s.replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '_').trim();

/// Convierte una canción a texto legible, con cada acorde (transpuesto si
/// [semitones] != 0) escrito encima de la palabra que le corresponde.
String songToPlainText(Song song, {int semitones = 0, bool lyricsOnly = false}) {
  final buf = StringBuffer();
  buf.writeln(song.title.toUpperCase());
  buf.writeln('Tono: ${transposeChord(song.key, semitones)}${song.bpm != null ? '  ·  ${song.bpm} BPM' : ''}');
  buf.writeln('-' * 8);
  buf.writeln();

  for (final sec in parseSong(song.body)) {
    buf.writeln(sec.label.toUpperCase());
    for (final line in sec.lines) {
      if (line.isEmpty) {
        buf.writeln();
        continue;
      }
      final hasChords = line.any((x) => x.chord != null);
      final lyric = line.map((x) => x.text).join();
      if (lyricsOnly || !hasChords) {
        buf.writeln(lyric.trimRight());
      } else {
        // Fila de acordes anclada a la misma columna que su sílaba.
        final chordRow = StringBuffer();
        var pos = 0;
        for (final seg in line) {
          while (chordRow.length < pos) {
            chordRow.write(' ');
          }
          if (seg.chord != null) chordRow.write(transposeChord(seg.chord!, semitones));
          pos += seg.text.length;
        }
        buf.writeln(chordRow.toString().trimRight());
        buf.writeln(lyric.trimRight());
      }
    }
    buf.writeln();
  }
  return buf.toString();
}

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

/// PDF sencillo de una canción (título, tono, secciones con acordes y letra).
Uint8List buildSongPdf(Song song, {int semitones = 0, bool lyricsOnly = false}) {
  final doc = PdfDocument();
  try {
    var page = doc.pages.add();
    const margin = 40.0;
    final maxWidth = page.size.width - margin * 2;

    final titleFont = PdfStandardFont(PdfFontFamily.helvetica, 20, style: PdfFontStyle.bold);
    final labelFont = PdfStandardFont(PdfFontFamily.helvetica, 12, style: PdfFontStyle.bold);
    final chordFont = PdfStandardFont(PdfFontFamily.helvetica, 10, style: PdfFontStyle.bold);
    final lyricFont = PdfStandardFont(PdfFontFamily.helvetica, 12);

    var y = 32.0;

    void breakPage() {
      page = doc.pages.add();
      y = 32.0;
    }

    page.graphics.drawString(song.title.toUpperCase(), titleFont, bounds: Rect.fromLTWH(margin, y, maxWidth, 30));
    y += 32;
    page.graphics.drawString(
      'Tono: ${transposeChord(song.key, semitones)}${song.bpm != null ? '  ·  ${song.bpm} BPM' : ''}',
      labelFont,
      bounds: Rect.fromLTWH(margin, y, maxWidth, 18),
    );
    y += 26;

    for (final sec in parseSong(song.body)) {
      if (y > 780) breakPage();
      page.graphics.drawString(sec.label.toUpperCase(), labelFont, bounds: Rect.fromLTWH(margin, y, maxWidth, 18));
      y += 20;
      for (final line in sec.lines) {
        if (y > 800) breakPage();
        if (line.isEmpty) {
          y += 10;
          continue;
        }
        final hasChords = line.any((x) => x.chord != null);
        final lyric = line.map((x) => x.text).join().trimRight();
        if (lyricsOnly || !hasChords) {
          y = _drawWrapped(page, lyric, lyricFont, margin, y, maxWidth, 17);
        } else {
          final chordRow = StringBuffer();
          var pos = 0;
          for (final seg in line) {
            while (chordRow.length < pos) {
              chordRow.write(' ');
            }
            if (seg.chord != null) chordRow.write(transposeChord(seg.chord!, semitones));
            pos += seg.text.length;
          }
          y = _drawWrapped(page, chordRow.toString().trimRight(), chordFont, margin, y, maxWidth, 13);
          y = _drawWrapped(page, lyric, lyricFont, margin, y, maxWidth, 17);
        }
      }
      y += 4;
    }
    return Uint8List.fromList(doc.saveSync());
  } finally {
    doc.dispose();
  }
}

Future<File> _tempPdf(String name, Uint8List bytes) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/${_safeName(name)}.pdf');
  await file.writeAsBytes(bytes);
  return file;
}

Rect? _shareOrigin(BuildContext context) {
  final box = context.findRenderObject() as RenderBox?;
  if (box == null || !box.hasSize) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}

/// Comparte la letra como texto plano (con acordes encima, transpuestos).
Future<void> shareSongText(BuildContext context, Song song, {int semitones = 0, bool lyricsOnly = false}) async {
  final origin = _shareOrigin(context);
  try {
    await Share.share(
      songToPlainText(song, semitones: semitones, lyricsOnly: lyricsOnly),
      subject: song.title,
      sharePositionOrigin: origin,
    );
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo compartir: $e')));
    }
  }
}

/// Comparte la canción como PDF.
Future<void> shareSongPdf(BuildContext context, Song song, {int semitones = 0, bool lyricsOnly = false}) async {
  final origin = _shareOrigin(context);
  try {
    final bytes = buildSongPdf(song, semitones: semitones, lyricsOnly: lyricsOnly);
    final file = await _tempPdf('${song.title}_tono_${transposeChord(song.key, semitones)}', bytes);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      text: '${song.title} · Tono ${transposeChord(song.key, semitones)}',
      sharePositionOrigin: origin,
    );
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo exportar el PDF: $e')));
    }
  }
}

/// Comparte el PDF de un setlist (reutiliza `buildSetlistPdf`).
Future<void> shareSetlistPdf(BuildContext context, Setlist list, List<Song> songs) async {
  final origin = _shareOrigin(context);
  try {
    final bytes = buildSetlistPdf(list, songs);
    final file = await _tempPdf('${list.name}_setlist', bytes);
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