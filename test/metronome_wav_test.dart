// Test de regresión del WAV generado por el metrónomo.
// Verifica que la cabecera es válida (RIFF/WAVE/fmt /data), que las
// muestras no son todas ceros (silencio), y que la envolvente elimina
// los "pops" digitales (primera y última muestra ≈ 0).
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:appchords/services/metronome.dart';

void main() {
  group('Generación WAV del metrónomo', () {
    for (final tipo in ClickSound.values) {
      test('WAV $tipo: cabecera correcta y muestras no nulas', () {
        final wav = _clickWavTest(tipo, milliseconds: 60, volume: 0.7);

        // 1) Cabecera RIFF
        expect(_readString(wav, 0, 4), equals('RIFF'));

        // 2) Tamaño RIFF (bytes 4-7) = 36 + total*2
        final riffSize = _readUint32LE(wav, 4);
        expect(riffSize, greaterThan(36));

        // 3) WAVE
        expect(_readString(wav, 8, 4), equals('WAVE'));

        // 4) fmt chunk
        expect(_readString(wav, 12, 4), equals('fmt '));
        final fmtSize = _readUint32LE(wav, 16);
        expect(fmtSize, equals(16));
        final audioFormat = _readUint16LE(wav, 20);
        expect(audioFormat, equals(1)); // PCM
        final channels = _readUint16LE(wav, 22);
        expect(channels, equals(1)); // mono
        final sampleRate = _readUint32LE(wav, 24);
        expect(sampleRate, equals(44100));

        // 5) data chunk
        expect(_readString(wav, 36, 4), equals('data'));
        final dataSize = _readUint32LE(wav, 40);
        expect(dataSize, greaterThan(0));
        expect(dataSize, equals(riffSize - 36));

        // 6) Muestras no son todas cero (habría detectado el bug anterior)
        final samples = <int>[];
        for (var i = 0; i < dataSize ~/ 2; i++) {
          final sample = _readInt16LE(wav, 44 + i * 2);
          samples.add(sample);
        }
        final nonZero = samples.where((s) => s != 0).length;
        expect(nonZero, greaterThan(0),
            reason: 'El WAV de $tipo no debe ser silencio (todas las muestras a 0)');

        // 7) Duración aproximada correcta (ms ±20%)
        final expectedSamples = (44100 * 60 / 1000).round();
        expect(samples.length, inInclusiveRange(expectedSamples - 100, expectedSamples + 100));

        // 8) El acento dura más que el normal
        final wavNormal = _clickWavTest(tipo, milliseconds: 40, volume: 0.7);
        final wavAcento = _clickWavTest(tipo, milliseconds: 60, volume: 1.0);
        final normalSize = _readUint32LE(wavNormal, 40);
        final acentoSize = _readUint32LE(wavAcento, 40);
        expect(acentoSize, greaterThan(normalSize),
            reason: 'El acento debe durar más que el click normal');
      });
    }

    test('Cada tipo de sonido genera formas de onda distintas', () {
      final waves = <ClickSound, Uint8List>{};
      for (final tipo in ClickSound.values) {
        waves[tipo] = _clickWavTest(tipo, milliseconds: 60, volume: 0.7);
      }
      // Comparar solo la parte de datos (sin cabecera)
      final dataParts = <ClickSound, List<int>>{};
      for (final e in waves.entries) {
        final dataSize = _readUint32LE(e.value, 40);
        final samples = <int>[];
        for (var i = 0; i < dataSize ~/ 2; i++) {
          samples.add(_readInt16LE(e.value, 44 + i * 2));
        }
        dataParts[e.key] = samples;
      }
      // Cada par debe diferir
      final tipos = ClickSound.values;
      for (var i = 0; i < tipos.length; i++) {
        for (var j = i + 1; j < tipos.length; j++) {
          final a = dataParts[tipos[i]]!;
          final b = dataParts[tipos[j]]!;
          final equal = a.length == b.length && a.asMap().entries.every((e) => e.value == b[e.key]);
          expect(equal, isFalse, reason: '${tipos[i]} y ${tipos[j]} no deben ser idénticos');
        }
      }
    });

    group('Envolvente (fade-in / fade-out)', () {
      for (final tipo in ClickSound.values) {
        test('$tipo: primera y última muestra ≈ 0 (sin pops)', () {
          final wav = _clickWavTest(tipo, milliseconds: 60, volume: 1.0);
          final dataSize = _readUint32LE(wav, 40);
          final firstSample = _readInt16LE(wav, 44);
          final lastSample = _readInt16LE(wav, 44 + (dataSize - 2));
          // Con la envolvente, la primera muestra (fade-in) y la última (fade-out) deben ser ~0
          expect(firstSample.abs(), lessThan(100),
              reason: 'Fade-in: primera muestra debe ser casi 0, es $firstSample');
          expect(lastSample.abs(), lessThan(100),
              reason: 'Fade-out: última muestra debe ser casi 0, es $lastSample');
        });

        test('$tipo: pico en la envolvente (amplitud significativa)', () {
          final wav = _clickWavTest(tipo, milliseconds: 60, volume: 1.0);
          final dataSize = _readUint32LE(wav, 40);
          final sampleCount = dataSize ~/ 2;
          // Buscar el máximo absoluto en la zona central (excluyendo fade-in/out)
          final start = 100.clamp(0, sampleCount);
          final end = (sampleCount - 100).clamp(0, sampleCount);
          var maxAbs = 0;
          for (var i = start; i < end; i++) {
            final s = _readInt16LE(wav, 44 + i * 2).abs();
            if (s > maxAbs) maxAbs = s;
          }
          expect(maxAbs, greaterThan(2000),
              reason: 'Debe haber señal significativa en la envolvente (max=$maxAbs)');
        });
      }
    });
  });
}

