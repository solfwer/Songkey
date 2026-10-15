// Metrónomo: sonido e indicador visual del beat.
// Usa flutter_soloud con loop de compás en memoria (WAV generado en Dart).
// En todas las plataformas el timing corre en Dart con programación absoluta
// (nextTime += intervalo, sin acumular jitter) y onBeat se dispara desde ahí.
import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:meta/meta.dart';

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
  corchea(2, 'Corcheas');

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
  final rng = Random(12345);

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

/// Genera un WAV de un compás completo con todos los clicks colocados
/// en sus posiciones exactas por muestra. Incluye acento en el primer
/// pulso si [accent] es true. Maneja wrap-around de colas que cruzan
/// el límite del compás para evitar pops en el loop.
Uint8List _buildBarWav({
  required ClickSound tipo,
  required int bpm,
  required int beatsPerBar,
  required int clicksPerBeat,
  required bool accent,
}) {
  const sampleRate = 44100;

  // Duración de un pulso (negra) en muestras
  final samplesPerBeat = ((sampleRate * 60) / bpm).round();
  // Duración total del compás en muestras
  final totalSamples = samplesPerBeat * beatsPerBar;
  // Click por subdivisión (negra=1, corchea=2)
  final samplesPerClick = (samplesPerBeat / clicksPerBeat).round();

  // Generar los dos clicks (normal y acento) con duración suficiente
  // La campana dura más (300ms acento, 250ms normal), otras ~60/40ms
  final msAcento = tipo == ClickSound.campana ? 300 : 60;
  final msNormal = tipo == ClickSound.campana ? 250 : 40;

  final clickNormal = _clickWav(tipo, milliseconds: msNormal, volume: 0.7);
  final clickAcento = _clickWav(tipo, milliseconds: msAcento, volume: 1.0);

  // Extraer solo las muestras de audio (sin cabecera WAV)
  Int16List extractSamples(Uint8List wav) {
    final dataSize = _readUint32LE(wav, 40);
    final samples = Int16List(dataSize ~/ 2);
    for (var i = 0; i < samples.length; i++) {
      samples[i] = _readInt16LE(wav, 44 + i * 2);
    }
    return samples;
  }

  final normalSamples = extractSamples(clickNormal);
  final acentoSamples = extractSamples(clickAcento);

  // Buffer de salida (mono 16-bit)
  final output = Int16List(totalSamples);

  // Total de clicks en el compás
  final totalClicks = beatsPerBar * clicksPerBeat;

  for (var k = 0; k < totalClicks; k++) {
    // Posición exacta de este click en muestras
    final pos = (k * samplesPerClick).round();
    if (pos >= totalSamples) continue;

    // Determinar si este click es el del acento (primer pulso, en tiempo, con acento activado)
    final enPulso = k % clicksPerBeat == 0;
    final pulso = k ~/ clicksPerBeat;
    final isAccent = enPulso && accent && pulso == 0;

    final src = isAccent ? acentoSamples : normalSamples;

    // Mezclar con wrap-around (cola que pasa al inicio del compás)
    for (var i = 0; i < src.length; i++) {
      final dst = (pos + i) % totalSamples;
      final sum = output[dst] + src[i];
      output[dst] = sum.clamp(-32768, 32767);
    }
  }

  return _writeWav(output);
}

/// Escribe un buffer Int16List como WAV mono 16-bit 44.1 kHz.
Uint8List _writeWav(Int16List pcm) {
  final dataLen = pcm.lengthInBytes;
  final b = ByteData(44 + dataLen);
  void str(int o, String s) {
    for (var i = 0; i < s.length; i++) {
      b.setUint8(o + i, s.codeUnitAt(i));
    }
  }

  str(0, 'RIFF');
  b.setUint32(4, 36 + dataLen, Endian.little);
  str(8, 'WAVE');
  str(12, 'fmt ');
  b.setUint32(16, 16, Endian.little);
  b.setUint16(20, 1, Endian.little);   // PCM
  b.setUint16(22, 1, Endian.little);   // mono
  b.setUint32(24, 44100, Endian.little);
  b.setUint32(28, 44100 * 2, Endian.little);
  b.setUint16(32, 2, Endian.little);
  b.setUint16(34, 16, Endian.little);
  str(36, 'data');
  b.setUint32(40, dataLen, Endian.little);

  final bytes = b.buffer.asUint8List();
  bytes.setRange(44, 44 + dataLen, pcm.buffer.asUint8List());
  return bytes;
}

