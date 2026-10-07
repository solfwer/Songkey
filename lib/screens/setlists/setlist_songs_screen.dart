import 'package:flutter/material.dart';

import '../../data/store.dart';
import '../../models/setlist.dart';
import '../../services/setlist_export.dart';
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
            Text('${l.date} · ${l.members.length} invitados', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            if (l.songIds.isEmpty)
              const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('Este setlist aún no tiene canciones.')))
            else
              for (var i = 0; i < l.songIds.length; i++)
                Builder(builder: (context) {
                  final song = store.state.songs.where((x) => x.id == l.songIds[i]).firstOrNull;
                  if (song == null) return const SizedBox.shrink();
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(child: Text(song.key)),
                      title: Text('${i + 1}. ${song.title}'),
                      subtitle: Text('Tono ${song.key}${song.bpm != null ? " · ${song.bpm} BPM" : ""}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SongScreen(store: store, songId: song.id, setlistId: l.id))),
                    ),
                  );
                }),
          ]),
        );
      },
    );
  }
}