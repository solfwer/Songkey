/// Modelo de canción: título, tono, BPM, grupo al que pertenece y cuerpo
/// ChordPro (letra con acordes inline `[Am]letra` o líneas de acordes).
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