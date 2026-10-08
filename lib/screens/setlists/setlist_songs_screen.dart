import 'package:flutter/material.dart';

import '../../data/format.dart';
import '../../data/store.dart';
import '../../models/app_state.dart';
import '../../models/setlist.dart';
import '../../models/song.dart';
import '../../services/setlist_export.dart';
import '../../theme.dart';
import '../song/song_screen.dart';
import 'setlists_screen.dart' show SetlistDetailScreen;

class SetlistSongsScreen extends StatelessWidget {
  final Store store;
  final String setlistId;
  const SetlistSongsScreen({super.key, required this.store, required this.setlistId});

  Setlist? _list(Store store) => store.state.setlists.where((l) => l.id == setlistId).firstOrNull;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final l = _list(store);
        if (l == null) return Scaffold(appBar: AppBar(), body: const Center(child: Text('Setlist no encontrado')));
        final ready = l.readyIds.where(l.songIds.contains).length;
        final total = l.songIds.length;
        return Scaffold(
          appBar: AppBar(
            title: Text(l.name, overflow: TextOverflow.ellipsis),
            actions: [
              IconButton(
                icon: const Icon(Icons.picture_as_pdf),
                tooltip: 'Exportar setlist en PDF',
                onPressed: () => shareSetlistPdf(context, l, store.state.songs),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SetlistDetailScreen(store: store, setlistId: l.id))),
              ),
            ],
          ),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            Row(children: [
              Expanded(
                child: Text(
                  [
                    formatLongDate(l.date),
                    if (l.venue.isNotEmpty) l.venue,
                    '${l.members.length} invitados',
                  ].join(' · '),
                  style: const TextStyle(color: Colors.grey),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: LinearProgressIndicator(
                    value: l.readyRatio,
                    minHeight: 8,
                    backgroundColor: Colors.grey.withValues(alpha: 0.2),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text('$ready / $total listos', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
            ]),
            const SizedBox(height: 12),
            if (l.songIds.isEmpty)
              const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('Este setlist aún no tiene canciones.')))
            else
              for (var i = 0; i < l.songIds.length; i++)
                Builder(builder: (context) {
                  final song = store.state.songs.where((x) => x.id == l.songIds[i]).firstOrNull;
                  if (song == null) return const SizedBox.shrink();
                  final isReady = l.readyIds.contains(song.id);
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isReady ? const Color(0xFF2E7D32).withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.15),
                        foregroundColor: isReady ? const Color(0xFF4CAF50) : Colors.grey,
                        child: Text(song.key, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                      title: Text('${i + 1}. ${song.title}'),
                      subtitle: Text('Tono ${song.key}${song.bpm != null ? " · ${song.bpm} BPM" : ""}'),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SongScreen(store: store, songId: song.id, setlistId: l.id))),
                      trailing: Wrap(spacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                        TextButton.icon(
                          onPressed: () => toggleReady(l, song),
                          icon: Icon(isReady ? Icons.check_circle : Icons.radio_button_unchecked, size: 18, color: isReady ? const Color(0xFF4CAF50) : Colors.grey),
                          label: Text(isReady ? 'Lista' : 'En progreso', style: TextStyle(fontSize: 12, color: isReady ? const Color(0xFF4CAF50) : Colors.grey)),
                        ),
                        const Icon(Icons.chevron_right),
                      ]),
                    ),
                  );
                }),
          ]),
        );
      },
    );
  }

  void toggleReady(Setlist l, Song song) {
    store.update((s) {
      final setlists = s.setlists.map((x) {
        if (x.id != l.id) return x;
        final ready = x.readyIds.contains(song.id);
        return x.copyWith(readyIds: ready ? x.readyIds.where((id) => id != song.id).toList() : [...x.readyIds, song.id]);
      }).toList();
      return AppState(groups: s.groups, songs: s.songs, setlists: setlists);
    });
  }
}