import 'package:flutter/material.dart';

import '../../../data/chord_parser.dart';
import '../../../theme.dart';

/// Widget para editar acordes visualmente sobre la letra.
/// - Tap en una línea → muestra picker de acordes en esa posición.
/// - Flechas ◀ ▶ mueven el acorde seleccionado 1 carácter.
/// - Undo/Redo con botones.
class VisualChordEditor extends StatefulWidget {
  final String initialBody; // cuerpo ChordPro original
  final String songKey; // tonalidad actual
  final ValueChanged<String> onChanged; // callback con nuevo cuerpo ChordPro
  final bool readOnly;
  const VisualChordEditor({super.key, required this.initialBody, required this.songKey, required this.onChanged, this.readOnly = false});

  @override
  State<VisualChordEditor> createState() => _VisualChordEditorState();
}

class _VisualChordEditorState extends State<VisualChordEditor> {
  late List<String> _lyricLines;
  late List<PositionedChord> _chords;
  int _selectedChordIdx = -1;
  int _selectedLine = -1;
  int _tapCharIndex = 0;
  // Clave por línea para obtener su RenderBox real (el contexto del itemBuilder
  // apunta al Sliver, no al ítem).
  final Map<int, GlobalKey> _lineKeys = {};

  // Undo/Redo stacks
  final List<({List<String> lines, List<PositionedChord> chords, int selIdx, int selLine, int tapChar})> _undoStack = [];
  final List<({List<String> lines, List<PositionedChord> chords, int selIdx, int selLine, int tapChar})> _redoStack = [];

  @override
  void initState() {
    super.initState();
    _loadFromBody(widget.initialBody);
  }

