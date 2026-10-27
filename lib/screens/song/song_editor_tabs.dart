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
import '../../../data/chordpro.dart';
import '../../../data/store.dart';
import 'widgets/song_view.dart';
import 'widgets/visual_chord_editor.dart';

class ContentTab extends StatefulWidget {
  final TextEditingController body;
  final TextEditingController songKey;
  final int visualRevision;
  final ValueChanged<String> onVisualChanged;
  final Store store;
  const ContentTab({required this.body, required this.songKey, required this.visualRevision, required this.onVisualChanged, required this.store});

  @override
  State<ContentTab> createState() => _ContentTabState();
}

class _ContentTabState extends State<ContentTab> {
  /// ltimo modo usado: se recuerda entre aperturas del editor.
  late bool _visualMode = widget.store.editorVisualMode;

  /// Cambio de modo. Si el texto ChordPro tiene errores, se avisa con el
  /// nmero de lnea y se deja elegir: quedarse en ChordPro o seguir (lo que no
  /// se entienda se descarta, pero nada se pierde en silencio).
  Future<void> _changeMode(bool visual) async {
    if (visual == _visualMode) return;
    if (visual) {
      final parser = ChordProParser()..parse(widget.body.text);
      if (parser.issues.isNotEmpty) {
        final seguir = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('El texto tiene cosas que no se entienden'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('En el editor visual estas partes se van a descartar:', style: TextStyle(fontSize: 13)),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final issue in parser.issues.take(8))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text('Lnea ${issue.line}: ${issue.message}', style: const TextStyle(fontSize: 12, color: Colors.orangeAccent)),
                        ),
                    ],
                  ),
                ),
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Quedarme en ChordPro')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Continuar')),
            ],
          ),
        );
        if (seguir != true) return;
      }
    }
    setState(() => _visualMode = visual);
    widget.store.setEditorVisualMode(visual);
  }

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
              ButtonSegment(value: true, label: Text('Editor visual')),
              ButtonSegment(value: false, label: Text('ChordPro')),
            ],
            selected: {_visualMode},
            showSelectedIcon: false,
            onSelectionChanged: (v) => _changeMode(v.first),
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
            : ChordProEditor(controller: widget.body, wide: wide, songKey: widget.songKey.text),
      ),
      // El botn de guardar est en la barra inferior del editor, fuera de
      // aqu, para que se vea en todas las pestaas.

    ]);
  }
}

/// Editor de texto ChordPro con la sintaxis resaltada: directivas en amarillo,
/// acordes en azul y encabezados de seccin en naranja.
class ChordProEditor extends StatefulWidget {
  final TextEditingController controller;
  final bool wide;

  /// Numeros de linea (1-based) que se resaltan con fondo naranja para que
  /// el usuario vea de un vistazo lo que tiene que revisar.
  final Set<int> warningLines;

  /// Tonalidad de la canción (para mostrar la barra de acordes rápidos).
  /// Si es null no se muestra la barra.
  final String? songKey;
  const ChordProEditor({super.key, required this.controller, required this.wide, this.warningLines = const {}, this.songKey});

  @override
  State<ChordProEditor> createState() => _ChordProEditorState();
}

class _ChordProEditorState extends State<ChordProEditor> {
  late final ChordSyntaxController _local;

  @override
  void initState() {
    super.initState();
    _local = ChordSyntaxController(text: widget.controller.text)..warningLines = widget.warningLines;
    _local.addListener(_push);
    widget.controller.addListener(_pull);
  }

  /// Inserta [acorde] entre corchetes en la posición del cursor del editor.
  void _insertarAcorde(String acorde) {
    final sel = _local.selection;
    final inicio = sel.start.clamp(0, _local.text.length);
    _local.value = TextEditingValue(
      text: _local.text.replaceRange(inicio, inicio, '[$acorde]'),
      selection: TextSelection.collapsed(offset: inicio + acorde.length + 2),
    );
  }

