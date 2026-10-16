import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../models/song_metadata_suggestion.dart';

/// Cliente de GetSongBPM (https://api.getsongbpm.com).
///
/// Busca canciones por título y devuelve tempo, tonalidad y compás si están disponibles.
/// Todas las fallas se silencian (degradación silenciosa): la UI nunca recibe una excepción.
class GetSongBpmClient {
  final String apiKey;
  final String? proxyUrl;

  GetSongBpmClient({required this.apiKey, this.proxyUrl});

  /// Base URL de la API (o proxy si está configurado).
  String get _base => proxyUrl ?? 'https://api.getsongbpm.com';

  /// Busca canciones por título. Devuelve hasta [limit] candidatos.
  Future<List<SongCandidate>> search(String title) async {
    if (apiKey.isEmpty && proxyUrl == null) return [];
    try {
      final url = '${_base}/search/?api_key=$apiKey&type=song&lookup=${Uri.encodeComponent(title)}&limit=8';
      final response = await _httpGet(url, timeoutSeconds: 8);
      if (response == null) return [];
      return _parseSearch(response);
    } catch (_) {
      return [];
    }
  }

  /// Obtiene el detalle de una canción por su ID externo.
  Future<SongCandidate?> songById(String externalId) async {
    if (apiKey.isEmpty && proxyUrl == null) return null;
    try {
      final url = '${_base}/song/?api_key=$apiKey&id=$externalId';
      final response = await _httpGet(url, timeoutSeconds: 8);
      if (response == null) return null;
      return _parseSongDetail(response, externalId);
    } catch (_) {
      return null;
    }
  }

  /// Petición HTTP genérica con timeout. Devuelve null en cualquier error.
  Future<Map<String, dynamic>?> _httpGet(String url, {int timeoutSeconds = 8}) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'Accept': 'application/json'},
      ).timeout(Duration(seconds: timeoutSeconds));
      if (response.statusCode != 200) return null;
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  List<SongCandidate> _parseSearch(Map<String, dynamic> data) {
    final candidates = <SongCandidate>[];
    // La respuesta de búsqueda puede tener distintas estructuras según la versión de la API.
    // Intentamos los campos más comunes.
    final results = _extractList(data);
    for (final item in results) {
      if (item is! Map<String, dynamic>) continue;
      final title = _str(item, 'title') ?? _str(item, 'song') ?? '';
      if (title.isEmpty) continue;
      candidates.add(SongCandidate(
        title: title,
        artist: _str(item, 'artist') ?? _str(item, 'artist_name'),
        key: _str(item, 'key') ?? _str(item, 'key_of'),
        bpm: _int(item, 'tempo') ?? _int(item, 'bpm'),
        timeSignature: _str(item, 'time_signature') ?? _str(item, 'time'),
        source: 'getsongbpm',
        externalId: _str(item, 'id') ?? _str(item, 'song_id') ?? '',
      ));
    }
    return candidates;
  }

  SongCandidate? _parseSongDetail(Map<String, dynamic> data, String externalId) {
    final title = _str(data, 'title') ?? '';
    if (title.isEmpty) return null;
    return SongCandidate(
      title: title,
      artist: _str(data, 'artist') ?? _str(data, 'artist_name'),
      key: _str(data, 'key') ?? _str(data, 'key_of'),
      bpm: _int(data, 'tempo') ?? _int(data, 'bpm'),
      timeSignature: _str(data, 'time_signature') ?? _str(data, 'time'),
      source: 'getsongbpm',
      externalId: externalId,
    );
  }

  /// Extrae la lista de resultados de la respuesta (soporta distintas estructuras).
  List<dynamic> _extractList(Map<String, dynamic> data) {
    // Intentar claves comunes: 'songs', 'results', 'data', 'search_results'
    for (final key in ['songs', 'results', 'data', 'search_results']) {
      final v = data[key];
      if (v is List) return v;
    }
    // Si la respuesta es una lista directamente (envuelto)
    final allValues = data.values.whereType<List>();
    if (allValues.isNotEmpty) return allValues.first;
    return [];
  }

  String? _str(Map<String, dynamic> m, String key) {
    final v = m[key];
    if (v == null) return null;
    return v.toString();
  }

  int? _int(Map<String, dynamic> m, String key) {
    final v = m[key];
    if (v == null) return null;
    return int.tryParse(v.toString());
  }
}
