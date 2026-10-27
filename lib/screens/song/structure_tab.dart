// Pestaña "Estructura": armar el orden de toque de la canción.
//
// Vista simplificada en dos paneles (como una cartelera):
//   * Izquierda "Estructura actual": lo que suena, en orden, con sus
//     repeticiones (x1, x2...). Se reordena arrastrando.
//   * Derecha "Disponibles": las secciones que aún no suenan. Se añaden con
//     un toque (o arrastrándolas al panel izquierdo).
//
// Lo avanzado (variante, dividir, unir, notas) vive en el menú de cada
// tarjeta, para que la vista de siempre esté limpia.
import 'package:flutter/material.dart';

import '../../data/chord_parser.dart';
import '../../models/app_state.dart';
import 'widgets/header_badge.dart';

/// Una sección de la canción: la letra vive aquí, una sola vez.
class _Sec {
  final String id;
  String name;
  SectionKind kind;
  List<String> lines;

  /// Directivas ChordPro originales, si el cuerpo vino en modo literal.
  String? open;
  String? close;
  _Sec({required this.id, required this.name, required this.kind, this.lines = const [], this.open, this.close});

  _Sec copia() => _Sec(id: id, name: name, kind: kind, lines: List.of(lines), open: open, close: close);
}

/// Una aparición de una sección en el orden de toque.
class _Ref {
  String sectionId;
  int repeat;
  String? note;
  _Ref({required this.sectionId, this.repeat = 1, this.note});
}

/// Foto del estado para deshacer / rehacer.
class _Snapshot {
  final List<_Sec> secs;
  final List<_Ref> arr;
  _Snapshot(this.secs, this.arr);
}

class StructureTab extends StatefulWidget {
  /// Cuerpo ChordPro (se sincroniza en los dos sentidos).
  final TextEditingController controller;

  /// Orden de toque guardado (`Song.structure`).
  final List<String>? initialStructure;
  final ValueChanged<List<String>?> onStructureChanged;

  const StructureTab({super.key, required this.controller, required this.initialStructure, required this.onStructureChanged});

  @override
  State<StructureTab> createState() => _StructureTabState();
}

class _StructureTabState extends State<StructureTab> {
  late List<_Sec> _secs;
  late List<_Ref> _arr;
  bool _pushing = false;
  final List<_Snapshot> _undo = [];
  final List<_Snapshot> _redo = [];

  @override
  void initState() {
    super.initState();
    _cargar();
    widget.controller.addListener(_onBodyChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onBodyChanged);
    super.dispose();
  }

  void _cargar() {
    final bloques = _partirTexto(widget.controller.text);
    _secs = [
      for (final b in bloques)
        _Sec(id: uid(), name: b.name, kind: _tipoDe(b.name), lines: List.of(b.content), open: b.open, close: b.close),
    ];
    final mapa = widget.initialStructure;
    _arr = [];
    if (mapa != null && mapa.isNotEmpty) {
      for (final h in mapa) {
        final sec = _porNombre(h);
        if (sec != null) _arr.add(_Ref(sectionId: sec.id));
      }
    }
    if (_arr.isEmpty) _arr = [for (final s in _secs) _Ref(sectionId: s.id)];
    _undo.clear();
    _redo.clear();
  }

  void _onBodyChanged() {
    if (_pushing) return;
    final antes = _arr.map((r) => _secPorId(r.sectionId)?.name ?? '').toList();
    final refs = _arr.toList();
    final bloques = _partirTexto(widget.controller.text);
    setState(() {
      _secs = [
        for (final b in bloques)
          _Sec(id: uid(), name: b.name, kind: _tipoDe(b.name), lines: List.of(b.content), open: b.open, close: b.close),
      ];
      final porClave = <String, _Sec>{};
      for (final s in _secs) {
        porClave.putIfAbsent(_clave(s.name), () => s);
      }
      _arr = [];
      for (var i = 0; i < refs.length; i++) {
        final nombre = i < antes.length ? antes[i] : '';
        final sec = porClave[_clave(nombre)];
        if (sec != null) _arr.add(_Ref(sectionId: sec.id, repeat: refs[i].repeat, note: refs[i].note));
      }
      if (_arr.isEmpty) _arr = [for (final s in _secs) _Ref(sectionId: s.id)];
    });
  }

