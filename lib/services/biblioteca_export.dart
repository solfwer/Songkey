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
typedef ImportResult = ({
  List<Group> newGroups,
  List<Song> newSongs,
  int added,
  int skipped,
  List<Song> duplicateSongs,
  List<Song> updatedSongs,
});

/// Fusiona una biblioteca compartida en [current]: reutiliza grupos por nombre
/// y maneja canciones existentes según las preferencias del usuario.
ImportResult mergeLibrary(AppState current, String raw, {bool updateExisting = false, List<Song> songsToUpdate = const []}) {
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

  // Canciones: detectar duplicados y manejar según preferencia.
  final existingTitles = {for (final s in current.songs) s.title.trim().toLowerCase()};
  final existingSongsMap = {for (final s in current.songs) s.title.trim().toLowerCase(): s};
  final usedIds = current.songs.map((s) => s.id).toSet();
  final newSongs = <Song>[];
  final updatedSongs = <Song>[];
  var added = 0, skipped = 0;
  for (final j in songsJson) {
    final song = Song.fromJson(j);
    final t = song.title.trim();
    if (t.isEmpty) {
      skipped++;
      continue;
    }
    final lowerTitle = t.toLowerCase();
    if (existingTitles.contains(lowerTitle)) {
      // Canción duplicada - decidir qué hacer
      if (updateExisting) {
        // Actualizar la canción existente
        final existingSong = current.songs.firstWhere((s) => s.title.toLowerCase() == lowerTitle);
        String? gid = song.groupId;
        if (gid != null) gid = groupMap[gid];
        final updatedSong = Song(
          id: existingSongsMap[t.toLowerCase()]?.id ?? song.id,
          title: t,
          author: song.author,
          key: song.key,
          bpm: song.bpm,
          groupId: gid,
          body: song.body,
          style: song.style,
          durationSec: song.durationSec,
          lastOpenedAt: null,
          structure: song.structure,
        );
        updatedSongs.add(Song(
          id: existingSongsMap[t.toLowerCase()]!.id,
          title: t,
          author: song.author,
          key: song.key,
          bpm: song.bpm,
          groupId: gid,
          body: song.body,
          style: song.style,
          durationSec: song.durationSec,
          lastOpenedAt: null,
          structure: song.structure,
        ));
      } else {
        // Saltar canción duplicada
        skipped++;
        continue;
      }
    }
    var id = song.id;
    if (id.isEmpty || id.startsWith('temp_') || usedIds.contains(id)) id = uid();
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
      lastOpenedAt: null,
      structure: song.structure,
    ));
    added++;
  }
  return (newGroups: newGroups, newSongs: newSongs, added: added, skipped: skipped, duplicateSongs: [], updatedSongs: updatedSongs);
}

/// Comparte la biblioteca o la guarda en el dispositivo (a eleccion del usuario).
Future<void> shareLibrary(BuildContext context, Store store) async {
  final messenger = ScaffoldMessenger.of(context);
  final opcion = await askShareOrSave(context, que: 'la biblioteca');
  if (opcion == null) return;

  if (opcion) {
    // Guardar en el telefono
    final bytes = utf8.encode(encodeLibrary(store.state));
    final nombre = datedFileName('Songkey_biblioteca', 'songkey');
    final ruta = await saveBytesToDevice(bytes: bytes, fileName: nombre, mimeType: 'application/octet-stream');
    if (!context.mounted) return;
    if (ruta != null) {
      messenger.showSnackBar(SnackBar(content: Text('Biblioteca guardada: $ruta'), duration: const Duration(seconds: 5)));
    } else {
      messenger.showSnackBar(const SnackBar(content: Text('No se pudo guardar el archivo.')));
    }
    return;
  }

  // Compartir por el panel del sistema
  final origin = shareOrigin(context);
  try {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/Songkey_biblioteca.songkey');
    await file.writeAsString(encodeLibrary(store.state));
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/octet-stream', name: 'Songkey_biblioteca.songkey')],
      text: 'Mi biblioteca de Songkey (canciones y grupos)',
      sharePositionOrigin: origin,
    );
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('No se pudo compartir la biblioteca: $e')));
  }
}

/// Pide un archivo de biblioteca y añade sus canciones/grupos con vista previa.
Future<void> importLibrary(BuildContext context, Store store) async {
  final messenger = ScaffoldMessenger.of(context);
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['json', 'songkey'],
    withData: true,
  );
  if (result == null || result.files.isEmpty) return;
  final file = result.files.single;
  final bytes = file.bytes;
  if (file == null || bytes == null) return;

  String raw;
  try {
    raw = utf8.decode(bytes);
  } catch (_) {
    if (!context.mounted) return;
    messenger.showSnackBar(const SnackBar(content: Text('No se pudo leer el archivo seleccionado.')));
    return;
  }

  // Validar que sea una biblioteca de Songkey
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

  // Mostrar diálogo de vista previa con opciones (pasando el raw ya leído)
  if (!context.mounted) return;
  await _showImportPreviewDialog(context, store, raw);
}