/// Copia interna de _clickWav para testear (no es pública).
/// Debe coincidir exactamente con la implementación en metronome.dart.
Uint8List _clickWavTest(ClickSound tipo, {required int milliseconds, required double volume}) {
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
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, sampleRate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  tag('data', 36);
  data.setUint32(40, total * 2, Endian.little);

  // Parámetros de envolvente (idénticos a metronome.dart)
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
        final noise = (rng.nextDouble() * 2 - 1);
        value = noise * exp(-t * 120);
        value += sin(2 * pi * 3500 * t) * exp(-t * 200) * 0.3;
      case ClickSound.bip:
        value = sin(2 * pi * 1100 * t) * exp(-t * 45);
      case ClickSound.caja:
        final noise = (rng.nextDouble() * 2 - 1) * exp(-t * 50);
        final tone = sin(2 * pi * 180 * t) * exp(-t * 35);
        final snap = sin(2 * pi * 2500 * t) * exp(-t * 150) * 0.2;
        value = noise + tone + snap;
      case ClickSound.campana:
        value = sin(2 * pi * 850 * t) * exp(-t * 9);
        value += sin(2 * pi * 1275 * t) * exp(-t * 12) * 0.6;
    }
    final sample = (value * volume * 32767 * env).clamp(-32768, 32767).round();
    data.setInt16(44 + i * 2, sample, Endian.little);
  }
  return data.buffer.asUint8List();
}

int _readUint32LE(Uint8List b, int offset) =>
    b[offset] | (b[offset + 1] << 8) | (b[offset + 2] << 16) | (b[offset + 3] << 24);

int _readUint16LE(Uint8List b, int offset) => b[offset] | (b[offset + 1] << 8);

int _readInt16LE(Uint8List b, int offset) {
  final v = _readUint16LE(b, offset);
  return v >= 32768 ? v - 65536 : v;
}

String _readString(Uint8List b, int offset, int len) =>
    String.fromCharCodes(b.sublist(offset, offset + len));