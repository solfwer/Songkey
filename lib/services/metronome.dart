// Metrnomo: sonido, vibracin e indicador visual del beat.
//
// El click no se guarda como archivo en el repo: se genera un WAV corto en
// cdigo (uno agudo para el acento y otro grave para el resto) y se escribe en
// la carpeta temporal la primera vez.
import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

/// Subdivisin: cuntos clicks entran en un pulso (la negra).
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

/// Comps habituales (pulsos por comps / unidad).
const List<({int beats, int unit, String label})> timeSignatures = [
  (beats: 4, unit: 4, label: '4/4'),
  (beats: 3, unit: 4, label: '3/4'),
  (beats: 2, unit: 4, label: '2/4'),
  (beats: 6, unit: 8, label: '6/8'),
  (beats: 5, unit: 4, label: '5/4'),
];

/// Ajustes del metrnomo (se guardan entre canciones).
class MetronomeSettings {
  int bpm;
  int beatsPerBar;
  int beatUnit;
  Subdivision subdivision;

  /// Primer tiempo ms fuerte.
  bool accent;

  /// Sonido activado.
  bool sound;

  /// Vibracin activada.
  bool vibration;
  MetronomeSettings({
    this.bpm = 120,
    this.beatsPerBar = 4,
    this.beatUnit = 4,
    this.subdivision = Subdivision.negra,
    this.accent = true,
    this.sound = true,
    this.vibration = true,
  });

  MetronomeSettings copy() => MetronomeSettings(
        bpm: bpm,
        beatsPerBar: beatsPerBar,
        beatUnit: beatUnit,
        subdivision: subdivision,
        accent: accent,
        sound: sound,
        vibration: vibration,
      );
}

/// Genera un WAV mono de un click con decaimiento exponencial.
Uint8List _clickWav({required double freq, required int milliseconds, required double volume}) {
  const sampleRate = 44100;
  final total = (sampleRate * milliseconds / 1000).round();
  final data = ByteData(44 + total * 2);

  void tag(String s) {
    for (var i = 0; i < s.length; i++) {
      data.setUint8(i, s.codeUnitAt(i));
    }
  }

  tag('RIFF');
  data.setUint32(4, 36 + total * 2, Endian.little);
  tag('WAVE');
  tag('fmt ');
  data.setUint32(16, 16, Endian.little); // tamao del bloque fmt
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
    // Decaimiento rpido para que sea un "click" y no un pitido largo.
    final decay = exp(-t * 28);
    final value = sin(2 * pi * freq * t) * decay * volume;
    final sample = (value * 32767).clamp(-32768, 32767).round();
    data.setInt16(44 + i * 2, sample, Endian.little);
  }
  return data.buffer.asUint8List();
}

/// Metrnomo con sonido, vibracin y aviso del beat.
class Metronome {
  MetronomeSettings settings;
  Metronome({MetronomeSettings? settings}) : settings = settings ?? MetronomeSettings();

  Timer? _timer;
  AudioPlayer? _player;
  String? _accentPath;
  String? _normalPath;
  bool _listo = false;
  int _click = 0;

  /// Se llama en cada click con el ndice de pulso dentro del comps
  /// (0 = primer tiempo) y si es el click del acento.
  void Function(int beat, bool acento)? onBeat;

  bool get activo => _timer != null;

  /// Prepara los archivos de sonido. Se puede llamar varias veces.
  Future<void> preparar() async {
    if (_listo) return;
    try {
      final dir = await getTemporaryDirectory();
      final acento = File('${dir.path}/metro_acento.wav');
      final normal = File('${dir.path}/metro_normal.wav');
      if (!await acento.exists()) {
        await acento.writeAsBytes(_clickWav(freq: 1600, milliseconds: 45, volume: 0.9));
      }
      if (!await normal.exists()) {
        await normal.writeAsBytes(_clickWav(freq: 950, milliseconds: 35, volume: 0.5));
      }
      _accentPath = acento.path;
      _normalPath = normal.path;
      _player = AudioPlayer(playerId: 'metronome');
      await _player!.setPlayerMode(PlayerMode.lowLatency);
      await _player!.setReleaseMode(ReleaseMode.stop);
      _listo = true;
    } catch (_) {
      // Si el sonido no est disponible, el metrnomo sigue vibrando.
      _listo = false;
    }
  }

  void start() {
    if (_timer != null) return;
    _click = 0;
    final porPulso = settings.subdivision.clicksPerBeat;
    final micros = (60000000 / settings.bpm / porPulso).round();
    _timer = Timer.periodic(Duration(microseconds: micros), (_) => _sonar());
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
      final path = acento ? _accentPath : _normalPath;
      if (path != null) {
        _player!.play(DeviceFileSource(path), volume: acento ? 1.0 : 0.7);
      }
    }
    if (settings.vibration) {
      HapticFeedback.selectionClick();
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
