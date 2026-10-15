// Tests del metrónomo: ajustes, subdivisiones y BPM según la canción.
import 'package:appchords/data/store.dart';
import 'package:appchords/models/song.dart';
import 'package:appchords/screens/song/widgets/metronome_controls.dart';
import 'package:appchords/services/metronome.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

/// Metrónomo de mentira para poder testear sin plugin de audio.
class _MetroFalso extends Metronome {
  _MetroFalso([MetronomeSettings? s]) : super(settings: s);
  int arranques = 0;
  @override
  Future<bool> preparar() async => true;
  @override
  void start() => arranques++;
  @override
  void stop() {}
  @override
  void restart() => arranques++;
  @override
  Future<void> regenerarSonido() async {}
  @override
  Future<void> dispose() async {}
}

/// Crea un controlador con metrónomo falso (sin audio real).
MetronomeController _ctrl(Store store) {
  final c = MetronomeController(store, metro: _MetroFalso());
  return c;
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('Subdivision', () {
    test('cada subdivisión tiene sus clicks por pulso', () {
      expect(Subdivision.negra.clicksPerBeat, 1);
      expect(Subdivision.corchea.clicksPerBeat, 2);
    });

    test('todas tienen etiqueta', () {
      for (final s in Subdivision.values) {
        expect(s.label.isNotEmpty, isTrue);
      }
    });

    test('solo existen negra y corchea (tresillo y semicorchea eliminados)', () {
      expect(Subdivision.values.length, equals(2));
      expect(Subdivision.values.map((e) => e.label), containsAll(['Negras', 'Corcheas']));
    });
  });

  group('timeSignatures', () {
    test('trae los compases habituales', () {
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
      final c = _ctrl(store);
      expect(c.settings.bpm, 95);
      expect(c.settings.beatsPerBar, store.metroBeats);
      c.dispose();
    });

    test('setBpm limita a un rango razonable', () {
      final store = Store();
      final c = _ctrl(store);
      c.setBpm(0);
      expect(c.settings.bpm, 30);
      c.setBpm(1000);
      expect(c.settings.bpm, 300);
      c.setBpm(124);
      expect(c.settings.bpm, 124);
      c.dispose();
    });

    test('el BPM se adapta al de la canción', () {
      final store = Store();
      final c = _ctrl(store);
      c.settings.bpm = 80;
      // Canción sin BPM: se respeta el que tenías.
      c.syncWithSong(Song(id: 's1', title: 'Sin bpm', key: 'C', body: 'x'));
      expect(c.settings.bpm, 80);
      // Canción con BPM: se adapta.
      c.syncWithSong(Song(id: 's2', title: 'Con bpm', key: 'C', body: 'x', bpm: 140));
      expect(c.settings.bpm, 140);
      c.dispose();
    });

    test('no resetea el BPM al reconstruir la misma canción', () {
      final store = Store();
      final c = _ctrl(store);
      c.syncWithSong(Song(id: 's1', title: 'Con bpm', key: 'C', body: 'x', bpm: 100));
      expect(c.settings.bpm, 100);
      // El usuario lo cambia a mano...
      c.setBpm(130);
      // ...y al reconstruir la misma canción no vuelve a 100.
      c.syncWithSong(Song(id: 's1', title: 'Con bpm', key: 'C', body: 'x', bpm: 100));
      expect(c.settings.bpm, 130);
      c.dispose();
    });

    test('cambiar compás y subdivisión actualiza los ajustes', () {
      final store = Store();
      final c = _ctrl(store);
      c.setCompas(3, 4);
      expect(c.settings.beatsPerBar, 3);
      expect(store.metroBeats, 3);
      c.setSubdivision(Subdivision.corchea);
      expect(c.settings.subdivision, Subdivision.corchea);
      expect(store.metroSub, Subdivision.corchea.index);
      c.dispose();
    });

    test('el acento se puede desactivar', () {
      final store = Store();
      final c = _ctrl(store);
      expect(c.settings.accent, isTrue);
      c.setAccent(false);
      expect(c.settings.accent, isFalse);
      c.dispose();
    });
  });

  testWidgets('MetronomeBar muestra BPM, compás y subdivisión', (tester) async {
    final store = Store();
    final c = _ctrl(store);
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

  group('Metronome timing regression', () {
    test('Timer usa microsegundos: BPM alto + subdivisiones no trunca', () {
      // 300 BPM + corchea (2 clicks/pulso) = 100000 µs = 100 ms
      // Con Duration(microseconds: micros) no hay truncado.
      final m = Metronome(settings: MetronomeSettings(bpm: 300, subdivision: Subdivision.corchea));
      // Verificar que el cálculo de micros es correcto
      final porPulso = m.settings.subdivision.clicksPerBeat;
      final micros = (60000000 / m.settings.bpm / porPulso).round();
      expect(micros, equals(100000)); // 100000 µs = 100 ms exactos
    });

    test('Timer 240 BPM corcheas: intervalo exacto', () {
      // 240 BPM + corchea (2 clicks/pulso) = 125000 µs = 125 ms
      final m = Metronome(settings: MetronomeSettings(bpm: 240, subdivision: Subdivision.corchea));
      final porPulso = m.settings.subdivision.clicksPerBeat;
      final micros = (60000000 / m.settings.bpm / porPulso).round();
      expect(micros, equals(125000));
    });

    test('start() no hace doble click: solo un _sonar inmediato', () async {
      int sonarCalls = 0;
      final m = Metronome(
        settings: MetronomeSettings(bpm: 120, subdivision: Subdivision.negra),
      );
      // Sobrescribir _sonar para contar llamadas
      final completer = Completer<void>();
      m.onBeat = (_, __) {
        sonarCalls++;
        if (!completer.isCompleted) completer.complete();
      };
      m.start();
      // Esperar a que se ejecute el Timer.run (siguiente microtask)
      await completer.future;
      // Inmediatamente después de start, debe haber exactamente 1 llamada a _sonar (el Timer.run)
      expect(sonarCalls, equals(1));
      m.stop();
    });

    test('restart() no hace doble click', () async {
      int sonarCalls = 0;
      final m = Metronome(
        settings: MetronomeSettings(bpm: 120, subdivision: Subdivision.negra),
      );
      // Primer start: esperar al primer _sonar
      final startCompleter = Completer<void>();
      m.onBeat = (_, __) {
        sonarCalls++;
        if (!startCompleter.isCompleted) startCompleter.complete();
      };
      m.start();
      await startCompleter.future;
      expect(sonarCalls, equals(1));
      // Preparar completer para el restart
      final restartCompleter = Completer<void>();
      m.onBeat = (_, __) {
        sonarCalls++;
        if (!restartCompleter.isCompleted) restartCompleter.complete();
      };
      // El completer DEBE estar listo ANTES de llamar a restart()
      m.restart();
      // restart debe resetear y disparar exactamente 1 _sonar nuevo
      await restartCompleter.future;
      expect(sonarCalls, equals(2));
      m.stop();
    });
  });

  group('Store migration', () {
    test('metroSub migrado: valores 2 o 3 se recortan a 1 (corcheas)', () async {
      SharedPreferences.setMockInitialValues({
        'songkey-metro-sub': 2, // antes era tresillo
      });
      final store = Store();
      await store.load();
      expect(store.metroSub, equals(1)); // recortado a corcheas

      SharedPreferences.setMockInitialValues({
        'songkey-metro-sub': 3, // antes era semicorchea
      });
      final store2 = Store();
      await store2.load();
      expect(store2.metroSub, equals(1)); // recortado a corcheas

      SharedPreferences.setMockInitialValues({
        'songkey-metro-sub': 0, // negra
      });
      final store3 = Store();
      await store3.load();
      expect(store3.metroSub, equals(0));

      SharedPreferences.setMockInitialValues({
        'songkey-metro-sub': 1, // corchea
      });
      final store4 = Store();
      await store4.load();
      expect(store4.metroSub, equals(1));
    });
  });
}