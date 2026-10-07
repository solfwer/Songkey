import 'package:flutter/material.dart';

import '../../data/store.dart';
import '../../models/app_state.dart';
import '../../models/setlist.dart';
import '../../models/song.dart';
import '../../theme.dart';

const _roles = ['Vocalista', 'Coros', 'Guitarra', 'Bajo', 'Batería', 'Teclados', 'Violín', 'Trompeta', 'Producción'];

class GroupsScreen extends StatefulWidget {
  final Store store;
  const GroupsScreen({super.key, required this.store});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  final colors = [GroupColor.primary, GroupColor.accent, GroupColor.warm, GroupColor.bridge];

  Color dot(GroupColor c) {
    switch (c) {
      case GroupColor.primary: return AppColors.primary;
      case GroupColor.accent: return AppColors.accent;
      case GroupColor.warm: return AppColors.warm;
      case GroupColor.bridge: return AppColors.bridge;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.store.state;
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: FilledButton.icon(onPressed: add, icon: const Icon(Icons.add), label: const Text('Nuevo grupo'))),
          ]),
          const SizedBox(height: 16),
          Expanded(
            child: s.groups.isEmpty
                ? const Center(child: Text('Aún no hay grupos. Crea uno arriba.'))
                : ListView.separated(
                    itemCount: s.groups.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final g = s.groups[i];
                      final songCount = s.songs.where((x) => x.groupId == g.id).length;
                      return Card(
                        child: ListTile(
                          leading: Container(width: 14, height: 14, decoration: BoxDecoration(color: dot(g.color), shape: BoxShape.circle)),
                          title: Text(g.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('$songCount canciones · ${g.members.length} integrantes'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => GroupDetailScreen(store: widget.store, groupId: g.id))),
                        ),
                      );
                    },
                  ),
          ),
        ]),
      ),
    );
  }

  void add() async {
    final nameCtrl = TextEditingController();
    final ownerCtrl = TextEditingController(text: widget.store.profileName);
    final res = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nuevo grupo'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nombre del grupo'), autofocus: true),
          TextField(controller: ownerCtrl, decoration: const InputDecoration(labelText: 'Quien crea (tu nombre)')),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Crear'))],
      ),
    );
    if (res != true) return;
    final name = nameCtrl.text.trim();
    if (name.isEmpty) return;
    widget.store.update((s) {
      final groups = [...s.groups, Group(id: uid(), name: name, color: colors[s.groups.length % 4], owner: ownerCtrl.text.trim().isEmpty ? null : ownerCtrl.text.trim())];
      return AppState(groups: groups, songs: s.songs, setlists: s.setlists);
    });
  }
}

class GroupDetailScreen extends StatefulWidget {
  final Store store;
  final String groupId;
  const GroupDetailScreen({super.key, required this.store, required this.groupId});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  final nameCtrl = TextEditingController();
  String role = _roles.first;

  Group? get group => widget.store.state.groups.where((g) => g.id == widget.groupId).firstOrNull;

  void updateGroup(Group Function(Group g) fn) {
    widget.store.update((s) {
      final groups = s.groups.map((g) => g.id == widget.groupId ? fn(g) : g).toList();
      return AppState(groups: groups, songs: s.songs, setlists: s.setlists);
    });
  }

  @override
  Widget build(BuildContext context) {
    final g = group;
    if (g == null) return Scaffold(appBar: AppBar(), body: const Center(child: Text('Grupo no encontrado')));
    return Scaffold(
      appBar: AppBar(title: Text(g.name), actions: [
        IconButton(icon: const Icon(Icons.delete), onPressed: () async {
          final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: Text('¿Eliminar “${g.name}”? Las canciones se conservan.'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar'))]));
          if (ok == true) {
            widget.store.update((st) => AppState(groups: st.groups.where((x) => x.id != g.id).toList(), songs: st.songs.map((x) => x.groupId == g.id ? Song(id: x.id, title: x.title, author: x.author, key: x.key, bpm: x.bpm, groupId: null, body: x.body) : x).toList(), setlists: st.setlists.map((l) => l.groupId == g.id ? Setlist(id: l.id, name: l.name, date: l.date, groupId: null, songIds: l.songIds, members: l.members) : l).toList()));
            if (mounted) Navigator.of(context).pop();
          }
        }),
      ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (g.owner != null) ...[
          Card(child: ListTile(leading: const Icon(Icons.person, color: AppColors.primary), title: Text('Creado por ${g.owner}'))),
          const SizedBox(height: 12),
        ],
        const Text('Integrantes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        for (final m in g.members)
          ListTile(
            leading: CircleAvatar(child: Text(m.name.isEmpty ? '?' : m.name[0].toUpperCase())),
            title: Text(m.name),
            subtitle: Text(m.role),
            trailing: IconButton(icon: const Icon(Icons.close), onPressed: () => updateGroup((g) => Group(id: g.id, name: g.name, color: g.color, members: g.members.where((x) => x.id != m.id).toList(), owner: g.owner))),
          ),
        Row(children: [
          Expanded(flex: 2, child: TextField(controller: nameCtrl, decoration: const InputDecoration(hintText: 'Nombre'))),
          const SizedBox(width: 8),
          Expanded(flex: 2, child: DropdownButtonFormField<String>(initialValue: role, items: _roles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(), onChanged: (v) => setState(() => role = v ?? role), decoration: const InputDecoration(labelText: 'Rol'))),
          IconButton(icon: const Icon(Icons.add), onPressed: () {
            if (nameCtrl.text.trim().isEmpty) return;
            updateGroup((g) => Group(id: g.id, name: g.name, color: g.color, members: [...g.members, Member(id: uid(), name: nameCtrl.text.trim(), role: role)], owner: g.owner));
            nameCtrl.clear();
          }),
        ]),
        const Divider(height: 32),
      ]),
    );
  }
}