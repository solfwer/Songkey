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
import '../theme.dart';
import 'share_utils.dart';

/// Codifica grupos + canciones (sin setlists) en un JSON intercambiable.
String encodeLibrary(AppState state) => jsonEncode({
      'app': 'Songkey',
      'version': 1,
      'groups': state.groups.map((g) => g.toJson()).toList(),
      'songs': state.songs.map((s) => s.toJson()).toList(),
    });

/// Decisión del usuario para cada canción duplicada al importar.
enum DuplicadoDecision { saltar, actualizar, reemplazar }

/// Resultado de una importación, para informar al usuario.
typedef ImportResult = ({
  List<Group> newGroups,
  List<Song> newSongs,
  int added,
  int skipped,
  List<Song> duplicateSongs,
  List<Song> updatedSongs,
  List<Song> replacedSongs,
});

/// Fusiona una biblioteca compartida en [current]: reutiliza grupos por nombre
/// y maneja canciones existentes según las preferencias del usuario.
///
/// [decisiones] es un mapa: título normalizado (lowercase) → [DuplicadoDecision].
/// Si una duplicada no tiene decisión, se salta por defecto.
ImportResult mergeLibrary(AppState current, String raw, {Map<String, DuplicadoDecision>? decisiones}) {
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

  // Canciones: detectar duplicados y manejar según la decisión del usuario.
  final existingTitles = {for (final s in current.songs) s.title.trim().toLowerCase()};
  final existingSongsMap = {for (final s in current.songs) s.title.trim().toLowerCase(): s};
  final usedIds = current.songs.map((s) => s.id).toSet();
  final newSongs = <Song>[];
  final updatedSongs = <Song>[];
  final replacedSongs = <Song>[];
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
      // Canción duplicada - decidir según el mapa de decisiones
      final decision = decisiones?[lowerTitle] ?? DuplicadoDecision.saltar;
      switch (decision) {
        case DuplicadoDecision.saltar:
          skipped++;
          continue;
        case DuplicadoDecision.actualizar:
          // Conservar el id existente (referencias de setlists intactas)
          final existingSong = current.songs.firstWhere((s) => s.title.toLowerCase() == lowerTitle);
          String? gid = song.groupId;
          if (gid != null) gid = groupMap[gid];
          final updatedSong = Song(
            id: existingSong.id,
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
          updatedSongs.add(updatedSong);
          break;
        case DuplicadoDecision.reemplazar:
          // Borrar la existente e insertar la importada tal cual
          String? gid = song.groupId;
          if (gid != null) gid = groupMap[gid];
          final replacedSong = Song(
            id: song.id.isEmpty || song.id.startsWith('temp_') || usedIds.contains(song.id) ? uid() : song.id,
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
          replacedSongs.add(replacedSong);
          break;
      }
      continue;
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
  return (newGroups: newGroups, newSongs: newSongs, added: added, skipped: skipped, duplicateSongs: [], updatedSongs: updatedSongs, replacedSongs: replacedSongs);
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
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/octet-stream', name: 'Songkey_biblioteca.songkey')],
        text: 'Mi biblioteca de Songkey (canciones y grupos)',
        sharePositionOrigin: origin,
      ),
    );
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('No se pudo compartir la biblioteca: $e')));
  }
}

/// Pide un archivo de biblioteca y añade sus canciones/grupos con vista previa.
Future<void> importLibrary(BuildContext context, Store store) async {
  final messenger = ScaffoldMessenger.of(context);
  final result = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['json', 'songkey'],
  );
  if (result.isEmpty) return;
  final file = result.single;
  final bytes = await file.readAsBytes();
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

