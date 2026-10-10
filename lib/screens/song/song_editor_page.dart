// Editor de canción con tres pestañas:
//  1. Texto (ChordPro): editor de texto clásico.
//  2. Editor visual: edición tocando las líneas.
//  3. Estructura de la canción: solo se edita la estructura (título, orden,
//     duplicar, eliminar, añadir); la letra y los acordes se editan en las
//     pestañas Texto y Editor visual.
import 'package:flutter/material.dart';

import '../../data/chord_parser.dart';
import '../../data/chordpro.dart';
import '../../data/format.dart';
import '../../data/store.dart';
import '../../models/app_state.dart';
import '../../models/song.dart';
import 'widgets/pdf_import_button.dart';
import 'widgets/song_view.dart' show sectionKindColor;
import 'widgets/visual_chord_editor.dart';
import 'song_editor_tabs.dart';

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
  late final TextEditingController author;
  late final TextEditingController style;
  late final TextEditingController duration;
  late final TextEditingController body;
  String? groupId;
  List<String>? _structure;
  late TabController _tabCtrl;

  /// true mientras el cambio de texto viene del editor visual: as no se
  /// reconstruye el editor con su propio resultado.
  bool _fromVisual = false;

  /// Contador que fuerza la recarga del editor visual cuando el cuerpo se
  /// edita en la pestaa Texto o se importa un PDF.
  int _visualRev = 0;

  /// Al abrir el editor, los metadatos que ya estn como directivas en el
  /// cuerpo rellenan la pestaña Datos (y as no se duplican ni se pierden).
  void _syncMetaFromBody() {
    final meta = ChordProParser().parse(body.text).meta;
    void fill(TextEditingController c, String? value) {
      if (c.text.trim().isNotEmpty) return;
      if (value == null || value.trim().isEmpty) return;
      c.text = value.trim();
    }

    fill(title, meta.title);
    fill(author, meta.artist);
    fill(key, meta.key);
    fill(bpm, meta.tempo);
  }

  @override
  void initState() {
    super.initState();
    title = TextEditingController(text: widget.song?.title ?? widget.initialTitle ?? '');
    key = TextEditingController(text: widget.song?.key ?? 'C');
    bpm = TextEditingController(text: widget.song?.bpm?.toString() ?? '');
    author = TextEditingController(text: widget.song?.author ?? '');
    style = TextEditingController(text: widget.song?.style ?? '');
    duration = TextEditingController(text: _durationLabel(widget.song?.durationSec));
    body = TextEditingController(text: widget.song?.body ?? widget.initialBody ?? '');
    // Canciones antiguas sin author/bpm guardados: se sacan de las directivas.
    if (widget.song != null) _syncMetaFromBody();
    groupId = widget.song?.groupId ?? widget.initialGroupId;
    _structure = widget.song?.structure?.toList();
    _tabCtrl = TabController(length: 4, vsync: this);
    body.addListener(_onBodyTextChanged);
  }

  static String _durationLabel(int? sec) {
    if (sec == null || sec <= 0) return '';
    return '${sec ~/ 60}:${(sec % 60).toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    body.removeListener(_onBodyTextChanged);
    for (final c in [title, key, bpm, author, style, duration, body]) {
      c.dispose();
    }
    super.dispose();
  }

  void _onVisualChanged(String newBody) {
    // Marca el origen del cambio para no recargar el editor visual con su
    // propio resultado (y volver al inicio del scroll).
    _fromVisual = true;
    body.text = newBody;
    _fromVisual = false;
  }

  /// El texto cambi desde la pestaña Texto (o por una importacin de PDF):
  /// el editor visual se reconstruye con la versin nueva.
  void _onBodyTextChanged() {
    if (_fromVisual) return;
    setState(() => _visualRev++);
  }

  @override
  Widget build(BuildContext context) {
    final groups = widget.store.state.groups;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.song == null ? 'Nueva canción' : 'Editar canción'),
        bottom: TabBar(
          controller: _tabCtrl,
          isScrollable: false,
          labelPadding: const EdgeInsets.symmetric(horizontal: 6),
          tabs: const [
            Tab(icon: Icon(Icons.info_outline, size: 20), text: 'Datos'),
            Tab(icon: Icon(Icons.edit_note, size: 20), text: 'Contenido'),
            Tab(icon: Icon(Icons.account_tree, size: 20), text: 'Estructura'),
            Tab(icon: Icon(Icons.visibility, size: 20), text: 'Vista previa'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          // Pestaña 1: Datos de la canción
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TextField(controller: title, decoration: const InputDecoration(labelText: 'Título')),
              const SizedBox(height: 12),
              TextField(controller: author, decoration: const InputDecoration(labelText: 'Autor (opcional)')),
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
              const SizedBox(height: 24),
              PdfImportButton(store: widget.store, initialGroupId: groupId),
              const SizedBox(height: 12),
              FilledButton(onPressed: save, child: const Text('Guardar')),
            ]),
          ),
          // Pestaña 2: Contenido (un solo sitio para la letra y los acordes,
          // con dos formas de editar: visual o ChordPro).
          ContentTab(
            body: body,
            songKey: key,
            visualRevision: _visualRev,
            onVisualChanged: _onVisualChanged,
            store: widget.store,
            onSave: save,
          ),
          // Pestaña 3: secciones y orden de toque
          _SectionsTab(controller: body, initialStructure: _structure, onStructureChanged: (v) => _structure = v),
          // Pestaña 4: vista previa de cmo queda la cancin
          PreviewTab(
            body: body,
            structure: _structure,
            songKey: key,
            title: title,
          ),
        ],
      ),
    );
  }

  void save() {
    if (title.text.trim().isEmpty) return;
    final id = widget.song?.id ?? uid();
    // El cuerpo se guarda SIEMPRE en el formato cannica: los metadatos de la
    // pestaa Datos se escriben como directivas al principio del texto.
    final parsed = ChordProParser().parse(body.text);
    parsed.meta.title = title.text.trim();
    final authorText = author.text.trim();
    parsed.meta.artist = authorText.isEmpty ? null : authorText;
    final keyText = key.text.trim();
    parsed.meta.key = keyText.isEmpty ? null : keyText;
    final bpmText = bpm.text.trim();
    parsed.meta.tempo = bpmText.isEmpty ? null : bpmText;
    final bodyCanonico = const ChordProSerializer().write(parsed);

    final song = Song(
      id: id,
      title: title.text.trim(),
      author: authorText.isEmpty ? null : authorText,
      key: keyText.isEmpty ? 'C' : keyText,
      bpm: int.tryParse(bpmText),
      groupId: groupId,
      body: bodyCanonico,
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

/// Pestaña 4: edición de secciones (el "arreglo" de la canción).
///
/// Modelo de trabajo, en memoria:
///  * [_Sec] = una sección con SU LETRA UNA SOLA VEZ (nombre, tipo y líneas
///    ChordPro tal cual). Editar la letra del Coro cambia todas sus
///    apariciones, porque las apariciones son referencias.
///  * [_Ref] = una aparición en el orden de toque: a qué sección apunta,
///    cuántas veces se repite (x2, x3...) y una nota opcional.
///
/// Al guardar se serializa de vuelta a `body` + `structure` (el formato que
/// ya usan las versiones anteriores), así que no hay migración de datos y las
/// canciones antiguas siguen funcionando igual.
class _SectionsTab extends StatefulWidget {
  final TextEditingController controller;
  final List<String>? initialStructure;
  final ValueChanged<List<String>?> onStructureChanged;
  const _SectionsTab({required this.controller, required this.initialStructure, required this.onStructureChanged});

  @override
  State<_SectionsTab> createState() => _SectionsTabState();
}

/// Sección de la canción: la letra vive aquí, una única vez.
class _Sec {
  final String id;
  String name;
  SectionKind kind;
  List<String> lines;

  /// Directivas ChordPro originales (`{start_of_verse: VERSO 1}`) si el
  /// cuerpo se importó en modo literal: se conservan al reescribir para no
  /// perder el formato del cancionero.
  String? open;
  String? close;
  _Sec({required this.id, required this.name, required this.kind, this.lines = const [], this.open, this.close});
}

/// Aparición de una sección en el orden de toque.
class _Ref {
  String sectionId;
  int repeat;
  String? note;
  _Ref({required this.sectionId, this.repeat = 1, this.note});
}

/// Foto del estado para deshacer/rehacer.
class _Snapshot {
  final List<_Sec> secs;
  final List<_Ref> arr;
  _Snapshot(this.secs, this.arr);
}

class _SectionsTabState extends State<_SectionsTab> {
  late List<_Sec> _secs;
  late List<_Ref> _arr;
  bool _pushing = false;
  final List<_Snapshot> _undo = [];
  final List<_Snapshot> _redo = [];

  @override
  void initState() {
    super.initState();
    _load();
    widget.controller.addListener(_onBodyChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onBodyChanged);
    super.dispose();
  }

  void _load() {
    final blocks = _parseBlocks(widget.controller.text);
    _secs = [
      for (final b in blocks)
        _Sec(id: uid(), name: b.name, kind: _kindOf(b.name), lines: List.of(b.content), open: b.open, close: b.close),
    ];
    final map = widget.initialStructure;
    _arr = [];
    if (map != null && map.isNotEmpty) {
      for (final h in map) {
        final sec = _byName(h);
        if (sec != null) _arr.add(_Ref(sectionId: sec.id));
      }
    }
    if (_arr.isEmpty) _arr = [for (final s in _secs) _Ref(sectionId: s.id)];
    _undo.clear();
    _redo.clear();
  }

  /// Si el texto cambió desde otra pestaña (Texto, visual, PDF), volver a
  /// interpretar las secciones. El arreglo se mantiene haciendo coincidir los
  /// nombres, para no perder el orden de toque ya elegido.
  void _onBodyChanged() {
    if (_pushing) return;
    final old = _arr.map((r) => _secById(r.sectionId)).toList();
    final oldRefs = _arr.toList();
    final blocks = _parseBlocks(widget.controller.text);
    setState(() {
      _secs = [
        for (final b in blocks)
          _Sec(id: uid(), name: b.name, kind: _kindOf(b.name), lines: List.of(b.content), open: b.open, close: b.close),
      ];
      final byName = <String, _Sec>{};
      for (final s in _secs) {
        byName.putIfAbsent(_norm(s.name), () => s);
      }
      _arr = [];
      for (var i = 0; i < oldRefs.length; i++) {
        final name = i < old.length ? (old[i]?.name ?? '') : '';
        final sec = byName[_norm(name)];
        if (sec != null) _arr.add(_Ref(sectionId: sec.id, repeat: oldRefs[i].repeat, note: oldRefs[i].note));
      }
      if (_arr.isEmpty) _arr = [for (final s in _secs) _Ref(sectionId: s.id)];
    });
  }

  // ---------------------------------------------------------------- helpers

  /// Clave de comparación de nombres ("VERSO 1" y "Verso 1" son la misma).
  String _norm(String s) => s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  _Sec? _byName(String name) {
    for (final s in _secs) {
      if (_norm(s.name) == _norm(name)) return s;
    }
    return null;
  }

  _Sec? _secById(String id) {
    for (final s in _secs) {
      if (s.id == id) return s;
    }
    return null;
  }

  String _secName(String id) => _secById(id)?.name ?? '';

  /// Nº de líneas de letra de la sección (para identificar la tarjeta).
  String _linesHint(_Sec sec) {
    final n = sec.lines.where((l) => l.trim().isNotEmpty).length;
    return n == 0 ? 'Sin letra aún' : '$n líneas de letra';
  }

  // ------------------------------------------------------------ undo / redo

  _Snapshot _snap() => _Snapshot(
        [for (final s in _secs) _Sec(id: s.id, name: s.name, kind: s.kind, lines: List.of(s.lines), open: s.open, close: s.close)],
        [for (final r in _arr) _Ref(sectionId: r.sectionId, repeat: r.repeat, note: r.note)],
      );

  void _pushUndo() {
    _undo.add(_snap());
    if (_undo.length > 40) _undo.removeAt(0);
    _redo.clear();
  }

  void _undoLast() {
    if (_undo.isEmpty) return;
    final snap = _undo.removeLast();
    _redo.add(_snap());
    _secs = snap.secs;
    _arr = snap.arr;
    _push();
  }

  void _redoLast() {
    if (_redo.isEmpty) return;
    final snap = _redo.removeLast();
    _undo.add(_snap());
    _secs = snap.secs;
    _arr = snap.arr;
    _push();
  }

  bool get _canUndo => _undo.isNotEmpty;
  bool get _canRedo => _redo.isNotEmpty;

  // --------------------------------------------------------- serialización

  /// Texto ChordPro completo: una sección por bloque, en el orden en que están
  /// guardadas (no en el del arreglo; el arreglo es solo el orden de toque).
  String _bodyText() => _secs.map((s) {
        final out = <String>[];
        if (s.open != null && s.open!.trim().isNotEmpty) out.add(s.open!);
        if (s.name.isNotEmpty && s.open == null) out.add(s.name);
        out.addAll(s.lines);
        if (s.close != null && s.close!.trim().isNotEmpty) out.add(s.close!);
        return out.join('\n');
      }).join('\n');

  /// Orden de toque con las repeticiones ya expandidas, como lo espera
  /// [Song.structure] y [sectionsInOrder].
  List<String> _structureList() {
    final out = <String>[];
    for (final r in _arr) {
      final sec = _secById(r.sectionId);
      if (sec == null) continue;
      for (var i = 0; i < r.repeat; i++) {
        out.add(sec.name);
      }
    }
    return out;
  }

  /// Escribe el resultado en el controlador del cuerpo y avisa al editor.
  void _push() {
    _pushing = true;
    widget.controller.text = _bodyText();
    _pushing = false;
    widget.onStructureChanged(_structureList());
    setState(() {});
  }

  // -------------------------------------------------------------- acciones

  Future<void> _addSection() async {
    final c = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nueva sección'),
        content: TextField(controller: c, autofocus: true, decoration: const InputDecoration(hintText: 'Verso 2, Coro, Puente...'), onSubmitted: (v) => Navigator.pop(context, v)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, c.text), child: const Text('Añadir')),
        ],
      ),
    );
    final label = (name ?? '').trim();
    if (label.isEmpty) return;
    _pushUndo();
    final sec = _Sec(id: uid(), name: label, kind: _kindOf(label), lines: <String>[]);
    setState(() {
      _secs.add(sec);
      _arr.add(_Ref(sectionId: sec.id));
      _push();
    });
  }

  /// Renombra la sección entera (todas sus apariciones del arreglo se
  /// actualizan solas, porque apuntan por id).
  void _rename(_Sec sec, String newName) {
    final label = newName.trim();
    if (label.isEmpty || label == sec.name) return;
    _pushUndo();
    setState(() {
      sec.name = label;
      sec.kind = _kindOf(label);
      _push();
    });
  }

  /// Repeticiones de una aparición (x1...x4).
  void _setRepeat(int index, int repeat) {
    if (repeat < 1 || repeat > 4 || _arr[index].repeat == repeat) return;
    _pushUndo();
    setState(() {
      _arr[index].repeat = repeat;
      _push();
    });
  }

  /// Quita una aparición del orden de toque. La sección y su letra se quedan
  /// (siguen disponibles para volver a añadirlas).
  void _removeRef(int index) {
    _pushUndo();
    setState(() {
      _arr.removeAt(index);
      _push();
    });
  }

  /// Elimina la sección con su letra. Avisa si se usa en el arreglo.
  Future<void> _deleteSection(_Sec sec) async {
    final uses = _arr.where((r) => r.sectionId == sec.id).length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Eliminar "${sec.name}"'),
        content: Text(uses == 0
            ? 'Se borrará la sección y su letra. Se puede deshacer.'
            : 'Esta sección se usa $uses ${uses == 1 ? 'vez' : 'veces'} en el orden de toque. Se quitarán esas apariciones y se borrará la letra. Se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok != true) return;
    _pushUndo();
    setState(() {
      _arr.removeWhere((r) => r.sectionId == sec.id);
      _secs.removeWhere((s) => s.id == sec.id);
      _push();
    });
  }

  /// Convierte una aparición en una copia independiente de la sección: a
  /// partir de ahí se puede editar su letra sin afectar a las demás.
  void _makeVariant(int index) {
    final sec = _secById(_arr[index].sectionId);
    if (sec == null) return;
    _pushUndo();
    setState(() {
      final base = sec.name;
      var name = '$base (variante)';
      var n = 2;
      while (_byName(name) != null) {
        name = '$base (variante $n)';
        n++;
      }
      final copy = _Sec(id: uid(), name: name, kind: sec.kind, lines: List.of(sec.lines));
      _secs.add(copy);
      _arr[index].sectionId = copy.id;
      _push();
    });
  }

  /// Nota de una aparición del arreglo ("con piano", "sin batera"...).
  Future<void> _editNote(int index) async {
    final c = TextEditingController(text: _arr[index].note ?? '');
    final note = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nota de esta aparición'),
        content: TextField(controller: c, autofocus: true, decoration: const InputDecoration(hintText: 'con piano, a dos voces...')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, c.text), child: const Text('Guardar')),
        ],
      ),
    );
    if (note == null) return;
    _pushUndo();
    setState(() {
      _arr[index].note = note.trim().isEmpty ? null : note.trim();
      _push();
    });
  }

  /// Divide una sección en dos por una línea de corte. Las apariciones de la
  /// original se sustituyen por la Parte 1 y la Parte 2 seguidas.
  Future<void> _splitSection(_Sec sec) async {
    if (sec.lines.length < 2) return;
    final cut = await showDialog<int>(context: context, builder: (_) => _SplitDialog(lines: sec.lines));
    if (cut == null || cut <= 0 || cut >= sec.lines.length) return;
    _pushUndo();
    setState(() {
      final first = _Sec(id: uid(), name: '${sec.name} (parte 1)', kind: sec.kind, lines: sec.lines.sublist(0, cut));
      final second = _Sec(id: uid(), name: '${sec.name} (parte 2)', kind: sec.kind, lines: sec.lines.sublist(cut));
      final at = _secs.indexOf(sec);
      _secs.remove(sec);
      _secs.insert(at, second);
      _secs.insert(at, first);
      final newArr = <_Ref>[];
      for (final r in _arr) {
        if (r.sectionId == sec.id) {
          for (var i = 0; i < r.repeat; i++) {
            newArr.add(_Ref(sectionId: first.id, note: r.note));
            newArr.add(_Ref(sectionId: second.id));
          }
        } else {
          newArr.add(r);
        }
      }
      _arr
        ..clear()
        ..addAll(newArr);
      _push();
    });
  }

  /// Une dos secciones en una (se queda con el nombre y la letra de la
  /// primera más las líneas de la segunda).
  Future<void> _joinSections(_Sec sec) async {
    if (_secs.length < 2) return;
    final other = await showDialog<_Sec>(
      context: context,
      builder: (_) => _JoinDialog(secs: _secs.where((s) => s.id != sec.id).toList()),
    );
    if (other == null) return;
    _pushUndo();
    setState(() {
      sec.lines.addAll(other.lines);
      _secs.remove(other);
      for (final r in _arr) {
        if (r.sectionId == other.id) r.sectionId = sec.id;
      }
      _push();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Expanded(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Row(children: [
            const Text('Orden de toque', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Spacer(),
            Text(_arr.isEmpty ? '0 partes' : '${_arr.length} partes', style: const TextStyle(color: Colors.grey)),
            IconButton(tooltip: 'Deshacer', icon: const Icon(Icons.undo, size: 20), onPressed: _canUndo ? _undoLast : null),
            IconButton(tooltip: 'Rehacer', icon: const Icon(Icons.redo, size: 20), onPressed: _canRedo ? _redoLast : null),
          ]),
          const SizedBox(height: 4),
          const Text(
            'Cada tarjeta es una aparición en el orden de toque. Repetir (x2, x3) añade apariciones SIN copiar la letra: si editas el Coro, cambian todas. "Variante" sí crea una copia independiente. La letra se edita en las pestañas Texto y Editor visual.',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 8),
          if (_arr.isEmpty)
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
              itemCount: _arr.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  final item = _arr.removeAt(oldIndex);
                  _arr.insert(newIndex > oldIndex ? newIndex - 1 : newIndex, item);
                  _push();
                });
              },
              itemBuilder: (context, index) {
                final sec = _secById(_arr[index].sectionId);
                return _ArrCard(
                  key: ValueKey('arr$index'),
                  index: index,
                  name: sec?.name ?? '',
                  kind: sec?.kind ?? SectionKind.other,
                  repeat: _arr[index].repeat,
                  note: _arr[index].note,
                  linesHint: sec == null ? null : _linesHint(sec),
                  onRename: sec == null ? null : (v) => _rename(sec, v),
                  onRepeat: (v) => _setRepeat(index, v),
                  onRemove: () => _removeRef(index),
                  onVariant: () => _makeVariant(index),
                  onNote: () => _editNote(index),
                  onSplit: sec == null ? null : () => _splitSection(sec),
                );
              },
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(onPressed: _addSection, icon: const Icon(Icons.add), label: const Text('Añadir sección')),
          const Divider(height: 32),
          const Text('Secciones de la canción', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text(
            'La letra de cada sección se guarda una sola vez. Aquí puedes partirla en dos, unirla con otra, añadirla al orden de toque o borrarla.',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 8),
          for (final sec in _secs)
            _SecCard(
              sec: sec,
              linesHint: _linesHint(sec),
              uses: _arr.where((r) => r.sectionId == sec.id).length,
              onRename: (v) => _rename(sec, v),
              onAddToArrangement: () {
                _pushUndo();
                setState(() {
                  _arr.add(_Ref(sectionId: sec.id));
                  _push();
                });
              },
              onSplit: () => _splitSection(sec),
              onJoin: _secs.length < 2 ? null : () => _joinSections(sec),
              onDelete: () => _deleteSection(sec),
            ),
        ]),
      ),
    ]);
  }
}

