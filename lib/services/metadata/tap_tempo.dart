/// Calcula BPM a partir de toques del usuario (tap tempo).
///
/// Funciona 100% offline. Registra los instantes de cada toque y calcula
/// el BPM como 60000 / promedio de los intervalos usando los últimos 6-8 toques.
/// Requiere mínimo 3 toques para dar resultado.
/// Reinicia la serie si pasan más de 2 segundos desde el último toque.
class TapTempo {
  static const _maxIntervalMs = 2000; // reiniciar si pasa más de 2 s
  static const _minTaps = 3;          // mínimo de toques para dar resultado
  static const _maxTaps = 8;          // usar los últimos N toques
  static const _bpmMin = 30;
  static const _bpmMax = 300;

  final List<DateTime> _taps = [];

  /// Registra un toque en el instante actual.
  void tap() {
    final now = DateTime.now();
    if (_taps.isNotEmpty &&
        now.difference(_taps.last).inMilliseconds > _maxIntervalMs) {
      _taps.clear();
    }
    _taps.add(now);
    if (_taps.length > _maxTaps) _taps.removeAt(0);
  }

  /// Devuelve el BPM calculado o null si no hay suficientes toques.
  int? get bpm {
    if (_taps.length < _minTaps) return null;
    final intervals = <int>[];
    for (var i = 1; i < _taps.length; i++) {
      intervals.add(_taps[i].difference(_taps[i - 1]).inMilliseconds);
    }
    final avg = intervals.reduce((a, b) => a + b) / intervals.length;
    if (avg <= 0) return null;
    var bpm = (60000 / avg).round();
    bpm = bpm.clamp(_bpmMin, _bpmMax);
    return bpm;
  }

  /// Número de toques registrados.
  int get tapCount => _taps.length;

  /// Reinicia la serie de toques.
  void reset() => _taps.clear();
}
