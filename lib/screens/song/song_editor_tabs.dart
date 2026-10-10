// Pestañas "Contenido" y "Vista previa" del editor.
//
// Contenido rene las dos formas de editar la misma letra con acordes:
//  * Editor visual: se tocan las lneas (deshacer/rehacer, mover acorde...).
//  * ChordPro: texto con la sintaxis resaltada y, en pantalla ancha, vista
//    previa en vivo al lado.
// Las dos editan el mismo controlador, as que lo que se escribe en un modo
// se ve en el otro y en la vista previa.
import 'package:flutter/material.dart';

import '../../../data/chord_parser.dart';
import '../../../data/store.dart';
import 'widgets/song_view.dart';
import 'widgets/visual_chord_editor.dart';

class ContentTab extends StatefulWidget {
  final TextEditingController body;
  final TextEditingController songKey;
  final int visualRevision;
  final ValueChanged<String> onVisualChanged;
  final Store store;
  final VoidCallback onSave;
  const ContentTab({required this.body, required this.songKey, required this.visualRevision, required this.onVisualChanged, required this.store, required this.onSave});

  @override
  State<ContentTab> createState() => _ContentTabState();
}

class _ContentTabState extends State<ContentTab> {
  /// ltimo modo usado: se recuerda entre aperturas del editor.
  late bool _visualMode = widget.store.editorVisualMode;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 700;
    return Column(children: [
      // Selector de modo
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
        child: SizedBox(
          width: double.infinity,
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, icon: Icon(Icons.touch_app, size: 16), label: Text('Editor visual')),
              ButtonSegment(value: false, icon: Icon(Icons.code, size: 16), label: Text('ChordPro')),
            ],
            selected: {_visualMode},
            showSelectedIcon: false,
            onSelectionChanged: (v) {
              setState(() => _visualMode = v.first);
              widget.store.setEditorVisualMode(v.first);
            },
          ),
        ),
      ),
      Expanded(
        child: _visualMode
            ? VisualChordEditor(
                key: ValueKey('visual${widget.visualRevision}'),
                initialBody: widget.body.text,
                songKey: widget.songKey.text,
                onChanged: widget.onVisualChanged,
              )
            : _ChordProEditor(controller: widget.body, wide: wide),
      ),
      // Guardar funciona igual en los dos modos.
      SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
          child: FilledButton.icon(
            onPressed: widget.onSave,
            icon: const Icon(Icons.save, size: 18),
            label: const Text('Guardar'),
          ),
        ),
      ),
    ]);
  }
}

/// Editor de texto ChordPro con la sintaxis resaltada: directivas en amarillo,
/// acordes en azul y encabezados de seccin en naranja.
class _ChordProEditor extends StatefulWidget {
  final TextEditingController controller;
  final bool wide;
  const _ChordProEditor({required this.controller, required this.wide});

  @override
  State<_ChordProEditor> createState() => _ChordProEditorState();
}

class _ChordProEditorState extends State<_ChordProEditor> {
  late final _SyntaxController _local;

  @override
  void initState() {
    super.initState();
    _local = _SyntaxController(text: widget.controller.text);
    _local.addListener(_push);
    widget.controller.addListener(_pull);
  }

  @override
  void dispose() {
    _local.removeListener(_push);
    widget.controller.removeListener(_pull);
    _local.dispose();
    super.dispose();
  }

  bool _pushing = false;

  void _push() {
    _pushing = true;
    widget.controller.text = _local.text;
    _pushing = false;
  }

  /// El cuerpo cambi desde fuera (importar PDF, editor visual...): se
  /// refresca el texto sin perder el cursor si no haca falta.
  void _pull() {
    if (_pushing) return;
    if (widget.controller.text == _local.text) return;
    final sel = _local.selection;
    _local.value = TextEditingValue(text: widget.controller.text, selection: TextSelection.collapsed(offset: widget.controller.text.length));
    if (sel.baseOffset <= _local.text.length) {
      _local.selection = sel;
    }
  }

  @override
  Widget build(BuildContext context) {
    final editor = TextField(
      controller: _local,
      maxLines: null,
      expands: true,
      textAlignVertical: TextAlignVertical.top,
      style: const TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.45),
      decoration: const InputDecoration(
        contentPadding: EdgeInsets.all(14),
        border: InputBorder.none,
        hintText: 'Escribe la letra con acordes\n\n{start_of_verse: VERSO 1}\nHola [C]mundo\n{end_of_verse}',
        hintStyle: TextStyle(fontFamily: 'monospace', fontSize: 12),
      ),
    );