/// Diálogo para elegir el punto de corte al dividir una sección.
class _SplitDialog extends StatefulWidget {
  final List<String> lines;
  const _SplitDialog({required this.lines});

  @override
  State<_SplitDialog> createState() => _SplitDialogState();
}

class _SplitDialogState extends State<_SplitDialog> {
  late int cut;

  @override
  void initState() {
    super.initState();
    final mid = (widget.lines.length / 2).ceil();
    cut = mid.clamp(1, widget.lines.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Dividir sección'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: widget.lines.length,
          itemBuilder: (context, i) {
            final text = widget.lines[i].trim().isEmpty ? '(línea vacía)' : widget.lines[i];
            return RadioListTile<int>(
              value: i + 1,
              groupValue: cut,
              dense: true,
              title: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
              subtitle: Text('Cortar antes de la línea ${i + 2}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
              onChanged: (v) => setState(() => cut = v!),
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(context, cut), child: const Text('Dividir')),
      ],
    );
  }
}

/// Diálogo para elegir con qué otra sección se une.
class _JoinDialog extends StatelessWidget {
  final List<_Sec> secs;
  const _JoinDialog({required this.secs});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Unir con otra sección'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final s in secs)
              ListTile(
                leading: CircleAvatar(
                  radius: 14,
                  backgroundColor: sectionKindColor(s.kind).withValues(alpha: 0.3),
                  child: Text(_abbrOf(s.name), style: const TextStyle(fontSize: 10)),
                ),
                title: Text(s.name.isEmpty ? '(texto inicial)' : s.name),
                subtitle: Text(_linesOfHint(s), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                onTap: () => Navigator.pop(context, s),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
      ],
    );
  }

