/// Cliente de MusicBrainz (https://musicbrainz.org/ws/2).
///
/// Busca el autor/artista de una grabación por título.
/// Respeta el límite de 1 petición por segundo mediante [RateLimiter].
/// Todas las fallas se silencian (degradación silenciosa).
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'rate_limiter.dart';

class MusicBrainzClient {
  final RateLimiter _rateLimiter;
  final String _userAgent;

  MusicBrainzClient({RateLimiter? rateLimiter, String? userAgent})
      : _rateLimiter = rateLimiter ?? RateLimiter(),
        _userAgent = userAgent ?? 'SongKey/1.0 (contacto@tudominio.com)';

  /// Busca el autor de una canción por título.
  /// Devuelve el nombre del artista o null si no se encuentra.
  Future<String?> searchArtist(String title) async {
    try {
      return await _rateLimiter.run(() async {
        final query = Uri.encodeComponent('recording:"$title"');
        final url = 'https://musicbrainz.org/ws/2/recording/?query=$query&fmt=json&limit=5';
        final response = await http.get(
          Uri.parse(url),
          headers: {'Accept': 'application/json', 'User-Agent': _userAgent},
        ).timeout(const Duration(seconds: 8));
        if (response.statusCode != 200) return null;
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final recordings = data['recordings'];
        if (recordings == null || recordings is! List) return null;
        if (recordings.isEmpty) return null;
        final first = recordings.first as Map<String, dynamic>;
        final artistCredit = first['artist-credit'];
        if (artistCredit == null || artistCredit is! List) return null;
        if (artistCredit.isEmpty) return null;
        final firstCredit = artistCredit.first as Map<String, dynamic>;
        final artist = firstCredit['artist'];
        if (artist == null || artist is! Map) return null;
        return artist['name'] as String?;
      });
    } catch (_) {
      return null;
    }
  }
}
