// Metrónomo: sonido, vibración e indicador visual del beat.
//
// Los clicks no se guardan como archivos: se generan WAV en memoria (uno por
// tipo de sonido) y se reproducen con BytesSource, así no dependemos de rutas
// temporales ni de permisos de almacenamiento.
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
///
/// Los clicks se generan como WAV en memoria (nada de archivos en disco) y se
/// reproducen con `BytesSource`: así no dependemos de rutas temporales ni de
/// permisos de almacenamiento, que es lo que haca que no sonara.
class Metronome {
  MetronomeSettings settings;
  Metronome({MetronomeSettings? settings}) : settings = settings ?? MetronomeSettings();

  Timer? _timer;
  AudioPlayer? _player;

  /// Clips ya generados, listos para reproducir.
  Uint8List? _acentoBytes;
  Uint8List? _normalBytes;

  bool _listo = false;
  bool _preparando = false;
  int _click = 0;

  /// Timbre actualmente preparado (para saber si hay que regenerar).
  ClickSound? _timoPreparado;

  /// Último error de audio (para poder diagnosticar en vez de callarse).
  Object? ultimoError;

  /// Se llama en cada click con el índice de pulso dentro del compás
  /// (0 = primer tiempo) y si es el click del acento.
  void Function(int beat, bool acento)? onBeat;

  bool get activo => _timer != null;

  /// true mientras se prepara el sonido.
  bool get preparando => _preparando;

  /// true si el sonido quedó listo para reproducir.
  bool get listo => _listo;

  /// Prepara los clips y el reproductor. Se puede llamar varias veces;
  /// devuelve true si el sonido quedó listo.
  Future<bool> preparar() async {
    if (_listo && _timoPreparado == settings.clickSound) return true;
    if (_preparando) return false;
    _preparando = true;
    try {
      final sonido = settings.clickSound;
      // El acento suena algo más largo y fuerte que el resto.
      final msAcento = sonido == ClickSound.campana ? 300 : 60;
      final msNormal = sonido == ClickSound.campana ? 250 : 40;
      _acentoBytes = _clickWav(sonido, milliseconds: msAcento, volume: 0.95);
      _normalBytes = _clickWav(sonido, milliseconds: msNormal, volume: 0.55);
      _timoPreparado = sonido;

      // Un solo reproductor para toda la vida del metrónomo.
      _player ??= AudioPlayer();
      await _player!.setPlayerMode(PlayerMode.mediaPlayer);
      await _player!.setReleaseMode(ReleaseMode.stop);
      _listo = true;
      ultimoError = null;
      return true;
    } catch (e) {
      // No se calla: guardamos el error para poder mostrarlo.
      ultimoError = e;
      _listo = false;
      return false;
    } finally {
      _preparando = false;
    }
  }

  /// Regenera los clips (al cambiar el tipo de sonido).
  Future<void> regenerarSonido() async {
    _listo = false;
    _timoPreparado = null;
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
      final bytes = acento ? _acentoBytes : _normalBytes;
      if (bytes != null) {
        _player!.play(BytesSource(bytes), volume: acento ? 1.0 : 0.75);
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