/// Muestra un diálogo de vista previa con opciones de importación.
/// Devuelve un mapa: título normalizado → [DuplicadoDecision].
Future<Map<String, DuplicadoDecision>?> _showImportPreviewDialog(BuildContext context, Store store, String raw) async {
  // Parsear para vista previa
  final data = jsonDecode(raw) as Map<String, dynamic>;
  final songsJson = (data['songs'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  final groupsJson = (data['groups'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

  final storeState = store.state;
  final existingTitles = {for (final s in storeState.songs) s.title.trim().toLowerCase()};
  final existingSongsMap = {for (final s in storeState.songs) s.title.trim().toLowerCase(): s};
  final existingGroupsByName = {for (final g in storeState.groups) g.name.trim().toLowerCase()};

  final newSongs = <Song>[];
  final duplicateSongs = <Song>[];
  int newGroupsCount = 0;

  for (final j in songsJson) {
    final song = Song.fromJson(j);
    final t = song.title.trim();
    if (t.isEmpty) continue;
    final lowerTitle = t.toLowerCase();
    if (existingTitles.contains(lowerTitle)) {
      duplicateSongs.add(song);
    } else {
      newSongs.add(song);
    }
  }

  for (final g in groupsJson) {
    final group = Group.fromJson(g);
    final name = group.name.trim().toLowerCase();
    if (!existingGroupsByName.contains(name) && name.isNotEmpty) {
      newGroupsCount++;
    }
  }

  if (!context.mounted) return null;

  final messenger = ScaffoldMessenger.of(context);

  // Mostrar diálogo de confirmación con vista previa por canción
  final decisiones = await showDialog<Map<String, DuplicadoDecision>>(
    context: context,
    builder: (context) => _ImportPreviewDialog(
      newSongs: newSongs,
      duplicateSongs: duplicateSongs,
      existingSongsMap: existingSongsMap,
      newGroupsCount: newGroupsCount,
    ),
  );

  if (decisiones == null) return null; // Usuario canceló

  // Importar con las decisiones elegidas
  try {
    final res = mergeLibrary(store.state, raw, decisiones: decisiones);
    store.update((s) {
      final canciones = <Song>[...s.songs];
      // Aplicar canciones actualizadas (conservan su id y referencias de setlists)
      for (final u in res.updatedSongs) {
        final idx = canciones.indexWhere((x) => x.id == u.id);
        if (idx >= 0) canciones[idx] = u;
      }
      // Aplicar canciones reemplazadas (borran la existente e insertan la importada)
      for (final r in res.replacedSongs) {
        final idx = canciones.indexWhere((x) => x.title.toLowerCase() == r.title.toLowerCase());
        if (idx >= 0) canciones[idx] = r;
        else canciones.add(r);
      }
      return AppState(
        groups: [...s.groups, ...res.newGroups],
        songs: [...res.newSongs, ...canciones],
        setlists: s.setlists,
      );
    });
    final partes = <String>[];
    if (res.added > 0) partes.add('${res.added} nueva${res.added == 1 ? '' : 's'}');
    if (res.updatedSongs.isNotEmpty) partes.add('${res.updatedSongs.length} actualizada${res.updatedSongs.length == 1 ? '' : 's'}');
    if (res.replacedSongs.isNotEmpty) partes.add('${res.replacedSongs.length} reemplazada${res.replacedSongs.length == 1 ? '' : 's'}');
    if (res.skipped > 0) partes.add('${res.skipped} saltada${res.skipped == 1 ? '' : 's'}');
    if (newGroupsCount > 0) partes.add('${newGroupsCount} grupo${newGroupsCount == 1 ? '' : 's'}');
    final msg = partes.isEmpty
        ? 'No había canciones nuevas en el archivo.'
        : 'Importado: ${partes.join(', ')}.';
    if (context.mounted) {
      messenger.showSnackBar(SnackBar(content: Text(msg)));
    }
  } catch (e) {
    if (context.mounted) {
      messenger.showSnackBar(SnackBar(content: Text('No se pudo importar la biblioteca: $e')));
    }
  }
  return null;
}

/// Diálogo de vista previa de importación con decisión por canción duplicada.
class _ImportPreviewDialog extends StatefulWidget {
  final List<Song> newSongs;
  final List<Song> duplicateSongs;
  final Map<String, Song> existingSongsMap;
  final int newGroupsCount;

  const _ImportPreviewDialog({
    required this.newSongs,
    required this.duplicateSongs,
    required this.existingSongsMap,
    required this.newGroupsCount,
  });

  @override
  State<_ImportPreviewDialog> createState() => _ImportPreviewDialogState();
}

class _ImportPreviewDialogState extends State<_ImportPreviewDialog> {
  // Decisión por canción duplicada (clave = título lowercase).
  final Map<String, DuplicadoDecision> _decisiones = {};

  DuplicadoDecision _decisionFor(String title) => _decisiones[title.toLowerCase()] ?? DuplicadoDecision.saltar;

  void _setAll(DuplicadoDecision decision) {
    setState(() {
      for (final s in widget.duplicateSongs) {
        _decisiones[s.title.trim().toLowerCase()] = decision;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tieneDuplicados = widget.duplicateSongs.isNotEmpty;

    return AlertDialog(
      title: const Text('Vista previa de importación'),
      content: SizedBox(
        width: double.maxFinite,
        height: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Resumen
            Text('Se importarán ${widget.newSongs.length} canción${widget.newSongs.length == 1 ? '' : 'es'} nueva${widget.newSongs.length == 1 ? '' : 's'}.', style: const TextStyle(fontWeight: FontWeight.w600)),
            if (tieneDuplicados)
              Text('Se detectaron ${widget.duplicateSongs.length} canción${widget.duplicateSongs.length == 1 ? '' : 's'} ya existente${widget.duplicateSongs.length == 1 ? '' : 's'}.', style: const TextStyle(color: Colors.orange)),
            if (widget.newGroupsCount > 0)
              Text('Se añadirán ${widget.newGroupsCount} grupo${widget.newGroupsCount == 1 ? '' : 's'} nuevo${widget.newGroupsCount == 1 ? '' : 's'}.'),
            const SizedBox(height: 16),

            // Botones globales para duplicados
            if (tieneDuplicados) ...[
              const Text('¿Qué hacer con las canciones duplicadas?', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _setAll(DuplicadoDecision.saltar),
                      child: const Text('Saltar todas'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _setAll(DuplicadoDecision.actualizar),
                      child: const Text('Actualizar todas'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _setAll(DuplicadoDecision.reemplazar),
                      style: OutlinedButton.styleFrom(foregroundColor: AppColors.destructive),
                      child: const Text('Reemplazar todas'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // Lista de duplicadas con decisión individual
            if (tieneDuplicados) ...[
              const Text('Canciones duplicadas:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: widget.duplicateSongs.length,
                  itemBuilder: (context, i) {
                    final song = widget.duplicateSongs[i];
                    final key = song.title.trim().toLowerCase();
                    final decision = _decisionFor(song.title);
                    final existente = widget.existingSongsMap[key];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(song.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (existente != null)
                              Text('En tu biblioteca: tono ${existente.key}${existente.bpm != null ? ' · ${existente.bpm} BPM' : ''}'),
                            Text('Importada: tono ${song.key}${song.bpm != null ? ' · ${song.bpm} BPM' : ''}'),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                _DecisionChip(
                                  decision: DuplicadoDecision.saltar,
                                  actual: decision,
                                  label: 'Saltar',
                                  onTap: () => setState(() => _decisiones[key] = DuplicadoDecision.saltar),
                                ),
                                const SizedBox(width: 6),
                                _DecisionChip(
                                  decision: DuplicadoDecision.actualizar,
                                  actual: decision,
                                  label: 'Actualizar',
                                  onTap: () => setState(() => _decisiones[key] = DuplicadoDecision.actualizar),
                                ),
                                const SizedBox(width: 6),
                                _DecisionChip(
                                  decision: DuplicadoDecision.reemplazar,
                                  actual: decision,
                                  label: 'Reemplazar',
                                  onTap: () => setState(() => _decisiones[key] = DuplicadoDecision.reemplazar),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _decisiones),
          child: const Text('Importar'),
        ),
      ],
    );
  }
}

/// Chip de decisión individual para una canción duplicada.
class _DecisionChip extends StatelessWidget {
  final DuplicadoDecision decision;
  final DuplicadoDecision actual;
  final String label;
  final VoidCallback onTap;

  const _DecisionChip({
    required this.decision,
    required this.actual,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final seleccionado = actual == decision;
    return FilterChip(
      label: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: seleccionado ? Colors.white : null)),
      selected: seleccionado,
      onSelected: (_) => onTap(),
      backgroundColor: Colors.grey.withValues(alpha: 0.15),
      selectedColor: _color(decision),
      checkmarkColor: Colors.white,
      showCheckmark: false,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Color _color(DuplicadoDecision d) {
    switch (d) {
      case DuplicadoDecision.saltar:
        return Colors.grey;
      case DuplicadoDecision.actualizar:
        return AppColors.primary;
      case DuplicadoDecision.reemplazar:
        return AppColors.destructive;
    }
  }
}
