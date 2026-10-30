// Editor de canción con tres pestañas:
//  1. Texto (ChordPro): editor de texto clásico.
//  2. Editor visual: edición tocando las líneas.
//  3. Estructura de la canción: solo se edita la estructura (título, orden,
//     duplicar, eliminar, añadir); la letra y los acordes se editan en las
//     pestañas Texto y Editor visual.
import 'package:flutter/material.dart';

import '../../data/chordpro.dart';
import '../../data/chord_parser.dart';
import '../../services/metronome.dart';
import '../../data/store.dart';
import '../../models/app_state.dart';
import '../../models/setlist.dart';
import '../../models/song.dart';
import '../../services/metadata/chord_key_detector.dart';
import 'widgets/pdf_import_button.dart';
import 'song_editor_tabs.dart';
import 'structure_tab.dart';

class SongEditorPage extends StatefulWidget {
  final Store store;
  final Song? song;
  final String? initialGroupId;
  final String?
      setlistId; // Si no es null, guarda como override en este setlist

  /// Borrador inicial (sin canción guardada todavía) para importaciones de PDF
  /// o documentos ChordPro. Solo se usa si [song] es null.
  final String? initialTitle;
  final String? initialBody;
  const SongEditorPage(
      {super.key,
      required this.store,
      this.song,
      this.initialGroupId,
      this.initialTitle,
      this.initialBody,
      this.setlistId});

  @override
  State<SongEditorPage> createState() => _SongEditorPageState();
}

