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
/// su tipo; al tocarla salta a esa sección. Si una sección suena varias
/// veces, el círculo lleva un contador (x2).
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
    // Cuntas veces suena cada seccin (para el contador del crculo).
    final counts = <String, int>{};
    for (final sec in sections) {
      counts[sec.label] = (counts[sec.label] ?? 0) + 1;
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: verticalPadding),
      child: Row(children: [
        for (final sec in sections)
          Padding(
            padding: EdgeInsets.only(right: spacing),
            child: Tooltip(
              message: counts[sec.label]! > 1 ? '${sec.label} (x${counts[sec.label]})' : sec.label,
              child: InkResponse(
                radius: 28,
                onTap: onSelect == null ? null : () => onSelect!(sec),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Stack(children: [
                    AnimatedContainer(
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
                    if (counts[sec.label]! > 1)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(color: sectionKindColor(sec.kind), borderRadius: BorderRadius.circular(7)),
                          child: Text('x${counts[sec.label]}', style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.black)),
                        ),
                      ),
                  ]),
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
///
/// Tipos de línea que se reconocen (mismo formato para todas las canciones):
///  - Línea de letra con acordes inline: cada acorde sobre su sílaba.
///  - Fila solo de acordes (`[C#m] | [A] | [E] | [B]`): se dibuja en una sola
///    fila monoespaciada, acordes en azul y barras `|` en gris, como los
///    visores ChordPro estándar.
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

  /// Línea compuesta únicamente por acordes y separadores (`|`, `-`, `–`):
  /// es una "progresión" (intro, interludio) y se pinta en una sola fila.
  bool get _isChordRow {
    if (line.isEmpty) return false;
    final sep = RegExp(r'^[\s|\-–—/·]*$');
    return line.every((s) => s.chord != null && sep.hasMatch(s.text));
  }

  @override
  Widget build(BuildContext context) {
    if (lyricsOnly) {
      // En modo "solo letra" las progresiones de acordes no aportan nada.
      if (_isChordRow) return const SizedBox.shrink();
      return Text(
        line.map((x) => x.text).join().replaceAll(RegExp(r'\s+'), ' ').trim(),
        style: TextStyle(fontSize: fontSize, height: lineHeight, color: Colors.white),
      );
    }
    if (_isChordRow) {
      const chordColor = Color(0xFF5AD1E6);
      return Text.rich(
        TextSpan(
          children: [
            for (final seg in line) ...[
              TextSpan(
                text: notateChord(transposeChord(seg.chord!, semitones), american: american),
                style: TextStyle(fontSize: fontSize * chordScale, fontWeight: FontWeight.bold, color: chordColor),
              ),
              if (seg.text.isNotEmpty)
                TextSpan(
                  text: seg.text,
                  style: TextStyle(fontSize: fontSize * chordScale, color: Colors.white38),
                ),
            ],
          ],
        ),
        style: TextStyle(fontFamily: 'monospace', height: chordLineHeight),
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
      Expanded(
        child: Text(
          sec.label.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: Colors.grey, fontSize: fontSize, letterSpacing: letterSpacing),
        ),
      ),
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

/// true si la línea es solo una progresión de acordes con separadores
/// (`[C#m] | [A] | [E] | [B]`, `G  C  D`...).
bool isChordRowLine(SongLine line) {
  if (line.isEmpty) return false;
  final sep = RegExp(r'^[\s|\-–—/·]*$');
  return line.every((s) => s.chord != null && sep.hasMatch(s.text));
}

/// Vista compacta: cada sección UNA sola vez, con `(x2)` si suena varias
/// veces. Es la que se usa en tarjetas y previsualizaciones; la pantalla de
/// la canción sigue mostrando el orden real de toque con las repeticiones.
class CompactSongView extends StatelessWidget {
  /// Secciones ya en orden de toque (con repeticiones incluidas).
  final List<Section> sections;
  final bool lyricsOnly;
  final int semitones;
  final double fontSize;
  final bool american;
  final int maxLinesPerSection;
  const CompactSongView({
    super.key,
    required this.sections,
    required this.lyricsOnly,
    required this.semitones,
    required this.fontSize,
    this.american = true,
    this.maxLinesPerSection = 3,
  });

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    final unique = <Section>[];
    for (final s in sections) {
      counts[s.label] = (counts[s.label] ?? 0) + 1;
      if (counts[s.label] == 1) unique.add(s);
    }
    if (unique.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final sec in unique) ...[
          SectionHeader(sec: sec, fontSize: (fontSize * 0.7).clamp(8.0, 12.0), gap: 6),
          if ((counts[sec.label] ?? 1) > 1)
            Padding(
              padding: const EdgeInsets.only(left: 2, bottom: 2),
              child: Text('(x${counts[sec.label]})', style: TextStyle(fontSize: fontSize * 0.7, color: Colors.white54, fontStyle: FontStyle.italic)),
            ),
          const SizedBox(height: 2),
          for (final line in sec.lines.take(maxLinesPerSection))
            if (line.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 0.5),
                child: SongLineView(line: line, lyricsOnly: lyricsOnly, semitones: semitones, fontSize: fontSize * 0.85, american: american, lineHeight: 1.2, chordLineHeight: 1.0),
              ),
          if (sec.lines.length > maxLinesPerSection)
            Text('+ ${sec.lines.length - maxLinesPerSection} líneas', style: TextStyle(fontSize: fontSize * 0.7, color: Colors.white38)),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

/// Una "pgina" ya distribuida en columnas con el tamao elegido.
typedef SongPage = ({List<List<Section>> columns, double fontSize});

/// Cuerpo de la cancin con auto-ajuste: prueba tamaos de fuente (del grande
/// al pequeo) y de 1 a 3 columnas hasta que toda la cancin quepa en la
/// pantalla. Si ni con el tamao mnimo legible cabe, la reparte en varias
/// pginas (se pasa de pgina deslizando).
class AutoFitSongBody extends StatelessWidget {
  /// Secciones en orden de toque (con repeticiones).
  final List<Section> sections;
  final bool lyricsOnly;
  final int semitones;
  final bool american;

  /// Tamao mximo a probar (normalmente el que tiene el usuario configurado).
  final double maxFontSize;

  /// Tamao mnimo legible; por debajo ya no se reduce.
  final double minFontSize;
  const AutoFitSongBody({
    super.key,
    required this.sections,
    required this.lyricsOnly,
    required this.semitones,
    required this.american,
    this.maxFontSize = 18,
    this.minFontSize = 11,
  });

  static const _gap = 12.0;

  @override
  Widget build(BuildContext context) {
    if (sections.isEmpty) {
      return const Center(child: Text('Esta cancin an no tiene letra.'));
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final pages = _computePages(constraints.maxWidth, constraints.maxHeight);
        if (pages.length <= 1) {
          return _renderPage(pages.first, constraints.maxWidth);
        }
        return PageView.builder(
          itemCount: pages.length,
          itemBuilder: (context, i) => _renderPage(pages[i], constraints.maxWidth),
        );
      },
    );
  }

  // ------------------------------------------------------------ medidas

  double _lyricLineHeight(double fs) => fs * 1.35;
  double _chordLineHeight(double fs) => fs * 1.15;

  /// Cuntas lneas ocupa el texto al envolverse en [width].
  int _wrappedLines(String text, double width, double fs) {
    if (text.trim().isEmpty) return 1;
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(fontSize: fs, height: 1.35)),
      textDirection: TextDirection.ltr,
      maxLines: 200,
    );
    tp.layout(maxWidth: width);
    final lines = (tp.size.height / _lyricLineHeight(fs)).ceil();
    tp.dispose();
    return lines < 1 ? 1 : lines;
  }

  double _sectionHeight(Section sec, double width, double fs) {
    var h = 22.0 + 6.0; // cabecera + separacin
    for (final line in sec.lines) {
      if (line.isEmpty) {
        h += 8;
        continue;
      }
      final hasChords = !lyricsOnly && line.any((x) => x.chord != null);
      if (hasChords && isChordRowLine(line)) {
        h += _chordLineHeight(fs);
        continue;
      }
      final text = line.map((e) => e.text).join();
      final n = _wrappedLines(text, width, fs);
      h += (hasChords ? _chordLineHeight(fs) : 0) + n * _lyricLineHeight(fs) + 2;
    }
    return h + 20; // margen entre secciones
  }

  /// Reparte las secciones en [columns] columnas equilibradas por altura.
  List<List<Section>> _balance(int columns, double width, double fs) {
    if (columns <= 1) return [sections];
    final cols = List.generate(columns, (_) => <Section>[]);
    final heights = List.filled(columns, 0.0);
    for (final sec in sections) {
      var target = 0;
      for (var i = 1; i < columns; i++) {
        if (heights[i] < heights[target]) target = i;
      }
      cols[target].add(sec);
      heights[target] += _sectionHeight(sec, width, fs);
    }
    return cols;
  }

  /// Mejor configuracin (fuente ms grande, y a igual tamao menos columnas)
  /// con la que estas secciones caben en [availH].
  SongPage? _bestConfig(List<Section> group, double availW, double availH) {
    for (var fs = maxFontSize; fs >= minFontSize; fs -= 0.5) {
      for (final cols in const [1, 2, 3]) {
        final width = (availW - _gap * (cols - 1)) / cols;
        final balanced = _balanceFor(cols, group, width, fs);
        final fits = balanced.every((c) => c.isEmpty || _columnsHeight(c, width, fs) <= availH);
        if (fits) return (columns: balanced, fontSize: fs);
      }
    }
    return null;
  }

  List<List<Section>> _balanceFor(int columns, List<Section> group, double width, double fs) {
    if (columns <= 1) return [group];
    final cols = List.generate(columns, (_) => <Section>[]);
    final heights = List.filled(columns, 0.0);
    for (final sec in group) {
      var target = 0;
      for (var i = 1; i < columns; i++) {
        if (heights[i] < heights[target]) target = i;
      }
      cols[target].add(sec);
      heights[target] += _sectionHeight(sec, width, fs);
    }
    return cols;
  }

  double _columnsHeight(List<Section> group, double width, double fs) {
    var h = 0.0;
    for (final s in group) {
      h += _sectionHeight(s, width, fs);
    }
    return h;
  }

  /// Calcula las pginas necesarias para que todo quepa.
  List<SongPage> _computePages(double availW, double availH) {
    final whole = _bestConfig(sections, availW, availH);
    if (whole != null) return [whole];

    // No cabe entera: repartir en pginas de la forma ms holgada posible.
    final pages = <SongPage>[];
    var current = <Section>[];
    void closeCurrent() {
      if (current.isEmpty) return;
      pages.add(_bestConfig(current, availW, availH) ?? (columns: _balanceFor(3, current, (availW - _gap * 2) / 3, minFontSize), fontSize: minFontSize));
      current = <Section>[];
    }

    for (final sec in sections) {
      final trial = [...current, sec];
      final fits = _bestConfig(trial, availW, availH) != null;
      if (fits || current.isEmpty) {
        current = trial;
      } else {
        closeCurrent();
        current = [sec];
      }
    }
    closeCurrent();
    return pages.isEmpty ? [(columns: [sections], fontSize: minFontSize)] : pages;
  }

  // -------------------------------------------------------------- dibujado

  Widget _renderPage(SongPage page, double availW) {
    final fs = page.fontSize;
    final cols = page.columns;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < cols.length; i++) ...[
            if (i > 0) const SizedBox(width: _gap),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final sec in cols[i]) ...[
                      SectionHeader(sec: sec, fontSize: (fs * 0.72).clamp(9.0, 13.0)),
                      const SizedBox(height: 4),
                      for (final line in sec.lines)
                        line.isEmpty
                            ? const SizedBox(height: 8)
                            : Padding(
                                padding: const EdgeInsets.symmetric(vertical: 1),
                                child: SongLineView(line: line, lyricsOnly: lyricsOnly, semitones: semitones, fontSize: fs, american: american),
                              ),
                      const SizedBox(height: 20),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}