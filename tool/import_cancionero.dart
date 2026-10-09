// Herramienta: convierte un cancionero ChordPro (.cho) en un JSON importable
// por Songkey (Ajustes > Biblioteca > Importar biblioteca).
//
// Uso: dart run tool/import_cancionero.dart [carpeta] [salida.json] [salida_reporte.txt]
//
// - Respeta el formato de Song.toJson (id, title, author, key, bpm, groupId,
//   body, style, durationSec, lastOpenedAt, structure) y el envoltorio de
//   biblioteca {app: 'Songkey', version: 1, groups: [], songs: [...]}.
// - Descartan copias con letra idéntica (conserva la primera por orden de
//   archivo) y marcan en el informe: mismo título con letra distinta, títulos
//   parecidos y canciones que ya existen en la biblioteca de ejemplo.
// - No requiere depender de Flutter: solo dart:core/io/convert.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

final _rng = Random();
const _chars = 'abcdefghijklmnopqrstuvwxyz0123456789';

String newId() =>
    List.generate(8, (_) => _chars[_rng.nextInt(_chars.length)]).join();

const _from = 'áàâäéèêëíìîïóòôöúùûüñç';
const _to = 'aaaaeeeeiiiioooouuuunc';

String deaccent(String s) {
  final sb = StringBuffer();
  for (final ch in s.split('')) {
    final i = _from.indexOf(ch);
    sb.write(i >= 0 ? _to[i] : ch);
  }
  return sb.toString();
}

/// Título normalizado para comparar (sin acentos, minúsculas, sin puntuación).
String normalize(String s) {
  final t = deaccent(s.toLowerCase());
  return t.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}

/// "AQUÍ ESTOY" -> "Aquí Estoy"; "ERES TÚ (DANILO MONTERO)" -> "Eres Tú (Danilo Montero)".
String titleCase(String s) {
  final words = s.trim().split(RegExp(r'\s+'));
  return words
      .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1).toLowerCase())
      .join(' ');
}

/// Letra "pura": cuerpo sin acordes inline ni espacios, para comparar copias.
String lyricsKey(String body) {
  final noChords = body.replaceAll(RegExp(r'\[[^\]]*\]'), '');
  return deaccent(noChords.toLowerCase()).replaceAll(RegExp(r'[^a-z0-9]+'), '');
}

String defaultLabel(String kind) {
  switch (kind.toLowerCase()) {
    case 'verse':
      return 'VERSO';
    case 'chorus':
      return 'CORO';
    case 'bridge':
      return 'PUENTE';
    case 'interlude':
      return 'INTERLUDIO';
    default:
      return kind.toUpperCase();
  }
}

class ParsedSong {
  final String file;
  final String title;
  final String key;
  final String body;
  ParsedSong(this.file, this.title, this.key, this.body);
}

