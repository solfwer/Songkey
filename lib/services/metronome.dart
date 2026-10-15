// Metrónomo: sonido e indicador visual del beat.
//
// Los clicks se generan como WAV en memoria y se reproducen con SoundPool
// nativo en Android (un solo `play()` por click, latencia ~5 ms).
// En iOS/web/tests cae a `audioplayers` con BytesSource.
import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'native_metronome.dart';

/// Tipo de sonido del click del metrónomo.
enum ClickSound {
  /// Click de madera: ruido filtrado + resonancia aguda, tipo baqueta.
  click('Click'),

  /// Tono puro con decay medio.
  bip('Bip'),

  /// Ruido + tono grave, tipo caja de batería.
  caja('Caja'),

  /// Tono con decay largo, metrónomo clásico (dos parciales).
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

  /// Tipo de sonido elegido.
  ClickSound clickSound;
  MetronomeSettings({
    this.bpm = 120,
    this.beatsPerBar = 4,
    this.beatUnit = 4,
    this.subdivision = Subdivision.negra,
    this.accent = true,
    this.sound = true,
    this.clickSound = ClickSound.click,
  });

  MetronomeSettings copy() => MetronomeSettings(
        bpm: bpm,
        beatsPerBar: beatsPerBar,
        beatUnit: beatUnit,
        subdivision: subdivision,
        accent: accent,
        sound: sound,
        clickSound: clickSound,
      );
}

/// Genera un WAV mono con el timbre del sonido elegido.
/// Incluye envolvente: fundido de entrada 1 ms y fundido de salida en el
/// último 15 % del clip para evitar "pops" digitales.
Uint8List _clickWav(ClickSound tipo, {required int milliseconds, required double volume}) {
  const sampleRate = 44100;
  final total = (sampleRate * milliseconds / 1000).round();
  final data = ByteData(44 + total * 2);
  final rng = Random(1234);

  void tag(String s, int offset) {
    for (var i = 0; i < s.length; i++) {
      data.setUint8(offset + i, s.codeUnitAt(i));
    }
  }

  tag('RIFF', 0);
  data.setUint32(4, 36 + total * 2, Endian.little);
  tag('WAVE', 8);
  tag('fmt ', 12);
  data.setUint32(16, 16, Endian.little); // tamaño del bloque fmt
  data.setUint16(20, 1, Endian.little); // PCM
  data.setUint16(22, 1, Endian.little); // mono
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, sampleRate * 2, Endian.little); // byte rate
  data.setUint16(32, 2, Endian.little); // block align
  data.setUint16(34, 16, Endian.little); // bits por muestra
  tag('data', 36);
  data.setUint32(40, total * 2, Endian.little);

  // Parámetros de envolvente
  const fadeInSamples = 44; // ~1 ms a 44.1 kHz
  final fadeOutStart = (total * 0.85).round(); // último 15 %

  for (var i = 0; i < total; i++) {
    final t = i / sampleRate;

    // Envolvente: fade-in lineal 1 ms, sostenido, fade-out lineal último 15 %
    double env;
    if (i < fadeInSamples) {
      env = i / fadeInSamples;
    } else if (i >= fadeOutStart) {
      env = (total - i) / (total - fadeOutStart);
    } else {
      env = 1.0;
    }

    var value = 0.0;
    switch (tipo) {
      case ClickSound.click:
        // Ruido filtrado (pasa-altas simple) + resonancia aguda ~3.5 kHz
        // Simula golpe de baqueta de madera.
        final noise = (rng.nextDouble() * 2 - 1);
        // Filtro pasa-altas simple de 1er orden (alpha ≈ 0.95 a 44.1 kHz)
        // Aplicamos a la muestra actual restando la anterior atenuada.
        // Para no guardar estado entre samples, usamos decay exponencial alto.
        value = noise * exp(-t * 120);
        // Resonancia aguda corta
        value += sin(2 * pi * 3500 * t) * exp(-t * 200) * 0.3;
      case ClickSound.bip:
        // Tono puro con decay medio.
        value = sin(2 * pi * 1100 * t) * exp(-t * 45);
      case ClickSound.caja:
        // Ruido + tono grave + resonancia media.
        final noise = (rng.nextDouble() * 2 - 1) * exp(-t * 50);
        final tone = sin(2 * pi * 180 * t) * exp(-t * 35);
        final snap = sin(2 * pi * 2500 * t) * exp(-t * 150) * 0.2;
        value = noise + tone + snap;
      case ClickSound.campana:
        // Dos parciales: fundamental 850 Hz + armónico 3 1275 Hz (campana metálica).
        value = sin(2 * pi * 850 * t) * exp(-t * 9);
        value += sin(2 * pi * 1275 * t) * exp(-t * 12) * 0.6;
    }
    final sample = (value * volume * 32767 * env).clamp(-32768, 32767).round();
    data.setInt16(44 + i * 2, sample, Endian.little);
  }
  return data.buffer.asUint8List();
}

