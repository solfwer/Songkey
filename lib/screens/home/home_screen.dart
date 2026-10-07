import 'package:flutter/material.dart';

import '../../data/store.dart';
import '../../theme.dart';
import 'library_screen.dart';

class HomeScreen extends StatelessWidget {
  final Store store;
  const HomeScreen({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final s = store.state;
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) => ListView(padding: const EdgeInsets.all(16), children: [
        Text('Hola 🎵', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text('Bienvenido a Songkey', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 20),
        Wrap(spacing: 12, runSpacing: 12, children: [
          _stat('Canciones', '${s.songs.length}', Icons.music_note),
          _stat('Grupos', '${s.groups.length}', Icons.groups),
          _stat('Setlists', '${s.setlists.length}', Icons.queue_music),
        ]),
        const SizedBox(height: 20),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(children: [
              Icon(Icons.bolt, color: AppColors.primary, size: 32),
              SizedBox(width: 12),
              Expanded(child: Text('Crea una nueva canción, arma un setlist o importa desde PDF.')),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        ListTile(leading: const Icon(Icons.play_arrow), title: const Text('Ir a la biblioteca'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => LibraryScreen(store: store)))),
      ]),
    );
  }

  Widget _stat(String label, String value, IconData icon) => SizedBox(
        width: 110,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              Text(label, style: const TextStyle(color: Colors.grey)),
            ]),
          ),
        ),
      );
}