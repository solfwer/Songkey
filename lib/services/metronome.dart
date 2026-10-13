// Metrónomo: sonido, vibración e indicador visual del beat.
//
// Los clicks no se guardan como archivos en el repo: se generan WAV en código
// (uno por tipo de sonido) y se escriben en la carpeta temporal la primera vez.
import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

/// Tipo de sonido del click del metrónomo.
enum ClickSound {
  /// Ruido blanco corto: vaqueta.
  click('Click'),

  /// Tono puro.
  bip('Bip'),

  /// Ruido + tono grave.
  caja('Caja'),

  /// Tono con decay largo, metrónomo clásico.
  campana('Campana');

  final String label;
  const ClickSound(this.label);
}

/// Subdivisión: cuántos clicks entran en un pulso (la negra).
enum Subdivision {
  /// 1 click por pulso.
  negra(1, 'Negras'),

  /// 2 clicks por pulso.
  corchea(2, 'Corcheas'),

  /// 3 clicks por pulso.
  tresillo(3, 'Tresillos'),

  /// 4 clicks por pulso.
  semicorchea(4, 'Semicorcheas');

  final int clicksPerBeat;
  final String label;
  const Subdivision(this.clicksPerBeat, this.label);
}

/// Compases habituales (pulsos por compás / unidad).
const List<({int beats, int unit, String label})> timeSignatures = [
  (beats: 4, unit: 4, label: '4/4'),
  (beats: 3, unit: 4, label: '3/4'),
  (beats: 2, unit: 4, label: '2/4'),
  (beats: 6, unit: 8, label: '6/8'),
  (beats: 5, unit: 4, label: '5/4'),
];

/// Ajustes del metrónomo (se guardan entre canciones).
class MetronomeSettings {
  int bpm;
  int beatsPerBar;
  int beatUnit;
  Subdivision subdivision;

  /// Primer tiempo más fuerte.
  bool accent;

  /// Sonido activado.
  bool sound;

  /// Vibración activada.
  bool vibration;

  /// Tipo de sonido elegido.
  ClickSound clickSound;
  MetronomeSettings({
    this.bpm = 120,
    this.beatsPerBar = 4,
    this.beatUnit = 4,
    this.subdivision = Subdivision.negra,
    this.accent = true,
    this.sound = true,
    this.vibration = true,
    this.clickSound = ClickSound.click,
  });

  MetronomeSettings copy() => MetronomeSettings(
        bpm: bpm,
        beatsPerBar: beatsPerBar,
        beatUnit: beatUnit,
        subdivision: subdivision,
        accent: accent,
        sound: sound,
        vibration: vibration,
        clickSound: clickSound,
      );
}

/// Genera un WAV mono con el timbre del sonido elegido.
Uint8List _clickWav(ClickSound tipo, {required int milliseconds, required double volume}) {
  const sampleRate = 44100;
  final total = (sampleRate * milliseconds / 1000).round();
  final data = ByteData(44 + total * 2);
  final rng = Random(1234);

  void tag(String s) {
    for (var i = 0; i < s.length; i++) {
      data.setUint8(i, s.codeUnitAt(i));
    }
  }

  tag('RIFF');
  data.setUint32(4, 36 + total * 2, Endian.little);
  tag('WAVE');
  tag('fmt ');
  data.setUint32(16, 16, Endian.little); // tamaño del bloque fmt
  data.setUint16(20, 1, Endian.little); // PCM
  data.setUint16(22, 1, Endian.little); // mono
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, sampleRate * 2, Endian.little); // byte rate
  data.setUint16(32, 2, Endian.little); // block align
  data.setUint16(34, 16, Endian.little); // bits por muestra
  tag('data');
  data.setUint32(40, total * 2, Endian.little);

  for (var i = 0; i < total; i++) {
    final t = i / sampleRate;
    var value = 0.0;
    switch (tipo) {
      case ClickSound.click:
        // Ruido blanco con decay muy rápido: golpe de vaqueta.
        value = (rng.nextDouble() * 2 - 1) * exp(-t * 90);
      case ClickSound.bip:
        // Tono puro con decay medio.
        value = sin(2 * pi * 1100 * t) * exp(-t * 45);
      case ClickSound.caja:
        // Ruido + tono grave, tipo caja de batería.
        value = (rng.nextDouble() * 2 - 1) * exp(-t * 40) + sin(2 * pi * 180 * t) * exp(-t * 30);
      case ClickSound.campana:
        // Tono con decay largo, metrónomo clásico.
        value = sin(2 * pi * 850 * t) * exp(-t * 9);
    }
    final sample = (value * volume * 32767).clamp(-32768, 32767).round();
    data.setInt16(44 + i * 2, sample, Endian.little);
  }
  return data.buffer.asUint8List();
}