  // ------------------------------------------------------------- utilidades

  String _clave(String s) {
    var t = s.trim().toLowerCase();
    t = t.replaceAll('á', 'a').replaceAll('é', 'e').replaceAll('í', 'i').replaceAll('ó', 'o').replaceAll('ú', 'u').replaceAll('ü', 'u').replaceAll('ñ', 'n');
    return t.replaceAll(RegExp(r'\s+'), ' ');
  }

  _Sec? _porNombre(String nombre) {
    for (final s in _secs) {
      if (_clave(s.name) == _clave(nombre)) return s;
    }
    return null;
  }

  _Sec? _secPorId(String id) {
    for (final s in _secs) {
      if (s.id == id) return s;
    }
    return null;
  }

  String _nombreDe(String id) => _secPorId(id)?.name ?? '';

  int _vecesUsada(String id) => _arr.where((r) => r.sectionId == id).length;

  /// Secciones que aún no suenan: las del panel derecho.
  /// Panel derecho: TODAS las secciones (el mismo catalogo que en el panel
  /// izquierdo), para poder arrastrarlas al orden aunque ya suenen.
  List<_Sec> get _disponibles => List.of(_secs);
  String _pista(_Sec sec) {
    final n = sec.lines.where((l) => l.trim().isNotEmpty).length;
    return n == 0 ? 'sin letra aún' : '$n líneas';
  }

  // ------------------------------------------------ deshacer / rehacer

  _Snapshot _foto() {
    final s = _secs.map((e) => e.copia()).toList();
    final r = _arr.map((e) => _Ref(sectionId: e.sectionId, repeat: e.repeat, note: e.note)).toList();
    return _Snapshot(s, r);
  }

  void _guardarFoto() {
    _undo.add(_foto());
    if (_undo.length > 40) _undo.removeAt(0);
    _redo.clear();
  }

  void _deshacer() {
    if (_undo.isEmpty) return;
    final snap = _undo.removeLast();
    _redo.add(_foto());
    _secs = snap.secs;
    _arr = snap.arr;
    _empujar();
  }

  void _rehacer() {
    if (_redo.isEmpty) return;
    final snap = _redo.removeLast();
    _undo.add(_foto());
    _secs = snap.secs;
    _arr = snap.arr;
    _empujar();
  }

  // ---------------------------------------------------- guardar el texto

  String _texto() => _secs.map((s) {
        final out = <String>[];
        if (s.open != null && s.open!.trim().isNotEmpty) out.add(s.open!);
        if (s.name.isNotEmpty && s.open == null) out.add(s.name);
        out.addAll(s.lines);
        if (s.close != null && s.close!.trim().isNotEmpty) out.add(s.close!);
        return out.join('\n');
      }).join('\n');

  List<String> _orden() {
    final out = <String>[];
    for (final r in _arr) {
      final sec = _secPorId(r.sectionId);
      if (sec == null) continue;
      for (var i = 0; i < r.repeat; i++) {
        out.add(sec.name);
      }
    }
    return out;
  }

  void _empujar() {
    _pushing = true;
    widget.controller.text = _texto();
    _pushing = false;
    widget.onStructureChanged(_orden());
    setState(() {});
  }

  // ------------------------------------------------------------ acciones

  /// Añade una sección de las disponibles al final del orden.
  void _anadir(_Sec sec) {
    _guardarFoto();
    setState(() {
      _arr.add(_Ref(sectionId: sec.id));
      _empujar();
    });
  }

