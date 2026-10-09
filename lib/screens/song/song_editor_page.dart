// Editor de canción con tres pestañas:
//  1. Texto (ChordPro): editor de texto clásico.
//  2. Editor visual: edición tocando las líneas.
//  3. Estructura de la canción: solo se edita la estructura (título, orden,
//     duplicar, eliminar, añadir); la letra y los acordes se editan en las
//     pestañas Texto y Editor visual.
import 'package:flutter/material.dart';

import '../../data/chord_parser.dart';
import '../../data/format.dart';
import '../../data/store.dart';
import '../../models/app_state.dart';
import '../../models/song.dart';
import 'widgets/pdf_import_button.dart';
import 'widgets/song_view.dart' show sectionKindColor;
import 'widgets/visual_chord_editor.dart';

class SongEditorPage extends StatefulWidget {
  final Store store;
  final Song? song;
  final String? initialGroupId;

  /// Borrador inicial (sin canción guardada todavía) para importaciones de PDF
  /// o documentos ChordPro. Solo se usa si [song] es null.
  final String? initialTitle;
  final String? initialBody;
  const SongEditorPage({super.key, required this.store, this.song, this.initialGroupId, this.initialTitle, this.initialBody});

  @override
  State<SongEditorPage> createState() => _SongEditorPageState();
}

class _SongEditorPageState extends State<SongEditorPage> with SingleTickerProviderStateMixin {
  late final TextEditingController title;
  late final TextEditingController key;
  late final TextEditingController bpm;
  late final TextEditingController style;
  late final TextEditingController duration;
  late final TextEditingController body;
  String? groupId;
  List<String>? _structure;
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    title = TextEditingController(text: widget.song?.title ?? widget.initialTitle ?? '');
    key = TextEditingController(text: widget.song?.key ?? 'C');
    bpm = TextEditingController(text: widget.song?.bpm?.toString() ?? '');
    style = TextEditingController(text: widget.song?.style ?? '');
    duration = TextEditingController(text: _durationLabel(widget.song?.durationSec));
    body = TextEditingController(text: widget.song?.body ?? widget.initialBody ?? '');
    groupId = widget.song?.groupId ?? widget.initialGroupId;
    _structure = widget.song?.structure?.toList();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  static String _durationLabel(int? sec) {
    if (sec == null || sec <= 0) return '';
    return '${sec ~/ 60}:${(sec % 60).toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    for (final c in [title, key, bpm, style, duration, body]) {
      c.dispose();
    }
    super.dispose();
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
            Tab(icon: Icon(Icons.account_tree), text: 'Estructura de la canción'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          // Pestaña 1: editor de texto clásico
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
              Row(children: [
                Expanded(child: TextField(controller: style, decoration: const InputDecoration(labelText: 'Estilo (opcional)'))),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: duration, decoration: const InputDecoration(labelText: 'Duración (3:45)'), keyboardType: TextInputType.text)),
              ]),
              const SizedBox(height: 12),
              TextField(controller: body, decoration: const InputDecoration(labelText: 'Letra con acordes', alignLabelWithHint: true), maxLines: 18, style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
              const SizedBox(height: 12),
              const Text('Consejo: la estructura se edita en la pestaña "Estructura de la canción".', style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 12),
              PdfImportButton(titleController: title, bodyController: body, onImported: () => setState(() {})),
              const SizedBox(height: 12),
              FilledButton(onPressed: save, child: const Text('Guardar')),
            ]),
          ),
          // Pestaña 2: editor visual
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
          // Pestaña 3: mapa de toque de la canción
          _SectionsTab(controller: body, initialStructure: _structure, onStructureChanged: (v) => _structure = v),
        ],
      ),
    );
  }

  void save() {
    if (title.text.trim().isEmpty) return;
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
      structure: _structure,
    );
    widget.store.update((s) {
      final songs = s.songs.any((x) => x.id == id) ? s.songs.map((x) => x.id == id ? song : x).toList() : [song, ...s.songs];
      return AppState(groups: s.groups, songs: songs, setlists: s.setlists);
    });
    Navigator.of(context).pop();
  }
}

/// Pestaña 3: el "mapa" de la canción (orden de toque). Cada entrada señala
/// una sección del cuerpo y puede repetirse SIN duplicar su letra: el orden se
/// guarda aparte ([Song.structure]). Renombrar solo cambia el encabezado;
/// añadir/eliminar secciones sí reescribe el cuerpo cuando hace falta,
/// conservando siempre el formato original.
class _SectionsTab extends StatefulWidget {
  final TextEditingController controller;
  final List<String>? initialStructure;
  final ValueChanged<List<String>?> onStructureChanged;
  const _SectionsTab({required this.controller, required this.initialStructure, required this.onStructureChanged});

