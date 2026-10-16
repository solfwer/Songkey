import 'chord_key_detector.dart';
import 'getsongbpm_client.dart';
import 'musicbrainz_client.dart';
import '../../models/song_metadata_suggestion.dart';

/// Orquestador de sugerencias de metadatos de canciones.
///
/// Combina fuentes offline (detecto de tonalidad por acordes, tap tempo)
/// con fuentes online (GetSongBPM, MusicBrainz) respetando:
/// 1. Nunca sobrescribir campos que el usuario ya llenó.
/// 2. Caché negativa: no volver a consultar un título fallido por 30 días.
/// 3. Degradación silenciosa: sin internet o error, solo se omite la parte online.
class SongMetadataService {
  final ChordKeyDetector _chordKeyDetector = ChordKeyDetector();
  final GetSongBpmClient _getsongbpm;
  final MusicBrainzClient _musicbrainz;

  /// Caché negativa: título normalizado → fecha de la última consulta fallida.
  /// Si pasó menos de 30 días, no se vuelve a consultar.
  final Map<String, DateTime> _negativeCache = {};

  SongMetadataService({
    required GetSongBpmClient getsongbpm,
    required MusicBrainzClient musicbrainz,
  })  : _getsongbpm = getsongbpm,
        _musicbrainz = musicbrainz;

  /// Debounce en ms para consultas automáticas al escribir el título.
  static const debounceMs = 700;

  /// Dias de caché negativa.
  static const negativeCacheDays = 30;

  /// Genera una sugerencia de metadatos para una canción.
  ///
  /// [titulo] título de la canción (para consultar online).
  /// [chordProText] texto ChordPro (para detectar tono offline).
  /// [existing] campos ya llenos por el usuario (no se sobrescriben).
  /// [consultarOnline] si se permite hacer peticiones HTTP.
  Future<SongMetadataSuggestion> sugerir({
    required String titulo,
    String? chordProText,
    required Map<String, String?> existing, // campo → valor actual (null si vacío)
    bool consultarOnline = true,
  }) async {
    var suggestion = SongMetadataSuggestion();

    // 1. Offline: detección de tonalidad por acordes.
    if (existing['key'] == null || existing['key']!.isEmpty) {
      if (chordProText != null && chordProText.isNotEmpty) {
        final det = _chordKeyDetector.detect(chordProText);
        if (det.key != null && det.confidence >= 0.3) {
          suggestion = suggestion.mergeWith(SongMetadataSuggestion(
            key: FieldSuggestion(det.key!, MetadataSource.chords, det.confidence),
          ));
        }
      }
    }

    // 2. Online: si faltan campos y hay conexión y no hay caché negativa vigente.
    if (consultarOnline && _shouldQueryOnline(titulo, existing)) {
      try {
        final apiResult = await _queryApis(titulo, existing);
        suggestion = suggestion.mergeWith(apiResult);
      } catch (_) {
        // Silenciar errores online.
      }
      // Marcar caché negativa aunque no haya resultados (para no re-consultar).
      _negativeCache[titulo.trim().toLowerCase()] = DateTime.now();
    }

    return suggestion;
  }

  /// Si se debe consultar online para este título.
  bool _shouldQueryOnline(String titulo, Map<String, String?> existing) {
    final tieneFaltantes = existing.values.any((v) => v == null || v!.isEmpty);
    if (!tieneFaltantes) return false; // Todo lleno, no hace falta.

    final key = titulo.trim().toLowerCase();
    final ultima = _negativeCache[key];
    if (ultima != null) {
      final dias = DateTime.now().difference(ultima).inDays;
      if (dias < negativeCacheDays) return false; // Caché negativa vigente.
    }
    return true;
  }

  /// Consulta GetSongBPM y MusicBrainz en paralelo, respetando los campos faltantes.
  Future<SongMetadataSuggestion> _queryApis(
      String titulo, Map<String, String?> existing) async {
    var suggestion = SongMetadataSuggestion();
    final needsArtist = existing['author'] == null || existing['author']!.isEmpty;
    final needsKey = existing['key'] == null || existing['key']!.isEmpty;
    final needsBpm = existing['bpm'] == null;
    final needsTime = existing['timeSignature'] == null || existing['timeSignature']!.isEmpty;

    // Búsqueda en GetSongBPM (si necesitamos al menos un campo).
    SongCandidate? gsbCandidate;
    if (needsArtist || needsKey || needsBpm || needsTime) {
      try {
        final candidates = await _getsongbpm.search(titulo);
        if (candidates.isNotEmpty) {
          gsbCandidate = candidates.first;
          suggestion = suggestion.mergeWith(SongMetadataSuggestion(
            candidates: candidates,
          ));
        }
      } catch (_) {}
    }

    // Detalle de la canción en GetSongBPM (si hay candidato y necesitamos más datos).
    if (gsbCandidate != null && (needsKey || needsBpm || needsTime)) {
      try {
        final detail = await _getsongbpm.songById(gsbCandidate.externalId);
        if (detail != null) {
          if (needsKey && detail.key != null && detail.key!.isNotEmpty) {
            suggestion = suggestion.mergeWith(SongMetadataSuggestion(
              key: FieldSuggestion(detail.key!, MetadataSource.api, 0.7),
            ));
          }
          if (needsBpm && detail.bpm != null) {
            suggestion = suggestion.mergeWith(SongMetadataSuggestion(
              bpm: FieldSuggestion(detail.bpm!, MetadataSource.api, 0.8),
            ));
          }
          if (needsTime && detail.timeSignature != null && detail.timeSignature!.isNotEmpty) {
            suggestion = suggestion.mergeWith(SongMetadataSuggestion(
              timeSignature: FieldSuggestion(
                  detail.timeSignature!, MetadataSource.api, 0.7),
            ));
          }
        }
      } catch (_) {}
    }

    // MusicBrainz para el autor (si lo necesitamos y no lo tenemos de GSB).
    if (needsArtist && (gsbCandidate?.artist == null || gsbCandidate!.artist!.isEmpty)) {
      try {
        final artist = await _musicbrainz.searchArtist(titulo);
        if (artist != null && artist.isNotEmpty) {
          suggestion = suggestion.mergeWith(SongMetadataSuggestion(
            artist: FieldSuggestion(artist, MetadataSource.api, 0.6),
          ));
        }
      } catch (_) {}
    } else if (needsArtist && gsbCandidate?.artist != null) {
      suggestion = suggestion.mergeWith(SongMetadataSuggestion(
        artist: FieldSuggestion(gsbCandidate!.artist!, MetadataSource.api, 0.7),
      ));
    }

    return suggestion;
  }

  /// Limpia la caché negativa de un título (para permitir reintentar).
  void clearNegativeCache(String titulo) {
    _negativeCache.remove(titulo.trim().toLowerCase());
  }
}
