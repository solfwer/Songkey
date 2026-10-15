// Comprueba todos los archivos .cho del cancionero contra el formato
// cannico: idempotencia (texto -> modelo -> texto), problemas de parseo,
// secciones vacas y acordes raros.
//
//   dart run tool/verificar_cancionero.dart [carpeta]
import 'dart:io';

import 'package:appchords/data/chord_parser.dart';
import 'package:appchords/data/chordpro.dart';

void main(List<String> args) async {
  final dir = args.isNotEmpty ? args.first : r'C:\Users\josue\Downloads\cancionero_chordpro\word_revisado';
  final files = Directory(dir)
      .listSync()
      .whereType<File>()
      .where((f) => f.path.toLowerCase().endsWith('.cho'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  if (files.isEmpty) {
    print('No hay archivos .cho en $dir');
    return;
  }

  var ok = 0;
  final sinIdempotencia = <String>[];
  final conIssues = <String>[];
  final seccionesVacias = <String>[];
  final sinTitulo = <String>[];
  final acordesRaros = <String, Set<String>>{};
  final sinSecciones = <String>[];
  var totalSecciones = 0;
  var totalLineas = 0;
  var totalAcordes = 0;

  for (final file in files) {
    final name = file.uri.pathSegments.last;
    final raw = await file.readAsString();
    final parser = ChordProParser();
    final song = parser.parse(raw);
    final out = const ChordProSerializer().write(song);

    if (parser.issues.isNotEmpty) {
      conIssues.add('$name -> ${parser.issues.take(3).map((i) => i.toString()).join(' | ')}');
    }
    final again = const ChordProSerializer().write(ChordProParser().parse(out));
    if (again != out) {
      sinIdempotencia.add(name);
    }
    if (song.meta.title == null || song.meta.title!.trim().isEmpty) {
      sinTitulo.add(name);
    }
    if (song.sections.isEmpty) {
      sinSecciones.add(name);
    }
    totalSecciones += song.sections.length;

    final vacias = song.sections.where((s) => s.lines.every((l) => l.lyric == null || l.lyric!.trim().isEmpty) && s.lines.every((l) => l.bars.isEmpty)).map((s) => s.label).toList();
    if (vacias.isNotEmpty) {
      seccionesVacias.add('$name -> ${vacias.join(', ')}');
    }

    for (final sec in song.sections) {
      for (final line in sec.lines) {
        totalLineas++;
        for (final c in line.chords) {
          totalAcordes++;
          if (!isChord(c.chord)) {
            acordesRaros.putIfAbsent(c.chord, () => <String>{}).add(name);
          }
        }
        for (final c in line.bars) {
          totalAcordes++;
          if (!isChord(c)) {
            acordesRaros.putIfAbsent(c, () => <String>{}).add(name);
          }
        }
      }
    }
    ok++;
  }

  print('=== Cancionero: $ok archivos revisados ===');
  print('Secciones: $totalSecciones   Lineas: $totalLineas   Acordes: $totalAcordes');
  print('');

  print('Sin idempotencia (${sinIdempotencia.length}):');
  for (final s in sinIdempotencia.take(15)) {
    print('  - $s');
  }
  print('');

  print('Con avisos del parser (${conIssues.length}):');
  for (final s in conIssues.take(15)) {
    print('  - $s');
  }
  print('');

  print('Sin titulo detectado (${sinTitulo.length}):');
  for (final s in sinTitulo.take(15)) {
    print('  - $s');
  }
  print('');

  print('Sin secciones (${sinSecciones.length}):');
  for (final s in sinSecciones.take(10)) {
    print('  - $s');
  }
  print('');

  print('Secciones sin ninguna letra (${seccionesVacias.length}):');
  for (final s in seccionesVacias.take(15)) {
    print('  - $s');
  }
  print('');

  print('Acordes que el parser no reconoce (${acordesRaros.length} tipos):');
  final raros = acordesRaros.entries.toList()..sort((a, b) => b.value.length.compareTo(a.value.length));
  for (final e in raros.take(20)) {
    print('  - [${e.key}] en ${e.value.length} canciones (ej. ${e.value.first})');
  }
}
