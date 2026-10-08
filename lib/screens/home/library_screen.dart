import 'package:flutter/material.dart';

import '../../data/chord_parser.dart';
import '../../data/format.dart';
import '../../data/store.dart';
import '../../models/song.dart';
import '../../theme.dart';
import '../song/song_editor_page.dart';
import '../song/song_screen.dart';

class LibraryScreen extends StatefulWidget {
  final Store store;
  const LibraryScreen({super.key, required this.store});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  String q = '';
  String? groupId;
  int category = 0; // 0 = Todas, 1 = Recientes

  List<Song> _applyFilters(List<Song> all) {
    final filtered = all
        .where((x) =>
            (category != 1 || x.lastOpenedAt != null) &&
            (groupId == null || x.groupId == groupId) &&
            x.title.toLowerCase().contains(q.toLowerCase()))
        .toList();
    if (category == 1) {
      filtered.sort((a, b) => ((b.lastOpenedAt ?? '')).compareTo(a.lastOpenedAt ?? ''));
      return filtered.take(12).toList();
    }
    return filtered;
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
              FilledButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SongEditorPage(store: widget.store, initialGroupId: groupId))),
                icon: const Icon(Icons.add),
                label: const Text('Nueva'),
              ),
            ]),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 4, children: [
              ChoiceChip(label: const Text('Todas'), selected: category == 0, onSelected: (_) => setState(() => category = 0)),
              ChoiceChip(label: const Text('Recientes'), selected: category == 1, onSelected: (_) => setState(() => category = 1)),
              const SizedBox(width: 4),
              ChoiceChip(label: const Text('Todos los grupos'), selected: groupId == null, onSelected: (_) => setState(() => groupId = null)),
              for (final g in s.groups)
                ChoiceChip(label: Text(g.name), selected: groupId == g.id, onSelected: (_) => setState(() => groupId = g.id)),
            ]),
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerRight, child: Text('${list.length} canciones', style: const TextStyle(color: Colors.grey))),
            const SizedBox(height: 8),
            Expanded(
              child: list.isEmpty
                  ? const Center(child: Text('No hay canciones. Crea una o importa tus PDF.'))
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