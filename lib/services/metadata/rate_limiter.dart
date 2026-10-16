/// Limita la frecuencia de peticiones a un intervalo mínimo.
///
/// Usado por el cliente de MusicBrainz (máximo 1 petición por segundo).
class RateLimiter {
  final Duration minInterval;
  DateTime? _lastCall;

  /// [minInterval] tiempo mínimo entre peticiones (por defecto 1 segundo).
  RateLimiter({Duration minInterval = const Duration(seconds: 1)})
      : minInterval = minInterval;

  /// Ejecuta [action] esperando si es necesario para respetar el intervalo.
  Future<T> run<T>(Future<T> Function() action) async {
    if (_lastCall != null) {
      final elapsed = DateTime.now().difference(_lastCall!);
      if (elapsed < minInterval) {
        await Future.delayed(minInterval - elapsed);
      }
    }
    _lastCall = DateTime.now();
    return action();
  }
}