/// Metrónomo con sonido, vibración y aviso del beat.
class Metronome {
  MetronomeSettings settings;
  Metronome({MetronomeSettings? settings}) : settings = settings ?? MetronomeSettings();

  Timer? _timer;
  AudioPlayer? _player;
  String? _acentoPath;
  String? _normalPath;
  bool _listo = false;
  bool _preparando = false;
  int _click = 0;

  /// Se llama en cada click con el índice de pulso dentro del compás
  /// (0 = primer tiempo) y si es el click del acento.
  void Function(int beat, bool acento)? onBeat;

  bool get activo => _timer != null;

  /// true mientras se prepara el sonido.
  bool get preparando => _preparando;

  /// Prepara los archivos de sonido. Se puede llamar varias veces; devuelve
  /// true si el sonido qued listo.
  Future<bool> preparar() async {
    if (_listo) return true;
    if (_preparando) return false;
    _preparando = true;
    try {
      final dir = await getTemporaryDirectory();
      final acento = File('${dir.path}/metro_acento.wav');
      final normal = File('${dir.path}/metro_normal.wav');
      final sonido = settings.clickSound;
      // El acento suena algo ms largo y fuerte que el resto.
      final msAcento = sonido == ClickSound.campana ? 300 : 60;
      final msNormal = sonido == ClickSound.campana ? 250 : 40;
      if (!await acento.exists()) {
        await acento.writeAsBytes(_clickWav(sonido, milliseconds: msAcento, volume: 0.95));
      }
      if (!await normal.exists()) {
        await normal.writeAsBytes(_clickWav(sonido, milliseconds: msNormal, volume: 0.55));
      }
      _acentoPath = acento.path;
      _normalPath = normal.path;
      // mediaPlayer (no lowLatency): es el modo que carga rutas de disco.
      _player = AudioPlayer(playerId: 'metronome');
      await _player!.setPlayerMode(PlayerMode.mediaPlayer);
      await _player!.setReleaseMode(ReleaseMode.stop);
      _listo = true;
      return true;
    } catch (_) {
      // Si el sonido no est disponible, el metrnomo sigue vibrando.
      _listo = false;
      return false;
    } finally {
      _preparando = false;
    }
  }

  /// Regenera los archivos (al cambiar el tipo de sonido).
  Future<void> regenerarSonido() async {
    try {
      final dir = await getTemporaryDirectory();
      await File('${dir.path}/metro_acento.wav').delete();
      await File('${dir.path}/metro_normal.wav').delete();
    } catch (_) {}
    _listo = false;
    await preparar();
  }

  void start() {
    if (_timer != null) return;
    _click = 0;
    _programar();
    _sonar();
  }

  void _programar() {
    _timer?.cancel();
    final porPulso = settings.subdivision.clicksPerBeat;
    final micros = (60000000 / settings.bpm / porPulso).round();
    _timer = Timer.periodic(Duration(milliseconds: micros ~/ 1000), (_) => _sonar());
  }

  void restart() {
    if (_timer == null) return;
    _click = 0;
    _programar();
    _sonar();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _click = 0;
  }

  void _sonar() {
    final porPulso = settings.subdivision.clicksPerBeat;
    final enPulso = _click % porPulso == 0;
    final pulso = _click ~/ porPulso;
    final beat = pulso % settings.beatsPerBar;
    final acento = enPulso && settings.accent && beat == 0;

    if (settings.sound && _listo && _player != null) {
      final path = acento ? _acentoPath : _normalPath;
      if (path != null) {
        _player!.play(DeviceFileSource(path), volume: acento ? 1.0 : 0.75);
      }
    }
    if (settings.vibration) {
      // heavyClick se nota mucho ms que selectionClick.
      HapticFeedback.vibrate();
    }
    onBeat?.call(beat, acento);
    _click++;
  }

  Future<void> dispose() async {
    stop();
    await _player?.dispose();
    _player = null;
    _listo = false;
  }
}
