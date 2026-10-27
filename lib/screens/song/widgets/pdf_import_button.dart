// Importar cancin desde PDF: abre el selector, convierte el PDF a ChordPro
// con el nuevo servicio y manda a la pantalla de revisin, donde se ve el
// resultado antes de guardar.
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../data/store.dart';
import '../../../services/pdf_chordpro/pdf_to_chordpro_service.dart';
import '../pdf_review_page.dart';
import '../pdf_format_help_page.dart';

class PdfImportButton extends StatelessWidget {
  final Store store;
  final String? initialGroupId;
  const PdfImportButton({super.key, required this.store, this.initialGroupId});

  Future<void> _import(BuildContext context) async {
    final res = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    final file = res.firstOrNull;
    final bytes = await file?.readAsBytes();
    if (file == null || bytes == null) return;
    if (!context.mounted) return;

    // Conversin (puede tardar un poco en PDFs grandes).
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    PdfConversion conversion;
    try {
      // Se ejecuta en un isolate aparte: la UI no se bloquea aunque el PDF sea grande.
      conversion = await const PdfToChordProService().convertAsync(bytes, fallbackTitle: file.name.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), ''));
    } catch (_) {
      if (context.mounted) Navigator.of(context).pop();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo leer el PDF (est escaneado como imagen?)')));
      }
      return;
    }
    if (!context.mounted) return;
    Navigator.of(context).pop();

    if (conversion.chordPro.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El PDF no traa letra con acordes que se pueda convertir')));
      return;
    }

    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PdfReviewPage(store: store, conversion: conversion, initialGroupId: initialGroupId),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: OutlinedButton.icon(
          icon: const Icon(Icons.picture_as_pdf),
          label: const Text('Importar cancin desde PDF'),
          onPressed: () => _import(context),
        ),
      ),
      IconButton(
        tooltip: 'Cmo tiene que ser el PDF',
        icon: const Icon(Icons.help_outline),
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PdfFormatHelpPage())),
      ),
    ]);
  }
}
