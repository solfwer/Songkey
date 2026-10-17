import 'package:appchords/models/setlist.dart';
import 'package:appchords/models/song.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SongOverride guarda y restaura el capo en el JSON', () {
    final override = SongOverride(
      songId: 's1',
      title: 'Canción de prueba',
      key: 'C',
      body: 'Verso 1\n[C]Hola',
      capo: 3,
    );
    final json = override.toJson();
    expect(json['capo'], 3);

    final restaurado = SongOverride.fromJson(json);
    expect(restaurado.capo, 3);
    expect(restaurado.toSong().key, 'C'); // el capo no se mezcla con el tono del Song
  });

  test('SongOverride sin capo en JSON se lee como sin capo (null)', () {
    final json = {
      'songId': 's1',
      'title': 'Canción',
      'key': 'G',
      'body': 'Verso 1\n[G]Hola',
      // sin 'capo' (canciones importadas de versiones anteriores)
    };
    final override = SongOverride.fromJson(json);
    expect(override.capo, isNull);
  });
}
