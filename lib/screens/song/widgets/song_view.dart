// Widgets de dibujado de la canción: chips de sección y cuerpo con letra y
// acordes. Son puro render: no manejan estado propio.
import 'package:flutter/material.dart';

import '../../../data/chord_parser.dart';
import '../../../theme.dart';

/// Color por tipo de sección (chips y encabezados).
Color sectionKindColor(SectionKind k) {
  switch (k) {
    case SectionKind.verse: return AppColors.primary;
    case SectionKind.chorus: return AppColors.warm;
    case SectionKind.prechorus: return AppColors.accent;
    case SectionKind.bridge: return AppColors.bridge;
    case SectionKind.intro: return const Color(0xFFE6C15C);
    case SectionKind.outro: return const Color(0xFFE6739F);
    case SectionKind.ending: return const Color(0xFFE5606B);
    case SectionKind.other: return Colors.grey;
  }
}

/// Fila horizontal de chips circulares con las secciones de la canción.
/// Cada sección es un círculo con su abreviatura (v1, c1, p1…) y el color de
/// su tipo; al tocarla salta a esa sección.
class SectionChips extends StatelessWidget {
  final List<Section> sections;
  /// Devuelve la opacidad del fondo del círculo para cada sección.
  final double Function(Section sec) alphaOf;
  /// Al tocar una sección salta a ella. Si es null, los chips no hacen nada.
  final void Function(Section sec)? onSelect;
  final double spacing;
  final double fontSize;
  final double verticalPadding;
  const SectionChips({super.key, required this.sections, required this.alphaOf, this.onSelect, this.spacing = 8, this.fontSize = 13, this.verticalPadding = 2});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: verticalPadding),
      child: Row(children: [
        for (final sec in sections)
          Padding(
            padding: EdgeInsets.only(right: spacing),
            child: Tooltip(
              message: sec.label,
              child: InkResponse(
                radius: 28,
                onTap: onSelect == null ? null : () => onSelect!(sec),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: sectionKindColor(sec.kind).withValues(alpha: (alphaOf(sec) + 0.22).clamp(0.0, 1.0)),
                    border: Border.all(color: sectionKindColor(sec.kind).withValues(alpha: 0.9), width: 1.5),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(sec.abbr.toLowerCase(), style: TextStyle(fontSize: fontSize.clamp(9.0, 13.0), fontWeight: FontWeight.bold, color: sectionKindColor(sec.kind))),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

/// Una línea de canción: acordes transpuestos encima de su palabra, o solo
/// texto si está en modo "solo letra".
class SongLineView extends StatelessWidget {
  final SongLine line;
  final bool lyricsOnly;
  final int semitones;
  final double fontSize;
  final double chordScale;
  final double lineHeight;
  final double chordLineHeight;

  /// true = notación americana (C, G, Am); false = latina (Do, Sol, Lam).
  final bool american;
  const SongLineView({super.key, required this.line, required this.lyricsOnly, required this.semitones, required this.fontSize, this.chordScale = 0.85, this.lineHeight = 1.35, this.chordLineHeight = 1.1, this.american = true});

  @override
  Widget build(BuildContext context) {
    if (lyricsOnly) {
      return Text(
        line.map((x) => x.text).join().replaceAll(RegExp(r'\s+'), ' ').trim(),
        style: TextStyle(fontSize: fontSize, height: lineHeight, color: Colors.white),
      );
    }
    return Wrap(spacing: 0, children: [
      for (final seg in line)
        Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(seg.chord != null ? notateChord(transposeChord(seg.chord!, semitones), american: american) : (line.any((x) => x.chord != null) ? ' ' : ''), style: TextStyle(fontSize: fontSize * chordScale, height: chordLineHeight, fontWeight: FontWeight.bold, color: const Color(0xFF5AD1E6), fontFamily: 'monospace')),
          Text(seg.text.isEmpty ? ' ' : seg.text, style: TextStyle(fontSize: fontSize, height: lineHeight, color: Colors.white)),
        ]),
    ]);
  }
}

/// Encabezado de sección (badge de color + etiqueta).
class SectionHeader extends StatelessWidget {
  final Section sec;
  final double fontSize;
  final double gap;
  final double letterSpacing;
  const SectionHeader({super.key, required this.sec, this.fontSize = 11, this.gap = 8, this.letterSpacing = 1.5});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: sectionKindColor(sec.kind).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
        child: Text(sec.abbr, style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: sectionKindColor(sec.kind))),
      ),
      SizedBox(width: gap),
      Text(sec.label.toUpperCase(), style: TextStyle(color: Colors.grey, fontSize: fontSize, letterSpacing: letterSpacing)),
    ]);
  }
}

/// Cuerpo de la canción en la vista normal (desplazamiento libre).
class SongBodyList extends StatelessWidget {
  final List<Section> sections;
  final bool lyricsOnly;
  final int semitones;
  final double fontSize;
  final bool american;

  /// Controlador de scroll (para saltar a secciones desde las chips).
  final ScrollController? controller;

  /// Claves por id de sección para calcular la posición de cada una.
  final Map<String, GlobalKey>? sectionKeys;
  const SongBodyList({super.key, required this.sections, required this.lyricsOnly, required this.semitones, required this.fontSize, this.american = true, this.controller, this.sectionKeys});

  @override
  Widget build(BuildContext context) {
    return ListView(controller: controller, padding: const EdgeInsets.all(16), children: [
      for (final sec in sections) ...[
        Padding(
          key: sectionKeys?[sec.id],
          padding: EdgeInsets.zero,
          child: SectionHeader(sec: sec),
        ),
        const SizedBox(height: 6),
        for (final line in sec.lines)
          line.isEmpty
              ? const SizedBox(height: 10)
              : Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: SongLineView(line: line, lyricsOnly: lyricsOnly, semitones: semitones, fontSize: fontSize, american: american),
                ),
        const SizedBox(height: 26),
      ],
      if (sections.isEmpty) const Text('Esta canción aún no tiene letra.'),
    ]);
  }
}