// Helpers para leer WAV (usados en _buildBarWav)
int _readUint32LE(Uint8List b, int offset) =>
    b[offset] | (b[offset + 1] << 8) | (b[offset + 2] << 16) | (b[offset + 3] << 24);

int _readUint16LE(Uint8List b, int offset) => b[offset] | (b[offset + 1] << 8);

int _readInt16LE(Uint8List b, int offset) {
  final v = _readUint16LE(b, offset);
  return v >= 32768 ? v - 65536 : v;
}

/// Metrónomo con flutter_soloud: loop de compás + timer visual absoluto.
class Metronome {
  MetronomeSettings settings;
  Metronome({MetronomeSettings? settings}) : settings = settings ?? MetronomeSettings();

  Timer? _timer;
  AudioSource? _barSource;
  SoundHandle? _barHandle;
  bool _disposed = false;
  bool _preparando = false;
  bool _listo = false;
  Object? _ultimoError;
  int _click = 0;
  ClickSound? _timbrePreparado;
  int? _prepBpm;
  int? _prepBeatsPerBar;
  int? _prepSubdivision;
  bool? _prepAccent;

  /// Se llama en cada click con el índice de pulso dentro del compás
  /// (0 = primer tiempo) y si es el click del acento.
  void Function(int beat, bool acento)? onBeat;

  bool get activo => _barHandle != null || _timer != null;
  bool get preparando => _preparando;
  bool get listo => _listo;
  Object? get ultimoError => _ultimoError;

  /// Prepara el motor y genera el WAV del compás actual.
  Future<bool> preparar() async {
    if (_listo &&
        _timbrePreparado == settings.clickSound &&
        _prepBpm == settings.bpm &&
        _prepBeatsPerBar == settings.beatsPerBar &&
        _prepSubdivision == settings.subdivision.clicksPerBeat &&
        _prepAccent == settings.accent) {
      return true;
    }
    if (_preparando) return false;

    _preparando = true;
    try {
      // Inicializar SoLoud si no está
      final so = SoLoud.instance;
      if (!so.isInitialized) {
        await so.init();
      }

      // Generar WAV del compás
      final barWav = _buildBarWav(
        tipo: settings.clickSound,
        bpm: settings.bpm,
        beatsPerBar: settings.beatsPerBar,
        clicksPerBeat: settings.subdivision.clicksPerBeat,
        accent: settings.accent,
      );

      // Cargar en SoLoud (nombre único para forzar reload)
      final name = 'metro_bar_${settings.clickSound.index}_${settings.bpm}_${settings.beatsPerBar}_${settings.subdivision.index}_${settings.accent ? 1 : 0}';
      _barSource = await so.loadMem(name, barWav);

      // Guardar parámetros de preparación
      _timbrePreparado = settings.clickSound;
      _prepBpm = settings.bpm;
      _prepBeatsPerBar = settings.beatsPerBar;
      _prepSubdivision = settings.subdivision.clicksPerBeat;
      _prepAccent = settings.accent;

      _listo = true;
      _ultimoError = null;
      return true;
    } catch (e) {
      _ultimoError = e;
      _listo = false;
      return false;
    } finally {
      _preparando = false;
    }
  }

