// Biblioteca de canciones: buscador + botón "+" para añadir canciones
// (manualmente con ChordPro, desde un PDF o desde un documento ChordPro).
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../data/chord_parser.dart';
import '../../data/format.dart';
import '../../data/store.dart';
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
    return f.isEmpty ? all : all.where((x) => x.title.toLowerCase().contains(f)).toList();
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
    final name = file.name.replaceAll(RegExp(r'\.[^.]+$'), '');
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => SongEditorPage(store: widget.store, initialTitle: name, initialBody: text)));
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
                        final group = s.groups.where((g) => g.id == song.groupId).map((g) => g.name).cast<String?>().firstWhere((_) => true, orElse: () => null);
                        final duration = formatDuration(song.durationSec);
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                            foregroundColor: AppColors.primary,
                            child: Text(notateChord(song.key, american: widget.store.americanNotation), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                          title: Text(song.title),
                          isThreeLine: song.style != null || duration.isNotEmpty,
                          subtitle: Text(
                            [
                              group ?? 'Sin grupo',
                              if (song.style != null && song.style!.isNotEmpty) song.style!,
                              if (song.bpm != null) '${song.bpm} BPM',
                              if (duration.isNotEmpty) duration,
                              secs.map((x) => x.abbr).join(' · '),
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