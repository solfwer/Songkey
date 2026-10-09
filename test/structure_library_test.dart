// Tests del "mapa de toque" (orden de secciones con repeticiones) y de la
// fusión de bibliotecas compartidas.
import 'package:appchords/data/chord_parser.dart';
import 'package:appchords/models/app_state.dart';
import 'package:appchords/models/song.dart';
import 'package:appchords/services/biblioteca_export.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('sectionsInOrder (mapa de toque)', () {
    test('sin estructura usa el orden del cuerpo tal cual', () {
      final body = 'Verso 1\n[G]letra\n\nCoro\n[C]coro\n';
      final secs = sectionsInOrder(body, null);
      expect(secs.map((s) => s.label.trim()).toList(), ['Verso 1', 'Coro']);
    });

    test('con estructura repite secciones reutilizando la letra', () {
      final body = 'Verso 1\n[G]letra\n\nCoro\n[C]coro\n';
      final secs = sectionsInOrder(body, ['Coro', 'Verso 1', 'Coro']);
      expect(secs.map((s) => s.label.trim()).toList(), ['Coro', 'Verso 1', 'Coro']);
      // La letra de la sección se muestra cada vez sin duplicarse en el texto:
      // ambas apariciones de "Coro" son la misma sección canónica.
      expect(identical(secs[0], secs[2]), isTrue);
    });

    test('encabezados inexistentes se ignoran', () {
      final body = 'Verso 1\n[G]letra\n';
      final secs = sectionsInOrder(body, ['Verso 1', 'Puente 9']);
      expect(secs.map((s) => s.label.trim()).toList(), ['Verso 1']);
    });

    test('el nombre del orden de toque casa sin distinguir maysculas ni acentos', () {
      // El cancionero escribe "VERSO 1" y el parser lo normaliza a "Verso 1":
      // el orden de toque debe seguir funcionando con las dos escrituras.
      const body = '{start_of_verse: VERSO 1}\n[G]letra\n{end_of_verse}\n{start_of_chorus: CORO}\n[C]coro\n{end_of_chorus}';
      final secs = sectionsInOrder(body, ['CORO', 'VERSO 1', 'CORO']);
      expect(secs.map((s) => s.label).toList(), ['CORO', 'VERSO 1', 'CORO']);
      expect(identical(secs[0], secs[2]), isTrue);
    });
  });

  group('Song.structure', () {
    test('serializa y deserializa el mapa', () {
      final s = Song(id: 'a', title: 'T', body: 'x', structure: const ['V1', 'C', 'V1']);
      final j = s.toJson();
      expect(j['structure'], ['V1', 'C', 'V1']);
      expect(Song.fromJson(j).structure, ['V1', 'C', 'V1']);
    });

    test('JSON antiguo sin structure queda en null', () {
      final back = Song.fromJson({'id': 'a', 'title': 'T'});
      expect(back.structure, isNull);
    });
  });

  group('mergeLibrary (compartir/importar)', () {
    test('añade canciones y grupos nuevos, omite repetidas por título', () {
      final current = AppState(
        groups: [Group(id: 'g1', name: 'Banda')],
        songs: [Song(id: 's1', title: 'Ya existe', body: '')],
        setlists: [],
      );
      final raw = encodeLibrary(AppState(
        groups: [
          Group(id: 'gx', name: 'Banda'), // nombre repetido -> reutiliza g1
          Group(id: 'gy', name: 'Nuevo grupo'),
        ],
        songs: [
          // Título repetido sin distinguir mayúsculas -> se omite.
          Song(id: 'sa', title: 'ya existe', body: 'x', groupId: 'gx'),
          Song(id: 'sb', title: 'Canción nueva', body: 'y', groupId: 'gy'),
        ],
        setlists: [],
      ));
      final res = mergeLibrary(current, raw);
      expect(res.added, 1);
      expect(res.skipped, 1);
      expect(res.newGroups.length, 1);
      expect(res.newGroups.first.name, 'Nuevo grupo');
      expect(res.newSongs.first.title, 'Canción nueva');
      expect(res.newSongs.first.groupId, res.newGroups.first.id);
    });

    test('genera ids nuevos si hay colisión con una canción existente', () {
      final current = AppState(
        groups: [],
        songs: [Song(id: 'sb', title: 'Otra', body: '')],
        setlists: [],
      );
      final raw = encodeLibrary(AppState(
        groups: [],
        songs: [Song(id: 'sb', title: 'Distinta', body: 'z')],
        setlists: [],
      ));
      final res = mergeLibrary(current, raw);
      expect(res.added, 1);
      expect(res.newSongs.first.id, isNot('sb'));
    });
  });
}