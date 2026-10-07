import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import 'setlist_songs_screen.dart';
import 'song_screen.dart';

class SetlistsScreen extends StatefulWidget {
  final Store store;
  const SetlistsScreen({super.key, required this.store});

  @override
  State<SetlistsScreen> createState() => _SetlistsScreenState();
}

class _SetlistsScreenState extends State<SetlistsScreen> {
  String? currentId;
  final mName = TextEditingController();
  final mRole = TextEditingController();

  Setlist? get current {
    final s = widget.store.state;
    return s.setlists.where((l) => l.id == currentId).firstOrNull ?? (s.setlists.isEmpty ? null : s.setlists.first);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.store.state;
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Row(children: [
            FilledButton.icon(onPressed: create, icon: const Icon(Icons.add), label: const Text('Nuevo setlist')),
          ]),
          const SizedBox(height: 12),
          Expanded(
            child: s.setlists.isEmpty
                ? const Center(child: Text('AÃºn no hay setlists.'))
                : ListView(children: [
                    for (final l in s.setlists)
                      Card(
                        child: ListTile(
                          title: Text(l.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('${l.date} Â· ${l.songIds.length} temas Â· ${l.members.length} invitados'),
                          trailing: Wrap(spacing: 0, crossAxisAlignment: WrapCrossAlignment.center, children: [
                            IconButton(icon: const Icon(Icons.edit), onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SetlistDetailScreen(store: widget.store, setlistId: l.id)))),
                            const Icon(Icons.chevron_right),
                          ]),
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SetlistSongsScreen(store: widget.store, setlistId: l.id))),
                        ),
                      ),
                  ]),
          ),
        ]),
      ),
    );
  }

  Future<void> create() async {
    final c = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nombre del setlist'),
        content: TextField(controller: c, autofocus: true, onSubmitted: (v) => Navigator.pop(context, v)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, c.text), child: const Text('Crear')),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty) return;
    final id = uid();
    widget.store.update((s) {
      final setlists = [...s.setlists, Setlist(id: id, name: name.trim(), date: DateTime.now().toIso8601String().substring(0, 10))];
      return AppState(groups: s.groups, songs: s.songs, setlists: setlists);
    });
    setState(() => currentId = id);
  }
}

class _Editor extends StatelessWidget {
  final Store store;
  final Setlist list;
  final TextEditingController mName;
  final TextEditingController mRole;
  final VoidCallback onChanged;
  const _Editor({required this.store, required this.list, required this.mName, required this.mRole, required this.onChanged});