ParsedSong parseFile(String path) {
  var text = File(path).readAsStringSync();
  if (text.startsWith('\uFEFF')) text = text.substring(1);
  final lines =
      text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');

  String? title;
  String? key;
  final out = <String>[];

  final dirTitle = RegExp(r'^\{title:\s*([^}]*)\}', caseSensitive: false);
  final dirKey = RegExp(r'^\{key:\s*([^}]*)\}', caseSensitive: false);
  final dirComment = RegExp(r'^\{comment:\s*([^}]*)\}', caseSensitive: false);
  final dirStart =
      RegExp(r'^\{start_of_([a-z]+):\s*([^}]*)\}', caseSensitive: false);
  final dirStartNoLabel =
      RegExp(r'^\{start_of_([a-z]+)\}', caseSensitive: false);
  final dirEnd = RegExp(r'^\{end_of_[a-z]+\}', caseSensitive: false);
  final dirOther =
      RegExp(r'^\{[a-z_]+(?::[^}]*)?\}', caseSensitive: false);

  for (final raw in lines) {
    final t = raw.trim();
    if (t.isEmpty) {
      out.add('');
      continue;
    }

    final mTitle = dirTitle.firstMatch(t);
    if (mTitle != null) {
      title = mTitle.group(1)!.trim();
      continue;
    }
    final mKey = dirKey.firstMatch(t);
    if (mKey != null) {
      key = mKey.group(1)!.trim();
      continue;
    }
    final mCom = dirComment.firstMatch(t);
    if (mCom != null) {
      // Notas musicales: quitar corchetes de acorde, conservar el texto.
      out.add(mCom.group(1)!.trim().replaceAll(RegExp(r'\[|\]'), ''));
      continue;
    }
    final mS = dirStart.firstMatch(t);
    if (mS != null) {
      final label = mS.group(2)!.trim();
      out.add(label.isEmpty ? defaultLabel(mS.group(1)!) : label);
      continue;
    }
    final mS2 = dirStartNoLabel.firstMatch(t);
    if (mS2 != null) {
      out.add(defaultLabel(mS2.group(1)!));
      continue;
    }
    if (dirEnd.hasMatch(t)) {
      out.add('');
      continue;
    }
    if (dirOther.hasMatch(t)) continue;
    out.add(t);
  }

  // Colapsar líneas en blanco repetidas, recortar el final.
  final collapsed = <String>[];
  var prevBlank = false;
  for (final l in out) {
    final s = l.trimRight();
    if (s.trim().isEmpty) {
      if (!prevBlank && collapsed.isNotEmpty) {
        collapsed.add('');
        prevBlank = true;
      }
    } else {
      collapsed.add(s);
      prevBlank = false;
    }
  }
  while (collapsed.isNotEmpty && collapsed.last.trim().isEmpty) {
    collapsed.removeLast();
  }

  if (title == null || title!.isEmpty) {
    var name = path.split(Platform.pathSeparator).last;
    name = name
        .replaceAll(RegExp(r'\.cho$'), '')
        .replaceAll(RegExp(r'^\d+_'), '')
        .replaceAll('_', ' ');
    title = titleCase(name);
  } else {
    title = titleCase(title);
  }

  return ParsedSong(path, title!, (key ?? 'C').trim(), collapsed.join('\n'));
}

int levenshtein(String a, String b) {
  final dp = List.generate(a.length + 1, (_) => List.filled(b.length + 1, 0));
  for (var i = 0; i <= a.length; i++) dp[i][0] = i;
  for (var j = 0; j <= b.length; j++) dp[0][j] = j;
  for (var i = 1; i <= a.length; i++) {
    for (var j = 1; j <= b.length; j++) {
      dp[i][j] = (a[i - 1] == b[j - 1])
          ? dp[i - 1][j - 1]
          : 1 +
              [
                dp[i - 1][j],
                dp[i][j - 1],
                dp[i - 1][j - 1],
              ].reduce((x, y) => x < y ? x : y);
    }
  }
  return dp[a.length][b.length];
}

