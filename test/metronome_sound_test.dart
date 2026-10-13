// Tests de los sonidos del metrónomo y de los círculos de los tiempos.
import 'package:appchords/screens/song/widgets/metronome_controls.dart';
import 'package:appchords/services/metronome.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ClickSound', () {
    test('trae los cuatro sonidos con etiqueta', () {
      expect(ClickSound.values.length, 4);
      expect(ClickSound.values.map((s) => s.label).toList(), ['Click', 'Bip', 'Caja', 'Campana']);
    });
  });

  group('MetronomeSettings', () {
    test('por defecto el sonido es Click', () {
      final s = MetronomeSettings();
      expect(s.clickSound, ClickSound.click);
    });

    test('copy conserva el tipo de sonido', () {
      final a = MetronomeSettings()..clickSound = ClickSound.campana;
      final b = a.copy();
      expect(b.clickSound, ClickSound.campana);
    });
  });

  group('BeatDots', () {
    testWidgets('dibuja un circulo por tiempo', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(child: BeatDots(beats: 4, actual: 0)),
        ),
      ));
      await tester.pumpAndSettle();
      // 4 crculos (como AnimatedContainer).
      expect(find.byType(AnimatedContainer), findsNWidgets(4));
    });

    testWidgets('cambia la cantidad segun el compas', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: Center(child: BeatDots(beats: 3, actual: 1))),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(AnimatedContainer), findsNWidgets(3));
    });

    testWidgets('seis ochos trae seis circulos', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: Center(child: BeatDots(beats: 6, actual: 5))),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(AnimatedContainer), findsNWidgets(6));
    });

    testWidgets('el acento agranda el circulo actual', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: Center(child: BeatDots(beats: 4, actual: 0, acento: true))),
      ));
      await tester.pumpAndSettle();
      final dot = tester.widget<AnimatedContainer>(find.byType(AnimatedContainer).first);
      expect(dot.constraints?.maxWidth, 16);
    });
  });
}
