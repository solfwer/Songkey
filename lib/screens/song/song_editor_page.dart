// Editor de canción: pestaña de texto ChordPro con reordenamiento de
// secciones e importación desde PDF, y pestaña del editor visual.
import 'package:flutter/material.dart';

import '../../data/chord_parser.dart';
import '../../data/store.dart';
import '../../models/app_state.dart';
import '../../models/song.dart';
import 'widgets/pdf_import_button.dart';
import 'widgets/visual_chord_editor.dart';

class SongEditorPage extends StatefulWidget {
  final Store store;
  final Song? song;
  final String? initialGroupId;
  const SongEditorPage({super.key, required this.store, this.song, this.initialGroupId});

  @override
  State<SongEditorPage> createState() => _SongEditorPageState();
}

class _SongEditorPageState extends State<SongEditorPage> with SingleTickerProviderStateMixin {
  late final TextEditingController title;
  late final TextEditingController key;
  late final TextEditingController bpm;
  late final TextEditingController body;
  String? groupId;
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    title = TextEditingController(text: widget.song?.title ?? '');
    key = TextEditingController(text: widget.song?.key ?? 'C');
    bpm = TextEditingController(text: widget.song?.bpm?.toString() ?? '');
    body = TextEditingController(text: widget.song?.body ?? '');
    groupId = widget.song?.groupId ?? widget.initialGroupId;
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(_syncTabs);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  void _syncTabs() {
    if (!_tabCtrl.indexIsChanging) {
      // Al cambiar de pestaña, sincronizar el cuerpo
      if (_tabCtrl.index == 1) {
        // Texto -> Visual: body ya tiene el texto actual
      } else {
        // Visual -> Texto: el VisualChordEditor ya llama onChanged
      }
    }
  }

  void _onVisualChanged(String newBody) {
    body.text = newBody;
  }

  @override
  Widget build(BuildContext context) {
    final groups = widget.store.state.groups;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.song == null ? 'Nueva canción' : 'Editar canción'),
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(icon: Icon(Icons.code), text: 'Texto (ChordPro)'),
            Tab(icon: Icon(Icons.touch_app), text: 'Editor visual'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          // Pestaña 1: Editor de texto clásico
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TextField(controller: title, decoration: const InputDecoration(labelText: 'Título')),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextField(controller: key, decoration: const InputDecoration(labelText: 'Tono'))),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: bpm, decoration: InputDecoration(labelText: 'BPM', suffixIcon: _TapTempoIcon(controller: bpm)), keyboardType: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(child: DropdownButtonFormField<String?>(initialValue: groupId, isExpanded: true, decoration: const InputDecoration(labelText: 'Grupo'), items: [null, ...groups.map((g) => g.id)].map((id) => DropdownMenuItem(value: id, child: Text(id == null ? 'Sin grupo' : groups.firstWhere((g) => g.id == id).name, overflow: TextOverflow.ellipsis))).toList(), onChanged: (v) => setState(() => groupId = v))),
              ]),
              const SizedBox(height: 12),
              TextField(controller: body, decoration: const InputDecoration(labelText: 'Letra con acordes', alignLabelWithHint: true), maxLines: 18, style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
              const SizedBox(height: 12),
              const Text('Secciones: toca los iconos para reordenar, repetir, renombrar o eliminar cada parte.', style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 8),
              _SectionsManager(controller: body, store: widget.store),
              const SizedBox(height: 12),
              PdfImportButton(titleController: title, bodyController: body, onImported: () => setState(() {})),
              const SizedBox(height: 12),
              FilledButton(onPressed: save, child: const Text('Guardar')),
            ]),
          ),
          // Pestaña 2: Editor visual
          Column(
            children: [
              // Cabecera común (título, tono, BPM, grupo) - compacta
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  TextField(controller: title, decoration: const InputDecoration(labelText: 'Título', isDense: true)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: TextField(controller: key, decoration: const InputDecoration(labelText: 'Tono', isDense: true))),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: bpm, decoration: InputDecoration(labelText: 'BPM', isDense: true, suffixIcon: _TapTempoIcon(controller: bpm)), keyboardType: TextInputType.number)),
                    const SizedBox(width: 8),
                    Expanded(child: DropdownButtonFormField<String?>(initialValue: groupId, isExpanded: true, decoration: const InputDecoration(labelText: 'Grupo', isDense: true), items: [null, ...groups.map((g) => g.id)].map((id) => DropdownMenuItem(value: id, child: Text(id == null ? 'Sin grupo' : groups.firstWhere((g) => g.id == id).name, overflow: TextOverflow.ellipsis))).toList(), onChanged: (v) => setState(() => groupId = v))),
                  ]),
                ]),
              ),
              const Divider(height: 1),
              Expanded(
                child: VisualChordEditor(
                  initialBody: body.text,
                  songKey: key.text,
                  onChanged: _onVisualChanged,
                ),
              ),
              // Botón guardar fijo abajo
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: FilledButton(onPressed: save, child: const Text('Guardar')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void save() {
    if (title.text.trim().isEmpty) return;
    final id = widget.song?.id ?? uid();
    final song = Song(id: id, title: title.text.trim(), key: key.text.trim().isEmpty ? 'C' : key.text.trim(), bpm: int.tryParse(bpm.text), groupId: groupId, body: body.text);
    widget.store.update((s) {
      final songs = s.songs.any((x) => x.id == id) ? s.songs.map((x) => x.id == id ? song : x).toList() : [song, ...s.songs];
      return AppState(groups: s.groups, songs: songs, setlists: s.setlists);
    });
    Navigator.of(context).pop();
  }
}

