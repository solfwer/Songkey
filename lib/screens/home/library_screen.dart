// Biblioteca de canciones: buscador + botón "+" para añadir canciones
// (manualmente con ChordPro, desde un PDF o desde un documento ChordPro).
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../data/chordpro.dart';
import '../../data/chord_parser.dart';
import '../../data/format.dart';
import '../../data/store.dart';
import '../../models/app_state.dart';
import '../../models/song.dart';
import '../../services/pdf_import.dart';
import '../../models/song.dart';
import '../../services/pdf_import.dart';
import '../../theme.dart';
import '../song/song_editor_page.dart';
import '../song/song_screen.dart';

/// Formas de añadir una canción desde el menú "+".
enum _AddOption { manual, pdf, chordpro }

class LibraryScreen extends StatefulWidget {
  final Store store;
  const LibraryScreen({super.key, required this.store});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  String q = '';

  List<Song> _applyFilters(List<Song> all) {
    final f = q.trim().toLowerCase();
    if (f.isEmpty) return all;
    return all.where((x) {
      final title = x.title.toLowerCase();
      final author = (x.author ?? '').toLowerCase();
      final body = x.body.toLowerCase();
      return title.contains(f) || author.contains(f) || body.contains(f);
    }).toList();
  }

  void _handleAdd(_AddOption opt) {
    switch (opt) {
      case _AddOption.manual:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => SongEditorPage(store: widget.store)));
      case _AddOption.pdf:
        _importPdf();
      case _AddOption.chordpro:
        _importChordPro();
    }
  }

  Future<void> _importPdf() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf'], withData: true);
    final file = res?.files.firstOrNull;
    final bytes = file?.bytes;
    if (file == null || bytes == null) return;
    try {
      final draft = await pdfToDraft(file.name, bytes);
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => SongEditorPage(store: widget.store, initialTitle: draft.title, initialBody: draft.body)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo leer el PDF (¿escaneado?)')));
      }
    }
  }

  Future<void> _importChordPro() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['cho', 'chopro', 'chordpro', 'txt'], withData: true);
    final file = res?.files.firstOrNull;
    final bytes = file?.bytes;
    if (file == null || bytes == null) return;
    final text = utf8.decode(bytes);
    final fileName = file.name.replaceAll(RegExp(r'\.[^.]+$'), '');

    // Dividir en canciones individuales
    final songTexts = splitChordProSongs(text);

    // Si solo hay 1 canción, comportamiento actual: abrir editor
    if (songTexts.length == 1) {
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => SongEditorPage(store: widget.store, initialTitle: fileName, initialBody: songTexts.first)));
      return;
    }

    // Varias canciones: parsear cada una y mostrar diálogo de selección
    final parser = ChordProParser();
    final existingTitles = widget.store.state.songs.map((s) => s.title.trim().toLowerCase()).toSet();
    final seenTitles = <String>{};

    final parsedSongs = <_ParsedSong>[];
    for (var i = 0; i < songTexts.length; i++) {
      final st = songTexts[i];
      parser.issues.clear();
      final song = parser.parse(st);
      String title = song.meta.title ?? '';
      if (title.isEmpty) title = '$fileName (${i + 1})';
      final author = song.meta.artist;
      final key = song.meta.key ?? 'C';
      final bpm = int.tryParse(song.meta.tempo ?? '');
      final isDuplicateInFile = seenTitles.contains(title.trim().toLowerCase());
      final isDuplicateInLibrary = existingTitles.contains(title.trim().toLowerCase());
      seenTitles.add(title.trim().toLowerCase());
      parsedSongs.add(_ParsedSong(
        title: title,
        author: author,
        key: key,
        bpm: bpm,
        body: st,
        isDuplicate: isDuplicateInFile || isDuplicateInLibrary,
        duplicateReason: isDuplicateInFile ? 'Repetida en el archivo' : (isDuplicateInLibrary ? 'Ya en la biblioteca' : null),
      ));
    }

    if (!mounted) return;
    final selected = await showDialog<List<_ParsedSong>>(
      context: context,
      builder: (_) => _MultiSongImportDialog(parsedSongs: parsedSongs),
    );

    if (selected == null || selected.isEmpty) return;

    // Guardar las seleccionadas
    widget.store.update((state) {
      final songs = [...state.songs, ...selected.map((p) => Song(
        id: uid(),
        title: p.title,
        author: p.author,
        key: p.key,
        bpm: p.bpm,
        body: p.body,
      ))];
      return AppState(groups: state.groups, songs: songs, setlists: state.setlists);
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Se añadieron ${selected.length} canciones')));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final s = widget.store.state;
        final list = _applyFilters(s.songs);
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Row(children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(hintText: 'Buscar canción…', prefixIcon: Icon(Icons.search)),
                  onChanged: (v) => setState(() => q = v),
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<_AddOption>(
                tooltip: 'Añadir canción',
                onSelected: _handleAdd,
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: _AddOption.manual,
                    child: ListTile(leading: Icon(Icons.edit), title: Text('Escribir a mano (ChordPro)'), contentPadding: EdgeInsets.zero, dense: true),
                  ),
                  const PopupMenuItem(
                    value: _AddOption.pdf,
                    child: ListTile(leading: Icon(Icons.picture_as_pdf), title: Text('Importar PDF'), contentPadding: EdgeInsets.zero, dense: true),
                  ),
                  const PopupMenuItem(
                    value: _AddOption.chordpro,
                    child: ListTile(leading: Icon(Icons.description), title: Text('Importar documento ChordPro'), contentPadding: EdgeInsets.zero, dense: true),
                  ),
                ],
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.add, color: Colors.white, size: 26),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerRight, child: Text('${list.length} canciones', style: const TextStyle(color: Colors.grey))),
            const SizedBox(height: 8),
            Expanded(
              child: list.isEmpty
                  ? const Center(child: Text('No hay canciones. Toca + para crear o importar.'))
                  : ListView.separated(
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final song = list[i];
                        final secs = parseSong(song.body).where((x) => x.kind != SectionKind.other).toList();
                        // Vista compacta: solo secciones únicas (sin repeticiones).
                        final uniqueAbbrs = secs.map((x) => x.abbr).toSet().toList();
                        final group = s.groups.where((g) => g.id == song.groupId).map((g) => g.name).cast<String?>().firstWhere((_) => true, orElse: () => null);
                        final duration = formatDuration(song.durationSec);
                        // ¿Dónde coincide la búsqueda?
                        final f = q.trim().toLowerCase();
                        final inTitle = song.title.toLowerCase().contains(f);
                        final inAuthor = (song.author ?? '').toLowerCase().contains(f);
                        final inBody = song.body.toLowerCase().contains(f);
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                            foregroundColor: AppColors.primary,
                            child: Text(notateChord(song.key, american: widget.store.americanNotation), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                          title: Row(children: [
                            Expanded(child: Text(song.title)),
                            if (f.isNotEmpty && !inTitle && (inAuthor || inBody))
                              Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: AppColors.accent.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    inAuthor && inBody ? 'autor + letra' : inAuthor ? 'autor' : 'letra',
                                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.accent),
                                  ),
                                ),
                              ),
                          ]),
                          isThreeLine: song.style != null || duration.isNotEmpty,
                          subtitle: Text(
                            [
                              group ?? 'Sin grupo',
                              if (song.style != null && song.style!.isNotEmpty) song.style!,
                              if (song.bpm != null) '${song.bpm} BPM',
                              if (duration.isNotEmpty) duration,
                              uniqueAbbrs.join(' · '),
                            ].join(' · '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SongScreen(store: widget.store, songId: song.id))),
                        );
                      },
                    ),
            ),
          ]),
        );
      },
    );
  }
}