  /// Regenera el compás (al cambiar timbre, BPM, compás, subdivisión o acento).
  Future<void> regenerarSonido() async {
    stop();
    _listo = false;
    _timbrePreparado = null;
    _prepBpm = null;
    _prepBeatsPerBar = null;
    _prepSubdivision = null;
    _prepAccent = null;
    if (_barSource != null) {
      try {
        await SoLoud.instance.disposeSource(_barSource!);
      } catch (_) {}
      _barSource = null;
    }
    await preparar();
  }

  /// Inicia el loop del compás y el timer visual.
  void start() {
    if (_disposed) return;
    if (activo) return;

    _click = 0;

    if (settings.sound && _listo && _barSource != null) {
      try {
        _barHandle = SoLoud.instance.play(_barSource!, looping: true);
      } catch (e) {
        _ultimoError = e;
        _barHandle = null;
      }
    }

    // Timer visual con programación absoluta (sin jitter acumulado)
    _iniciarTimerVisual();
  }

  void _iniciarTimerVisual() {
    _timer?.cancel();
    _click = 0;
    final porPulso = settings.subdivision.clicksPerBeat;
    final micros = (60000000 / settings.bpm / porPulso).round();
    var nextTime = DateTime.now().microsecondsSinceEpoch;

    void tick() {
      if (_disposed || _timer == null) return;

      final now = DateTime.now().microsecondsSinceEpoch;
      final interval = micros;

      // Si llegamos tarde, saltar al siguiente tiempo absoluto (no acumular retraso)
      if (now > nextTime + interval) {
        final elapsed = now - nextTime;
        final skipped = (elapsed / interval).floor() + 1;
        nextTime += skipped * interval;
        _click += skipped;
      }

      final enPulso = _click % porPulso == 0;
      final pulso = _click ~/ porPulso;
      final beat = pulso % settings.beatsPerBar;
      final acento = enPulso && settings.accent && beat == 0;

      onBeat?.call(beat, acento);
      _click++;
      nextTime += interval;

      // Programar siguiente tick
      final sleepMicros = nextTime - DateTime.now().microsecondsSinceEpoch;
      if (sleepMicros > 0) {
        _timer = Timer(Duration(microseconds: sleepMicros), tick);
      } else {
        // Ya pasó el tiempo, ejecutar en siguiente microtask
        Timer.run(tick);
      }
    }

    Timer.run(tick);
  }

  /// Reinicia el metrónomo (cambio de BPM, compás, subdivisión, timbre).
  /// Reconstruye el WAV y reinicia en el tiempo 1.
  void restart() {
    if (_disposed) return;
    stop();
    _listo = false;
    _timbrePreparado = null;
    _prepBpm = null;
    _prepBeatsPerBar = null;
    _prepSubdivision = null;
    _prepAccent = null;
    if (_barSource != null) {
      SoLoud.instance.disposeSource(_barSource!);
      _barSource = null;
    }
    // prepararse y arrancar de nuevo se hace desde el controlador
  }

  /// Detiene el metrónomo (audio y timer visual).
  void stop() {
    if (_barHandle != null) {
      try {
        SoLoud.instance.stop(_barHandle!);
      } catch (_) {}
      _barHandle = null;
    }
    _timer?.cancel();
    _timer = null;
    _click = 0;
  }

  Future<void> dispose() async {
    _disposed = true;
    stop();
    if (_barSource != null) {
      try {
        await SoLoud.instance.disposeSource(_barSource!);
      } catch (_) {}
      _barSource = null;
    }
    _listo = false;
  }

  /// Para tests: permite reiniciar el contador de clicks sin detener el metrónomo.
  @visibleForTesting
  void resetClickCount() => _click = 0;

  /// Para tests: expone el generador de compás.
  @visibleForTesting
  static Uint8List buildBarWavForTest({
    required ClickSound tipo,
    required int bpm,
    required int beatsPerBar,
    required int clicksPerBeat,
    required bool accent,
  }) => _buildBarWav(
        tipo: tipo,
        bpm: bpm,
        beatsPerBar: beatsPerBar,
        clicksPerBeat: clicksPerBeat,
        accent: accent,
      );
}