  @override
  State<_SectionsTab> createState() => _SectionsTabState();
}

class _SectionsTabState extends State<_SectionsTab> {
  late List<_Block> blocks;
  List<String>? _map;
  final List<String> _entryIds = [];
  bool _pushing = false;

  @override
  void initState() {
    super.initState();
    blocks = _parseBlocks(widget.controller.text);
    if (widget.initialStructure != null) {
      _map = List<String>.of(widget.initialStructure!);
    }
    _syncIds(_activeMap().length);
    widget.controller.addListener(_onBodyChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onBodyChanged);
    super.dispose();
  }

  /// Si el texto cambió desde otra pestaña (Texto, visual, PDF), volver a
  /// interpretar las secciones. Ignora los cambios que nosotros mismos
  /// hacemos al recomponer el texto (los bloqueamos con [_pushing]).
  void _onBodyChanged() {
    if (_pushing) return;
    setState(() => blocks = _parseBlocks(widget.controller.text));
  }

  /// Mapa activo: el editado por el usuario, o el orden del cuerpo tal cual
  /// si nunca se tocó la estructura de esta canción.
  List<String> _activeMap() => _map ?? blocks.map((b) => b.header).toList();

  /// Primera edición sobre una canción sin estructura: fija el mapa al orden
  /// actual del cuerpo. Desde entonces el orden vive en [Song.structure] y
  /// repetir/reordenar ya no reescribe la letra.
  void _ensureMap() {
    if (_map == null) {
      _map = blocks.map((b) => b.header).toList();
      widget.onStructureChanged(List<String>.of(_map!));
    }
  }

  void _pushStructure() => widget.onStructureChanged(List<String>.of(_map!));

  /// Mantiene ids estables por entrada para que las tarjetas conserven su
  /// estado (su campo de texto) al reordenar el mapa.
  void _syncIds(int n) {
    if (_entryIds.length > n) _entryIds.removeRange(n, _entryIds.length);
    while (_entryIds.length < n) {
      _entryIds.add(uid());
    }
  }

  /// Solo se reescribe el texto cuando cambian los bloques (añadir, renombrar
  /// o eliminar una sección entera); conserva el texto crudo y el formato.
  void _rebuildBody() {
    _pushing = true;
    widget.controller.text = blocks.map((b) => b.toRaw()).join('\n');
    _pushing = false;
    setState(() {});
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
    _ensureMap();
    setState(() {
      blocks.add(_Block(id: uid(), header: name.trim()));
      _map!.add(name.trim());
      _entryIds.add(uid());
      _pushStructure();
      _rebuildBody();
    });
  }

  /// Renombra la sección entera (todas sus apariciones en el mapa y el
  /// encabezado del cuerpo; la letra no se toca).
  void _rename(String oldH, String newH) {
    final trimmed = newH.trim();
    if (trimmed.isEmpty || trimmed == oldH) return;
    _ensureMap();
    setState(() {
      _map = _map!.map((h) => h == oldH ? trimmed : h).toList();
      for (final b in blocks) {
        if (b.header == oldH) b.header = trimmed;
      }
      _pushStructure();
      _rebuildBody();
    });
  }

  /// Nº de líneas de letra de la sección (para identificar la tarjeta).
  String? _linesHint(String header) {
    final b = blocks.where((x) => x.header == header).firstOrNull;
    if (b == null) return null;
    final n = b.content.where((l) => l.trim().isNotEmpty).length;
    return n == 0 ? 'Sin letra aún' : '$n líneas de letra';
  }

  @override
  Widget build(BuildContext context) {
    final map = _activeMap();
    _syncIds(map.length);
    return Column(children: [
      Expanded(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Row(children: [
            const Text('Orden de toque', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Spacer(),
            Text(map.isEmpty ? '0 partes' : '${map.length} partes', style: const TextStyle(color: Colors.grey)),
          ]),
          const SizedBox(height: 4),
          const Text('Es el mapa de lo que suena, en orden y con repeticiones. Repetir añade la sección al mapa SIN copiar su letra; renombrar solo cambia el encabezado. La letra se edita en las pestañas Texto y Editor visual.', style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 8),
          if (map.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Aún no hay orden de toque. Pulsa "Añadir sección" para crear una parte; la letra se escribe en la pestaña Texto.', style: TextStyle(color: Colors.grey)),
              ),
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: map.length,
              onReorderItem: (oldIndex, newIndex) {
                setState(() {
                  _ensureMap();
                  final item = _map!.removeAt(oldIndex);
                  _map!.insert(newIndex, item);
                  final id = _entryIds.removeAt(oldIndex);
                  _entryIds.insert(newIndex, id);
                  _pushStructure();
                });
              },
              itemBuilder: (context, index) {
                final header = map[index];
                return _SectionCard(
                  key: ValueKey(_entryIds[index]),
                  header: header,
                  index: index,
                  linesHint: _linesHint(header),
                  onRename: (v) => _rename(header, v),
                  onDuplicate: () => setState(() {
                    _ensureMap();
                    _map!.insert(index + 1, header);
                    _entryIds.insert(index + 1, uid());
                    _pushStructure();
                  }),
                  onDelete: () => setState(() {
                    _ensureMap();
                    final removed = _map!.removeAt(index);
                    _entryIds.removeAt(index);
                    _pushStructure();
                    // Si era la única aparición, se elimina también la sección
                    // (y su letra) del cuerpo, conservando el formato.
                    if (!_map!.contains(removed)) {
                      blocks.removeWhere((b) => b.header == removed);
                      _rebuildBody();
                    }
                  }),
                );
              },
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(onPressed: _addSection, icon: const Icon(Icons.add), label: const Text('Añadir sección')),
          const SizedBox(height: 8),
        ]),
      ),
    ]);
  }
}