  void _quitarDelOrden(int index) {
    _guardarFoto();
    setState(() {
      _arr.removeAt(index);
      _empujar();
    });
  }

  void _cambiarRepeticiones(int index, int delta) {
    final nuevo = (_arr[index].repeat + delta).clamp(1, 8);
    if (nuevo == _arr[index].repeat) return;
    _guardarFoto();
    setState(() {
      _arr[index].repeat = nuevo;
      _empujar();
    });
  }

  void _reordenar(int viejo, int nuevo) {
    _guardarFoto();
    setState(() {
      final item = _arr.removeAt(viejo);
      _arr.insert(nuevo > viejo ? nuevo - 1 : nuevo, item);
      _empujar();
    });
  }

  Future<void> _nuevaSeccion() async {
    final nombre = await showDialog<String>(
      context: context,
      builder: (_) => _DialogoNuevaSeccion(crear: (v) => Navigator.pop(context, v)),
    );
    final etiqueta = (nombre ?? '').trim();
    if (etiqueta.isEmpty) return;
    _guardarFoto();
    final sec = _Sec(id: uid(), name: etiqueta, kind: _tipoDe(etiqueta), lines: <String>[]);
    setState(() {
      _secs.add(sec);
      _arr.add(_Ref(sectionId: sec.id));
      _empujar();
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sección creada. Escribe su letra en la pestaña Contenido.')));
    }
  }

  Future<void> _eliminarSeccion(_Sec sec) async {
    final usos = _vecesUsada(sec.id);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Eliminar "${sec.name}"'),
        content: Text(usos == 0
            ? 'Se borrará la sección y su letra. Se puede deshacer.'
            : 'Esta sección suena $usos ${usos == 1 ? 'vez' : 'veces'} en el orden. Se quitarán esas apariciones y se borrará la letra. Se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok != true) return;
    _guardarFoto();
    setState(() {
      _arr.removeWhere((r) => r.sectionId == sec.id);
      _secs.removeWhere((s) => s.id == sec.id);
      _empujar();
    });
  }

  /// Convierte una aparición en una copia independiente de la sección.
  void _hacerVariante(int index) {
    final sec = _secPorId(_arr[index].sectionId);
    if (sec == null) return;
    _guardarFoto();
    setState(() {
      var nombre = '${sec.name} (variante)';
      var n = 2;
      while (_porNombre(nombre) != null) {
        nombre = '${sec.name} (variante $n)';
        n++;
      }
      final copia = _Sec(id: uid(), name: nombre, kind: sec.kind, lines: List.of(sec.lines));
      _secs.add(copia);
      _arr[index].sectionId = copia.id;
      _empujar();
    });
  }

  Future<void> _dividir(_Sec sec) async {
    if (sec.lines.length < 2) return;
    final corte = await showDialog<int>(context: context, builder: (_) => _DialogoDividir(lines: sec.lines));
    if (corte == null || corte <= 0 || corte >= sec.lines.length) return;
    _guardarFoto();
    setState(() {
      final primera = _Sec(id: uid(), name: '${sec.name} (parte 1)', kind: sec.kind, lines: sec.lines.sublist(0, corte));
      final segunda = _Sec(id: uid(), name: '${sec.name} (parte 2)', kind: sec.kind, lines: sec.lines.sublist(corte));
      final at = _secs.indexOf(sec);
      _secs.remove(sec);
      _secs.insert(at, segunda);
      _secs.insert(at, primera);
      final nuevoArr = <_Ref>[];
      for (final r in _arr) {
        if (r.sectionId == sec.id) {
          for (var i = 0; i < r.repeat; i++) {
            nuevoArr.add(_Ref(sectionId: primera.id, note: r.note));
            nuevoArr.add(_Ref(sectionId: segunda.id));
          }
        } else {
          nuevoArr.add(r);
        }
      }
      _arr
        ..clear()
        ..addAll(nuevoArr);
      _empujar();
    });
  }

  Future<void> _unir(_Sec sec) async {
    if (_secs.length < 2) return;
    final otra = await showDialog<_Sec>(
      context: context,
      builder: (_) => _DialogoUnir(secs: _secs.where((s) => s.id != sec.id).toList()),
    );
    if (otra == null) return;
    _guardarFoto();
    setState(() {
      sec.lines.addAll(otra.lines);
      _secs.remove(otra);
      for (final r in _arr) {
        if (r.sectionId == otra.id) r.sectionId = sec.id;
      }
      _empujar();
    });
  }

  Future<void> _ponerNota(int index) async {
    final c = TextEditingController(text: _arr[index].note ?? '');
    final nota = await showDialog<String>(
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
    if (nota == null) return;
    _guardarFoto();
    setState(() {
      _arr[index].note = nota.trim().isEmpty ? null : nota.trim();
      _empujar();
    });
  }

  // --------------------------------------------------------------- vista

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.of(context).size.width;
    final dosColumnas = ancho >= 620;

    return Column(children: [
      // Cabecera
      Container(
        width: double.infinity,
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.account_tree, size: 18),
            const SizedBox(width: 8),
            const Text('Arma tu estructura', style: TextStyle(fontWeight: FontWeight.bold)),
            const Spacer(),
            IconButton(tooltip: 'Deshacer', visualDensity: VisualDensity.compact, icon: const Icon(Icons.undo, size: 20), onPressed: _undo.isEmpty ? null : _deshacer),
            IconButton(tooltip: 'Rehacer', visualDensity: VisualDensity.compact, icon: const Icon(Icons.redo, size: 20), onPressed: _redo.isEmpty ? null : _rehacer),
          ]),
          const Text(
            'Toca una sección de la derecha para añadirla al orden. Arrastra dentro del panel izquierdo para cambiarlo de sitio.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ]),
      ),
      Expanded(
        child: dosColumnas
            ? Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [_panelActual(flex: 5), _panelDisponibles(flex: 4)])
            : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [_panelActual(flex: 3), _panelDisponibles(flex: 2)]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
        child: OutlinedButton.icon(onPressed: _nuevaSeccion, icon: const Icon(Icons.add), label: const Text('Crear sección nueva')),
      ),
    ]);
  }

  /// Panel izquierdo: el orden de toque.
  Widget _panelActual({required int flex}) => Expanded(
        flex: flex,
        child: DragTarget<String>(
          onWillAcceptWithDetails: (_) => true,
          onAcceptWithDetails: (d) {
            final sec = _secPorId(d.data);
            if (sec != null) _anadir(sec);
          },
          builder: (context, candidate, rejected) => Container(
            margin: const EdgeInsets.only(right: 6, top: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: candidate.isNotEmpty ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outlineVariant),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _tituloPanel(Icons.queue_music, 'Estructura actual', '${_arr.length} partes'),
              Expanded(
                child: _arr.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Aún no suena nada. Añade secciones desde la derecha.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                      )
                    : ReorderableListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        itemCount: _arr.length,
                        onReorder: _reordenar,
                        itemBuilder: (context, i) => _TarjetaOrden(
                          key: ValueKey('orden${i}_${_arr[i].sectionId}'),
                          index: i,
                          nombre: _nombreDe(_arr[i].sectionId),
                          repeat: _arr[i].repeat,
                          nota: _arr[i].note,
                          pista: _pistaDe(_arr[i].sectionId),
                          onMenos: () => _cambiarRepeticiones(i, -1),
                          onMas: () => _cambiarRepeticiones(i, 1),
                          onQuitar: () => _quitarDelOrden(i),
                          onVariante: () => _hacerVariante(i),
                          onDividir: () {
                            final sec = _secPorId(_arr[i].sectionId);
                            if (sec != null) _dividir(sec);
                          },
                          onUnir: () {
                            final sec = _secPorId(_arr[i].sectionId);
                            if (sec != null) _unir(sec);
                          },
                          onNota: () => _ponerNota(i),
                          onEliminar: () {
                            final sec = _secPorId(_arr[i].sectionId);
                            if (sec != null) _eliminarSeccion(sec);
                          },
                        ),
                      ),
              ),
            ]),
          ),
        ),
      );

  /// Panel derecho: secciones que aún no suenan.
  Widget _panelDisponibles({required int flex}) => Expanded(
        flex: flex,
        child: Container(
          margin: const EdgeInsets.only(left: 0, top: 6),
          decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerLowest, borderRadius: BorderRadius.circular(12), border: Border.all(color: Theme.of(context).colorScheme.outlineVariant)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _tituloPanel(Icons.library_music, 'Secciones', '${_disponibles.length} en total'),
            Expanded(
              child: _disponibles.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('An no hay secciones. Crea una con el botn de abajo.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      itemCount: _disponibles.length,
                      itemBuilder: (context, i) {
                        final sec = _disponibles[i];
                        return _TarjetaDisponible(
                          key: ValueKey('disp_${sec.id}'),
                          nombre: sec.name,
                          pista: _pista(sec),
                          onAnadir: () => _anadir(sec),
                          onEliminar: () => _eliminarSeccion(sec),
                        );
                      },
                    ),
            ),
          ]),
        ),
      );

  Widget _tituloPanel(IconData icono, String titulo, String contador) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
        child: Row(children: [
          Icon(icono, size: 16),
          const SizedBox(width: 8),
          Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold)),
          const Spacer(),
          Text(contador, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ]),
      );

  String _pistaDe(String id) {
    final sec = _secPorId(id);
    return sec == null ? '' : _pista(sec);
  }
}