class _SectionsManager extends StatefulWidget {
  final TextEditingController controller;
  final Store store;
  const _SectionsManager({required this.controller, required this.store});

  @override
  State<_SectionsManager> createState() => _SectionsManagerState();
}

class _SectionsManagerState extends State<_SectionsManager> {
  late List<_Block> blocks;

  @override
  void initState() {
    super.initState();
    blocks = _parseBlocks(widget.controller.text);
  }

  @override
  void didUpdateWidget(covariant _SectionsManager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller.text != oldWidget.controller.text) {
      setState(() => blocks = _parseBlocks(widget.controller.text));
    }
  }

  void _rebuildBody() {
    widget.controller.text = blocks.map((b) => b.toString()).join('\n');
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Estructura de la canción', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          if (blocks.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Sin secciones detectadas. Escribe "Verso 1", "Coro", etc. en el editor.',
                  style: TextStyle(color: Colors.grey)),
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: blocks.length,
              onReorderItem: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex--;
                  final item = blocks.removeAt(oldIndex);
                  blocks.insert(newIndex, item);
                  _rebuildBody();
                });
              },
              itemBuilder: (context, index) {
                final b = blocks[index];
                return Card(
                  key: ValueKey(b.id),
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: ListTile(
                    leading: ReorderableDragStartListener(
                      index: index,
                      child: const Icon(Icons.drag_handle, color: Colors.grey),
                    ),
                    title: Text(b.header, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${b.lines.length} líneas'),
                    trailing: Wrap(spacing: 4, children: [
                      IconButton(
                        tooltip: 'Repetir (duplicar)',
                        icon: const Icon(Icons.content_copy),
                        onPressed: () => setState(() {
                          blocks.insert(index + 1, b.copy());
                          _rebuildBody();
                        }),
                      ),
                      IconButton(
                        tooltip: 'Renombrar',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _rename(b),
                      ),
                      IconButton(
                        tooltip: 'Eliminar',
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        onPressed: () => setState(() {
                          blocks.removeAt(index);
                          _rebuildBody();
                        }),
                      ),
                    ]),
                    onTap: () => _editLines(b),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  void _rename(_Block b) {
    final c = TextEditingController(text: b.header);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Renombrar sección'),
        content: TextField(controller: c, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: () { setState(() { b.header = c.text.trim(); _rebuildBody(); }); Navigator.pop(context); }, child: const Text('OK')),
        ],
      ),
    );
  }

  void _editLines(_Block b) {
    final c = TextEditingController(text: b.body);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Editar: ${b.header}'),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: c,
            maxLines: 12,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            decoration: const InputDecoration(hintText: 'Letra y acordes…'),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: () { setState(() { b.body = c.text.trim(); _rebuildBody(); }); Navigator.pop(context); }, child: const Text('Guardar')),
        ],
      ),
    );
  }
}

class _Block {
  final String id;
  String header;
  String body;
  _Block({required this.id, required this.header, required this.body});
  _Block copy() => _Block(id: uid(), header: header, body: body);

  List<String> get lines => body.split('\n').where((l) => l.trim().isNotEmpty).toList();

  @override
  String toString() => '$header\n$body';
}

List<_Block> _parseBlocks(String text) {
  final lines = text.replaceAll('\r', '').split('\n');
  final blocks = <_Block>[];
  _Block? cur;
  for (final line in lines) {
    if (isSectionHeader(line)) {
      if (cur != null) blocks.add(cur);
      cur = _Block(id: uid(), header: line.trim(), body: '');
    } else if (cur != null) {
      cur.body = '${cur.body.isEmpty ? '' : '\n'}$line';
    } else if (line.trim().isNotEmpty) {
      // Líneas antes del primer encabezado -> crear bloque "Intro"
      if (blocks.isEmpty || blocks.last.header != 'Intro') {
        cur = _Block(id: uid(), header: 'Intro', body: line);
      } else {
        cur!.body = '${cur.body}\n$line';
      }
    }
  }
  if (cur != null) blocks.add(cur);
  return blocks;
}

/// Botón de "tap tempo": toca al ritmo de la canción y calcula el BPM promedio.
/// Funciona sin internet. Tras 3 s sin tocar, reinicia la medición.
class _TapTempoIcon extends StatefulWidget {
  final TextEditingController controller;
  const _TapTempoIcon({required this.controller});
  @override
  State<_TapTempoIcon> createState() => _TapTempoIconState();
}

class _TapTempoIconState extends State<_TapTempoIcon> {
  final List<DateTime> _taps = [];

  void _tap() {
    final now = DateTime.now();
    if (_taps.isNotEmpty && now.difference(_taps.last).inMilliseconds > 3000) _taps.clear();
    _taps.add(now);
    if (_taps.length > 8) _taps.removeAt(0);
    if (_taps.length >= 2) {
      final intervals = <int>[];
      for (var i = 1; i < _taps.length; i++) {
        intervals.add(_taps[i].difference(_taps[i - 1]).inMilliseconds);
      }
      final avg = intervals.reduce((a, b) => a + b) / intervals.length;
      widget.controller.text = (60000 / avg).round().toString();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: 'Tap tempo: toca al ritmo (reinicia tras 3 s)',
        icon: const Icon(Icons.touch_app),
        onPressed: _tap,
      );
}