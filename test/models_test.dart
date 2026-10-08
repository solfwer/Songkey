import 'package:flutter_test/flutter_test.dart';

import 'package:appchords/data/chord_parser.dart';
import 'package:appchords/data/format.dart';
import 'package:appchords/models/setlist.dart';
import 'package:appchords/models/song.dart';

void main() {
  group('notación', () {
    test('notateChord pasa acordes en americana y los traduce a latina', () {
      expect(notateChord('G7', american: true), 'G7');
      expect(notateChord('G7', american: false), 'Sol7');
      expect(notateChord('Bm', american: false), 'Sim');
      expect(notateChord('F#m', american: false), 'Fa#m');
      expect(notateChord('C', american: false), 'Do');
      expect(notateChord('A', american: false), 'La');
      expect(notateChord('B', american: false), 'Si');
      expect(notateChord('Bb', american: false), 'Sib');
      expect(notateChord('Dm7/G', american: false), 'Rem7/Sol');
      expect(chordToLatin('E'), 'Mi');
    });

    test('sharpen normaliza bemoles a sostenidos', () {
      expect(sharpen('Eb'), 'D#');
      expect(sharpen('Ab'), 'G#');
      expect(sharpen('C'), 'C');
    });
  });

  group('formato', () {
    test('formatDuration y parseDuration', () {
      expect(formatDuration(225), '3:45');
      expect(formatDuration(null), '');
      expect(formatDuration(0), '');
      expect(parseDuration('3:45'), 225);
      expect(parseDuration('90'), 90);
      expect(parseDuration('abc'), null);
      expect(parseDuration(''), null);
    });

    test('formatShortDate usa fecha legible en español', () {
      expect(formatShortDate('2026-10-08'), '8 oct 2026');
      expect(formatShortDate(''), '');
    });
  });

  group('modelos', () {
    test('Song serializa/deserializa los campos nuevos', () {
      final song = Song(
        id: 's1',
        title: 'Test',
        key: 'C',
        bpm: 120,
        body: 'Coro\n[C]Hola',
        style: 'Rock',
        durationSec: 210,
        lastOpenedAt: '2026-10-08T12:00:00',
      );
      final back = Song.fromJson(song.toJson());
      expect(back.style, 'Rock');
      expect(back.durationSec, 210);
      expect(back.lastOpenedAt, '2026-10-08T12:00:00');
    });

    test('Song tolera JSON antiguo sin campos nuevos', () {
      final back = Song.fromJson({'id': 'x', 'title': 'Vieja', 'key': 'G', 'body': ''});
      expect(back.style, isNull);
      expect(back.durationSec, isNull);
      expect(back.lastOpenedAt, isNull);
    });

    test('Song copyWith solo cambia lo indicado', () {
      final song = Song(id: 's1', title: 'A', body: 'x', style: 'Rock', lastOpenedAt: 't1');
      final copy = song.copyWith(title: 'B', lastOpenedAt: 't2');
      expect(copy.id, 's1');
      expect(copy.title, 'B');
      expect(copy.style, 'Rock');
      expect(copy.lastOpenedAt, 't2');
      expect(song.lastOpenedAt, 't1');
    });

    test('Setlist serializa venue/readyIds y calcula readyRatio', () {
      final l = Setlist(id: 'l1', name: 'Domingo', date: '2026-10-08', venue: 'Capilla 3', songIds: ['a', 'b', 'c'], readyIds: ['a']);
      expect(l.readyRatio, closeTo(1 / 3, 0.001));
      final back = Setlist.fromJson(l.toJson());
      expect(back.venue, 'Capilla 3');
      expect(back.readyIds, ['a']);
      expect(back.readyRatio, closeTo(1 / 3, 0.001));
    });

    test('Setlist tolera JSON antiguo sin venue/readyIds', () {
      final back = Setlist.fromJson({'id': 'l1', 'name': 'N', 'date': '2026-01-01', 'songIds': ['a']});
      expect(back.venue, '');
      expect(back.readyIds, isEmpty);
    });
  });
}