/// Muestra un diálogo de vista previa con opciones de importación
Future<void> _showImportPreviewDialog(BuildContext context, Store store, String raw) async {
  // Parsear para vista previa
  final data = jsonDecode(raw) as Map<String, dynamic>;
  final songsJson = (data['songs'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  final groupsJson = (data['groups'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

  // Analizar duplicados
  final storeState = store.state;
  final existingTitles = {for (final s in storeState.songs) s.title.trim().toLowerCase()};
  final existingGroupsByName = {for (final g in storeState.groups) g.name.trim().toLowerCase()};

  int newSongsCount = 0;
  int duplicateSongsCount = 0;
  int newGroupsCount = 0;

  for (final j in songsJson) {
    final song = Song.fromJson(j);
    final t = song.title.trim();
    final lowerTitle = t.toLowerCase();
    if (existingTitles.contains(lowerTitle)) {
      duplicateSongsCount++;
    } else {
      newSongsCount++;
    }
  }

  for (final g in groupsJson) {
    final group = Group.fromJson(g);
    final name = group.name.trim().toLowerCase();
    if (!existingGroupsByName.contains(name) && name.isNotEmpty) {
      newGroupsCount++;
    }
  }

  if (!context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);

  // Mostrar diálogo de confirmación con vista previa
  final updateExisting = await showDialog<bool>(
    context: context,
    builder: (context) => _ImportPreviewDialog(
      newSongsCount: newSongsCount,
      duplicateSongsCount: duplicateSongsCount,
      newGroupsCount: newGroupsCount,
    ),
  );

  if (updateExisting == null) return; // Usuario canceló

  // Importar con las opciones elegidas
  try {
    final res = mergeLibrary(store.state, raw, updateExisting: updateExisting);
    store.update((s) => AppState(
      groups: [...s.groups, ...res.newGroups],
      songs: [...res.newSongs, ...s.songs],
      setlists: s.setlists,
    ));
    final msg = res.added == 0 && res.skipped == 0
        ? 'No había canciones nuevas en el archivo.'
        : 'Importadas ${res.added} canción${res.added == 1 ? '' : 'es'}'
            '${res.skipped > 0 ? ', ${res.skipped} repetida${res.skipped == 1 ? '' : 's'} omitida${res.skipped == 1 ? '' : 's'}' : ''}'
            '${res.updatedSongs.isNotEmpty ? ', ${res.updatedSongs.length} canción${res.updatedSongs.length == 1 ? '' : 'es'} actualizada${res.updatedSongs.length == 1 ? '' : 's'}' : ''}'
            '${res.newGroups.isNotEmpty ? ', ${res.newGroups.length} grupo${res.newGroups.length == 1 ? '' : 's'} nuevo${res.newGroups.length == 1 ? '' : 's'}' : ''}.';
    if (context.mounted) {
      messenger.showSnackBar(SnackBar(content: Text(msg)));
    }
  } catch (e) {
    if (context.mounted) {
      messenger.showSnackBar(SnackBar(content: Text('No se pudo importar la biblioteca: $e')));
    }
  }
}

/// Diálogo de vista previa de importación
class _ImportPreviewDialog extends StatelessWidget {
  final int newSongsCount;
  final int duplicateSongsCount;
  final int newGroupsCount;

  const _ImportPreviewDialog({
    required this.newSongsCount,
    required this.duplicateSongsCount,
    required this.newGroupsCount,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Vista previa de importación'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Se importarán $newSongsCount canción${newSongsCount == 1 ? '' : 'es'} nueva${newSongsCount == 1 ? '' : 's'}.'),
            if (duplicateSongsCount > 0)
              Text('Se detectaron $duplicateSongsCount canción${duplicateSongsCount == 1 ? '' : 's'} ya existente${duplicateSongsCount == 1 ? '' : 's'}.'),
            if (newGroupsCount > 0)
              Text('Se añadirán $newGroupsCount grupo${newGroupsCount == 1 ? '' : 's'} nuevo${newGroupsCount == 1 ? '' : 's'}.'),
            const SizedBox(height: 16),
            const Text('¿Qué hacer con las canciones duplicadas?'),
            const SizedBox(height: 8),
            const Text('Las canciones con el mismo título ya existen en tu biblioteca.', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false), // Saltar duplicados
          child: const Text('Saltar duplicados'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true), // Actualizar duplicados
          child: const Text('Actualizar duplicados'),
        ),
      ],
    );
  }
}
