// Modelo de setlist: canciones, grupos, invitados y overrides locales.
import 'song.dart';

/// Integrante/colaborador invitado de un setlist o grupo.
class Member {
  String id;
  String name;
  String role;
  String status; // 'pendiente' | 'confirmado'
  Member({required this.id, required this.name, this.role = 'músico', this.status = 'pendiente'});
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'role': role, 'status': status};
  factory Member.fromJson(Map<String, dynamic> j) =>
      Member(id: j['id'], name: j['name'] ?? '', role: j['role'] ?? '', status: j['status'] ?? 'pendiente');
}

/// Override de una canción dentro de un setlist: permite editar la canción
/// solo para este setlist sin modificar la original de la biblioteca.
class SongOverride {
  String songId;
  String title;
  String? author;
  String key;
  int? bpm;
  String body;
  String? style;
  int? durationSec;
  List<String>? structure;
  String? timeSignature;

  /// Capo en trastes (0 = sin capo). Se guarda solo en el override del
  /// setlist: fuera de un setlist el capo es transitorio (sesión).
  int? capo;

  SongOverride({
    required this.songId,
    required this.title,
    this.author,
    required this.key,
    this.bpm,
    required this.body,
    this.style,
    this.durationSec,
    this.structure,
    this.timeSignature,
    this.capo,
  });

  Map<String, dynamic> toJson() => {
        'songId': songId,
        'title': title,
        'author': author,
        'key': key,
        'bpm': bpm,
        'body': body,
        'style': style,
        'durationSec': durationSec,
        'structure': structure,
        'timeSignature': timeSignature,
        'capo': capo,
      };

  factory SongOverride.fromJson(Map<String, dynamic> j) => SongOverride(
        songId: j['songId'] as String,
        title: j['title'] as String,
        author: j['author'] as String?,
        key: j['key'] as String,
        bpm: j['bpm'] as int?,
        body: j['body'] as String,
        style: j['style'] as String?,
        durationSec: j['durationSec'] as int?,
        structure: (j['structure'] as List?)?.map((e) => e.toString()).toList(),
        timeSignature: j['timeSignature'],
        capo: j['capo'] as int?,
      );

  /// Convierte el override en una Song completa (para uso en pantalla).
  Song toSong() => Song(
        id: songId,
        title: title,
        author: author,
        key: key,
        bpm: bpm,
        groupId: null, // Los overrides no tienen grupo propio
        body: body,
        style: style,
        durationSec: durationSec,
        structure: structure,
        timeSignature: timeSignature,
      );
}

/// Setlist: lista ordenada de canciones para una fecha, con lugar, banda
/// invitada y el estado de preparación de cada tema ([readyIds]).
/// También guarda [songOverrides]: ediciones locales de canciones que solo
/// aplican a este setlist, sin tocar la original de la biblioteca.
class Setlist {
  String id;
  String name;

  /// Fecha "yyyy-mm-dd".
  String date;

  /// Lugar/ocasión (ej. "Capilla 3", "Ensayo jueves").
  String venue;
  String? groupId;
  List<String> songIds;

  /// Ids de canciones marcadas como "Lista" (preparadas para tocar).
  List<String> readyIds;
  List<Member> members;

  /// Overrides locales: key = songId original, value = versión editada para este setlist.
  Map<String, SongOverride> songOverrides;

  Setlist({
    required this.id,
    required this.name,
    required this.date,
    this.venue = '',
    this.groupId,
    List<String>? songIds,
    List<String>? readyIds,
    List<Member>? members,
    Map<String, SongOverride>? songOverrides,
  })  : songIds = songIds ?? [],
        readyIds = readyIds ?? [],
        members = members ?? [],
        songOverrides = songOverrides ?? {};

  /// Fracción (0..1) de canciones preparadas.
  double get readyRatio => songIds.isEmpty ? 0 : readyIds.where(songIds.contains).length / songIds.length;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'date': date,
        'venue': venue,
        'groupId': groupId,
        'songIds': songIds,
        'readyIds': readyIds,
        'members': members.map((m) => m.toJson()).toList(),
        'songOverrides': songOverrides.map((k, v) => MapEntry(k, v.toJson())),
      };

  factory Setlist.fromJson(Map<String, dynamic> j) => Setlist(
        id: j['id'],
        name: j['name'] ?? '',
        date: j['date'] ?? '',
        venue: j['venue'] ?? '',
        groupId: j['groupId'],
        songIds: List<String>.from(j['songIds'] ?? []),
        readyIds: List<String>.from(j['readyIds'] ?? []),
        members: (j['members'] as List? ?? [])
            .map((m) => Member.fromJson(Map<String, dynamic>.from(m)))
            .toList(),
        songOverrides: (j['songOverrides'] as Map<String, dynamic>? ?? {}).map(
          (k, v) => MapEntry(k, SongOverride.fromJson(Map<String, dynamic>.from(v))),
        ),
      );

  /// Copia del setlist cambiando solo lo indicado (mantiene id y resto).
  Setlist copyWith({
    String? name,
    String? date,
    String? venue,
    String? groupId,
    List<String>? songIds,
    List<String>? readyIds,
    List<Member>? members,
    Map<String, SongOverride>? songOverrides,
  }) =>
      Setlist(
        id: id,
        name: name ?? this.name,
        date: date ?? this.date,
        venue: venue ?? this.venue,
        groupId: groupId ?? this.groupId,
        songIds: songIds ?? this.songIds,
        readyIds: readyIds ?? this.readyIds,
        members: members ?? this.members,
        songOverrides: songOverrides ?? this.songOverrides,
      );

  /// Obtiene la versión de la canción para este setlist.
  /// Si hay override local, lo devuelve; si no, devuelve null.
  SongOverride? getOverride(String songId) => songOverrides[songId];

  /// Establece o elimina un override para una canción en este setlist.
  Setlist withOverride(String songId, SongOverride? override) {
    final newOverrides = Map<String, SongOverride>.from(songOverrides);
    if (override == null) {
      newOverrides.remove(songId);
    } else {
      newOverrides[songId] = override;
    }
    return copyWith(songOverrides: newOverrides);
  }
}