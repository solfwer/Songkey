import 'dart:convert';
import 'dart:math';

String uid() {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final r = Random.secure();
  return List.generate(8, (_) => chars[r.nextInt(chars.length)]).join();
}

enum GroupColor { primary, accent, warm, bridge }

GroupColor groupColorFromString(String? s) =>
    GroupColor.values.firstWhere((e) => e.name == s, orElse: () => GroupColor.primary);

class Group {
  String id;
  String name;
  GroupColor color;
  List<Member> members;
  String? owner;
  Group({required this.id, required this.name, this.color = GroupColor.primary, List<Member>? members, this.owner})
      : members = members ?? [];
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'color': color.name, 'members': members.map((m) => m.toJson()).toList(), 'owner': owner};
  factory Group.fromJson(Map<String, dynamic> j) =>
      Group(id: j['id'], name: j['name'], color: groupColorFromString(j['color']), members: (j['members'] as List? ?? []).map((m) => Member.fromJson(Map<String, dynamic>.from(m))).toList(), owner: j['owner']);
}

class Song {
  String id;
  String title;
  String? author;
  String key;
  int? bpm;
  String? groupId;
  String body;
  Song({required this.id, required this.title, this.author, this.key = 'C', this.bpm, this.groupId, this.body = ''});
  Map<String, dynamic> toJson() => {
        'id': id, 'title': title, 'author': author, 'key': key, 'bpm': bpm, 'groupId': groupId, 'body': body,
      };
  factory Song.fromJson(Map<String, dynamic> j) => Song(
        id: j['id'], title: j['title'] ?? '', author: j['author'], key: j['key'] ?? 'C',
        bpm: j['bpm'], groupId: j['groupId'], body: j['body'] ?? '',
      );
}

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

class AppState {
  List<Group> groups;
  List<Song> songs;
  List<Setlist> setlists;
  AppState({required this.groups, required this.songs, required this.setlists});
  Map<String, dynamic> toJson() => {
        'groups': groups.map((g) => g.toJson()).toList(),
        'songs': songs.map((s) => s.toJson()).toList(),
        'setlists': setlists.map((l) => l.toJson()).toList(),
      };
  String encode() => jsonEncode(toJson());
  factory AppState.fromJson(Map<String, dynamic> j) => AppState(
        groups: (j['groups'] as List? ?? []).map((g) => Group.fromJson(Map<String, dynamic>.from(g))).toList(),
        songs: (j['songs'] as List? ?? []).map((s) => Song.fromJson(Map<String, dynamic>.from(s))).toList(),
        setlists: (j['setlists'] as List? ?? []).map((l) => Setlist.fromJson(Map<String, dynamic>.from(l))).toList(),
      );
  factory AppState.decode(String raw) => AppState.fromJson(jsonDecode(raw));
}

