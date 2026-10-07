// Importar letra desde PDF: botón que abre el selector de archivos, convierte
// el PDF a un borrador ChordPro (acordes alineados) y lo vuelca en el editor.
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
    try {
      final draft = await pdfToDraft(file.name, bytes);
      if (titleController.text.trim().isEmpty) titleController.text = draft.title;
      bodyController.text = draft.body;
      onImported();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo leer el PDF (¿escaneado?)')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      icon: const Icon(Icons.picture_as_pdf),
      label: const Text('Importar letra desde PDF'),
      onPressed: () => _import(context),
    );
  }
}