// Pantalla de revisin de una cancin recin importada desde PDF.
//
// Ensea el ChordPro generado (con las lneas sospechosas resaltadas), la
// vista previa de cmo quedar, y la lista de advertencias. El usuario puede
// corregir el texto, el ttulo y el tono antes de guardar.
import 'package:flutter/material.dart';

import '../../data/chord_parser.dart';
import '../../data/store.dart';
import '../../models/app_state.dart';
import '../../models/song.dart';
import '../../services/pdf_chordpro/pdf_models.dart';
import '../../services/pdf_chordpro/pdf_to_chordpro_service.dart';
import 'song_editor_tabs.dart' show ChordProEditor;
import 'widgets/song_view.dart';

class PdfReviewPage extends StatefulWidget {
  final Store store;
  final PdfConversion conversion;
  final String? initialGroupId;

  const PdfReviewPage({super.key, required this.store, required this.conversion, this.initialGroupId});

  @override
  State<PdfReviewPage> createState() => _PdfReviewPageState();
}

class _PdfReviewPageState extends State<PdfReviewPage> {
  late final TextEditingController _body = TextEditingController(text: widget.conversion.chordPro);
  late final TextEditingController _title = TextEditingController(text: widget.conversion.title);
  late final TextEditingController _key = TextEditingController(text: widget.conversion.suggestedKey ?? 'C');
  late Set<int> _warningLines;

  @override
  void initState() {
    super.initState();
    _warningLines = widget.conversion.warnings.map((w) => w.line).where((l) => l > 0).toSet();
    _body.addListener(_recalcularAvisos);
  }

  @override
  void dispose() {
    _body.removeListener(_recalcularAvisos);
    _body.dispose();
    _title.dispose();
    _key.dispose();
    super.dispose();
  }

  /// Las advertencias apuntan a lneas del texto original: si el usuario
  /// corrige y la lnea deja de tener problemas, el aviso se quita solo.
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

  void _guardar() {
    final titulo = _title.text.trim();
    if (titulo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ponle un ttulo a la cancin.')));
      return;
    }
    final song = Song(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: titulo,
      key: _key.text.trim().isEmpty ? 'C' : _key.text.trim(),
      body: _body.text,
      groupId: widget.initialGroupId,
    );
    widget.store.update((s) => AppState(
          groups: s.groups,
          songs: [song, ...s.songs],
          setlists: s.setlists,
        ));
    Navigator.of(context).pop(song);
  }

  @override
  Widget build(BuildContext context) {
    final avisos = widget.conversion.warnings;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Revisar importacin'),
        actions: [
          TextButton.icon(
            onPressed: _guardar,
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Guardar'),
          ),
        ],
      ),
      body: Column(children: [
        // Ttulo y tono sugerido
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Ttulo', isDense: true),
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
              if (avisos.length > 6) Text('- y ${avisos.length - 6} ms', style: const TextStyle(fontSize: 11.5, color: Colors.orangeAccent)),
            ]),
          ),
        const Divider(height: 1),
        // Editor y vista previa
        Expanded(
          child: Row(children: [
            Expanded(
              flex: 5,
              child: ChordProEditor(controller: _body, wide: true, warningLines: _warningLines),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              flex: 4,
              child: Column(children: [
                Container(
                  width: double.infinity,
                  color: Colors.white10,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: const Text('VISTA PREVIA', style: TextStyle(fontSize: 10, letterSpacing: 1.5, color: Colors.grey, fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _body,
                    builder: (context, value, _) {
                      final secs = sectionsInOrder(value.text, null);
                      if (secs.isEmpty) {
                        return const Center(child: Text('An no hay letra', style: TextStyle(color: Colors.grey)));
                      }
                      return SongBodyList(sections: secs, lyricsOnly: false, semitones: 0, fontSize: 14, american: true);
                    },
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}
