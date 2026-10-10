// Editor visual de acordes: se toca una linea de la letra y luego un acorde
// de la barra rpida, sin hace falta saber la sintaxis ChordPro.
//
//  * Barra rpida arriba: acordes de la tonalidad, inversiones y variantes
//    del acorde marcado, ms el boton `[]` para escribirlo a mano.
//  * Deshacer / rehacer.
//  * Flechas para mover el acorde o la linea seleccionados.
//  * Encabezados de seccion con su badge de color.
import 'package:flutter/material.dart';

import '../../../data/chord_parser.dart';
import '../../../theme.dart';
import 'chord_quick_bar.dart';
import 'header_badge.dart';
import 'song_view.dart';

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

  // Clave por linea para obtener su RenderBox real (el contexto del
  // itemBuilder apunta al Sliver, no al item).
  final Map<int, GlobalKey> _lineKeys = {};

  // Pilas de deshacer / rehacer.
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

  // --- Interaccion ---

  /// Tocar una linea la selecciona y fija el punto de insercion. Los encabezados
  /// se saltan (no llevan acordes).
  void _onLineTap(int lineIdx, TapDownDetails details, GlobalKey lineKey) {
    if (widget.readOnly) return;
    if (lineIdx < 0 || lineIdx >= _lyricLines.length) return;
    final line = _lyricLines[lineIdx];
    if (isSectionHeader(line)) return;

    final box = lineKey.currentContext?.findRenderObject() as RenderBox?;
    var charIdx = line.length;
    if (box != null && box.attached) {
      final offset = box.globalToLocal(details.globalPosition);
      // Descontar el prefijo visual: padding izq (8) + numero de linea (36) + hueco (8).
      const prefix = 52.0;
      final textPainter = TextPainter(
        text: TextSpan(text: line, style: const TextStyle(fontFamily: 'monospace', fontSize: 16)),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: (box.size.width - prefix - 8).clamp(40.0, double.infinity));
      final adjusted = Offset((offset.dx - prefix).clamp(0.0, double.infinity), offset.dy);
      charIdx = textPainter.getPositionForOffset(adjusted).offset.clamp(0, line.length);
    }

    setState(() {
      _selectedLine = lineIdx;
      _tapCharIndex = charIdx;
      _selectedChordIdx = _findChordAt(lineIdx, charIdx);
    });
  }

  int _findChordAt(int lineIdx, int charIdx) {
    for (var i = 0; i < _chords.length; i++) {
      if (_chords[i].lineIndex == lineIdx && _chords[i].charIndex == charIdx) return i;
    }
    return -1;
  }

  /// Linea sobre la que se inserta: la elegida, o la primera con letra.
  int get _lineaDeInsercion {
    if (_selectedLine >= 0 && _selectedLine < _lyricLines.length && !isSectionHeader(_lyricLines[_selectedLine])) {
      return _selectedLine;
    }
    for (var i = 0; i < _lyricLines.length; i++) {
      if (!isSectionHeader(_lyricLines[i])) return i;
    }
    return -1;
  }

  /// Inserta (o cambia) el acorde elegido en la barra rapida.
  void _insertarAcorde(String chord) {
    final lineIdx = _lineaDeInsercion;
    if (lineIdx < 0) return;
    _saveSnapshot();
    setState(() {
      if (_selectedChordIdx >= 0 && _selectedChordIdx < _chords.length) {
        // Habia un acorde marcado: se sustituye.
        _chords[_selectedChordIdx] = _chords[_selectedChordIdx].copyWith(chord: chord);
      } else {
        _chords.add(PositionedChord(lineIndex: lineIdx, charIndex: _tapCharIndex.clamp(0, _lyricLines[lineIdx].length), chord: chord));
        _selectedChordIdx = _chords.length - 1;
        _selectedLine = lineIdx;
      }
      _chords.sort((a, b) => a.lineIndex != b.lineIndex ? a.lineIndex.compareTo(b.lineIndex) : a.charIndex.compareTo(b.charIndex));
    });
    _notifyChange();
  }

  /// El boton `[]`: escribe el acorde a mano y se inserta igual.
  void _pedirAcordeAMano() {
    final lineIdx = _lineaDeInsercion;
    if (lineIdx < 0) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom),
        child: ManualChordField(
          onSubmit: (chord) {
            _insertarAcorde(chord);
            Navigator.pop(ctx);
          },
        ),
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
        // Barra de herramientas
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
                    Expanded(
                      child: Text(
                        _selectedChordIdx >= 0 ? 'Acorde marcado: ${_chords[_selectedChordIdx].chord}' : 'Editor visual de acordes',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      const Padding(padding: EdgeInsets.only(left: 8, right: 4), child: Text('Mover acorde / linea:', style: TextStyle(color: Colors.grey, fontSize: 12))),
                      IconButton(icon: const Icon(Icons.chevron_left), tooltip: 'Mover acorde ←', visualDensity: VisualDensity.compact, onPressed: _selectedChordIdx >= 0 ? () => _nudgeSelected(-1) : null),
                      IconButton(icon: const Icon(Icons.chevron_right), tooltip: 'Mover acorde →', visualDensity: VisualDensity.compact, onPressed: _selectedChordIdx >= 0 ? () => _nudgeSelected(1) : null),
                      Container(width: 1, height: 24, margin: const EdgeInsets.symmetric(horizontal: 6), color: Colors.grey),
                      IconButton(icon: const Icon(Icons.keyboard_arrow_up), tooltip: 'Subir de linea', visualDensity: VisualDensity.compact, onPressed: _selectedChordIdx >= 0 ? () => _moveSelectedLine(-1) : null),
                      IconButton(icon: const Icon(Icons.keyboard_arrow_down), tooltip: 'Bajar de linea', visualDensity: VisualDensity.compact, onPressed: _selectedChordIdx >= 0 ? () => _moveSelectedLine(1) : null),
                      if (_selectedChordIdx >= 0) ...[
                        Container(width: 1, height: 24, margin: const EdgeInsets.symmetric(horizontal: 6), color: Colors.grey),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          tooltip: 'Quitar el acorde marcado',
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            _saveSnapshot();
                            setState(() {
                              _chords.removeAt(_selectedChordIdx);
                              _selectedChordIdx = -1;
                              _selectedLine = -1;
                            });
                            _notifyChange();
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        // Barra rapida de acordes: se toca una linea y luego un acorde.
        if (!widget.readOnly)
          ChordQuickBar(
            songKey: widget.songKey,
            selectedChord: _selectedChordIdx >= 0 && _selectedChordIdx < _chords.length ? _chords[_selectedChordIdx].chord : null,
            lineNumber: _lineaDeInsercion >= 0 ? _lineaDeInsercion : null,
            onPick: _insertarAcorde,
            onManual: _pedirAcordeAMano,
          ),
        // Area de letra
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
                      // Numero de linea (con badge de color en los encabezados
                      // de seccion, para que se lean igual que en la vista)
                      if (isHeader) ...[
                        HeaderBadge(line: line),
                        const SizedBox(width: 8),
                      ] else ...[
                        SizedBox(width: 36, child: Text('${i + 1}', style: mono.copyWith(fontSize: 12, color: Colors.grey))),
                        const SizedBox(width: 8),
                      ],
                      // Texto con acordes superpuestos como chips
                      Expanded(
                        child: _LyricLineWithChords(
                          line: line,
                          chords: lineChords,
                          selectedIdx: _selectedChordIdx >= 0 && _selectedChordIdx < _chords.length && _chords[_selectedChordIdx].lineIndex == i ? _chords.indexOf(_chords[_selectedChordIdx]) : -1,
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

/// Linea de letra con chips de acordes insertados en su posicion visual.
/// Cada chip lleva un margen para que dos acordes seguidos no se peguen.
class _LyricLineWithChords extends StatelessWidget {
  final String line;
  final List<PositionedChord> chords;
  final int selectedIdx; // ndice dentro de `chords`
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
        child: Padding(
          // Margen a los lados: as dos acordes seguidos se pueden separar y
          // cada uno tiene su sitio para tocarlo.
          padding: const EdgeInsets.symmetric(horizontal: 4),
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
        ),
      ));
      last = idx;
    }
    if (last < line.length) spans.add(TextSpan(text: line.substring(last), style: style));
    return Text.rich(TextSpan(children: spans, style: style));
  }
}
