import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/metadata/chord_key_detector.dart';

void main() {
  final detector = ChordKeyDetector();

  test('devuelve null si no hay acordes', () {
    final resultado = detector.detect('Esta es una letra sin acordes');
    expect(resultado.key, isNull);
  });

  test('detecta tono con progresión C-G-Am-F', () {
    final resultado = detector.detect(
        '[C] letra [G] letra [Am] letra [F] letra');
    expect(resultado.key, 'C');
    expect(resultado.confidence, greaterThanOrEqualTo(0.3));
  });

  test('detecta tono con progresión Am-F-C-G', () {
    final resultado = detector.detect(
        '[Am] letra [F] letra [C] letra [G] letra');
    expect(resultado.key, isNotNull);
    expect(resultado.confidence, greaterThanOrEqualTo(0.3));
  });

  test('detecta D mayor con progresión D-A-Bm-G', () {
    final resultado = detector.detect(
        '[D] letra [A] letra [Bm] letra [G] letra');
    expect(resultado.key, 'D');
  });

  test('normaliza bemoles: Bb → A#', () {
    // [Bb] en contexto de F mayor: F, Bb, C → F
    final resultado = detector.detect(
        '[F] letra [Bb] letra [C] letra');
    expect(resultado.key, 'F');
  });

  test('maneja acordes con bajo: C/E usa la raíz C', () {
    final resultado = detector.detect(
        '[C] letra [C/E] letra [G] letra');
    expect(resultado.key, 'C');
  });

  test('menos de 2 acordes distintos devuelve null', () {
    final resultado = detector.detect('[C] letra [C] letra');
    expect(resultado.key, isNull);
  });

  test('texto vacío devuelve null', () {
    final resultado = detector.detect('');
    expect(resultado.key, isNull);
  });
}