  static String _linesOfHint(_Sec s) {
    final n = s.lines.where((l) => l.trim().isNotEmpty).length;
    return n == 0 ? 'Sin letra' : '$n líneas';
  }
}

/// Tarjeta de una aparición en el orden de toque.
class _ArrCard extends StatefulWidget {
  final int index;
  final String name;
  final SectionKind kind;
  final int repeat;
  final String? note;
  final String? linesHint;
  final ValueChanged<String>? onRename;
  final ValueChanged<int> onRepeat;
  final VoidCallback onRemove;
  final VoidCallback onVariant;
  final VoidCallback onNote;
  final VoidCallback? onSplit;
  const _ArrCard({
    super.key,
    required this.index,
    required this.name,
    required this.kind,
    required this.repeat,
    this.note,
    this.linesHint,
    this.onRename,
    required this.onRepeat,
    required this.onRemove,
    required this.onVariant,
    required this.onNote,
    this.onSplit,
  });

  @override
  State<_ArrCard> createState() => _ArrCardState();
}

class _ArrCardState extends State<_ArrCard> {
  late final TextEditingController _name;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.name);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
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
                    color: sectionKindColor(widget.kind).withValues(alpha: 0.25),
                    border: Border.all(color: sectionKindColor(widget.kind).withValues(alpha: 0.8)),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Text(_abbrOf(widget.name), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(isDense: true, border: InputBorder.none),
                        onChanged: widget.onRename,
                      ),
                      Text(
                        [
                          if (widget.linesHint != null) widget.linesHint!,
                          if (widget.repeat > 1) 'suena ${widget.repeat} veces',
                          if (widget.note != null && widget.note!.isNotEmpty) widget.note!,
                        ].join('  ·  '),
                        style: const TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<int>(
                  tooltip: 'Repeticiones',
                  icon: Row(children: [
                    Text('x${widget.repeat}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const Icon(Icons.arrow_drop_down, size: 18),
                  ]),
                  initialValue: widget.repeat,
                  onSelected: widget.onRepeat,
                  itemBuilder: (_) => [
                    for (var i = 1; i <= 4; i++) PopupMenuItem(value: i, child: Text(i == 1 ? 'Una vez' : '$i veces')),
                  ],
                ),
                PopupMenuButton<String>(
                  tooltip: 'Más opciones',
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'variante', child: Text('Hacer variante (copia independiente)')),
                    const PopupMenuItem(value: 'nota', child: Text('Poner nota')),
                    if (widget.onSplit != null) const PopupMenuItem(value: 'dividir', child: Text('Dividir sección en dos')),
                    const PopupMenuItem(value: 'quitar', child: Text('Quitar del orden de toque')),
                  ],
                  onSelected: (v) {
                    switch (v) {
                      case 'variante':
                        widget.onVariant();
                      case 'nota':
                        widget.onNote();
                      case 'dividir':
                        widget.onSplit!();
                      case 'quitar':
                        widget.onRemove();
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta de una sección (su letra vive aquí, una sola vez).
class _SecCard extends StatefulWidget {
  final _Sec sec;
  final String linesHint;
  final int uses;
  final ValueChanged<String> onRename;
  final VoidCallback onAddToArrangement;
  final VoidCallback? onSplit;
  final VoidCallback? onJoin;
  final VoidCallback onDelete;
  const _SecCard({
    super.key,
    required this.sec,
    required this.linesHint,
    required this.uses,
    required this.onRename,
    required this.onAddToArrangement,
    this.onSplit,
    this.onJoin,
    required this.onDelete,
  });

  @override
  State<_SecCard> createState() => _SecCardState();
}

class _SecCardState extends State<_SecCard> {
  late final TextEditingController _name;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.sec.name);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.sec.name;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: sectionKindColor(widget.sec.kind).withValues(alpha: 0.25),
                    border: Border.all(color: sectionKindColor(widget.sec.kind).withValues(alpha: 0.8)),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Text(_abbrOf(name), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: name.isEmpty ? 'Texto inicial (sin encabezado)' : null,
                      hintStyle: const TextStyle(fontWeight: FontWeight.normal, color: Colors.grey, fontStyle: FontStyle.italic),
                    ),
                    onChanged: widget.onRename,
                  ),
                ),
                IconButton(
                  tooltip: 'Añadir al orden de toque',
                  icon: const Icon(Icons.playlist_add, size: 20),
                  onPressed: widget.onAddToArrangement,
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 36),
              child: Text(
                '${widget.linesHint}  ·  ${widget.uses == 0 ? 'no se usa en el orden' : widget.uses == 1 ? '1 aparición' : '${widget.uses} apariciones'}',
                style: const TextStyle(color: Colors.grey, fontSize: 11),
              ),
            ),
            Wrap(
              spacing: 4,
              children: [
                if (widget.onSplit != null)
                  TextButton.icon(
                    onPressed: widget.onSplit,
                    icon: const Icon(Icons.call_split, size: 16),
                    label: const Text('Dividir', style: TextStyle(fontSize: 12)),
                  ),
                if (widget.onJoin != null)
                  TextButton.icon(
                    onPressed: widget.onJoin,
                    icon: const Icon(Icons.merge, size: 16),
                    label: const Text('Unir', style: TextStyle(fontSize: 12)),
                  ),
                TextButton.icon(
                  onPressed: widget.onDelete,
                  icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                  label: const Text('Eliminar', style: TextStyle(fontSize: 12, color: Colors.redAccent)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


/// Tipo de sección a partir del nombre ("Coro 2" -> coro).
SectionKind _kindOf(String name) {
  final secs = parseSong(name);
  return secs.isNotEmpty ? secs.first.kind : SectionKind.other;
}

/// Abreviatura en minúsculas ("Verso 2" -> "v2") para el círculo de la tarjeta.
String _abbrOf(String name) {
  final secs = parseSong(name);
  if (secs.isNotEmpty && secs.first.abbr != '•' && secs.first.abbr.isNotEmpty) {
    return secs.first.abbr.toLowerCase();
  }
  final t = name.trim();
  return t.isEmpty ? '?' : t.length <= 2 ? t.toLowerCase() : t.substring(0, 2).toLowerCase();
}

class _Block {
  final String id;

  /// Etiqueta de la sección tal como la interpreta el parser (vacío = texto
  /// inicial sin encabezado; se conserva tal cual, sin inventar "Intro").
  final String name;

  /// Líneas que siguen al encabezado, exactamente como se escribieron
  /// (incluye las líneas en blanco entre secciones).
  final List<String> content;

  /// Directivas ChordPro originales, si el cuerpo se importó en modo literal.
  final String? open;
  final String? close;
  _Block({required this.id, required this.name, this.content = const [], this.open, this.close});
}

/// `{end_of_verse}` y compañía (cierre de sección en ChordPro).
final _endOfDir = RegExp(r'^\s*\{\s*end(?:_of)?_[a-z_]+\s*\}\s*$', caseSensitive: false);

/// Etiqueta canónica de un encabezado: la misma que después usa
/// [sectionsInOrder] para casar con el orden de toque guardado.
String _nameFromHeader(String line) {
  final t = line.trim();
  if (t.isEmpty) return '';
  final parsed = parseSong(t);
  if (parsed.length == 1 && parsed.first.label != 'Inicio') return parsed.first.label;
  return t;
}

/// Parte el cuerpo en secciones. Reconoce encabezados normales ("Verso 1") y
/// también directivas ChordPro (`{start_of_verse: VERSO 1}` ... `{end_of_verse}`),
/// que se conservan para reescribir el texto sin perder el formato original
/// del cancionero.
List<_Block> _parseBlocks(String text) {
  final lines = text.replaceAll('\r', '').split('\n');
  final blocks = <_Block>[];
  _Block? cur;
  String? pendingClose;
  for (final line in lines) {
    final t = line.trim();
    if (_endOfDir.hasMatch(t)) {
      pendingClose = t;
      continue;
    }
    if (isSectionHeader(line)) {
      cur = _Block(
        id: uid(),
        name: _nameFromHeader(line),
        content: [],
        open: isChordProSectionStart(line) ? t : null,
        close: pendingClose,
      );
      pendingClose = null;
      blocks.add(cur);
      continue;
    }
    if (cur != null) {
      cur.content.add(line);
      continue;
    }
    if (t.isNotEmpty) {
      // Líneas antes del primer encabezado: bloque sin encabezado, se
      // conserva tal cual.
      cur = _Block(id: uid(), name: '', content: [line]);
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