import 'package:flutter/material.dart';

import '../../data/format.dart';
import '../../data/store.dart';
import '../../models/setlist.dart';
import '../../models/song.dart';
import '../../theme.dart';
import '../song/song_screen.dart';
import '../setlists/setlist_songs_screen.dart';

class HomeScreen extends StatelessWidget {
  final Store store;
  const HomeScreen({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final s = store.state;
        final nextGig = _nextGig(s.setlists);
        final recientes = s.songs.where((x) => x.lastOpenedAt != null).toList()
          ..sort((a, b) => (b.lastOpenedAt!).compareTo(a.lastOpenedAt!));
        final name = store.profileName.trim();
        return ListView(padding: const EdgeInsets.all(16), children: [
          Text(name.isEmpty ? 'Hola 🎵' : 'Hola, $name 👋', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Letras, acordes y setlists para tu banda', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 20),
          if (nextGig != null) _NextGigCard(setlist: nextGig, store: store),
          const SizedBox(height: 16),
          Wrap(spacing: 12, runSpacing: 12, children: [
            _stat('Canciones', '${s.songs.length}', Icons.music_note),
            _stat('Grupos', '${s.groups.length}', Icons.groups),
            _stat('Setlists', '${s.setlists.length}', Icons.queue_music),
          ]),
          if (recientes.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Recientes', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Card(
              child: Column(children: [
                for (final song in recientes.take(5)) _RecentTile(song: song, store: store),
              ]),
            ),
          ],
        ]);
      },
    );
  }

  /// El próximo setlist con fecha futura (o el más reciente si no hay futuros).
  Setlist? _nextGig(List<Setlist> setlists) {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final upcoming = setlists.where((l) => l.date.compareTo(today) >= 0).toList()..sort((a, b) => a.date.compareTo(b.date));
    if (upcoming.isNotEmpty) return upcoming.first;
    if (setlists.isEmpty) return null;
    final past = setlists.toList()..sort((a, b) => b.date.compareTo(a.date));
    return past.first;
  }

  Widget _stat(String label, String value, IconData icon) => SizedBox(
        width: 104,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              Text(label, style: const TextStyle(color: Colors.grey)),
            ]),
          ),
        ),
      );
}

/// Tarjeta destacada con la próxima tocada/ensayo y su progreso de preparación.
class _NextGigCard extends StatelessWidget {
  final Setlist setlist;
  final Store store;
  const _NextGigCard({required this.setlist, required this.store});

  @override
  Widget build(BuildContext context) {
    final group = store.state.groups.where((g) => g.id == setlist.groupId).map((g) => g.name).firstOrNull;
    final ready = setlist.readyIds.where(setlist.songIds.contains).length;
    final total = setlist.songIds.length;
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SetlistSongsScreen(store: store, setlistId: setlist.id))),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primary.withValues(alpha: 0.9), AppColors.card],
            ),
          ),
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.event, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('PRÓXIMA TOCADA', style: TextStyle(fontSize: 11, letterSpacing: 1.5, color: Colors.white.withValues(alpha: 0.7), fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text('${setlist.name}${setlist.venue.isNotEmpty ? ' · ${setlist.venue}' : ''}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                ]),
              ),
            ]),
            const SizedBox(height: 12),
            Text('${formatLongDate(setlist.date)}${group != null ? ' · $group' : ''}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: total == 0 ? 0 : ready / total,
                    minHeight: 8,
                    backgroundColor: Colors.white.withValues(alpha: 0.15),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text('$ready / $total temas listos', style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _RecentTile extends StatelessWidget {
  final Song song;
  final Store store;
  const _RecentTile({required this.song, required this.store});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: const Icon(Icons.music_note, color: AppColors.accent),
      title: Text(song.title, maxLines: 3, overflow: TextOverflow.visible),
      subtitle: Text([song.key, if (song.bpm != null) '${song.bpm} BPM'].join(' · ')),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SongScreen(store: store, songId: song.id))),
    );
  }
}