// Utilidades compartidas por los exportadores (texto y PDF): limpieza de
// nombres de archivo, archivos temporales y origen del popup de compartir.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

String safeFileName(String s) =>
    s.replaceAll(RegExp(r'[\\/:*?"<>|]'), '').replaceAll(RegExp(r'\s+'), '_').trim().isEmpty
        ? 'export'
        : s.replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '_').trim();

Future<File> tempPdfFile(String name, Uint8List bytes) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/${safeFileName(name)}.pdf');
  await file.writeAsBytes(bytes);
  return file;
}

/// Rectángulo del widget actual (para anclar el popup de compartir en tablets).
Rect? shareOrigin(BuildContext context) {
  final box = context.findRenderObject() as RenderBox?;
  if (box == null || !box.hasSize) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}