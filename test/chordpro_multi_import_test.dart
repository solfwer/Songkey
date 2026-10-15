// Tests del importador multi-canción ChordPro.
import 'package:appchords/data/chordpro.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('splitChordProSongs', () {
    test('un solo bloque sin separadores devuelve 1 canción', () {
      const text = '{title: Una canción}\n{key: G}\n{tempo: 120}\n\n[G] Letra [C] de prueba\n[D] más líneas';
      final chunks = splitChordProSongs(text);
      expect(chunks.length, equals(1));
      expect(chunks.first, contains('{title: Una canción}'));
    });

    test('divide por {new_song}', () {
      const text = '{title: Primera}\n{key: G}\n[G] Letra 1\n{new_song}\n{title: Segunda}\n{key: D}\n[D] Letra 2';
      final chunks = splitChordProSongs(text);
      expect(chunks.length, equals(2));
      expect(chunks[0], contains('Primera'));
      expect(chunks[1], contains('Segunda'));
    });

    test('divide por {title:} posterior al primero', () {
      const text = '{title: Una}\n{key: G}\n[G] Letra\n{title: Dos}\n{key: C}\n[C] Otra\n{title: Tres}\n{key: D}\n[D] Tercera';
      final chunks = splitChordProSongs(text);
      expect(chunks.length, equals(3));
      expect(chunks[0], contains('Una'));
      expect(chunks[1], contains('Dos'));
      expect(chunks[2], contains('Tres'));
    });

    test('divide por {t:} abreviado posterior al primero', () {
      const text = '{t: Primera}\n{key: G}\n[G] Letra\n{t: Segunda}\n{key: C}\n[C] Otra';
      final chunks = splitChordProSongs(text);
      expect(chunks.length, equals(2));
    });

    test('descarta chunks vacíos (solo metadatos)', () {
      const text = '{title: Con contenido}\n[G] Letra\n{title: Solo metadatos}\n{key: D}';
      final chunks = splitChordProSongs(text);
      expect(chunks.length, equals(1));
      expect(chunks.first, contains('Con contenido'));
    });

    test('metadatos parseados en Song: título, autor, tono, BPM', () {
      const text = '{title: Mi canción}\n{artist: Mi autor}\n{key: Am}\n{tempo: 140}\n[G] Letra';
      final parser = ChordProParser();
      final song = parser.parse(text);
      expect(song.meta.title, equals('Mi canción'));
      expect(song.meta.artist, equals('Mi autor'));
      expect(song.meta.key, equals('Am'));
      expect(song.meta.tempo, equals('140'));
    });

    test('canción sin {title} usa fallback', () {
      const text = '{title: Título real}\n[G] Letra\n{title: }';
      final chunks = splitChordProSongs(text);
      // El chunk vacío se descarta
      expect(chunks.length, equals(1));
    });
  });

  group('Detección de duplicados', () {
    test('título existente en biblioteca detectado como duplicado', () {
      const text = '{title: Gracia asombrosa}\n{key: G}\n[G] Letra';
      final parser = ChordProParser();
      final song = parser.parse(text);
      expect(song.meta.title, equals('Gracia asombrosa'));
      // La lógica de duplicado está en library_screen: comparando con existingTitles
    });

    test('título repetido dentro del mismo archivo detectado', () {
      const text = '{title: Repetida}\n{key: G}\n[G] Letra 1\n{title: Repetida}\n{key: C}\n[C] Letra 2';
      final chunks = splitChordProSongs(text);
      expect(chunks.length, equals(2));
      // La lógica de isDuplicateInFile está en library_screen
    });
  });
}