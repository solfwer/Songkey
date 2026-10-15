// Envoltura del canal nativo SoundPool para el metrónomo.
// En Android usa un hilo dedicado con timing absoluto; en iOS/web/tests cae a audioplayers.
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart';

class NativeMetronome {
  static const _channel = MethodChannel('com.songkey/metronome');

  static bool _available = true;
  static final _beatCallbacks = <void Function(int beat, bool accent)>[];

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

  /// Inicia el metrónomo nativo con los parámetros dados.
  /// El loop corre en un hilo dedicado en Android; Dart solo recibe callbacks onBeat.
  static Future<bool> start({
    required int bpm,
    required int beatsPerBar,
    required int subdivision, // 1 = negra, 2 = corchea
    required int timbre, // 0=click, 1=bip, 2=caja, 3=campana
    required bool accent,
    required bool soundOn,
  }) async {
    if (!_available) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('start', {
        'bpm': bpm,
        'beatsPerBar': beatsPerBar,
        'subdivision': subdivision,
        'timbre': timbre,
        'accent': accent,
        'soundOn': soundOn,
      });
      return ok ?? false;
    } on PlatformException catch (_) {
      _available = false;
      return false;
    }
  }

  /// Actualiza ajustes en caliente sin reiniciar el hilo nativo.
  static Future<bool> updateSettings({
    required int bpm,
    required int beatsPerBar,
    required int subdivision,
    required int timbre,
    required bool accent,
    required bool soundOn,
  }) async {
    if (!_available) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('updateSettings', {
        'bpm': bpm,
        'beatsPerBar': beatsPerBar,
        'subdivision': subdivision,
        'timbre': timbre,
        'accent': accent,
        'soundOn': soundOn,
      });
      return ok ?? false;
    } on PlatformException catch (_) {
      _available = false;
      return false;
    }
  }

  /// Detiene el metrónomo nativo.
  static Future<void> stop() async {
    if (!_available) return;
    try {
      await _channel.invokeMethod('stop');
    } catch (_) {
      _available = false;
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

  /// Registra un callback para recibir eventos de beat desde el nativo.
  static void addBeatListener(void Function(int beat, bool accent) callback) {
    _beatCallbacks.add(callback);
    _ensureListener();
  }

  /// Elimina un callback.
  static void removeBeatListener(void Function(int beat, bool accent) callback) {
    _beatCallbacks.remove(callback);
  }

  static bool _listenerRegistered = false;

  static void _ensureListener() {
    if (_listenerRegistered) return;
    _listenerRegistered = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onBeat') {
        final args = Map<String, dynamic>.from(call.arguments as Map);
        final beat = args['beat'] as int;
        final accent = args['accent'] as bool;
        for (final cb in _beatCallbacks) {
          cb(beat, accent);
        }
      }
    });
  }

  /// Para tests: fuerza el fallback a audioplayers.
  static void forceFallback() => _available = false;

  /// Para tests: restaura disponibilidad real.
  static void resetAvailability() {
    _available = true;
    _listenerRegistered = false;
  }

  static bool get available => _available;
}