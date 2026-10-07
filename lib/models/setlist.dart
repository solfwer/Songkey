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

/// Setlist: lista ordenada de canciones para una fecha, con banda invitada.
class Setlist {
  String id;
  String name;
  String date;
  String? groupId;
  List<String> songIds;
  List<Member> members;
  Setlist({required this.id, required this.name, required this.date, this.groupId, List<String>? songIds, List<Member>? members})
      : songIds = songIds ?? [],
        members = members ?? [];
  Map<String, dynamic> toJson() => {
        'id': id, 'name': name, 'date': date, 'groupId': groupId,
        'songIds': songIds, 'members': members.map((m) => m.toJson()).toList(),
      };
  factory Setlist.fromJson(Map<String, dynamic> j) => Setlist(
        id: j['id'], name: j['name'] ?? '', date: j['date'] ?? '', groupId: j['groupId'],
        songIds: List<String>.from(j['songIds'] ?? []),
        members: (j['members'] as List? ?? []).map((m) => Member.fromJson(Map<String, dynamic>.from(m))).toList(),
      );
}