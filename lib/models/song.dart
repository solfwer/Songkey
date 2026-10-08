/// Modelo de canción: título, tono, BPM, grupo al que pertenece y cuerpo
/// ChordPro (letra con acordes inline `[Am]letra` o líneas de acordes).
/// Los campos [style], [durationSec] y [lastOpenedAt] son opcionales para no
/// romper datos guardados por versiones anteriores.
class Song {
  String id;
  String title;
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
      );
}