  /// Fila de chips de acordes de la tonalidad para insertar tocando.
  Widget _buildAcordeBar(String songKey) {
    final grupos = quickBarChords(songKey);
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Text('Acorde:', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
          for (final acorde in grupos.scale) ...[
            const SizedBox(width: 4),
            _ChipAcordeSimple(acorde: acorde, onTap: () => _insertarAcorde(acorde)),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    _local.removeListener(_push);
    widget.controller.removeListener(_pull);
    _local.dispose();
    super.dispose();
  }

  bool _pushing = false;

  @override
  void didUpdateWidget(covariant ChordProEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_mismoSet(oldWidget.warningLines, widget.warningLines)) {
      _local.warningLines = widget.warningLines;
      setState(() {});
    }
  }

  bool _mismoSet(Set<int> a, Set<int> b) => a.length == b.length && a.containsAll(b);

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

    Widget editorConBarra = editor;
    if (widget.songKey != null && widget.songKey!.isNotEmpty) {
      editorConBarra = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildAcordeBar(widget.songKey!),
          const SizedBox(height: 4),
          Expanded(child: editor),
        ],
      );
    }

    final fondo = Theme.of(context).colorScheme.surfaceContainerLowest;
    if (!widget.wide) {
      return Container(color: fondo, child: editorConBarra);
    }

    // Pantalla ancha: editor a la izquierda, vista previa en vivo a la derecha.
    return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(flex: 5, child: Container(color: fondo, child: editorConBarra)),
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
class ChordSyntaxController extends TextEditingController {
  /// Lineas (1-based) que se pintan con fondo de aviso.
  Set<int> warningLines = const {};
  ChordSyntaxController({super.text});

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    return TextSpan(style: style, children: chordSyntaxSpans(text, warningLines: warningLines));
  }
}

/// Convierte el texto en spans coloreados: directivas en amarillo, acordes en
/// azul, encabezados de seccion en rojo. Las lineas de [warningLines] llevan
/// fondo naranja para que se vea lo que hay que revisar.
List<TextSpan> chordSyntaxSpans(String text, {Set<int> warningLines = const {}}) {
  final lines = text.split('\n');
  final out = <TextSpan>[];
  for (var i = 0; i < lines.length; i++) {
    if (i > 0) out.add(const TextSpan(text: '\n'));
    final fondoAviso = warningLines.contains(i + 1) ? const Color(0x55FFB300) : null;
    out.addAll(_spansDeLinea(lines[i], fondoAviso));
  }
  return out;
}

/// Spans de una linea suelta.
List<TextSpan> _spansDeLinea(String line, Color? fondo) {
  final spans = <TextSpan>[];
  final re = RegExp(r'(\{[^{}]*\})|(\[[^\[\]]*\])');
  var last = 0;
  for (final m in re.allMatches(line)) {
    if (m.start > last) spans.add(_spanTexto(line.substring(last, m.start), fondo));
    final esDirectiva = m.group(1) != null;
    spans.add(TextSpan(
      text: m.group(0),
      style: TextStyle(
        color: esDirectiva ? _colorDirective : _colorChord,
        fontWeight: FontWeight.bold,
        backgroundColor: fondo,
      ),
    ));
    last = m.end;
  }
  if (last < line.length) spans.add(_spanTexto(line.substring(last), fondo));
  return spans;
}

/// Texto sin acordes: si la linea entera es un encabezado, se pone en rojo.
TextSpan _spanTexto(String t, Color? fondo) {
  if (isSectionHeader(t)) {
    return TextSpan(text: t, style: TextStyle(color: _colorHeader, fontWeight: FontWeight.bold, letterSpacing: 1.2, backgroundColor: fondo));
  }
  return TextSpan(text: t, style: TextStyle(backgroundColor: fondo));
}
class _ChipAcordeSimple extends StatelessWidget {
  final String acorde;
  final VoidCallback onTap;
  const _ChipAcordeSimple({required this.acorde, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(8),
    onTap: onTap,
    child: Container(
      constraints: const BoxConstraints(minWidth: 42),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Text(
        acorde,
        style: TextStyle(fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
      ),
    ),
  );
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
