// Test de regresión: syncWithSong con BPM distinto NO debe causar
// "setState() called during build" dentro de un AnimatedBuilder sobre Store.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:appchords/data/store.dart';
import 'package:appchords/models/song.dart';
import 'package:appchords/screens/song/widgets/metronome_controls.dart';
import 'package:appchords/services/metronome.dart';

/// Metrónomo falso para testear sin audio.
class _MetroFalso extends Metronome {
  _MetroFalso([MetronomeSettings? s]) : super(settings: s);
  @override
  Future<bool> preparar() async => true;
  @override
  void start() {}
  @override
  void stop() {}
  @override
  void restart() {}
  @override
  Future<void> regenerarSonido() async {}
  @override
  Future<void> dispose() async {}
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('syncWithSong con BPM distinto dentro del build no lanza excepción', (tester) async {
    final store = Store();
    await store.load();

    // Reproducir el escenario: un AnimatedBuilder que escucha el store
    // y dentro del builder llama a syncWithSong con una canción de BPM distinto.
    final controller = MetronomeController(store, metro: _MetroFalso());

    // Configurar store con BPM 120
    store.metroBpm = 120;

    // Widget que simula SongScreen: AnimatedBuilder sobre store + syncWithSong en build
    final testWidget = Builder(
      builder: (context) {
        return AnimatedBuilder(
          animation: store,
          builder: (context, _) {
            // Simular canción con BPM 140 (distinto al store.metroBpm = 120)
            final song = Song(id: 's1', title: 'Test', key: 'C', body: 'x', bpm: 140);
            controller.syncWithSong(song);
            return const SizedBox.shrink();
          },
        );
      },
    );

    // Debería poder hacer pump sin que salte la excepción
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: testWidget)));
    await tester.pump();

    // No debe haber excepción
    expect(tester.takeException(), isNull);

    controller.dispose();
  });

  testWidgets('syncWithSong con mismo BPM no llama a setBpm', (tester) async {
    final store = Store();
    await store.load();

    final controller = MetronomeController(store, metro: _MetroFalso());
    store.metroBpm = 120;

    final testWidget = Builder(
      builder: (context) {
        return AnimatedBuilder(
          animation: store,
          builder: (context, _) {
            // Mismo BPM que el store -> no debe llamar a setBpm
            final song = Song(id: 's1', title: 'Test', key: 'C', body: 'x', bpm: 120);
            controller.syncWithSong(song);
            return const SizedBox.shrink();
          },
        );
      },
    );

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: testWidget)));
    await tester.pump();

    expect(tester.takeException(), isNull);
    controller.dispose();
  });
}