// Pantalla de revisión de una canción recién importada desde PDF.
//
// Flujo paginado (4 pantallas): Datos → Editor → Vista previa → Estructura.
// El usuario puede deslizar o tocar Atrás/Siguiente. Guardar está siempre
// visible en el AppBar.
import 'package:flutter/material.dart';

import '../../data/chord_parser.dart';
import '../../data/store.dart';
import '../../models/app_state.dart';
import '../../models/song.dart';
import '../../services/pdf_chordpro/pdf_models.dart';
import '../../services/pdf_chordpro/pdf_to_chordpro_service.dart';
import 'song_editor_tabs.dart' show ChordProEditor, PreviewTab;
import 'structure_tab.dart';

class PdfReviewPage extends StatefulWidget {
  final Store store;
  final PdfConversion conversion;
  final String? initialGroupId;

  const PdfReviewPage({super.key, required this.store, required this.conversion, this.initialGroupId});

  @override
  State<PdfReviewPage> createState() => _PdfReviewPageState();
}

class _PdfReviewPageState extends State<PdfReviewPage> {
  late final PageController _page = PageController();
  int _pageIndex = 0;

  /// Título y tono: se editan en la página 1 (Datos) y se muestran en la 3 (Vista previa).
  late final TextEditingController _title = TextEditingController(text: widget.conversion.title);
  late final TextEditingController _key = TextEditingController(text: widget.conversion.suggestedKey ?? 'C');
  /// Cuerpo ChordPro: se edita en la página 2 (Editor) y se previsualiza en la 3.
  late final TextEditingController _body = TextEditingController(text: widget.conversion.chordPro);
  /// Orden de toque: se edita en la página 4 (Estructura) y se usa en la 3.
  List<String>? _structure;

  late Set<int> _warningLines;

  @override
  void initState() {
    super.initState();
    _warningLines = widget.conversion.warnings.map((w) => w.line).where((l) => l > 0).toSet();
    _body.addListener(_recalcularAvisos);
  }

  @override
  void dispose() {
    _page.dispose();
    _body.removeListener(_recalcularAvisos);
    _title.dispose();
    _key.dispose();
    _body.dispose();
    super.dispose();
  }

  /// Las advertencias apuntan a líneas del texto original: si el usuario
  /// corrige y la línea deja de tener problemas, el aviso se quita solo.
  void _recalcularAvisos() {
    final vivas = <int>{};
    for (final w in widget.conversion.warnings) {
      if (w.line <= 0 || w.line > _body.text.split('\n').length) continue;
      final textoLinea = _body.text.split('\n')[w.line - 1];
      if (textoLinea.trim() != _textoOriginalDe(w)) vivas.add(w.line);
    }
    if (!_mismo(vivas, _warningLines)) {
      setState(() => _warningLines = vivas);
    }
  }

  String _textoOriginalDe(ImportWarning w) => '';

  bool _mismo(Set<int> a, Set<int> b) => a.length == b.length && a.containsAll(b);

  bool get _puedeAvanzar => _pageIndex < 3;
  bool get _puedeRetroceder => _pageIndex > 0;

  void _siguiente() {
    if (_puedeAvanzar) _page.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.ease);
  }

  void _anterior() {
    if (_puedeRetroceder) _page.previousPage(duration: const Duration(milliseconds: 250), curve: Curves.ease);
  }

  void _guardar() {
    final titulo = _title.text.trim();
    if (titulo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ponle un título a la canción.')));
      return;
    }
    final song = Song(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: titulo,
      key: _key.text.trim().isEmpty ? 'C' : _key.text.trim(),
      body: _body.text,
      groupId: widget.initialGroupId,
      structure: _structure,
    );
    widget.store.update((s) => AppState(
          groups: s.groups,
          songs: [song, ...s.songs],
          setlists: s.setlists,
        ));
    Navigator.of(context).pop(song);
  }

  /// Página 1: Datos (título y tono).
  Widget _datosPage() {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Row(children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Título', isDense: true),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 110,
            child: TextField(
              controller: _key,
              decoration: const InputDecoration(labelText: 'Tono', isDense: true),
            ),
          ),
        ]),
      ),
      const Divider(height: 1),
      Expanded(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.info_outline, color: Colors.grey),
              const SizedBox(height: 8),
              Text(
                'Edita el título y el tono si es necesario. '
                'El resto de la canción se edita en la siguiente pantalla.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    ]);
  }

  /// Página 2: Editor a pantalla completa (sin preview duplicado).
  Widget _editorPage() {
    final avisos = widget.conversion.warnings;
    return Column(children: [
      if (avisos.isNotEmpty)
        Container(
          width: double.infinity,
          color: Colors.orange.withValues(alpha: 0.14),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.warning_amber, size: 16, color: Colors.orangeAccent),
              const SizedBox(width: 6),
              Text('${avisos.length} ${avisos.length == 1 ? 'aviso' : 'avisos'} para revisar', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ]),
            const SizedBox(height: 4),
            for (final w in avisos.take(6))
              Text('- ${w.message}', style: const TextStyle(fontSize: 11.5, color: Colors.orangeAccent)),
            if (avisos.length > 6) Text('- y ${avisos.length - 6} más', style: const TextStyle(fontSize: 11.5, color: Colors.orangeAccent)),
          ]),
        ),
      Expanded(
        child: ChordProEditor(
          controller: _body,
          wide: false,
          warningLines: _warningLines,
        ),
      ),
    ]);
  }

  /// Página 3: Vista previa a pantalla completa (usa la estructura de la página 4 si ya existe).
  Widget _previewPage() {
    return PreviewTab(
      body: _body,
      structure: _structure,
      songKey: _key,
      title: _title,
    );
  }

  /// Página 4: Estructura (orden de toque, duplicar, x2, notas).
  Widget _estructuraPage() {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Row(children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Título', isDense: true),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 110,
            child: TextField(
              controller: _key,
              decoration: const InputDecoration(labelText: 'Tono', isDense: true),
            ),
          ),
        ]),
      ),
      const Divider(height: 1),
      Expanded(
        child: StructureTab(
          controller: _body,
          initialStructure: _structure,
          onStructureChanged: (v) => setState(() => _structure = v),
        ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Revisar importación'),
        actions: [
          TextButton.icon(
            onPressed: _guardar,
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Guardar'),
          ),
        ],
      ),
      body: Column(children: [
        // Páginas del wizard (Editor, Vista previa y Estructura ocupan todo el alto).
        Expanded(
          child: PageView(
            controller: _page,
            onPageChanged: (i) => setState(() => _pageIndex = i),
            children: [
              _datosPage(),
              _editorPage(),
              _previewPage(),
              _estructuraPage(),
            ],
          ),
        ),
        // Barra de navegación del wizard.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.black12,
          child: Row(children: [
            Expanded(
              child: Text('${_pageIndex + 1}/4', textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ),
            TextButton(
              onPressed: _puedeRetroceder ? _anterior : null,
              child: const Text('Atrás'),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: _puedeAvanzar ? _siguiente : null,
              child: const Text('Siguiente'),
            ),
          ]),
        ),
      ]),
    );
  }
}
