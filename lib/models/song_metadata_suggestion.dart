/// Resultado de una sugerencia de metadatos para una canción.
/// Cada campo trae su valor, la fuente y una confianza (0.0 - 1.0).
/// Nunca se guarda a ciegas: el usuario confirma o edita.

enum MetadataSource { chords, api, tap, manual }

String metadataSourceLabel(MetadataSource s) {
  switch (s) {
    case MetadataSource.chords:
      return 'Detectado por acordes';
    case MetadataSource.api:
      return 'GetSongBPM / MusicBrainz';
    case MetadataSource.tap:
      return 'Tap tempo';
    case MetadataSource.manual:
      return 'Introducido manualmente';
  }
}

/// Un campo con su sugerencia, fuente y confianza.
class FieldSuggestion<T> {
  final T value;
  final MetadataSource source;
  final double confidence; // 0.0 - 1.0

  const FieldSuggestion(this.value, this.source, this.confidence);
}

/// Candidato devuelto por una API online (para elegir entre varios).
class SongCandidate {
  final String title;
  final String? artist;
  final String? key;
  final int? bpm;
  final String? timeSignature;
  final String source; // 'getsongbpm' | 'musicbrainz'
  final String externalId;

  SongCandidate({
    required this.title,
    this.artist,
    this.key,
    this.bpm,
    this.timeSignature,
    required this.source,
    required this.externalId,
  });
}

/// Sugerencia completa de metadatos para una canción.
class SongMetadataSuggestion {
  final FieldSuggestion<String>? key;        // ej. "C#m"
  final FieldSuggestion<int>? bpm;
  final FieldSuggestion<String>? artist;
  final FieldSuggestion<String>? timeSignature; // ej. "4/4"
  final List<SongCandidate> candidates;

  const SongMetadataSuggestion({
    this.key,
    this.bpm,
    this.artist,
    this.timeSignature,
    this.candidates = const [],
  });

  /// Si hay alguna sugerencia disponible.
  bool get hasAny =>
      key != null || bpm != null || artist != null || timeSignature != null;

  /// Combina esta sugerencia con otra (esta tiene prioridad en los campos que tiene).
  SongMetadataSuggestion mergeWith(SongMetadataSuggestion other) {
    return SongMetadataSuggestion(
      key: key ?? other.key,
      bpm: bpm ?? other.bpm,
      artist: artist ?? other.artist,
      timeSignature: timeSignature ?? other.timeSignature,
      candidates: [...other.candidates, ...candidates],
    );
  }
}