/// Ancho fijo del grupo de controles: así los botones de todas las tarjetas
/// caen en la misma columna, sin importar cuánto mida el chip de la sección.
const double _anchoControles = 176;

/// Tarjeta de una aparición en el orden de toque.
class _TarjetaOrden extends StatelessWidget {
  final int index;
  final String nombre;
  final int repeat;
  final String? nota;
  final String pista;
  final VoidCallback onMenos;
  final VoidCallback onMas;
  final VoidCallback onQuitar;
  final VoidCallback onVariante;
  final VoidCallback onDividir;
  final VoidCallback onUnir;
  final VoidCallback onNota;
  final VoidCallback onEliminar;

  const _TarjetaOrden({
    super.key,
    required this.index,
    required this.nombre,
    required this.repeat,
    this.nota,
    required this.pista,
    required this.onMenos,
    required this.onMas,
    required this.onQuitar,
    required this.onVariante,
    required this.onDividir,
    required this.onUnir,
    required this.onNota,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 6, 10, 6),
        child: Row(children: [
          ReorderableDragStartListener(index: index, child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.drag_handle, color: Colors.grey, size: 20))),
          const SizedBox(width: 4),
          Expanded(child: Align(alignment: Alignment.centerLeft, child: HeaderBadge(line: nombre.isEmpty ? '(texto inicial)' : nombre))),
          SizedBox(
            width: _anchoControles,
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              IconButton(visualDensity: VisualDensity.compact, tooltip: 'Suena menos veces', icon: const Icon(Icons.remove, size: 18), onPressed: onMenos),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text('x$repeat', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              IconButton(visualDensity: VisualDensity.compact, tooltip: 'Suena más veces', icon: const Icon(Icons.add, size: 18), onPressed: onMas),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                tooltip: 'Más opciones',
                icon: const Icon(Icons.more_vert, size: 20),
                onSelected: (v) {
                  switch (v) {
                    case 'variante':
                      onVariante();
                    case 'dividir':
                      onDividir();
                    case 'unir':
                      onUnir();
                    case 'nota':
                      onNota();
                    case 'quitar':
                      onQuitar();
                    case 'eliminar':
                      onEliminar();
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'variante', child: Text('Hacer variante (copia independiente)')),
                  PopupMenuItem(value: 'dividir', child: Text('Dividir la sección en dos')),
                  PopupMenuItem(value: 'unir', child: Text('Unir con otra sección')),
                  PopupMenuItem(value: 'nota', child: Text('Poner una nota')),
                  PopupMenuItem(value: 'quitar', child: Text('Quitar del orden')),
                  PopupMenuItem(value: 'eliminar', child: Text('Eliminar la sección')),
                ],
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Tarjeta de una sección que aún no está en el orden.
class _TarjetaDisponible extends StatelessWidget {
  final String nombre;
  final String pista;
  final VoidCallback onAnadir;
  final VoidCallback onEliminar;
  const _TarjetaDisponible({super.key, required this.nombre, required this.pista, required this.onAnadir, required this.onEliminar});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onAnadir,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 10, 8),
          child: Row(children: [
            LongPressDraggable<String>(
              data: nombre,
              feedback: Material(color: Colors.transparent, child: SizedBox(width: 220, child: HeaderBadge(line: nombre))),
              child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.drag_handle, color: Colors.grey, size: 20)),
            ),
            const SizedBox(width: 6),
            Expanded(child: Align(alignment: Alignment.centerLeft, child: HeaderBadge(line: nombre.isEmpty ? '(texto inicial)' : nombre))),
            SizedBox(
              width: _anchoControles,
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                Flexible(
                  child: Text(pista, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                ),
                const SizedBox(width: 10),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Añadir al orden',
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                  onPressed: onAnadir,
                ),
                const SizedBox(width: 2),
                PopupMenuButton<String>(
                  tooltip: 'Más opciones',
                  icon: const Icon(Icons.more_vert, size: 18),
                  onSelected: (v) {
                    if (v == 'eliminar') onEliminar();
                  },
                  itemBuilder: (_) => const [PopupMenuItem(value: 'eliminar', child: Text('Eliminar la sección'))],
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Diálogo para elegir por qué línea se corta una sección.
/// Dialogo para crear una seccion nueva: lista desplegable con los tipos que
/// puede tener una cancion, mas el numero o un nombre libre.
class _DialogoNuevaSeccion extends StatefulWidget {
  final ValueChanged<String> crear;
  const _DialogoNuevaSeccion({required this.crear});

  @override
  State<_DialogoNuevaSeccion> createState() => _DialogoNuevaSeccionState();
}

/// Tipos de seccion que se le ofrecen al usuario.
const _tiposSeccion = <({String valor, String etiqueta})>[
  (valor: 'INTRODUCCION', etiqueta: 'Introduccion'),
  (valor: 'VERSO', etiqueta: 'Verso'),
  (valor: 'PRE-CORO', etiqueta: 'Pre-coro'),
  (valor: 'CORO', etiqueta: 'Coro'),
  (valor: 'PUENTE', etiqueta: 'Puente'),
  (valor: 'INTERLUDIO', etiqueta: 'Interludio'),
  (valor: 'INSTRUMENTAL', etiqueta: 'Instrumental'),
  (valor: 'TRANSICION', etiqueta: 'Transicion'),
  (valor: 'FINAL', etiqueta: 'Final'),
  (valor: 'OUTRO', etiqueta: 'Outro'),
];

class _DialogoNuevaSeccionState extends State<_DialogoNuevaSeccion> {
  String _tipo = 'VERSO';
  final _numero = TextEditingController(text: '2');
  final _libre = TextEditingController();
  bool _conNumero = true;

  @override
  void dispose() {
    _numero.dispose();
    _libre.dispose();
    super.dispose();
  }

  void _crear() {
    if (_conNumero) {
      final n = _numero.text.trim();
      widget.crear(n.isEmpty ? _tipo : '$_tipo $n');
    } else {
      final libre = _libre.text.trim();
      if (libre.isNotEmpty) widget.crear(libre);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Nueva seccion'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            DropdownButtonFormField<String>(
              initialValue: _tipo,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Tipo de seccion'),
              items: [for (final t in _tiposSeccion) DropdownMenuItem(value: t.valor, child: Text(t.etiqueta))],
              onChanged: (v) {
                if (v != null) setState(() => _tipo = v);
              },
            ),
            const SizedBox(height: 12),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Con numero')),
                ButtonSegment(value: false, label: Text('Nombre libre')),
              ],
              selected: {_conNumero},
              onSelectionChanged: (v) => setState(() => _conNumero = v.first),
            ),
            const SizedBox(height: 12),
            if (_conNumero)
              TextField(
                controller: _numero,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Numero', hintText: '2'),
              )
            else
              TextField(
                controller: _libre,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Nombre', hintText: 'Solo de guitarra'),
              ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: _crear, child: const Text('Crear')),
        ],
      );
}
class _DialogoDividir extends StatefulWidget {
  final List<String> lines;
  const _DialogoDividir({required this.lines});

  @override
  State<_DialogoDividir> createState() => _DialogoDividirState();
}

class _DialogoDividirState extends State<_DialogoDividir> {
  late int corte = (widget.lines.length / 2).ceil().clamp(1, widget.lines.length - 1);

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Dividir sección'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: widget.lines.length,
            itemBuilder: (context, i) => RadioListTile<int>(
              value: i + 1,
              groupValue: corte,
              dense: true,
              title: Text(widget.lines[i].trim().isEmpty ? '(línea vacía)' : widget.lines[i], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
              onChanged: (v) => setState(() => corte = v!),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, corte), child: const Text('Dividir')),
        ],
      );
}

/// Diálogo para elegir con qué otra sección se une.
class _DialogoUnir extends StatelessWidget {
  final List<_Sec> secs;
  const _DialogoUnir({required this.secs});

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Unir con otra sección'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final s in secs)
                ListTile(
                  leading: HeaderBadge(line: s.name),
                  title: Text(s.name.isEmpty ? '(texto inicial)' : s.name),
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

/// Parte el cuerpo en secciones, conservando las directivas originales.
class _Bloque {
  final String id;
  final String name;
  final List<String> content;
  final String? open;
  final String? close;
  _Bloque({required this.id, required this.name, this.content = const [], this.open, this.close});
}

final _cierreDir = RegExp(r'^\s*\{\s*end(?:_of)?_[a-z_]+\s*\}\s*$', caseSensitive: false);

String _nombreDe(String linea) {
  final t = linea.trim();
  if (t.isEmpty) return '';
  final parsed = parseSong(t);
  if (parsed.length == 1 && parsed.first.label.trim() != 'Inicio') return parsed.first.label;
  return t;
}

List<_Bloque> _partirTexto(String texto) {
  final lineas = texto.replaceAll('\r', '').split('\n');
  final bloques = <_Bloque>[];
  _Bloque? actual;
  String? cierrePendiente;
  for (final linea in lineas) {
    final t = linea.trim();
    if (_cierreDir.hasMatch(t)) {
      cierrePendiente = t;
      continue;
    }
    if (isSectionHeader(linea)) {
      actual = _Bloque(
        id: uid(),
        name: _nombreDe(linea),
        content: [],
        open: isChordProSectionStart(linea) ? t : null,
        close: cierrePendiente,
      );
      cierrePendiente = null;
      bloques.add(actual);
      continue;
    }
    if (actual != null) {
      actual.content.add(linea);
      continue;
    }
    if (t.isNotEmpty) {
      actual = _Bloque(id: uid(), name: '', content: [linea]);
      bloques.add(actual);
    }
  }
  return bloques;
}

SectionKind _tipoDe(String nombre) {
  final secs = parseSong(nombre);
  return secs.isEmpty ? SectionKind.other : secs.first.kind;
}
