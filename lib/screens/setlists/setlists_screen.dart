import 'package:flutter/material.dart';

import '../../data/format.dart';
import '../../data/store.dart';
import '../../models/app_state.dart';
import '../../models/setlist.dart';
import '../../services/setlist_export.dart';
import '../song/song_screen.dart';
import 'setlist_songs_screen.dart';

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
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final s = widget.store.state;
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Row(children: [
              FilledButton.icon(onPressed: create, icon: const Icon(Icons.add), label: const Text('Nuevo setlist')),
            ]),
            const SizedBox(height: 12),
            Expanded(
              child: s.setlists.isEmpty
                  ? const Center(child: Text('Aún no hay setlists.'))
                  : ListView(children: [
                      for (final l in s.setlists)
                        _SetlistCard(setlist: l, store: widget.store),
                    ]),
            ),
          ]),
        );
      },
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
    if (!mounted) return;
    // Abrir el detalle para rellenar fecha/lugar y canciones.
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => SetlistDetailScreen(store: widget.store, setlistId: id)));
  }
}

/// Tarjeta de setlist con fecha, lugar y barra de preparación.
class _SetlistCard extends StatelessWidget {
  final Setlist setlist;
  final Store store;
  const _SetlistCard({required this.setlist, required this.store});

  @override
  Widget build(BuildContext context) {
    final l = setlist;
    final s = store.state;
    final ready = l.readyIds.where(l.songIds.contains).length;
    final total = l.songIds.length;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        ListTile(
          title: Text(l.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(
            [
              formatShortDate(l.date),
              if (l.venue.isNotEmpty) l.venue,
              '$total temas',
              if (total > 0) '$ready listos',
            ].join(' · '),
          ),
          isThreeLine: total > 0,
          trailing: Wrap(spacing: 0, crossAxisAlignment: WrapCrossAlignment.center, children: [
            IconButton(icon: const Icon(Icons.picture_as_pdf), tooltip: 'Exportar PDF', onPressed: () => shareSetlistPdf(context, l, s.songs)),
            IconButton(icon: const Icon(Icons.edit), onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SetlistDetailScreen(store: store, setlistId: l.id)))),
            const Icon(Icons.chevron_right),
          ]),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SetlistSongsScreen(store: store, setlistId: l.id))),
        ),
        if (total > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(value: l.readyRatio, minHeight: 6, backgroundColor: Colors.grey.withValues(alpha: 0.2)),
            ),
          ),
      ]),
    );
  }
}

class _Editor extends StatefulWidget {
  final Store store;
  final Setlist list;
  final TextEditingController mName;
  final TextEditingController mRole;
  final VoidCallback onChanged;
  const _Editor({required this.store, required this.list, required this.mName, required this.mRole, required this.onChanged});

  @override
  State<_Editor> createState() => _EditorState();
}