class _SongEditorPageState extends State<SongEditorPage>
    with SingleTickerProviderStateMixin {
  late final TextEditingController title;
  late final TextEditingController key;
  late final TextEditingController bpm;
  late final TextEditingController author;
  late final TextEditingController body;
  late final TextEditingController timeSignature;
  String? groupId;
  List<String>? _structure;
  late TabController _tabCtrl;

  /// Detector de tonalidad a partir de los acordes (offline).
  final ChordKeyDetector _keyDetector = ChordKeyDetector();

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
    fill(timeSignature, meta.time);
  }

  /// Detecta la tonalidad a partir de los acordes del texto (offline, sin
  /// internet) y la pone en el campo "Tono". Lo dispara el usuario con el botón.
  void _detectarTono() {
    final texto = body.text;
    final det = texto.trim().isEmpty ? null : _keyDetector.detect(texto);
    final detectado = (det != null && det.key != null && det.confidence >= 0.3)
        ? det.key!
        : null;
    if (detectado != null) {
      setState(() => key.text = detectado);
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(detectado != null
          ? 'Tono detectado por los acordes: $detectado'
          : 'No hay acordes suficientes para detectar el tono'),
      duration: const Duration(seconds: 3),
    ));
  }

  @override
  void initState() {
    super.initState();
    title = TextEditingController(
        text: widget.song?.title ?? widget.initialTitle ?? '');
    key = TextEditingController(text: widget.song?.key ?? 'C');
    bpm = TextEditingController(text: widget.song?.bpm?.toString() ?? '');
    author = TextEditingController(text: widget.song?.author ?? '');
    body = TextEditingController(
        text: widget.song?.body ?? widget.initialBody ?? '');
    timeSignature =
        TextEditingController(text: widget.song?.timeSignature ?? '');
    // Canciones antiguas sin author/bpm guardados: se sacan de las directivas.
    if (widget.song != null) _syncMetaFromBody();
    _bodyInicial = body.text;
    groupId = widget.song?.groupId ?? widget.initialGroupId;
    _structure = widget.song?.structure?.toList();
    _tabCtrl = TabController(length: 4, vsync: this);
    body.addListener(_onBodyTextChanged);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    body.removeListener(_onBodyTextChanged);
    for (final c in [title, key, bpm, author, body, timeSignature]) {
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
    setState(() {
      _visualRev++;
      _guardado = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final groups = widget.store.state.groups;
    return PopScope(
      canPop: !_hayCambios,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmarSalida();
      },
      child: Scaffold(
        // El botn de guardar vive aqu, fuera de las pestaas: as se ve siempre
        // (tambin en ChordPro y en el editor visual) y no estorba al escribir.
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
            child: FilledButton.icon(
              onPressed: save,
              icon: Icon(_guardado ? Icons.check : Icons.save, size: 18),
              label: Text(_guardado ? 'Guardado' : 'Guardar'),
              style: _guardado
                  ? FilledButton.styleFrom(backgroundColor: Colors.green)
                  : null,
            ),
          ),
        ),
        appBar: AppBar(
          title: Text(widget.song == null ? 'Nueva canción' : 'Editar canción'),
          bottom: TabBar(
            controller: _tabCtrl,
            isScrollable: false,
            tabs: const [
              Tab(text: 'Datos'),
              Tab(text: 'Contenido'),
              Tab(text: 'Estructura'),
              Tab(text: 'Vista'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabCtrl,
          children: [
            // Pestaña 1: Datos de la canción
          SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      Expanded(
                        child: TextField(
                            controller: title,
                            decoration:
                                const InputDecoration(labelText: 'Título')),
                      ),
                      const SizedBox(width: 6),
                      OutlinedButton(
                        onPressed: _detectarTono,
                        style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8)),
                        child:
                            const Text('Tono', style: TextStyle(fontSize: 12)),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    TextField(
                        controller: author,
                        decoration: const InputDecoration(
                            labelText: 'Autor (opcional)')),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: key.text.isEmpty ? 'C' : key.text,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Tono'),
                          items: List<DropdownMenuItem<String>>.from(
                            twelveKeys.map((t) => DropdownMenuItem(
                              value: t,
                              child: Text(notateChord(t, american: true)),
                            )),
                          ),
                          onChanged: (v) {
                            if (v != null) setState(() => key.text = v);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: bpm,
                          decoration: InputDecoration(
                              labelText: 'BPM',
                              suffixIcon: _TapTempoIcon(controller: bpm)),
                          keyboardType: TextInputType.number),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: timeSignature.text.isEmpty ? '4/4' : timeSignature.text,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Compás'),
                          items: List<DropdownMenuItem<String>>.from(
                            timeSignatures.map((t) => DropdownMenuItem(
                              value: t.label,
                              child: Text(t.label),
                            )),
                          ),
                          onChanged: (v) {
                            if (v != null) setState(() => timeSignature.text = v);
                          },
                        ),
                      ),
                    ]),
                    const SizedBox(height: 24),
                    PdfImportButton(
                        store: widget.store, initialGroupId: groupId),
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
            ),
            // Pestaña 3: secciones y orden de toque
            StructureTab(
                controller: body,
                initialStructure: _structure,
                onStructureChanged: (v) => _structure = v),
            // Pestaña 4: vista previa de cmo queda la cancin
            PreviewTab(
              body: body,
              structure: _structure,
              songKey: key,
              title: title,
            ),
          ],
        ),
      ),
    );
  }

  /// Texto con el que se abri el editor (para saber si hay cambios sin guardar).
  String _bodyInicial = '';

  /// ¿Hay cambios en la letra que an no se han guardado?
  bool get _hayCambios => body.text != _bodyInicial;

  /// true tras guardar, para que el botn lo confirme (y no se cierra la
  /// pantalla: as se ve claro que se ha guardado).
  bool _guardado = false;

  /// Avisa antes de salir con cambios sin guardar (es la causa ms comn de
  /// "no me guarda los cambios": se vuelve atrs sin pulsar Guardar).
  Future<void> _confirmarSalida() async {
    final salir = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Tienes cambios sin guardar'),
        content: const Text(
            'Si sales ahora se perdern los ltimos cambios en la letra y los acordes.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Seguir editando')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Salir sin guardar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Guardar')),
        ],
      ),
    );
    if (salir == true) {
      if (mounted) Navigator.of(context).pop();
    } else if (salir == null) {
      save();
    }
  }

  /// Deja el cuerpo como lo escribi el usuario y solo pone al principio las
  /// directivas de metadatos (quitando las que ya hubiera, para no duplicar).
  String _cuerpoConMetadatos({
    required String cuerpo,
    required String titulo,
    required String autor,
    required String tono,
    required String tempo,
    String? timeSignature,
  }) {
    final meta = RegExp(
        r'^\s*\{\s*(title|t|subtitle|st|artist|author|composer|key|k|tempo|bpm|time|capo)\s*[:=].*\}\s*$',
        caseSensitive: false);
    final lineas = cuerpo.replaceAll('\r', '').split('\n');
    final resto = <String>[];
    for (final l in lineas) {
      if (meta.hasMatch(l)) continue;
      resto.add(l);
    }
    while (resto.isNotEmpty && resto.first.trim().isEmpty) {
      resto.removeAt(0);
    }
    final cabecera = <String>[
      if (titulo.isNotEmpty) '{title: $titulo}',
      if (autor.isNotEmpty) '{artist: $autor}',
      if (tono.isNotEmpty) '{key: $tono}',
      if (tempo.isNotEmpty) '{tempo: $tempo}',
      if (timeSignature != null && timeSignature.isNotEmpty)
        '{time: $timeSignature}',
    ];
    if (cabecera.isEmpty) return resto.join('\n');
    return [...cabecera, '', ...resto].join('\n');
  }

  void save() {
    if (title.text.trim().isEmpty) return;
    final id = widget.song?.id ?? uid();
    // El cuerpo se guarda SIEMPRE en el formato cannica: los metadatos de la
    // pestaa Datos se escriben como directivas al principio del texto.
    final authorText = author.text.trim();
    final keyText = key.text.trim();
    final bpmText = bpm.text.trim();

    // El cuerpo se guarda TAL CUAL lo ha escrito el usuario (si puso un espacio
    // dentro del corchete, se queda). Lo nico que se aade o se actualiza son
    // las directivas de metadatos del principio, para que no se pierdan.
    final bodyCanonico = _cuerpoConMetadatos(
      cuerpo: body.text,
      titulo: title.text.trim(),
      autor: authorText,
      tono: keyText,
      tempo: bpmText,
    );

    // El controlador se queda con lo que realmente se ha guardado y a partir
    // de aqu ya no hay cambios pendientes.
    body.text = bodyCanonico;
    _bodyInicial = bodyCanonico;

    final song = Song(
      id: id,
      title: title.text.trim(),
      author: authorText.isEmpty ? null : authorText,
      key: keyText.isEmpty ? 'C' : keyText,
      bpm: int.tryParse(bpmText),
      groupId: groupId,
      body: bodyCanonico,
      style: widget.song?.style,
      durationSec: widget.song?.durationSec,
      lastOpenedAt: widget.song?.lastOpenedAt,
      structure: _structure,
      timeSignature:
          timeSignature.text.trim().isEmpty ? null : timeSignature.text.trim(),
    );

    if (widget.setlistId != null) {
      // Guardar como override en el setlist (no toca la canción original)
      final override = SongOverride(
        songId: id,
        title: song.title,
        author: song.author,
        key: song.key,
        bpm: song.bpm,
        body: song.body,
        style: song.style,
        durationSec: song.durationSec,
        structure: song.structure,
      );
      widget.store.update((s) {
        final setlists = s.setlists.map((l) {
          if (l.id != widget.setlistId) return l;
          return l.withOverride(id, override);
        }).toList();
        return AppState(groups: s.groups, songs: s.songs, setlists: setlists);
      });
    } else {
      // Guardar en la biblioteca (comportamiento original)
      widget.store.update((s) {
        final songs = s.songs.any((x) => x.id == id)
            ? s.songs.map((x) => x.id == id ? song : x).toList()
            : [song, ...s.songs];
        return AppState(groups: s.groups, songs: songs, setlists: s.setlists);
      });
    }
    // No se cierra la pantalla: el botn pasa a decir "Guardado" para que se
    // vea claro. Vuelve a "Guardar" en cuanto se toque algo.
    setState(() => _guardado = true);
  }
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
    if (_taps.isNotEmpty && now.difference(_taps.last).inMilliseconds > 3000)
      _taps.clear();
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
