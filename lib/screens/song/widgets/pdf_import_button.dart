// Importar letra desde PDF: abre el selector de archivos, convierte el PDF a
// un borrador ChordPro (con los acordes alineados a su sílaba) y muestra una
// vista previa antes de volcarlo en el editor, para poder revisarlo.
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../services/pdf_import.dart';

class PdfImportButton extends StatelessWidget {
  final TextEditingController titleController;
  final TextEditingController bodyController;

  /// Se invoca cuando la importación volcó el borrador en los controladores
  /// (para que el padre haga setState si necesita re-sincronizar widgets).
  final VoidCallback onImported;
  const PdfImportButton({super.key, required this.titleController, required this.bodyController, this.onImported = _noop});

  static void _noop() {}

  Future<void> _import(BuildContext context) async {
    final res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf'], withData: true);
    final file = res?.files.firstOrNull;
    final bytes = file?.bytes;
    if (file == null || bytes == null) return;

    ({String title, String body}) draft;
    try {
      draft = await pdfToDraft(file.name, bytes);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo leer el PDF (¿está escaneado como imagen?)')));
      }
      return;
    }
    if (draft.body.trim().isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El PDF no traía letra con acordes que se pueda convertir')));
      }
      return;
    }
    if (!context.mounted) return;

    // Vista previa: se ve el resultado antes de tocar el editor.
    final habaTexto = bodyController.text.trim().isNotEmpty;
    final accion = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Así queda la canción (ChordPro)'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Título: ${draft.title}', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('${draft.body.split('\n').length} líneas convertidas', style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 8),
            Flexible(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
                child: SingleChildScrollView(
                  child: Text(draft.body, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                ),
              ),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          if (habaTexto)
            TextButton(onPressed: () => Navigator.pop(ctx, 'anadir'), child: const Text('Añadir al final')),
          FilledButton(onPressed: () => Navigator.pop(ctx, 'usar'), child: Text(habaTexto ? 'Reemplazar' : 'Usar')),
        ],
      ),
    );
    if (accion == null || accion.isEmpty) return;

    if (titleController.text.trim().isEmpty) titleController.text = draft.title;
    bodyController.text = accion == 'anadir' ? '${bodyController.text.trimRight()}\n\n${draft.body}' : draft.body;
    onImported();
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      icon: const Icon(Icons.picture_as_pdf),
      label: const Text('Importar canción desde PDF'),
      onPressed: () => _import(context),
    );
  }
}
