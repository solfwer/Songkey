// Widgets de dibujado de la canción: chips de sección, cuerpo con letra y
// acordes (vista normal y modo "ajustar todo"), y barra de navegación del
// modo ajustado. Son puro render: no manejan estado propio.
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

/// Fila horizontal de chips con las secciones de la canción.
class SectionChips extends StatelessWidget {
  final List<Section> sections;
  /// Devuelve la opacidad del fondo del chip para cada sección (para
  /// resaltar la página activa en el modo "ajustar todo").
  final double Function(Section sec) alphaOf;
  /// Al tocar una sección (scroll en vista normal, salto de página en modo
  /// "ajustar todo"). Si es null, los chips no hacen nada.
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
            child: ActionChip(
              backgroundColor: sectionKindColor(sec.kind).withValues(alpha: alphaOf(sec)),
              side: BorderSide(color: sectionKindColor(sec.kind).withValues(alpha: 0.7)),
              label: Text(sec.abbr, style: TextStyle(color: sectionKindColor(sec.kind), fontWeight: FontWeight.bold, fontSize: fontSize)),
              onPressed: onSelect == null ? null : () => onSelect!(sec),
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

/// Una columna de página en el modo "ajustar todo" (se puede dividir en dos
/// columnas en horizontal/tablet).
class FitPageColumn extends StatelessWidget {
  final List<Section> sections;
  final bool lyricsOnly;
  final int semitones;
  final double fontSize;
  final bool american;
  const FitPageColumn({super.key, required this.sections, required this.lyricsOnly, required this.semitones, required this.fontSize, this.american = true});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final sec in sections) ...[
            SectionHeader(sec: sec, fontSize: 10, gap: 6, letterSpacing: 1.2),
            const SizedBox(height: 4),
            for (final line in sec.lines)
              line.isEmpty
                  ? const SizedBox(height: 6)
                  : Padding(
                      padding: const EdgeInsets.symmetric(vertical: 0.5),
                      child: SongLineView(line: line, lyricsOnly: lyricsOnly, semitones: semitones, fontSize: fontSize, chordScale: 0.8, lineHeight: 1.2, chordLineHeight: 1.0, american: american),
                    ),
            const SizedBox(height: 16),
          ],
          if (sections.isEmpty)
            Center(child: Padding(padding: const EdgeInsets.all(32), child: Text('Esta canción aún no tiene letra.', style: TextStyle(fontSize: fontSize, color: Colors.grey)))),
        ],
      ),
    );
  }
}

/// Indicador inferior de navegación del modo "ajustar todo".
class FitNavBar extends StatelessWidget {
  final int fitPage;
  final int pages;

  /// Botón para salir del modo presentación (null = sin botón).
  final VoidCallback? onExit;
  const FitNavBar({super.key, required this.fitPage, required this.pages, this.onExit});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chevron_left, color: fitPage > 0 ? AppColors.primary : Colors.grey),
            const SizedBox(width: 8),
            Flexible(
              child: Text('Toca los lados ◀ ▶ · Flechas / Pedal', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: fitPage < pages - 1 ? AppColors.primary : Colors.grey),
            if (onExit != null) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.fullscreen_exit, size: 20),
                tooltip: 'Salir del modo presentación',
                onPressed: onExit,
              ),
            ],
          ],
        ),
      ),
    );
  }
}