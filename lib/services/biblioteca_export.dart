// Compartir e importar la biblioteca completa (canciones + grupos) con otra
// persona: se exporta como archivo JSON que se envía por el panel de
// compartir (WhatsApp, correo…) y se importa desde Ajustes > Biblioteca.
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/store.dart';
import '../models/app_state.dart';
import '../models/song.dart';
import 'share_utils.dart';

/// Codifica grupos + canciones (sin setlists) en un JSON intercambiable.
String encodeLibrary(AppState state) => jsonEncode({
      'app': 'Songkey',
      'version': 1,
      'groups': state.groups.map((g) => g.toJson()).toList(),
      'songs': state.songs.map((s) => s.toJson()).toList(),
    });

/// Resultado de una importación, para informar al usuario.
typedef ImportResult = ({List<Group> newGroups, List<Song> newSongs, int added, int skipped});

/// Fusiona una biblioteca compartida en [current]: reutiliza grupos por nombre
/// y salta canciones que ya existan (por título, sin distinguir mayúsculas).
ImportResult mergeLibrary(AppState current, String raw) {
  final data = jsonDecode(raw) as Map<String, dynamic>;
  final songsJson = (data['songs'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  final groupsJson = (data['groups'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

  String? norm(String? n) => n?.trim().toLowerCase();

  // Grupos: reutilizar por nombre o añadir con id nuevo (evita colisiones).
  final existingGroupByName = <String, String>{for (final g in current.groups) norm(g.name)!: g.id};
  final groupMap = <String, String>{};
  final newGroups = <Group>[];
  for (final g in groupsJson) {
    final imported = Group.fromJson(g);
    final name = imported.name.trim();
    if (name.isEmpty) continue;
    final existing = existingGroupByName[norm(name)];
    if (existing != null) {
      groupMap[imported.id] = existing;
      continue;
    }
    final newId = uid();
    groupMap[imported.id] = newId;
    newGroups.add(Group(id: newId, name: imported.name, color: imported.color, members: imported.members, owner: imported.owner));
  }

  // Canciones: saltar las que ya existen por título.
  final existingTitles = {for (final s in current.songs) s.title.trim().toLowerCase()};
  final usedIds = current.songs.map((s) => s.id).toSet();
  final newSongs = <Song>[];
  var added = 0, skipped = 0;
  for (final j in songsJson) {
    final song = Song.fromJson(j);
    final t = song.title.trim();
    if (t.isEmpty) {
      skipped++;
      continue;
    }
    if (existingTitles.contains(t.toLowerCase())) {
      skipped++;
      continue;
    }
    var id = song.id;
    if (id.isEmpty || usedIds.contains(id)) id = uid();
    usedIds.add(id);
    String? gid = song.groupId;
    if (gid != null) gid = groupMap[gid];
    newSongs.add(Song(
      id: id,
      title: t,
      author: song.author,
      key: song.key,
      bpm: song.bpm,
      groupId: gid,
      body: song.body,
      style: song.style,
      durationSec: song.durationSec,
      // El "recién abierta" de otro dispositivo no interesa aquí.
      lastOpenedAt: null,
      structure: song.structure,
    ));
    added++;
  }
  return (newGroups: newGroups, newSongs: newSongs, added: added, skipped: skipped);
}

/// Comparte la biblioteca por el panel de compartir del sistema.
Future<void> shareLibrary(BuildContext context, Store store) async {
  final messenger = ScaffoldMessenger.of(context);
  final origin = shareOrigin(context);
  try {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/Songkey_biblioteca.json');
    await file.writeAsString(encodeLibrary(store.state));
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/json', name: 'Songkey_biblioteca.json')],
      text: 'Mi biblioteca de Songkey (canciones y grupos)',
      sharePositionOrigin: origin,
    );
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('No se pudo compartir la biblioteca: $e')));
  }
}

/// Pide un archivo de biblioteca y añade sus canciones/grupos.
Future<void> importLibrary(BuildContext context, Store store) async {
  final messenger = ScaffoldMessenger.of(context);
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['json', 'songkey'],
    withData: true,
  );
  if (result == null || result.files.isEmpty) return;
  final bytes = result.files.single.bytes;
  if (bytes == null) {
    messenger.showSnackBar(const SnackBar(content: Text('No se pudo leer el archivo seleccionado.')));
    return;
  }
  String raw;
  try {
    raw = utf8.decode(bytes);
  } catch (_) {
    messenger.showSnackBar(const SnackBar(content: Text('El archivo no se pudo leer como texto.')));
    return;
  }
  try {
    final data = jsonDecode(raw);
    if (data is! Map<String, dynamic> || data['app'] != 'Songkey' || data['songs'] is! List) {
      messenger.showSnackBar(const SnackBar(content: Text('Ese archivo no es una biblioteca de Songkey.')));
      return;
    }
  } catch (_) {
    messenger.showSnackBar(const SnackBar(content: Text('Ese archivo no es una biblioteca de Songkey.')));
    return;
  }
  try {
    final res = mergeLibrary(store.state, raw);
    store.update((s) => AppState(
          groups: [...s.groups, ...res.newGroups],
          songs: [...res.newSongs, ...s.songs],
          setlists: s.setlists,
        ));
    final msg = res.added == 0 && res.skipped == 0
        ? 'No había canciones nuevas en el archivo.'
        : 'Importadas ${res.added} canción${res.added == 1 ? '' : 'es'}'
            '${res.skipped > 0 ? ', ${res.skipped} repetida${res.skipped == 1 ? '' : 's'} omitida${res.skipped == 1 ? '' : 's'}' : ''}'
            '${res.newGroups.isNotEmpty ? ', ${res.newGroups.length} grupo${res.newGroups.length == 1 ? '' : 's'} nuevo${res.newGroups.length == 1 ? '' : 's'}' : ''}.';
    messenger.showSnackBar(SnackBar(content: Text(msg)));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('No se pudo importar la biblioteca: $e')));
  }
}