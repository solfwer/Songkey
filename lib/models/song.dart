/// Modelo de canción: título, tono, BPM, grupo al que pertenece y cuerpo
/// ChordPro (letra con acordes inline `[Am]letra` o líneas de acordes).
/// Los campos [style], [durationSec] y [lastOpenedAt] son opcionales para no
/// romper datos guardados por versiones anteriores.
class Song {
  String id;
  String title;

  /// Autor o creador de la canción (opcional).
  String? author;
  String key;
  int? bpm;
  String? groupId;
  String body;

  /// Estilo musical opcional (ej. "Balada", "Adoración", "Rock").
  String? style;

  /// Duración en segundos (opcional).
  int? durationSec;

  /// Momento de la última apertura (ISO-8601) para "Canciones recientes".
  String? lastOpenedAt;

  /// Orden de toque (el "mapa"): encabezados de sección en orden de
  /// interpretación, admite repeticiones (["Verso 1", "Coro", "Verso 1"]).
  /// La letra de cada sección se guarda una sola vez en [body]; las
  /// repeticiones viven solo aquí. null o [] = usar el orden del cuerpo
  /// tal como está escrito (comportamiento anterior).
  List<String>? structure;

  /// Compás (ej. "4/4", "3/4", "6/8").
  String? timeSignature;

  /// Por cada campo de metadatos, de dónde viene su valor:
  /// 'acordes' (detectado offline), 'api' (GetSongBPM/MusicBrainz), 'tap' (tap tempo), 'manual'.
  /// Claves: 'author', 'key', 'bpm', 'timeSignature'.
  Map<String, String>? metadataSource;

  /// Fecha de la última consulta online de metadatos (ISO-8601).
  String? metadataFetchedAt;

  Song({
    required this.id,
    required this.title,
    this.author,
    this.key = 'C',
    this.bpm,
    this.groupId,
    this.body = '',
    this.style,
    this.durationSec,
    this.lastOpenedAt,
    this.structure,
    this.timeSignature,
    this.metadataSource,
    this.metadataFetchedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'author': author,
        'key': key,
        'bpm': bpm,
        'groupId': groupId,
        'body': body,
        'style': style,
        'durationSec': durationSec,
        'lastOpenedAt': lastOpenedAt,
        'structure': structure,
        'timeSignature': timeSignature,
        'metadataSource': metadataSource,
        'metadataFetchedAt': metadataFetchedAt,
      };

  factory Song.fromJson(Map<String, dynamic> j) => Song(
        id: j['id'],
        title: j['title'] ?? '',
        author: j['author'],
        key: j['key'] ?? 'C',
        bpm: j['bpm'],
        groupId: j['groupId'],
        body: j['body'] ?? '',
        style: j['style'],
        durationSec: j['durationSec'],
        lastOpenedAt: j['lastOpenedAt'],
        structure: (j['structure'] as List?)?.map((e) => e.toString()).toList(),
        timeSignature: j['timeSignature'],
        metadataSource: (j['metadataSource'] as Map<String, dynamic>?)
            ?.map((k, v) => MapEntry(k, v.toString())),
        metadataFetchedAt: j['metadataFetchedAt'],
      );

  /// Copia de la canción cambiando solo lo indicado (mantiene id y resto).
  Song copyWith({
    String? title,
    String? author,
    String? key,
    int? bpm,
    String? groupId,
    String? body,
    String? style,
    int? durationSec,
    String? lastOpenedAt,
    List<String>? structure,
    String? timeSignature,
    Map<String, String>? metadataSource,
    String? metadataFetchedAt,
  }) =>
      Song(
        id: id,
        title: title ?? this.title,
        author: author ?? this.author,
        key: key ?? this.key,
        bpm: bpm ?? this.bpm,
        groupId: groupId ?? this.groupId,
        body: body ?? this.body,
        style: style ?? this.style,
        durationSec: durationSec ?? this.durationSec,
        lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
        structure: structure ?? this.structure,
        timeSignature: timeSignature ?? this.timeSignature,
        metadataSource: metadataSource ?? this.metadataSource,
        metadataFetchedAt: metadataFetchedAt ?? this.metadataFetchedAt,
      );
}