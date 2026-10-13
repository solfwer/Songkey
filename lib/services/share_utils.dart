// Utilidades compartidas por los exportadores (texto y PDF): limpieza de
// nombres de archivo, archivos temporales, origen del popup de compartir y
// guardado de archivos en el dispositivo.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
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

/// Rectngulo del widget actual (para anclar el popup de compartir en tablets).
Rect? shareOrigin(BuildContext context) {
  final box = context.findRenderObject() as RenderBox?;
  if (box == null || !box.hasSize) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}

/// Nombre de archivo con fecha para no pisar copias anteriores:
/// `Songkey_biblioteca_2026-10-12.json`.
String datedFileName(String base, String extension) {
  final now = DateTime.now();
  final fecha = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  return '${safeFileName(base)}_$fecha.$extension';
}

/// Guarda [bytes] como archivo en el dispositivo usando el selector del
/// sistema (Descargas, Documentos...). Devuelve la ruta elegida o null si el
/// usuario cancel o hubo un error.
Future<String?> saveBytesToDevice({
  required Uint8List bytes,
  required String fileName,
  String mimeType = 'application/octet-stream',
}) async {
  try {
    final params = SaveFileDialogParams(
      data: bytes,
      fileName: fileName,
      mimeTypesFilter: [mimeType],
    );
    return await FlutterFileDialog.saveFile(params: params);
  } catch (_) {
    return null;
  }
}

/// Dilogo para elegir entre compartir o guardar en el dispositivo.
/// Devuelve `true` (guardar), `false` (compartir) o `null` (cancelar).
Future<bool?> askShareOrSave(
  BuildContext context, {
  required String que,
  String? shareLabel,
  String? saveLabel,
}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Como quieres sacar $que?'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          leading: const Icon(Icons.ios_share, color: Colors.blueAccent),
          title: Text(shareLabel ?? 'Compartir'),
          subtitle: const Text('Enviar por WhatsApp, correo...'),
          onTap: () => Navigator.pop(ctx, false),
        ),
        ListTile(
          leading: const Icon(Icons.save_alt, color: Colors.green),
          title: Text(saveLabel ?? 'Guardar en el telfono'),
          subtitle: const Text('Dejar el archivo en Descargas o Documentos'),
          onTap: () => Navigator.pop(ctx, true),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
      ],
    ),
  );
}