// Editor de canción: una sola pantalla por secciones. Cada sección es una
// tarjeta con su título editable (Verso, Coro, Puente…) y su letra/acordes
// editables debajo; puedes añadir secciones, arrastrar para reordenarlas,
// duplicarlas y eliminarlas. La estructura completa queda visible y editable
// a la vez. El botón de importar PDF rellena título y secciones automáticamente.
import 'package:flutter/material.dart';

import '../../data/chord_parser.dart';
import '../../data/format.dart';
import '../../data/store.dart';
import '../../models/app_state.dart';
import '../../models/song.dart';
import 'widgets/pdf_import_button.dart';
import 'widgets/song_view.dart' show sectionKindColor, sectionKindIcon;

class SongEditorPage extends StatefulWidget {
  final Store store;
  final Song? song;
  final String? initialGroupId;
  const SongEditorPage({super.key, required this.store, this.song, this.initialGroupId});

  @override
  State<SongEditorPage> createState() => _SongEditorPageState();
}

class _SongEditorPageState extends State<SongEditorPage> {
  late final TextEditingController title;
  late final TextEditingController key;
  late final TextEditingController bpm;
  late final TextEditingController style;
  late final TextEditingController duration;
  late final TextEditingController body;
  String? groupId;
  late List<_Block> blocks;

  @override
  void initState() {
    super.initState();
    title = TextEditingController(text: widget.song?.title ?? '');
    key = TextEditingController(text: widget.song?.key ?? 'C');
    bpm = TextEditingController(text: widget.song?.bpm?.toString() ?? '');
    style = TextEditingController(text: widget.song?.style ?? '');
    duration = TextEditingController(text: _durationLabel(widget.song?.durationSec));
    body = TextEditingController(text: widget.song?.body ?? '');
    groupId = widget.song?.groupId ?? widget.initialGroupId;
    blocks = _parseBlocks(body.text);
  }

  static String _durationLabel(int? sec) {
    if (sec == null || sec <= 0) return '';
    return '${sec ~/ 60}:${(sec % 60).toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    for (final c in [title, key, bpm, style, duration, body]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Recomponer el texto ChordPro completo desde las secciones (fuente de la
  /// verdad para guardar, exportar e importar PDF).
  void _syncBody() {
    body.text = blocks.map((b) => b.toString()).join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final groups = widget.store.state.groups;
    return Scaffold(
      appBar: AppBar(title: Text(widget.song == null ? 'Nueva canción' : 'Editar canción')),
      body: Column(children: [
        Expanded(
          child: ListView(padding: const EdgeInsets.all(16), children: [
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
            Row(children: [
              Expanded(child: TextField(controller: style, decoration: const InputDecoration(labelText: 'Estilo (opcional)'))),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: duration, decoration: const InputDecoration(labelText: 'Duración (3:45)'), keyboardType: TextInputType.text)),
            ]),
            const SizedBox(height: 20),
            Row(children: [
              const Text('Secciones', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              Text('${blocks.length}', style: const TextStyle(color: Colors.grey)),
            ]),
            const SizedBox(height: 4),
            const Text('Arrastra para reordenar · toca el título para renombrar', style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 8),
            if (blocks.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Aún no hay secciones. Pulsa "Añadir sección" o escribe encabezados como "Verso 1" / "Coro".', style: TextStyle(color: Colors.grey)),
                ),
              )
            else
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: blocks.length,
                onReorderItem: (oldIndex, newIndex) {
                  setState(() {
                    final item = blocks.removeAt(oldIndex);
                    blocks.insert(newIndex, item);
                    _syncBody();
                  });
                },
                itemBuilder: (context, index) {
                  final b = blocks[index];
                  return _SectionCard(
                    key: ValueKey(b.id),
                    block: b,
                    index: index,
                    onChanged: _syncBody,
                    onDuplicate: () => setState(() {
                      blocks.insert(index + 1, b.copy());
                      _syncBody();
                    }),
                    onDelete: () => setState(() {
                      blocks.removeAt(index);
                      _syncBody();
                    }),
                  );
                },
              ),
            const SizedBox(height: 12),
            OutlinedButton.icon(onPressed: _addSection, icon: const Icon(Icons.add), label: const Text('Añadir sección')),
            const SizedBox(height: 8),
            PdfImportButton(titleController: title, bodyController: body, onImported: () => setState(() => blocks = _parseBlocks(body.text))),
            const SizedBox(height: 8),
          ]),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(width: double.infinity, child: FilledButton(onPressed: save, child: const Text('Guardar'))),
          ),
        ),
      ]),
    );
  }

  Future<void> _addSection() async {
    final c = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nueva sección'),
        content: TextField(controller: c, autofocus: true, decoration: const InputDecoration(hintText: 'Verso 2, Coro, Puente…'), onSubmitted: (v) => Navigator.pop(context, v)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, c.text), child: const Text('Añadir')),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty) return;
    setState(() {
      blocks.add(_Block(id: uid(), header: name.trim(), body: ''));
      _syncBody();
    });
  }

  void save() {
    if (title.text.trim().isEmpty) return;
    _syncBody();
    final id = widget.song?.id ?? uid();
    final song = Song(
      id: id,
      title: title.text.trim(),
      key: key.text.trim().isEmpty ? 'C' : key.text.trim(),
      bpm: int.tryParse(bpm.text),
      groupId: groupId,
      body: body.text,
      style: style.text.trim().isEmpty ? null : style.text.trim(),
      durationSec: parseDuration(duration.text),
      lastOpenedAt: widget.song?.lastOpenedAt,
    );
    widget.store.update((s) {
      final songs = s.songs.any((x) => x.id == id) ? s.songs.map((x) => x.id == id ? song : x).toList() : [song, ...s.songs];
      return AppState(groups: s.groups, songs: songs, setlists: s.setlists);
    });
    Navigator.of(context).pop();
  }
}

