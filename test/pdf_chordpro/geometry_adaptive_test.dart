// Regresion: si las cajas de las palabras vienen "infladas" (muy altas), la
// fila de acordes y la de letra se funden al agrupar. El importador debe
// reintentar con tolerancias mas estrictas y conservar la X real de cada
// acorde, en vez de caer al texto layout (que solo es aproximado).
import 'package:appchords/services/pdf_chordpro/pdf_line_processor.dart';
import 'package:appchords/services/pdf_chordpro/pdf_models.dart';
import 'package:appchords/services/pdf_chordpro/pdf_to_chordpro_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Palabra con 6 pt por letra y la X de cada letra (como da Syncfusion).
PdfWord _w(String text, double left, double top, {double h = 12, double fs = 11}) => PdfWord(
      text: text,
      left: left,
      right: left + 6.0 * text.length,
      top: top,
      bottom: top + h,
      fontSize: fs,
      glyphLefts: [for (var i = 0; i < text.length; i++) left + 6.0 * i],
      page: 0,
    );

/// Titulo + dos pares fila-de-acordes / fila-de-letra, a 14 pt de separacion.
List<PdfWord> _song({required double h}) => [
      _w('MI', 100, 40, h: h, fs: 16),
      _w('CANCION', 118, 40, h: h, fs: 16),
      // par 1: acorde D sobre la 5.a letra de "humillamos", G sobre la 2.a de "delante"
      _w('D', 148, 100, h: h),
      _w('G', 196, 100, h: h),
      _w('Nos', 100, 114, h: h),
      _w('humillamos', 124, 114, h: h),
      _w('delante', 190, 114, h: h),
      // par 2
      _w('Bm', 106, 150, h: h),
      _w('Sacrificio', 100, 164, h: h),
      _w('agradable', 166, 164, h: h),
    ];

void main() {
  const svc = PdfToChordProService();

  test('con cajas altas, la tolerancia por defecto funde acordes y letra', () {
    final lines = groupLines(_song(h: 40), 612);
    // Sin el reintento esto es lo que pasaba: filas fundidas.
    expect(lines.length < 5, isTrue);
  });

  test('una tolerancia mas estricta separa las filas', () {
    final lines = groupLines(_song(h: 40), 612, tolerance: 0.15);
    expect(lines.length, 5);
  });

  test('linesFromWordsReliable encuentra una tolerancia que separa las filas', () {
    final r = svc.linesFromWordsReliable(_song(h: 40), 612);
    expect(r, isNotNull);
    expect(r!.lines.length, 5);
    expect(r.tolerance < 0.5, isTrue);
  });

  test('con cajas normales basta la tolerancia por defecto', () {
    final r = svc.linesFromWordsReliable(_song(h: 12), 612);
    expect(r, isNotNull);
    expect(r!.tolerance, lineGroupTolerance);
  });

  for (final h in [12.0, 40.0, 60.0]) {
    test('el acorde queda sobre su letra real (altura de caja $h)', () {
      final r = svc.linesFromWordsReliable(_song(h: h), 612)!;
      final out = svc
          .buildFromLines(r.lines, pageWidth: 612, tolerance: r.tolerance)
          .chordPro;
      expect(out, contains('Nos humi[D]llamos d[G]elante'));
      expect(out, contains('S[Bm]acrificio agradable'));
      expect(out.contains('[D][G]'), isFalse);
    });
  }
}
