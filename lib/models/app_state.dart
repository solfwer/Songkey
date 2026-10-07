import 'dart:convert';
import 'dart:math';

import 'setlist.dart';
import 'song.dart';

/// Genera un id corto aleatorio para entidades (canciones, grupos, setlists...).
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

/// Estado global de la app: grupos, canciones y setlists.
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