    if (!widget.wide) {
      return Container(color: Colors.black12, child: editor);
    }

    // Pantalla ancha: editor a la izquierda, vista previa en vivo a la derecha.
    return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(flex: 5, child: Container(color: Colors.black12, child: editor)),
      const VerticalDivider(width: 1),
      Expanded(
        flex: 4,
        child: Material(
          color: Colors.transparent,
          child: _LivePreview(text: widget.controller.text),
        ),
      ),
    ]);
  }
}

/// Colores del resaltado de sintaxis ChordPro.
const _colorDirective = Color(0xFFE6C15C); // {start_of_verse: ...}
const _colorChord = Color(0xFF5AD1E6); // [C#m]
const _colorHeader = Color(0xFFE5606B); // VERSO 1 (encabezado en texto plano)

/// Controlador que pinta el texto con la sintaxis ChordPro resaltada.
class _SyntaxController extends TextEditingController {
  _SyntaxController({super.text});

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    return TextSpan(style: style, children: _spansFor(text));
  }
}

List<TextSpan> _spansFor(String text) {
  final out = <TextSpan>[];
  final re = RegExp(r'(\{[^{}]*\})|(\[[^\[\]]*\])');
  var last = 0;
  for (final m in re.allMatches(text)) {
    if (m.start > last) {
      out.addAll(_plainSpans(text.substring(last, m.start)));
    }
    final isDirective = m.group(1) != null;
    out.add(TextSpan(
      text: m.group(0),
      style: TextStyle(
        color: isDirective ? _colorDirective : _colorChord,
        fontWeight: FontWeight.bold,
      ),
    ));
    last = m.end;
  }
  if (last < text.length) out.addAll(_plainSpans(text.substring(last)));
  return out;
}

/// Texto normal, resaltando las lneas que son encabezados de seccin.
List<TextSpan> _plainSpans(String text) {
  final lines = text.split('\n');
  return [
    for (var i = 0; i < lines.length; i++) ...[
      if (i > 0) const TextSpan(text: '\n'),
      TextSpan(
        text: lines[i],
        style: isSectionHeader(lines[i])
            ? const TextStyle(color: _colorHeader, fontWeight: FontWeight.bold, letterSpacing: 1.2)
            : null,
      ),
    ],
  ];
}

/// Vista previa en vivo de la pestaa "Contenido" (pantalla ancha).
class _LivePreview extends StatelessWidget {
  final String text;
  const _LivePreview({required this.text});

  @override
  Widget build(BuildContext context) {
    final sections = sectionsInOrder(text, null);
    return Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        color: Colors.white10,
        width: double.infinity,
        child: const Text('VISTA PREVIA', style: TextStyle(fontSize: 10, letterSpacing: 1.5, color: Colors.grey, fontWeight: FontWeight.bold)),
      ),
      Expanded(
        child: sections.isEmpty
            ? const Center(child: Text('An no hay letra', style: TextStyle(color: Colors.grey)))
            : SongBodyList(sections: sections, lyricsOnly: false, semitones: 0, fontSize: 14, american: true),
      ),
    ]);
  }
}

/// Pestaa 4: cmo queda la cancin al guardarse.
class PreviewTab extends StatefulWidget {
  final TextEditingController body;
  final List<String>? structure;
  final TextEditingController songKey;
  final TextEditingController title;
  const PreviewTab({required this.body, required this.structure, required this.songKey, required this.title});

  @override
  State<PreviewTab> createState() => _PreviewTabState();
}

class _PreviewTabState extends State<PreviewTab> {
  @override
  void initState() {
    super.initState();
    widget.body.addListener(_onChanged);
    widget.title.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.body.removeListener(_onChanged);
    widget.title.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final sections = sectionsInOrder(widget.body.text, widget.structure);
    final label = widget.title.text.trim().isEmpty ? 'Sin ttulo' : widget.title.text.trim();
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Column(children: [
          Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text('Tono: ${widget.songKey.text.trim().isEmpty ? 'C' : widget.songKey.text.trim()}', style: const TextStyle(color: Colors.grey)),
        ]),
      ),
      const Divider(height: 12),
      Expanded(
        child: sections.isEmpty
            ? const Center(child: Text('An no hay letra para mostrar.'))
            : SongBodyList(sections: sections, lyricsOnly: false, semitones: 0, fontSize: 15, american: true),
      ),
    ]);
  }
}
