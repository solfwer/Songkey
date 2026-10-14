// Envoltura del canal nativo SoundPool para el metrónomo.
// Si el canal no está disponible (tests, iOS, web), lanza UnsupportedError.
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart';

class NativeMetronome {
  static const _channel = MethodChannel('com.songkey/metronome');

  static bool _available = true;

  /// Prepara el SoundPool nativo con los 8 WAV (4 timbres × acento/normal).
  /// [sounds] mapa: slot → bytes WAV. Slots 0-3 = normal, 4-7 = acento.
  static Future<bool> prepare(Map<int, Uint8List> sounds) async {
    if (!_available) return false;
    try {
      final map = <String, List<int>>{};
      sounds.forEach((k, v) {
        map[k.toString()] = v.toList();
      });
      final ok = await _channel.invokeMethod<bool>('prepare', {'sounds': map});
      return ok ?? false;
    } on PlatformException catch (_) {
      _available = false;
      return false;
    }
  }

  /// Dispara un click. [slot] 0-7, [volume] 0.0-1.0.
  static Future<bool> play(int slot, double volume) async {
    if (!_available) throw UnsupportedError('NativeMetronome not available');
    try {
      final ok = await _channel.invokeMethod<bool>('play', {
        'slot': slot,
        'volume': volume,
      });
      return ok ?? false;
    } on PlatformException catch (_) {
      _available = false;
      rethrow;
    }
  }

  static Future<void> dispose() async {
    if (!_available) return;
    try {
      await _channel.invokeMethod('dispose');
    } catch (_) {
      // ignore
    }
  }

  /// Para tests: fuerza el fallback a audioplayers.
  static void forceFallback() => _available = false;

  /// Para tests: restaura disponibilidad real.
  static void resetAvailability() => _available = true;

  static bool get available => _available;
}