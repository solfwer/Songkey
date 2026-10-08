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

/// Setlist: lista ordenada de canciones para una fecha, con lugar, banda
/// invitada y el estado de preparación de cada tema ([readyIds]).
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

  Setlist({
    required this.id,
    required this.name,
    required this.date,
    this.venue = '',
    this.groupId,
    List<String>? songIds,
    List<String>? readyIds,
    List<Member>? members,
  })  : songIds = songIds ?? [],
        readyIds = readyIds ?? [],
        members = members ?? [];

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
      );
}