// Verifica que el PDF de muestra (docs/ejemplo_pdf_valido.pdf) se importa
// correctamente con el servicio real y produce el ChordPro esperado.
//
// Regenerar el PDF con: dart run tool/generar_pdf_ejemplo.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:appchords/services/pdf_chordpro/pdf_to_chordpro_service.dart';

void main() {
  test('el PDF de ejemplo se convierte a ChordPro', () {
    final file = File('docs/ejemplo_pdf_valido.pdf');
    expect(file.existsSync(), isTrue,
        reason: 'Ejecuta: dart run tool/generar_pdf_ejemplo.dart');
    final bytes = Uint8List.fromList(file.readAsBytesSync());

    final res = const PdfToChordProService().convert(bytes);

    // ignore: avoid_print
    print('--- ChordPro result ---\n${res.chordPro}\n'
        'title=${res.title} key=${res.suggestedKey} cols=${res.columns}\n'
        'warnings=${res.warnings.map((w) => w.message).toList()}');

    expect(res.title, 'A DANZAR');
    expect(res.columns, 1);
    expect(res.chordPro, contains('{start_of_verse: VERSO 1}'));
    expect(res.chordPro, contains('{start_of_chorus: CORO}'));
    expect(res.chordPro, contains('{start_of_bridge: PUENTE}'));
    // Progresión de la introducción como progresión de barras.
    expect(res.chordPro, contains('[C#m] | [A] | [E] | [B]'));
    // Acordes colocados sobre la sílaba correcta de la letra.
    expect(res.chordPro.contains('Se[C#m]ñor') || res.chordPro.contains('[C#m]tú'),
        isTrue);
    // El número de página se filtra.
    expect(res.chordPro, contains('Gracias, Señor'));
    expect(res.chordPro.contains('\n1'), isFalse);
  });
}