/// Tarjeta de sección editable: título (arrastrable, renombrable) + texto con
/// acordes debajo. Mantiene su propio estado para no perder el cursor al teclear.
class _SectionCard extends StatefulWidget {
  final _Block block;
  final int index;
  final VoidCallback onChanged;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;
  const _SectionCard({super.key, required this.block, required this.index, required this.onChanged, required this.onDuplicate, required this.onDelete});

  @override
  State<_SectionCard> createState() => _SectionCardState();
}

class _SectionCardState extends State<_SectionCard> {
  late final TextEditingController _header;
  late final TextEditingController _body;

  @override
  void initState() {
    super.initState();
    _header = TextEditingController(text: widget.block.header);
    _body = TextEditingController(text: widget.block.body);
  }

  @override
  void dispose() {
    _header.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kind = _kindOf(widget.block.header);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 8, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            ReorderableDragStartListener(
              index: widget.index,
              child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.drag_handle, color: Colors.grey)),
            ),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: sectionKindColor(kind).withValues(alpha: 0.25),
                border: Border.all(color: sectionKindColor(kind).withValues(alpha: 0.8)),
              ),
              child: Icon(sectionKindIcon(kind), size: 17, color: sectionKindColor(kind)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _header,
                style: const TextStyle(fontWeight: FontWeight.bold),
                decoration: const InputDecoration(isDense: true, border: InputBorder.none),
                onChanged: (v) {
                  widget.block.header = v;
                  widget.onChanged();
                },
              ),
            ),
            IconButton(tooltip: 'Duplicar sección', icon: const Icon(Icons.content_copy, size: 20), onPressed: widget.onDuplicate),
            IconButton(tooltip: 'Eliminar sección', icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent), onPressed: widget.onDelete),
          ]),
          Padding(
            padding: const EdgeInsets.only(left: 10, right: 2),
            child: TextField(
              controller: _body,
              minLines: 2,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              decoration: const InputDecoration(hintText: 'Letra y acordes…  ej: [Am]Hola [F]mundo', border: OutlineInputBorder()),
              onChanged: (v) {
                widget.block.body = v;
                widget.onChanged();
              },
            ),
          ),
        ]),
      ),
    );
  }
}

/// Tipo de sección a partir del encabezado ("Coro 2" -> coro).
SectionKind _kindOf(String header) {
  final secs = parseSong(header);
  return secs.isNotEmpty ? secs.first.kind : SectionKind.other;
}

class _Block {
  final String id;
  String header;
  String body;
  _Block({required this.id, required this.header, required this.body});
  _Block copy() => _Block(id: uid(), header: header, body: body);

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