class _EditorState extends State<_Editor> {
  final _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  void update(Setlist Function(Setlist l) fn) {
    widget.store.update((s) {
      final setlists = s.setlists.map((l) => l.id == widget.list.id ? fn(l) : l).toList();
      return AppState(groups: s.groups, songs: s.songs, setlists: setlists);
    });
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.store.state;
    final q = _q.text.trim().toLowerCase();
    final candidates = s.songs
        .where((x) => !widget.list.songIds.contains(x.id) && x.title.toLowerCase().contains(q))
        .take(8)
        .toList();
    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextFormField(
          key: ValueKey(widget.list.id + widget.list.name),
          initialValue: widget.list.name,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          decoration: const InputDecoration(border: InputBorder.none, isDense: true),
          onChanged: (v) => update((l) => l.copyWith(name: v)),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
          DropdownButton<String?>(
            value: widget.list.groupId,
            hint: const Text('Sin grupo'),
            items: [null, ...s.groups.map((g) => g.id)].map((id) => DropdownMenuItem(value: id, child: Text(id == null ? 'Sin grupo' : s.groups.firstWhere((g) => g.id == id).name))).toList(),
            onChanged: (v) => update((l) => l.copyWith(groupId: v)),
          ),
          TextButton.icon(
            icon: const Icon(Icons.calendar_month, size: 18),
            label: Text(formatShortDate(widget.list.date)),
            onPressed: () => _pickDate(context),
          ),
          TextButton(
            onPressed: () async {
              final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('Eliminar setlist'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar'))]));
              if (ok == true) widget.store.update((st) => AppState(groups: st.groups, songs: st.songs, setlists: st.setlists.where((l) => l.id != widget.list.id).toList()));
            },
            child: const Text('Eliminar setlist', style: TextStyle(color: Colors.redAccent)),
          ),
        ]),
        const SizedBox(height: 8),
        TextFormField(
          key: ValueKey(widget.list.id + widget.list.venue),
          initialValue: widget.list.venue,
          decoration: const InputDecoration(labelText: 'Lugar / ocasión', isDense: true),
          onChanged: (v) => update((l) => l.copyWith(venue: v)),
        ),
        const SizedBox(height: 12),
        if (widget.list.songIds.isEmpty)
          const Text('Sin canciones todavía. Búscalas con el campo de abajo.', style: TextStyle(color: Colors.grey))
        else ...[
          const Text('Arrastra el icono = para cambiar el orden.', style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 4),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.list.songIds.length,
            onReorderItem: (oldIndex, newIndex) => move(oldIndex, newIndex),
            itemBuilder: (context, index) {
              final id = widget.list.songIds[index];
              final song = s.songs.where((x) => x.id == id).firstOrNull;
              if (song == null) return const SizedBox.shrink();
              final ready = widget.list.readyIds.contains(song.id);
              return Card(
                key: ValueKey(song.id),
                child: ListTile(
                  leading: Row(mainAxisSize: MainAxisSize.min, children: [
                    ReorderableDragStartListener(
                      index: index,
                      child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.drag_indicator, color: Colors.grey)),
                    ),
                    Text('${index + 1}.'.padLeft(3, '0'), style: const TextStyle(color: Colors.deepPurpleAccent)),
                  ]),
                  title: Text(song.title),
                  subtitle: Text('Tono ${song.key}'),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SongScreen(store: widget.store, songId: song.id, setlistId: widget.list.id))),
                  trailing: Wrap(spacing: 0, children: [
                    Checkbox(
                      value: ready,
                      onChanged: (_) => update((l) => l.copyWith(readyIds: l.readyIds.contains(song.id) ? l.readyIds.where((x) => x != song.id).toList() : [...l.readyIds, song.id])),
                    ),
                    IconButton(icon: const Icon(Icons.close), tooltip: 'Quitar del setlist', onPressed: () => update((l) => l.copyWith(songIds: l.songIds.asMap().entries.where((e) => e.key != index).map((e) => e.value).toList(), readyIds: l.readyIds.where((x) => x != song.id).toList()))),
                  ]),
                ),
              );
            },
          ),
        ],
        const SizedBox(height: 12),
        TextField(
          controller: _q,
          decoration: const InputDecoration(labelText: 'Buscar canción para añadir', prefixIcon: Icon(Icons.search), isDense: true),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 4),
        if (q.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text('Escribe el nombre de una canción de tu biblioteca para añadirla al setlist.', style: TextStyle(color: Colors.grey, fontSize: 12)),
          )
        else if (candidates.isEmpty)
          const Padding(padding: EdgeInsets.all(8), child: Text('Sin coincidencias', style: TextStyle(color: Colors.grey)))
        else
          for (final c in candidates)
            ListTile(
              dense: true,
              leading: const Icon(Icons.playlist_add),
              title: Text(c.title, overflow: TextOverflow.ellipsis),
              subtitle: Text('Tono ${c.key}'),
              trailing: const Icon(Icons.add_circle_outline, size: 20),
              onTap: () => update((l) => l.copyWith(songIds: [...l.songIds, c.id])),
            ),
        const Divider(),
        const Text('Banda invitada', style: TextStyle(letterSpacing: 2, color: Colors.grey)),
        for (final m in widget.list.members)
          ListTile(
            leading: CircleAvatar(child: Text(m.name.isEmpty ? '?' : m.name.substring(0, 1).toUpperCase())),
            title: Text('${m.name} · ${m.role}'),
            trailing: Wrap(spacing: 0, children: [
              TextButton(onPressed: () => update((l) => l.copyWith(members: l.members.map((x) => x.id == m.id ? Member(id: x.id, name: x.name, role: x.role, status: x.status == 'confirmado' ? 'pendiente' : 'confirmado') : x).toList())), child: Text(m.status, style: TextStyle(color: m.status == 'confirmado' ? Colors.green : Colors.orange))),
              IconButton(icon: const Icon(Icons.close), onPressed: () => update((l) => l.copyWith(members: l.members.where((x) => x.id != m.id).toList()))),
            ]),
          ),
        Row(children: [
          Expanded(child: TextField(controller: widget.mName, decoration: const InputDecoration(hintText: 'Nombre'), onSubmitted: (_) => invite())),
        ]),
        Row(children: [
          Expanded(child: TextField(controller: widget.mRole, decoration: const InputDecoration(hintText: 'Rol (voz, guitarra…)'), onSubmitted: (_) => invite())),
          IconButton(icon: const Icon(Icons.add), onPressed: invite),
        ]),
      ]),
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final parsed = DateTime.tryParse(widget.list.date);
    final picked = await showDatePicker(
      context: context,
      initialDate: parsed ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) update((l) => l.copyWith(date: picked.toIso8601String().substring(0, 10)));
  }

  /// Reordenar canciones arrastrando: [oldIndex] era la posición salida y
  /// [newIndex] la de destino (ya ajustada por ReorderableListView).
  void move(int oldIndex, int newIndex) {
    update((l) {
      final ids = [...l.songIds];
      final item = ids.removeAt(oldIndex);
      ids.insert(newIndex, item);
      return l.copyWith(songIds: ids);
    });
  }

  void invite() {
    if (widget.mName.text.trim().isEmpty) return;
    update((l) => l.copyWith(members: [...l.members, Member(id: uid(), name: widget.mName.text.trim(), role: widget.mRole.text.trim().isEmpty ? 'músico' : widget.mRole.text.trim())]));
    widget.mName.clear();
    widget.mRole.clear();
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
      appBar: AppBar(
        title: Text(l.name, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Exportar setlist en PDF',
            onPressed: () => shareSetlistPdf(context, l, widget.store.state.songs),
          ),
        ],
      ),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: _Editor(store: widget.store, list: l, mName: mName, mRole: mRole, onChanged: () => setState(() {}))),
    );
  }
}