/// Tarjeta de posición en el orden de toque: solo estructura. Nombre editable
/// (renombra la sección entera), arrastrar para reordenar, repetir y eliminar.
class _SectionCard extends StatefulWidget {
  final String header;
  final int index;
  final String? linesHint;
  final ValueChanged<String> onRename;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;
  const _SectionCard({super.key, required this.header, required this.index, this.linesHint, required this.onRename, required this.onDuplicate, required this.onDelete});

  @override
  State<_SectionCard> createState() => _SectionCardState();
}

class _SectionCardState extends State<_SectionCard> {
  late final TextEditingController _header;

  @override
  void initState() {
    super.initState();
    _header = TextEditingController(text: widget.header);
  }

  @override
  void dispose() {
    _header.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kind = _kindOf(widget.header);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
        child: Row(children: [
          ReorderableDragStartListener(
            index: widget.index,
            child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.drag_handle, color: Colors.grey)),
          ),
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: sectionKindColor(kind).withValues(alpha: 0.25),
              border: Border.all(color: sectionKindColor(kind).withValues(alpha: 0.8)),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Text(_abbrOf(widget.header), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextField(
                controller: _header,
                style: const TextStyle(fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: widget.header.isEmpty ? 'Texto inicial (sin encabezado)' : null,
                  hintStyle: const TextStyle(fontWeight: FontWeight.normal, color: Colors.grey, fontStyle: FontStyle.italic),
                ),
                onChanged: widget.onRename,
              ),
              if (widget.linesHint != null)
                Text(widget.linesHint!, style: const TextStyle(color: Colors.grey, fontSize: 11)),
            ]),
          ),
          IconButton(tooltip: 'Repetir esta sección', icon: const Icon(Icons.content_copy, size: 20), onPressed: widget.onDuplicate),
          IconButton(tooltip: 'Eliminar del orden', icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent), onPressed: widget.onDelete),
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

/// Abreviatura en minúsculas ("Verso 2" -> "v2") para el círculo de la tarjeta.
String _abbrOf(String header) {
  final secs = parseSong(header);
  if (secs.isNotEmpty && secs.first.abbr != '•' && secs.first.abbr.isNotEmpty) {
    return secs.first.abbr.toLowerCase();
  }
  final t = header.trim();
  return t.isEmpty ? '?' : t.length <= 2 ? t.toLowerCase() : t.substring(0, 2).toLowerCase();
}

class _Block {
  final String id;

  /// Encabezado (primera línea del bloque). Vacío si el texto inicial no
  /// tiene encabezado (se conserva tal cual, sin inventar un "Intro").
  String header;

  /// Líneas que siguen al encabezado, exactamente como se escribieron
  /// (incluye las líneas en blanco entre secciones).
  final List<String> content;
  _Block({required this.id, required this.header, List<String>? content}) : content = content ?? [];

  /// Texto crudo del bloque conservando el formato original.
  String toRaw() => [
        if (header.isNotEmpty) header,
        ...content,
      ].join('\n');
}

List<_Block> _parseBlocks(String text) {
  final lines = text.replaceAll('\r', '').split('\n');
  final blocks = <_Block>[];
  _Block? cur;
  for (final line in lines) {
    if (isSectionHeader(line)) {
      cur = _Block(id: uid(), header: line.trim());
      blocks.add(cur);
    } else if (cur != null) {
      cur.content.add(line);
    } else if (line.trim().isNotEmpty) {
      // Líneas antes del primer encabezado: bloque sin encabezado, se
      // conserva tal cual.
      cur = _Block(id: uid(), header: '', content: [line]);
      blocks.add(cur);
    }
  }
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