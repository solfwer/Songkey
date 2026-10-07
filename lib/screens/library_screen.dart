import 'package:flutter/material.dart';

import '../songs.dart';
import '../store.dart';
import '../theme.dart';
import 'song_screen.dart';

class LibraryScreen extends StatefulWidget {
  final Store store;
  const LibraryScreen({super.key, required this.store});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  String q = '';
  String? groupId;

  Color sectionColor(SectionKind k) {
    switch (k) {
      case SectionKind.verse: return AppColors.primary;
      case SectionKind.chorus: return AppColors.warm;
      case SectionKind.prechorus: return AppColors.accent;
      case SectionKind.bridge: return AppColors.bridge;
      default: return AppColors.accent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.store.state;
    final list = s.songs
        .where((x) => (groupId == null || x.groupId == groupId) && x.title.toLowerCase().contains(q.toLowerCase()))
        .toList();
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) => Padding(
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
          Wrap(spacing: 8, children: [
            ChoiceChip(label: const Text('Todas'), selected: groupId == null, onSelected: (_) => setState(() => groupId = null)),
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
                      return ListTile(
                        leading: CircleAvatar(child: Text(song.key)),
                        title: Text(song.title),
                        subtitle: Text('${group ?? "Sin grupo"}${song.bpm != null ? " · ${song.bpm} BPM" : ""} · ${secs.map((x) => x.abbr).join(" · ")}'),
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SongScreen(store: widget.store, songId: song.id))),
                      );
                    },
                  ),
          ),
        ]),
      ),
    );
  }
}