class _ParsedSong {
  final String title;
  final String? author;
  final String key;
  final int? bpm;
  final String body;
  final bool isDuplicate;
  final String? duplicateReason;
  final bool selected;

  _ParsedSong({
    required this.title,
    required this.author,
    required this.key,
    required this.bpm,
    required this.body,
    required this.isDuplicate,
    required this.duplicateReason,
    this.selected = true,
  });

  _ParsedSong copyWith({bool? selected}) => _ParsedSong(
    title: title,
    author: author,
    key: key,
    bpm: bpm,
    body: body,
    isDuplicate: isDuplicate,
    duplicateReason: duplicateReason,
    selected: selected ?? this.selected,
  );
}

class _MultiSongImportDialog extends StatefulWidget {
  final List<_ParsedSong> parsedSongs;
  const _MultiSongImportDialog({required this.parsedSongs});

  @override
  State<_MultiSongImportDialog> createState() => _MultiSongImportDialogState();
}

class _MultiSongImportDialogState extends State<_MultiSongImportDialog> {
  late List<_ParsedSong> _songs;

  @override
  void initState() {
    super.initState();
    _songs = List.from(widget.parsedSongs);
  }

  int get _selectedCount => _songs.where((s) => s.selected).length;

  void _toggle(int i) {
    setState(() => _songs[i] = _songs[i].copyWith(selected: !_songs[i].selected));
  }

  void _selectAll() {
    setState(() => _songs = _songs.map((s) => s.copyWith(selected: true)).toList());
  }

  void _selectNone() {
    setState(() => _songs = _songs.map((s) => s.copyWith(selected: false)).toList());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Importar canciones'),
      content: SizedBox(
        width: double.maxFinite,
        height: 500,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: _selectAll, child: const Text('Todas')),
                const SizedBox(width: 8),
                TextButton(onPressed: _selectNone, child: const Text('Ninguna')),
              ],
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _songs.length,
                itemBuilder: (context, i) {
                  final song = _songs[i];
                  return ExpansionTile(
                    initiallyExpanded: false,
                    leading: Checkbox(
                      value: song.selected,
                      onChanged: (_) => _toggle(i),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            song.title,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: song.isDuplicate ? Colors.orange : null,
                              decoration: song.isDuplicate ? TextDecoration.lineThrough : null,
                            ),
                          ),
                        ),
                        if (song.bpm != null) Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text('${song.bpm} BPM', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                        if (song.isDuplicate) Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(song.duplicateReason!, style: const TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text('Tono: ${song.key} · ${song.author ?? 'Sin autor'}'),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          song.body.length > 500 ? '${song.body.substring(0, 500)}...' : song.body,
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const Divider(),
            Text('Se añadirán $_selectedCount canciones', style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, <_ParsedSong>[]), child: const Text('Cancelar')),
        FilledButton(
          onPressed: _selectedCount == 0 ? null : () => Navigator.pop(context, _songs.where((s) => s.selected).toList()),
          child: Text('Importar $_selectedCount'),
        ),
      ],
    );
  }
}