/// Mapeo de slots para SoundPool nativo:
/// 0-3 = normal (click, bip, caja, campana)
/// 4-7 = acento (click, bip, caja, campana)
int _slotFor(ClickSound tipo, bool acento) => acento ? tipo.index + 4 : tipo.index;

/// Metrónomo con sonido, vibración y aviso del beat.
class Metronome {
  MetronomeSettings settings;
  Metronome({MetronomeSettings? settings}) : settings = settings ?? MetronomeSettings();

  Timer? _timer;

  /// Clips ya generados (fallback audioplayers).
  Uint8List? _acentoBytes;
  Uint8List? _normalBytes;

  /// Bytes de todos los 8 slots para SoundPool nativo.
  final List<Uint8List?> _nativeBytes = List.filled(8, null);

  bool _listo = false;
  bool _preparando = false;
  bool _nativeReady = false;
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

      _normalBytes = _clickWav(sonido, milliseconds: msNormal, volume: 0.7);
      _acentoBytes = _clickWav(sonido, milliseconds: msAcento, volume: 1.0);
      _nativeBytes[_slotFor(sonido, false)] = _normalBytes;
      _nativeBytes[_slotFor(sonido, true)] = _acentoBytes;

      _timoPreparado = sonido;

      // Fallback audioplayers (para iOS/web/tests).
      _player ??= AudioPlayer();
      await _player!.setPlayerMode(PlayerMode.mediaPlayer);
      await _player!.setReleaseMode(ReleaseMode.stop);

      // Intento nativo (Android).
      if (NativeMetronome.available) {
        try {
          await NativeMetronome.prepare(_nativeBytes.asMap()
              .map((k, v) => MapEntry(k, v!))
              .cast<int, Uint8List>());
          _nativeReady = true;
        } catch (e) {
          _nativeReady = false;
          ultimoError = e; // Guardar error para diagnóstico
        }
      }

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
    _nativeReady = false;
    _timoPreparado = null;
    await preparar();
  }

  /// Fallback audioplayers para iOS/web/tests.
  AudioPlayer? _player;

  void start() {
    if (_timer != null) return;
    _click = 0;
    _programar();
    // Primer click inmediato sin esperar al timer (evita doble click si el timer dispara rápido).
    Timer.run(_sonar);
  }

  void _programar() {
    _timer?.cancel();
    final porPulso = settings.subdivision.clicksPerBeat;
    final micros = (60000000 / settings.bpm / porPulso).round();
    // Usar microsegundos directamente para precisión en BPM altos + subdivisiones.
    _timer = Timer.periodic(Duration(microseconds: micros), (_) => _sonar());
  }

  void restart() {
    if (_timer == null) return;
    _click = 0;
    _programar();
    Timer.run(_sonar);
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

    if (settings.sound && _listo) {
      if (_nativeReady) {
        // Nativo: una llamada, latencia ~5 ms, permite solapamiento.
        final slot = _slotFor(settings.clickSound, acento);
        final volume = acento ? 1.0 : 0.75;
        NativeMetronome.play(slot, volume).catchError((_) {
          // Fallback silencioso si el canal falla en runtime.
          _nativeReady = false;
          _playFallback(acento);
        });
      } else {
        _playFallback(acento);
      }
    }
    onBeat?.call(beat, acento);
    _click++;
  }

  void _playFallback(bool acento) {
    if (_player == null) return;
    final bytes = acento ? _acentoBytes : _normalBytes;
    if (bytes != null) {
      _player!.play(BytesSource(bytes), volume: acento ? 1.0 : 0.75);
    }
  }

  Future<void> dispose() async {
    stop();
    await _player?.dispose();
    _player = null;
    if (_nativeReady) {
      await NativeMetronome.dispose();
      _nativeReady = false;
    }
    _listo = false;
  }
}