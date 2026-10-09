/// Modelo de canción: título, tono, BPM, grupo al que pertenece y cuerpo
/// ChordPro (letra con acordes inline `[Am]letra` o líneas de acordes).
/// Los campos [style], [durationSec] y [lastOpenedAt] son opcionales para no
/// romper datos guardados por versiones anteriores.
class Song {
  String id;
  String title;
  String? author;
  String? style;
  String key;
  int? bpm;
  String? groupId;
  String body;

  /// Estilo musical opcional (ej. "Balada", "Adoración", "Rock").

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
      );
}