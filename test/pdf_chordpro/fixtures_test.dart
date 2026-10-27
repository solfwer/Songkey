// Importación de PDFs reales de test/pdf_chordpro/fixtures/.
//
// Recorre TODOS los PDFs de la carpeta: cada uno debe convertirse sin romper
// nada y, si tiene un `.cho` al lado con el mismo nombre, el resultado tiene
// que coincidir línea a línea (así se revisa lo que cambia el importador).
import 'dart:io';

import 'package:appchords/services/pdf_chordpro/pdf_models.dart';
import 'package:appchords/services/pdf_chordpro/pdf_to_chordpro_service.dart';
import 'package:flutter_test/flutter_test.dart';

const _dir = 'test/pdf_chordpro/fixtures';

/// Para regenerar los `.cho` esperados despues de un cambio INTENCIONADO del
/// importador (revisa el diff con git antes de guardarlos):
///   Windows (PowerShell):  $env:UPDATE_FIXTURES='1'; flutter test test/pdf_chordpro/fixtures_test.dart
///   Mac/Linux:             UPDATE_FIXTURES=1 flutter test test/pdf_chordpro/fixtures_test.dart
final _update = Platform.environment['UPDATE_FIXTURES'] == '1';

String _expectedPath(String pdfPath) =>
    pdfPath.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '.cho');

void main() {
  final pdfs = Directory(_dir)
      .listSync()
      .whereType<File>()
      .where((f) => f.path.toLowerCase().endsWith('.pdf'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  test('hay PDFs de prueba', () {
    expect(pdfs, isNotEmpty);
  });

  for (final pdf in pdfs) {
    final name = pdf.uri.pathSegments.last;

    test('$name se convierte', () {
      final res = const PdfToChordProService().convert(pdf.readAsBytesSync());
      expect(res.title.trim(), isNotEmpty);
      if (!res.warnings.any((w) => w.kind == WarningKind.noText)) {
        expect(res.chordPro, contains('{title:'));
      }
    });

    final expected = File(_expectedPath(pdf.path));
    if (_update) {
      test('$name: regenera su .cho esperado', () {
        final res = const PdfToChordProService().convert(pdf.readAsBytesSync());
        expected.writeAsStringSync('${res.chordPro.trim()}\n');
      });
    } else if (expected.existsSync()) {
      test('$name coincide con su .cho esperado', () {
        final res = const PdfToChordProService().convert(pdf.readAsBytesSync());
        expect(res.chordPro.trim(), expected.readAsStringSync().trim());
      });
    }
  }
}
