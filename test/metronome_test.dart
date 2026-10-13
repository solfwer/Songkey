// Tests del metrónomo: ajustes, subdivisiones y BPM segn la cancin.
import 'package:appchords/data/store.dart';
import 'package:appchords/models/song.dart';
import 'package:appchords/screens/song/widgets/metronome_controls.dart';
import 'package:appchords/services/metronome.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('Subdivision', () {
    test('cada subdivisin tiene sus clicks por pulso', () {
      expect(Subdivision.negra.clicksPerBeat, 1);
      expect(Subdivision.corchea.clicksPerBeat, 2);
      expect(Subdivision.tresillo.clicksPerBeat, 3);
      expect(Subdivision.semicorchea.clicksPerBeat, 4);
    });

    test('todas tienen etiqueta', () {
      for (final s in Subdivision.values) {
        expect(s.label.isNotEmpty, isTrue);
      }
    });
  });

  group('timeSignatures', () {
    test('trae los comps habituales', () {
      final labels = timeSignatures.map((t) => t.label).toList();
      expect(labels, contains('4/4'));
      expect(labels, contains('3/4'));
      expect(labels, contains('6/8'));
    });
  });

  group('MetronomeSettings', () {
    test('valores por defecto', () {
      final s = MetronomeSettings();
      expect(s.bpm, 120);
      expect(s.beatsPerBar, 4);
      expect(s.subdivision, Subdivision.negra);
      expect(s.accent, isTrue);
      expect(s.sound, isTrue);
      expect(s.vibration, isTrue);
    });

    test('copy crea una copia independiente', () {
      final a = MetronomeSettings();
      final b = a.copy();
      b.bpm = 90;
      b.subdivision = Subdivision.corchea;
      expect(a.bpm, 120);
      expect(a.subdivision, Subdivision.negra);
    });
  });

  group('MetronomeController', () {
    test('arranca con los ajustes guardados en el Store', () {
      final store = Store()..metroBpm = 95;
      final c = MetronomeController(store);
      expect(c.settings.bpm, 95);
      expect(c.settings.beatsPerBar, store.metroBeats);
      c.dispose();
    });

    test('setBpm limita a un rango razonable', () {
      final store = Store();
      final c = MetronomeController(store);
      c.setBpm(0);
      expect(c.settings.bpm, 30);
      c.setBpm(1000);
      expect(c.settings.bpm, 300);
      c.setBpm(124);
      expect(c.settings.bpm, 124);
      c.dispose();
    });

    test('el BPM se adapta al de la cancion', () {
      final store = Store();
      final c = MetronomeController(store);
      c.settings.bpm = 80;
      // Cancion sin BPM: se respeta el que tenas.
      c.syncWithSong(Song(id: 's1', title: 'Sin bpm', key: 'C', body: 'x'));
      expect(c.settings.bpm, 80);
      // Cancion con BPM: se adapta.
      c.syncWithSong(Song(id: 's2', title: 'Con bpm', key: 'C', body: 'x', bpm: 140));
      expect(c.settings.bpm, 140);
      c.dispose();
    });

    test('no resetea el BPM al reconstruir la misma cancin', () {
      final store = Store();
      final c = MetronomeController(store);
      c.syncWithSong(Song(id: 's1', title: 'Con bpm', key: 'C', body: 'x', bpm: 100));
      expect(c.settings.bpm, 100);
      // El usuario lo cambia a mano...
      c.setBpm(130);
      // ...y al reconstruir la misma cancin no vuelve a 100.
      c.syncWithSong(Song(id: 's1', title: 'Con bpm', key: 'C', body: 'x', bpm: 100));
      expect(c.settings.bpm, 130);
      c.dispose();
    });

    test('cambiar comps y subdivisin actualiza los ajustes', () {
      final store = Store();
      final c = MetronomeController(store);
      c.setCompas(3, 4);
      expect(c.settings.beatsPerBar, 3);
      expect(store.metroBeats, 3);
      c.setSubdivision(Subdivision.tresillo);
      expect(c.settings.subdivision, Subdivision.tresillo);
      expect(store.metroSub, Subdivision.tresillo.index);
      c.dispose();
    });

    test('se puede apagar sonido y vibracin por separado', () {
      final store = Store();
      final c = MetronomeController(store);
      c.setSound(false);
      expect(c.settings.sound, isFalse);
      expect(c.settings.vibration, isTrue);
      c.setVibration(false);
      expect(c.settings.vibration, isFalse);
      expect(store.metroSound, isFalse);
      expect(store.metroVib, isFalse);
      c.dispose();
    });

    test('el acento se puede desactivar', () {
      final store = Store();
      final c = MetronomeController(store);
      expect(c.settings.accent, isTrue);
      c.setAccent(false);
      expect(c.settings.accent, isFalse);
      c.dispose();
    });
  });

  testWidgets('MetronomeBar muestra BPM, comps y subdivisin', (tester) async {
    final store = Store();
    final c = MetronomeController(store);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: MetronomeBar(controller: c)),
    ));
    await tester.pumpAndSettle();
    expect(find.text('${c.settings.bpm}'), findsOneWidget);
    expect(find.text('4/4'), findsOneWidget);
    expect(find.text('Negras'), findsOneWidget);
    expect(find.text('Parar'), findsOneWidget);
    c.dispose();
  });
}