void main(List<String> args) {
  final folder = args.isNotEmpty
      ? args[0]
      : r'C:\Users\josue\Downloads\cancionero_chordpro\word_revisado';
  final outJson = args.length > 1
      ? args[1]
      : r'C:\Users\josue\Downloads\Songkey_cancionero_nuevas.json';
  final outReport = args.length > 2
      ? args[2]
      : r'C:\Users\josue\Downloads\cancionero_revisado.txt';

  final files = Directory(folder)
      .listSync()
      .whereType<File>()
      .where((f) => f.path.toLowerCase().endsWith('.cho'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  print('Archivos .cho encontrados: ${files.length}');

  final parsed = files.map((f) => parseFile(f.path)).toList();

  // Títulos de la biblioteca de ejemplo (seed) para avisar de coincidencias.
  final seedNorm = <String>{};
  final seedFile = File('lib/data/seed.dart');
  if (seedFile.existsSync()) {
    for (final m
        in RegExp(r"title: '([^']+)'").allMatches(seedFile.readAsStringSync())) {
      seedNorm.add(normalize(m.group(1)!));
    }
  }

  // Agrupar por título normalizado.
  final byTitle = <String, List<ParsedSong>>{};
  for (final p in parsed) {
    byTitle.putIfAbsent(normalize(p.title), () => []).add(p);
  }

  final keep = <ParsedSong>[];
  final dropped = <String>[];
  final sameTitleDifferent = <String>[]; // "Título": items

  for (final entry in byTitle.entries) {
    final group = entry.value;
    if (group.length == 1) {
      keep.add(group.first);
      continue;
    }
    final unique = <ParsedSong>[];
    for (final p in group) {
      final pk = lyricsKey(p.body);
      final dup = unique.where((u) => lyricsKey(u.body) == pk).firstOrNull;
      if (dup != null) {
        dropped.add('${p.file}\n    → copia de ${dup.file}');
      } else {
        unique.add(p);
      }
    }
    keep.addAll(unique);
    if (unique.length > 1) {
      final files_ = unique.map((u) => u.file).join(', ');
      sameTitleDifferent.add('"${unique.first.title}"\n    ($files_)');
    }
  }

  final normTitles = byTitle.keys.toList();
  final similarPairs = <String>[];
  for (var i = 0; i < normTitles.length; i++) {
    for (var j = i + 1; j < normTitles.length; j++) {
      final a = normTitles[i];
      final b = normTitles[j];
      final minLen = a.length < b.length ? a.length : b.length;
      if (minLen < 5) continue;
      final similar = a.contains(b) ||
          b.contains(a) ||
          levenshtein(a, b) <= 2;
      if (similar) {
        similarPairs.add('"${byTitle[a]!.first.title}" ↔ "${byTitle[b]!.first.title}"');
      }
    }
  }

  keep.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  final seedHits = keep
      .where((p) => seedNorm.contains(normalize(p.title)))
      .toList()
    ..sort((a, b) => a.title.compareTo(b.title));

  // Escribir el JSON importable.
  final songsJson = keep.map((p) => <String, dynamic>{
        'id': newId(),
        'title': p.title,
        'author': null,
        'key': p.key,
        'bpm': null,
        'groupId': null,
        'body': p.body,
        'style': null,
        'durationSec': null,
        'lastOpenedAt': null,
        'structure': null,
      }).toList();
  final wrapper = <String, dynamic>{
    'app': 'Songkey',
    'version': 1,
    'groups': <Object>[],
    'songs': songsJson,
  };
  File(outJson)
      .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(wrapper));

  // Escribir el informe.
  final sb = StringBuffer();
  sb.writeln('=== RESUMEN ===');
  sb.writeln('Archivos .cho encontrados: ${files.length}');
  sb.writeln('Canciones nuevas (a importar): ${keep.length}');
  sb.writeln('Copias idénticas descartadas: ${dropped.length}');
  sb.writeln('Grupos con mismo título pero letra distinta: ${sameTitleDifferent.length}');
  sb.writeln('Posibles similares (revisar): ${similarPairs.length}');
  sb.writeln('Ya en la biblioteca de ejemplo de la app: ${seedHits.length}');
  sb.writeln('');
  sb.writeln('=== CANCIONES NUEVAS ===');
  for (var i = 0; i < keep.length; i++) {
    final p = keep[i];
    sb.writeln('${i + 1}. ${p.title}  [${p.file.split(Platform.pathSeparator).last}]');
  }
  if (dropped.isNotEmpty) {
    sb.writeln('');
    sb.writeln('=== COPIAS IDÉNTICAS DESCARTADAS ===');
    for (final d in dropped) {
      sb.writeln('- $d');
    }
  }
  if (sameTitleDifferent.isNotEmpty) {
    sb.writeln('');
    sb.writeln('=== MISMO TÍTULO CON LETRA DISTINTA (se conservan todas) ===');
    for (final s in sameTitleDifferent) {
      sb.writeln('- $s');
    }
  }
  if (similarPairs.isNotEmpty) {
    sb.writeln('');
    sb.writeln('=== POSIBLES SIMILARES (revisar si son la misma canción) ===');
    for (final s in similarPairs) {
      sb.writeln('- $s');
    }
  }
  if (seedHits.isNotEmpty) {
    sb.writeln('');
    sb.writeln('=== YA EN LA BIBLIOTECA DE EJEMPLO DE LA APP ===');
    for (final p in seedHits) {
      sb.writeln('- ${p.title}  [${p.file.split(Platform.pathSeparator).last}]');
    }
  }
  File(outReport).writeAsStringSync(sb.toString());

  print('Canciones nuevas: ${keep.length}');
  print('Copias descartadas: ${dropped.length}');
  print('Mismo título con letra distinta: ${sameTitleDifferent.length}');
  print('Posibles similares: ${similarPairs.length}');
  print('En biblioteca de ejemplo: ${seedHits.length}');
  print('JSON: $outJson');
  print('Informe: $outReport');
}