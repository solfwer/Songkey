import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/metadata/tap_tempo.dart';

void main() {
  test('menos de 3 toques devuelve null', () {
    final tempo = TapTempo();
    tempo.tap();
    tempo.tap();
    expect(tempo.bpm, isNull);
    expect(tempo.tapCount, 2);
  });

  test('reset limpia los toques', () {
    final tempo = TapTempo();
    tempo.tap();
    tempo.tap();
    tempo.tap();
    tempo.reset();
    expect(tempo.tapCount, 0);
    expect(tempo.bpm, isNull);
  });

  test('tap incrementa el contador', () {
    final tempo = TapTempo();
    tempo.tap();
    tempo.tap();
    tempo.tap();
    expect(tempo.tapCount, 3);
  });
}