  @override
  void didUpdateWidget(covariant VisualChordEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialBody != widget.initialBody) {
      _loadFromBody(widget.initialBody);
    }
  }

  void _loadFromBody(String body) {
    final parsed = chordProToPositioned(body);
    setState(() {
      _lyricLines = parsed.lyricLines;
      _chords = parsed.chords;
      _selectedChordIdx = -1;
      _selectedLine = -1;
      _tapCharIndex = 0;
      _undoStack.clear();
      _redoStack.clear();
    });
  }

  void _saveSnapshot() {
    _undoStack.add((lines: List.from(_lyricLines), chords: List.from(_chords), selIdx: _selectedChordIdx, selLine: _selectedLine, tapChar: _tapCharIndex));
    if (_undoStack.length > 50) _undoStack.removeAt(0);
    _redoStack.clear();
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add((lines: List.from(_lyricLines), chords: List.from(_chords), selIdx: _selectedChordIdx, selLine: _selectedLine, tapChar: _tapCharIndex));
    final snap = _undoStack.removeLast();
    setState(() {
      _lyricLines = snap.lines;
      _chords = snap.chords;
      _selectedChordIdx = snap.selIdx;
      _selectedLine = snap.selLine;
      _tapCharIndex = snap.tapChar;
    });
    _notifyChange();
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add((lines: List.from(_lyricLines), chords: List.from(_chords), selIdx: _selectedChordIdx, selLine: _selectedLine, tapChar: _tapCharIndex));
    final snap = _redoStack.removeLast();
    setState(() {
      _lyricLines = snap.lines;
      _chords = snap.chords;
      _selectedChordIdx = snap.selIdx;
      _selectedLine = snap.selLine;
      _tapCharIndex = snap.tapChar;
    });
    _notifyChange();
  }

  void _notifyChange() {
    widget.onChanged(positionedToChordPro(_lyricLines, _chords));
  }

  // --- Interacción ---
  void _onLineTap(int lineIdx, TapDownDetails details, GlobalKey lineKey) {
    if (widget.readOnly) return;
    if (lineIdx < 0 || lineIdx >= _lyricLines.length) return;
    final line = _lyricLines[lineIdx];
    if (isSectionHeader(line)) return; // no colocar acordes en encabezados

    final box = lineKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return;

    final offset = box.globalToLocal(details.globalPosition);
    // Descontar el prefijo visual: padding izq (8) + número de línea (36) + hueco (8).
    const prefix = 52.0;
    final textPainter = TextPainter(
      text: TextSpan(text: line, style: const TextStyle(fontFamily: 'monospace', fontSize: 16)),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: (box.size.width - prefix - 8).clamp(40.0, double.infinity));
    final adjusted = Offset((offset.dx - prefix).clamp(0.0, double.infinity), offset.dy);
    final pos = textPainter.getPositionForOffset(adjusted);
    final charIdx = pos.offset.clamp(0, line.length);

    setState(() {
      _selectedLine = lineIdx;
      _tapCharIndex = charIdx;
      _selectedChordIdx = _findChordAt(lineIdx, charIdx);
    });
    _showChordPicker(lineIdx, charIdx);
  }

  int _findChordAt(int lineIdx, int charIdx) {
    for (var i = 0; i < _chords.length; i++) {
      if (_chords[i].lineIndex == lineIdx && _chords[i].charIndex == charIdx) return i;
    }
    return -1;
  }

  void _showChordPicker(int lineIdx, int charIdx) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => _ChordPickerSheet(
        currentKey: widget.songKey,
        lyricLine: _lyricLines[lineIdx],
        charIndex: charIdx,
        existingChord: _selectedChordIdx >= 0 ? _chords[_selectedChordIdx].chord : null,
        onPick: (chord) {
          _saveSnapshot();
          setState(() {
            if (_selectedChordIdx >= 0) {
              _chords[_selectedChordIdx] = _chords[_selectedChordIdx].copyWith(chord: chord);
            } else {
              _chords.add(PositionedChord(lineIndex: lineIdx, charIndex: charIdx, chord: chord));
              _selectedChordIdx = _chords.length - 1;
            }
            _chords.sort((a, b) => a.lineIndex != b.lineIndex ? a.lineIndex.compareTo(b.lineIndex) : a.charIndex.compareTo(b.charIndex));
          });
          _notifyChange();
          Navigator.pop(ctx);
        },
        onDelete: _selectedChordIdx >= 0
            ? () {
                _saveSnapshot();
                setState(() {
                  _chords.removeAt(_selectedChordIdx);
                  _selectedChordIdx = -1;
                  _selectedLine = -1;
                });
                _notifyChange();
                Navigator.pop(ctx);
              }
            : null,
      ),
    );
  }

  void _nudgeSelected(int delta) {
    if (_selectedChordIdx < 0) return;
    _saveSnapshot();
    final moved = _chords[_selectedChordIdx];
    final lineLen = _lyricLines[moved.lineIndex].length;
    final updated = moved.copyWith(charIndex: (moved.charIndex + delta).clamp(0, lineLen));
    setState(() {
      _chords[_selectedChordIdx] = updated;
      _chords.sort((a, b) => a.lineIndex != b.lineIndex ? a.lineIndex.compareTo(b.lineIndex) : a.charIndex.compareTo(b.charIndex));
      _selectedChordIdx = _chords.indexWhere((c) => c.lineIndex == updated.lineIndex && c.charIndex == updated.charIndex && c.chord == updated.chord);
    });
    _notifyChange();
  }

  void _moveSelectedLine(int deltaLine) {
    if (_selectedChordIdx < 0) return;
    _saveSnapshot();
    final moved = _chords[_selectedChordIdx];
    final newLine = (moved.lineIndex + deltaLine).clamp(0, _lyricLines.length - 1);
    if (isSectionHeader(_lyricLines[newLine])) return; // no mover a encabezado
    final updated = moved.copyWith(lineIndex: newLine);
    setState(() {
      _chords[_selectedChordIdx] = updated;
      _chords.sort((a, b) => a.lineIndex != b.lineIndex ? a.lineIndex.compareTo(b.lineIndex) : a.charIndex.compareTo(b.charIndex));
      _selectedChordIdx = _chords.indexWhere((c) => c.lineIndex == updated.lineIndex && c.charIndex == updated.charIndex && c.chord == updated.chord);
    });
    _notifyChange();
  }

  @override
  Widget build(BuildContext context) {
    const mono = TextStyle(fontFamily: 'monospace', fontSize: 16, height: 1.5, color: Colors.white);

    return Column(
      children: [
        // Toolbar
        if (!widget.readOnly)
          Container(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
            decoration: BoxDecoration(color: AppColors.card, border: Border(bottom: BorderSide(color: Colors.grey[800]!))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(icon: const Icon(Icons.undo), tooltip: 'Deshacer', visualDensity: VisualDensity.compact, onPressed: _undoStack.isNotEmpty ? _undo : null),
                    IconButton(icon: const Icon(Icons.redo), tooltip: 'Rehacer', visualDensity: VisualDensity.compact, onPressed: _redoStack.isNotEmpty ? _redo : null),
                    const SizedBox(width: 4),
                    const Expanded(child: Text('Editor visual de acordes', overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      const Padding(padding: EdgeInsets.only(left: 8, right: 4), child: Text('Mover acorde / línea:', style: TextStyle(color: Colors.grey, fontSize: 12))),
                      IconButton(icon: const Icon(Icons.chevron_left), tooltip: 'Mover acorde ←', onPressed: _selectedChordIdx >= 0 ? () => _nudgeSelected(-1) : null),
                      IconButton(icon: const Icon(Icons.chevron_right), tooltip: 'Mover acorde →', onPressed: _selectedChordIdx >= 0 ? () => _nudgeSelected(1) : null),
                      Container(width: 1, height: 24, margin: const EdgeInsets.symmetric(horizontal: 6), color: Colors.grey),
                      IconButton(icon: const Icon(Icons.keyboard_arrow_up), tooltip: 'Subir de línea', onPressed: _selectedChordIdx >= 0 ? () => _moveSelectedLine(-1) : null),
                      IconButton(icon: const Icon(Icons.keyboard_arrow_down), tooltip: 'Bajar de línea', onPressed: _selectedChordIdx >= 0 ? () => _moveSelectedLine(1) : null),
                    ],
                  ),
                ),
              ],
            ),
          ),
        // Área de letra
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _lyricLines.length,
            itemBuilder: (_, i) {
              final line = _lyricLines[i];
              final isHeader = isSectionHeader(line);
              final lineChords = _chords.where((c) => c.lineIndex == i).toList()..sort((a, b) => a.charIndex.compareTo(b.charIndex));
              final lineKey = _lineKeys.putIfAbsent(i, () => GlobalKey());
              return GestureDetector(
                onTapDown: widget.readOnly || isHeader ? null : (d) => _onLineTap(i, d, lineKey),
                child: Container(
                  key: lineKey,
                  padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  decoration: BoxDecoration(
                    color: _selectedLine == i ? AppColors.primary.withValues(alpha: 0.15) : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: _selectedLine == i ? Border.all(color: AppColors.primary, width: 1.5) : null,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Número de línea
                      SizedBox(width: 36, child: Text('${i + 1}', style: mono.copyWith(fontSize: 12, color: Colors.grey))),
                      const SizedBox(width: 8),
                      // Texto con acordes superpuestos como chips
                      Expanded(
                        child: _LyricLineWithChords(
                          line: line,
                          chords: lineChords,
                          selectedIdx: _selectedChordIdx >= 0 && _chords[_selectedChordIdx].lineIndex == i ? _chords.indexOf(_chords[_selectedChordIdx]) : -1,
                          style: mono,
                          onChordTap: (chordIdx) {
                            setState(() {
                              _selectedChordIdx = _chords.indexOf(lineChords[chordIdx]);
                              _selectedLine = i;
                              _tapCharIndex = lineChords[chordIdx].charIndex;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Línea de letra con chips de acordes insertados en su posición visual.
class _LyricLineWithChords extends StatelessWidget {
  final String line;
  final List<PositionedChord> chords;
  final int selectedIdx; // índice dentro de `chords`
  final TextStyle style;
  final ValueChanged<int> onChordTap;
  const _LyricLineWithChords({required this.line, required this.chords, required this.selectedIdx, required this.style, required this.onChordTap});

  @override
  Widget build(BuildContext context) {
    if (chords.isEmpty) return Text(line, style: style);

    final spans = <InlineSpan>[];
    int last = 0;
    for (var i = 0; i < chords.length; i++) {
      final c = chords[i];
      final idx = c.charIndex.clamp(0, line.length);
      if (idx > last) {
        spans.add(TextSpan(text: line.substring(last, idx), style: style));
      }
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: GestureDetector(
          onTap: () => onChordTap(i),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: selectedIdx == i ? AppColors.accent : AppColors.primary,
              borderRadius: BorderRadius.circular(4),
              boxShadow: selectedIdx == i ? [BoxShadow(color: AppColors.accent.withValues(alpha: 0.5), blurRadius: 4)] : null,
            ),
            child: Text(c.chord, style: style.copyWith(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ),
      ));
      last = idx;
    }
    if (last < line.length) spans.add(TextSpan(text: line.substring(last), style: style));
    return Text.rich(TextSpan(children: spans, style: style));
  }
}

/// Bottom sheet con acordes diatónicos + extensiones comunes.
class _ChordPickerSheet extends StatelessWidget {
  final String currentKey;
  final String lyricLine;
  final int charIndex;
  final String? existingChord;
  final ValueChanged<String> onPick;
  final VoidCallback? onDelete;
  const _ChordPickerSheet({required this.currentKey, required this.lyricLine, required this.charIndex, this.existingChord, required this.onPick, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final diatonic = diatonicChords(currentKey);
    final firstChord = diatonic.isNotEmpty ? diatonic.first.symbol : currentKey;
    final extensions = commonExtensions(firstChord);
    final preview = lyricLine.length > charIndex ? lyricLine.substring(charIndex) : '';
    final previewShort = preview.length > 20 ? '${preview.substring(0, 20)}…' : preview;

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (ctx, scrollCtrl) => Container(
        padding: const EdgeInsets.all(16),
        child: ListView(
          controller: scrollCtrl,
          children: [
            Row(
              children: [
                const Icon(Icons.music_note, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Insertar acorde en "$previewShort"',
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                ),
                if (onDelete != null)
                  TextButton.icon(icon: const Icon(Icons.delete, color: Colors.redAccent), label: const Text('Eliminar', style: TextStyle(color: Colors.redAccent)), onPressed: onDelete),
              ],
            ),
            const Divider(),
            // Acordes diatónicos
            const Text('Acordes de la tonalidad', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final d in diatonic)
                  _ChordChip(
                    label: '${d.symbol} (${d.degree})',
                    selected: existingChord == d.symbol,
                    onTap: () => onPick(d.symbol),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            // Extensiones comunes
            const Text('Extensiones comunes', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final ext in extensions)
                  _ChordChip(label: ext, selected: existingChord == ext, onTap: () => onPick(ext)),
              ],
            ),
            const SizedBox(height: 16),
            // Entrada manual
            const Text('Otro acorde', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 8),
            _ManualChordInput(onSubmit: onPick),
          ],
        ),
      ),
    );
  }
}

class _ChordChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ChordChip({required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => FilterChip(
        label: Text(label, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
        selected: selected,
        onSelected: (_) => onTap(),
        backgroundColor: AppColors.card,
        selectedColor: AppColors.primary,
        checkmarkColor: Colors.white,
        labelStyle: TextStyle(color: selected ? Colors.white : Colors.white),
      );
}

class _ManualChordInput extends StatefulWidget {
  final ValueChanged<String> onSubmit;
  const _ManualChordInput({required this.onSubmit});
  @override
  State<_ManualChordInput> createState() => _ManualChordInputState();
}

class _ManualChordInputState extends State<_ManualChordInput> {
  final _ctrl = TextEditingController();
  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(child: TextField(controller: _ctrl, decoration: const InputDecoration(hintText: 'Ej: Bm7, F#sus4...'), onSubmitted: (v) { if (v.trim().isNotEmpty) widget.onSubmit(v.trim()); })),
          const SizedBox(width: 8),
          FilledButton(onPressed: () { if (_ctrl.text.trim().isNotEmpty) widget.onSubmit(_ctrl.text.trim()); }, child: const Text('Añadir')),
        ],
      );
}