  void update(Setlist Function(Setlist l) fn) {
    store.update((s) {
      final setlists = s.setlists.map((l) => l.id == list.id ? fn(l) : l).toList();
      return AppState(groups: s.groups, songs: s.songs, setlists: setlists);
    });
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final s = store.state;
    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextFormField(
          key: ValueKey(list.id + list.name),
          initialValue: list.name,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          decoration: const InputDecoration(border: InputBorder.none, isDense: true),
          onChanged: (v) => update((l) => Setlist(id: l.id, name: v, date: l.date, groupId: l.groupId, songIds: l.songIds, members: l.members)),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
          DropdownButton<String?>(
            value: list.groupId,
            hint: const Text('Sin grupo'),
            items: [null, ...s.groups.map((g) => g.id)].map((id) => DropdownMenuItem(value: id, child: Text(id == null ? 'Sin grupo' : s.groups.firstWhere((g) => g.id == id).name))).toList(),
            onChanged: (v) => update((l) => Setlist(id: l.id, name: l.name, date: l.date, groupId: v, songIds: l.songIds, members: l.members)),
          ),
          TextButton(
            onPressed: () async {
              final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('Eliminar setlist'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar'))]));
              if (ok == true) store.update((st) => AppState(groups: st.groups, songs: st.songs, setlists: st.setlists.where((l) => l.id != list.id).toList()));
            },
            child: const Text('Eliminar setlist', style: TextStyle(color: Colors.redAccent)),
          ),
        ]),
        const SizedBox(height: 8),
        for (var i = 0; i < list.songIds.length; i++)
          Builder(builder: (context) {
            final song = s.songs.where((x) => x.id == list.songIds[i]).firstOrNull;
            if (song == null) return const SizedBox.shrink();
            return Card(
              child: ListTile(
                leading: Text('${i + 1}.'.padLeft(3, '0'), style: const TextStyle(color: Colors.deepPurpleAccent)),
                title: Text(song.title),
                subtitle: Text('Tono ${song.key}'),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SongScreen(store: store, songId: song.id, setlistId: list.id))),
                trailing: Wrap(spacing: 0, children: [
                  IconButton(icon: const Icon(Icons.arrow_upward), onPressed: () => move(i, -1)),
                  IconButton(icon: const Icon(Icons.arrow_downward), onPressed: () => move(i, 1)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => update((l) => Setlist(id: l.id, name: l.name, date: l.date, groupId: l.groupId, songIds: l.songIds.asMap().entries.where((e) => e.key != i).map((e) => e.value).toList(), members: l.members))),
                ]),
              ),
            );
          }),
        const SizedBox(height: 8),
        DropdownButton<String>(
          hint: const Text('+ AÃ±adir canciÃ³nâ€¦'),
          value: null,
          items: s.songs.where((x) => !list.songIds.contains(x.id)).map((x) => DropdownMenuItem(value: x.id, child: Text('${x.title} (${x.key})'))).toList(),
          onChanged: (v) { if (v != null) update((l) => Setlist(id: l.id, name: l.name, date: l.date, groupId: l.groupId, songIds: [...l.songIds, v], members: l.members)); },
        ),
        const Divider(),
        const Text('Banda invitada', style: TextStyle(letterSpacing: 2, color: Colors.grey)),
        for (final m in list.members)
          ListTile(
            leading: CircleAvatar(child: Text(m.name.isEmpty ? '?' : m.name.substring(0, 1).toUpperCase())),
            title: Text('${m.name} Â· ${m.role}'),
            trailing: Wrap(spacing: 0, children: [
              TextButton(onPressed: () => update((l) => Setlist(id: l.id, name: l.name, date: l.date, groupId: l.groupId, songIds: l.songIds, members: l.members.map((x) => x.id == m.id ? Member(id: x.id, name: x.name, role: x.role, status: x.status == 'confirmado' ? 'pendiente' : 'confirmado') : x).toList())), child: Text(m.status, style: TextStyle(color: m.status == 'confirmado' ? Colors.green : Colors.orange))),
              IconButton(icon: const Icon(Icons.close), onPressed: () => update((l) => Setlist(id: l.id, name: l.name, date: l.date, groupId: l.groupId, songIds: l.songIds, members: l.members.where((x) => x.id != m.id).toList()))),
            ]),
          ),
        Row(children: [
          Expanded(child: TextField(controller: mName, decoration: const InputDecoration(hintText: 'Nombre'), onSubmitted: (_) => invite())),
        ]),
        Row(children: [
          Expanded(child: TextField(controller: mRole, decoration: const InputDecoration(hintText: 'Rol (voz, guitarraâ€¦)'), onSubmitted: (_) => invite())),
          IconButton(icon: const Icon(Icons.add), onPressed: invite),
        ]),
      ]),
    );
  }

  void move(int i, int d) {
    update((l) {
      final ids = [...l.songIds];
      final j = i + d;
      if (j < 0 || j >= ids.length) return l;
      final t = ids[i]; ids[i] = ids[j]; ids[j] = t;
      return Setlist(id: l.id, name: l.name, date: l.date, groupId: l.groupId, songIds: ids, members: l.members);
    });
  }

  void invite() {
    if (mName.text.trim().isEmpty) return;
    update((l) => Setlist(id: l.id, name: l.name, date: l.date, groupId: l.groupId, songIds: l.songIds, members: [...l.members, Member(id: uid(), name: mName.text.trim(), role: mRole.text.trim().isEmpty ? 'mÃºsico' : mRole.text.trim())]));
    mName.clear();
    mRole.clear();
  }
}


class SetlistDetailScreen extends StatefulWidget {
  final Store store;
  final String setlistId;
  const SetlistDetailScreen({super.key, required this.store, required this.setlistId});

  @override
  State<SetlistDetailScreen> createState() => _SetlistDetailScreenState();
}

class _SetlistDetailScreenState extends State<SetlistDetailScreen> {
  final mName = TextEditingController();
  final mRole = TextEditingController();

  Setlist? get list => widget.store.state.setlists.where((l) => l.id == widget.setlistId).firstOrNull;

  @override
  Widget build(BuildContext context) {
    final l = list;
    if (l == null) return Scaffold(appBar: AppBar(), body: const Center(child: Text('Setlist no encontrado')));
    return Scaffold(
      appBar: AppBar(title: Text(l.name, overflow: TextOverflow.ellipsis)),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: _Editor(store: widget.store, list: l, mName: mName, mRole: mRole, onChanged: () => setState(() {}))),
    );
  }
}

