/// Detector de tonalidad a partir de los acordes de un texto ChordPro.
///
/// Funciona 100% offline. Extrae los acordes entre corchetes [..],
/// normaliza (bemoles → sostenidos, bajo C/E usa la raíz C, calidad menor/disminuida/mayor)
/// y puntúa las 24 tonalidades (12 mayores + 12 menores) por cuántos acordes
/// de la canción pertenecen al conjunto diatónico de cada tonalidad.
const _sharps = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];

class ChordKeyDetector {

  /// Mapeo de bemoles a su equivalente en sostenidos.
  static const _flats = {
    'Db': 'C#', 'Eb': 'D#', 'Gb': 'F#', 'Ab': 'G#', 'Bb': 'A#',
    'Cb': 'B', 'Fb': 'E',
  };

  /// Los 12 tonos en sostenidos.
  static const _roots = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];

  /// Extrae y normaliza los acordes de un texto ChordPro.
  /// Devuelve acordes normalizados (ej. "C", "C#m", "D", "F#dim").
  List<String> _extractChords(String text) {
    final chords = <String>[];
    final chordRegex = RegExp(r'\[([^\[\]]+)\]');
    for (final match in chordRegex.allMatches(text)) {
      final raw = match.group(1)!;
      if (raw.startsWith('*') || raw.startsWith('{') || raw.startsWith(':')) continue;
      final normalized = _normalizeChord(raw);
      if (normalized != null) chords.add(normalized);
    }
    return chords;
  }

  /// Normaliza un acorde crudo a su forma canónica: raíz + calidad.
  String? _normalizeChord(String raw) {
    final m = RegExp(r'^([A-G][#b]?)(m|maj|M|dim|°|aug|\+|sus|add)?(/[A-G][#b]?)?(\d+.*)?$')
        .firstMatch(raw);
    if (m == null) return null;

    final rootRaw = m.group(1)!;
    final qualityRaw = (m.group(2) ?? '').toLowerCase();
    // Si hay bajo (C/E), usar solo la raíz.

    final root = _flats[rootRaw] ?? rootRaw;

    // Determinar calidad.
    String quality;
    if (qualityRaw.startsWith('m') && !qualityRaw.startsWith('maj')) {
      quality = 'm'; // menor: Am, Am7, Cm (no maj7)
    } else if (qualityRaw.contains('dim') || qualityRaw.contains('°')) {
      quality = 'dim'; // disminuida
    } else {
      quality = ''; // mayor/dominante/sus4/etc → se trata como mayor
    }

    return '$root$quality';
  }

  /// Devuelve los 7 acordes diatónicos de una tonalidad mayor.
  List<String> _majorDiatonic(String tonic) {
    final i = _roots.indexOf(tonic);
    return [
      tonic,                                    // I
      '${_roots[(i + 2) % 12]}m',              // ii
      '${_roots[(i + 4) % 12]}m',              // iii
      _roots[(i + 5) % 12],                    // IV
      _roots[(i + 7) % 12],                    // V
      '${_roots[(i + 9) % 12]}m',              // vi
      '${_roots[(i + 11) % 12]}dim',           // vii°
    ];
  }

  /// Devuelve los 7 acordes diatónicos de una tonalidad menor (natural + V mayor).
  List<String> _minorDiatonic(String tonic) {
    final i = _roots.indexOf(tonic);
    return [
      '${tonic}m',                               // i
      '${_roots[(i + 2) % 12]}dim',            // ii°
      _roots[(i + 3) % 12],                    // III
      '${_roots[(i + 5) % 12]}m',              // iv
      _roots[(i + 7) % 12],                    // V (armónica: mayor)
      _roots[(i + 8) % 12],                    // VI
      _roots[(i + 10) % 12],                   // VII
    ];
  }

  /// Detecta la tonalidad más probable y su confianza.
  /// Devuelve clave nula si no hay acordes suficientes.
  ({String? key, double confidence}) detect(String chordProText) {
    final chords = _extractChords(chordProText);
    if (chords.isEmpty) return (key: null, confidence: 0.0);

    final chordCounts = <String, int>{};
    for (final c in chords) {
      chordCounts[c] = (chordCounts[c] ?? 0) + 1;
    }
    final distinctCount = chordCounts.keys.length;
    if (distinctCount < 2) return (key: null, confidence: 0.0);

    final firstChord = chords.first;
    final lastChord = chords.last;

    final scores = <String, double>{};

    for (final root in _roots) {
      // Tonalidad mayor.
      final majorDiatonic = _majorDiatonic(root);
      var majorScore = 0.0;
      for (final entry in chordCounts.entries) {
        if (majorDiatonic.contains(entry.key)) {
          majorScore += entry.value * 1.0;
        } else {
          majorScore -= entry.value * 0.3;
        }
      }
      if (firstChord == root) majorScore += 2.0;
      if (lastChord == root) majorScore += 2.0;
      scores[root] = majorScore;

      // Tonalidad menor.
      final minorKey = '${root}m';
      final minorDiatonic = _minorDiatonic(root);
      var minorScore = 0.0;
      for (final entry in chordCounts.entries) {
        if (minorDiatonic.contains(entry.key)) {
          minorScore += entry.value * 1.0;
        } else {
          minorScore -= entry.value * 0.3;
        }
      }
      if (firstChord == minorKey) minorScore += 2.0;
      if (lastChord == minorKey) minorScore += 2.0;
      scores[minorKey] = minorScore;
    }

    final sorted = scores.entries.toList()
      ..sort((a, b) {
        final cmp = b.value.compareTo(a.value);
        if (cmp != 0) return cmp;
        // Desempate: preferir la tonalidad cuya tónica es el primer acorde.
        final aTonic = a.key.replaceAll('m', '');
        final bTonic = b.key.replaceAll('m', '');
        final aFirst = aTonic == firstChord.replaceAll('m', '');
        final bFirst = bTonic == firstChord.replaceAll('m', '');
        if (aFirst && !bFirst) return -1;
        if (!aFirst && bFirst) return 1;
        return 0;
      });

    final best = sorted.first;
    final second = sorted.length > 1 ? sorted[1].value : 0.0;

    // Confianza: fracción de acordes distintos de la canción que están en el
    // conjunto diatónico de la mejor tonalidad, ajustada por separación al segundo.
    final bestDiatonic = best.key.endsWith('m')
        ? _minorDiatonic(best.key.replaceAll('m', ''))
        : _majorDiatonic(best.key);
    final matchingDistinct = chordCounts.keys.where((c) => bestDiatonic.contains(c)).length;
    var confidence = (matchingDistinct / distinctCount).clamp(0.0, 1.0);
    // Reducir si el segundo está muy cerca.
    if (best.value > 0) {
      confidence = confidence * ((best.value - second) / best.value).clamp(0.3, 1.0);
    }

    // Desempate entre relativo mayor/menor (ej. C vs Am).
    if (sorted.length >= 2) {
      final bestKey = best.key;
      final secondKey = sorted[1].key;
      final bestIsMinor = bestKey.endsWith('m');
      final secondIsMinor = secondKey.endsWith('m');
      if (bestIsMinor != secondIsMinor) {
        final bestRoot = bestKey.replaceAll('m', '');
        final secondRoot = secondKey.replaceAll('m', '');
        final bestRootCount = chordCounts[bestRoot] ?? 0;
        final secondRootCount = chordCounts[secondRoot] ?? 0;
        if (secondRootCount > bestRootCount) {
          final secondDiatonic = sorted[1].key.endsWith('m')
              ? _minorDiatonic(sorted[1].key.replaceAll('m', ''))
              : _majorDiatonic(sorted[1].key);
          final secondMatching = chordCounts.keys.where((c) => secondDiatonic.contains(c)).length;
          confidence = (secondMatching / distinctCount).clamp(0.0, 1.0);
          return (key: sorted[1].key, confidence: confidence);
        }
      }
    }

    return (key: best.key, confidence: confidence);
  }
}
