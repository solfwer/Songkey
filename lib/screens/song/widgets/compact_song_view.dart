// Vista compacta de la cancin.
//
// A diferencia de la vista normal (que recorre el arreglo con sus
// repeticiones), aqu se recorren las secciones UNICAS, una sola vez cada una,
// en el orden de su primera aparicin, con una etiqueta "x2" cuando suena
// varias veces. Las que no estn en el arreglo se aaden al final.
//
// El tamao de letra se calcula solo: con TextPainter se mide cunto ocupa la
// cancin y se busca (por biseccin) la fuente ms grande que haga que quepa en
// la pantalla sin scroll. Si ni al mnimo legible cabe, se deja scrollear.
import 'package:flutter/material.dart';

import '../../../models/song.dart';
import '../../../data/chord_parser.dart';
import 'compact_sections.dart';
import 'song_view.dart';
import '../../../theme.dart';

/// Tamao mnimo que se considera legible.
const double _minFontSize = 10;

/// Tamao mximo que se intenta (si cabe, ya est).
const double _maxFontSize = 22;

class CompactSongView extends StatefulWidget {
  /// La misma cancin que usa la vista normal.
  final Song song;

  /// Con acordes o solo letra.
  final bool lyricsOnly;

  /// Semitonos de transposicin.
  final int semitones;

  /// Notacin americana o latina.
  final bool american;

  /// Si es true, se busca el tamao ms grande que haga que toda la cancin
  /// quepa en pantalla (sin pasarse de [maxFontSize]).
  final bool autoFit;

  /// Tamao elegido por el usuario (panel de opciones o Ajustes): es el tope
  /// que se usa al auto-ajustar y el tamao fijo si el auto-ajuste est apagado.
  final double maxFontSize;

  const CompactSongView({
    super.key,
    required this.song,
    required this.lyricsOnly,
    required this.semitones,
    this.american = true,
    this.autoFit = true,
    this.maxFontSize = 22,
  });

  @override
  State<CompactSongView> createState() => _CompactSongViewState();
}

class _CompactSongViewState extends State<CompactSongView> {
  double _fontSize = 22;

  @override
  void didUpdateWidget(covariant CompactSongView old) {
    super.didUpdateWidget(old);
    if (old.song.body != widget.song.body || old.lyricsOnly != widget.lyricsOnly || old.autoFit != widget.autoFit || old.maxFontSize != widget.maxFontSize) {
      _fontSize = widget.maxFontSize;
    }
  }

  @override
  Widget build(BuildContext context) {
    final secs = compactSections(widget.song);
    if (secs.isEmpty) {
      return const Center(child: Text('Esta cancin an no tiene letra.'));
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        // Con auto-ajuste se busca el mejor tamao hasta el mximo que el
        // usuario ha elegido; sin l, se usa ese tamao tal cual.
        _fontSize = widget.autoFit
            ? _mejorFontSize(secs, constraints.maxWidth, constraints.maxHeight, widget.lyricsOnly).clamp(_minFontSize, widget.maxFontSize)
            : widget.maxFontSize;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final sec in secs) ...[
                _CabeceraCompacta(sec: sec),
                if (sec.muestraRepeticion)
                  Padding(
                    padding: const EdgeInsets.only(left: 2, bottom: 2),
                    child: Text(
                      'x${sec.repeats}',
                      style: TextStyle(fontSize: _fontSize * 0.75, color: Colors.white54, fontStyle: FontStyle.italic),
                    ),
                  ),
                for (final line in sec.lines)
                  if (line.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 0.5),
                      child: SongLineView(
                        line: line,
                        lyricsOnly: widget.lyricsOnly,
                        semitones: widget.semitones,
                        fontSize: _fontSize,
                        american: widget.american,
                        lineHeight: 1.25,
                        chordLineHeight: 1.05,
                      ),
                    ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        );
      },
    );
  }

  /// Busca la fuente ms grande con la que todo cabe en pantalla.
  double _mejorFontSize(List<CompactSection> secs, double width, double height, bool lyricsOnly) {
    if (_cabe(secs, widget.maxFontSize, width, height, lyricsOnly)) return widget.maxFontSize;
    if (!_cabe(secs, _minFontSize, width, height, lyricsOnly)) return _minFontSize;
    var lo = _minFontSize;
    var hi = widget.maxFontSize;
    for (var i = 0; i < 8; i++) {
      final mid = (lo + hi) / 2;
      if (_cabe(secs, mid, width, height, lyricsOnly)) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  /// Mide la cancin completa con TextPainter y comprueba si cabe.
  bool _cabe(List<CompactSection> secs, double fs, double width, double height, bool lyricsOnly) {
    var usado = 0.0;
    for (final sec in secs) {
      usado += fs * 1.6 + 6; // cabecera
      if (sec.muestraRepeticion) usado += fs; // etiqueta x2
      for (final line in sec.lines) {
        if (line.isEmpty) continue;
        final texto = _textoDeLinea(line, lyricsOnly);
        if (texto.trim().isEmpty) continue;
        usado += _altoTexto(texto, width, fs, lyricsOnly && line.any((s) => s.chord != null));
      }
      usado += 12; // separacin entre secciones
    }
    return usado <= height;
  }

  String _textoDeLinea(SongLine line, bool lyricsOnly) {
    if (lyricsOnly) {
      final chordsOnly = line.every((s) => s.chord != null && s.text.trim().isEmpty);
      if (chordsOnly) return '';
      return line.map((s) => s.text).join().trim();
    }
    return line.map((s) => s.chord != null ? '${s.chord} ${s.text}' : s.text).join().trim();
  }

  double _altoTexto(String text, double width, double fs, bool esFilaDeAcordes) {
    final tp = TextPainter(
      text: TextSpan(text: text.isEmpty ? ' ' : text, style: TextStyle(fontSize: fs, height: 1.25)),
      textDirection: TextDirection.ltr,
      maxLines: 500,
    );
    tp.layout(maxWidth: width);
    final alto = tp.size.height;
    tp.dispose();
    return esFilaDeAcordes ? alto + fs * 1.1 : alto;
  }
}

/// Cabecera de seccion con el badge de color (igual que en la vista normal).
class _CabeceraCompacta extends StatelessWidget {
  final CompactSection sec;
  const _CabeceraCompacta({required this.sec});

  @override
  Widget build(BuildContext context) {
    final abbr = _abreviatura(sec.label);
    final simple = simpleSectionLabel(sec.label);
    final esOscuro = Theme.of(context).brightness == Brightness.dark;
    return Row(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
            color: AppColors.destructive.withValues(alpha: esOscuro ? 0.25 : 0.15),
            borderRadius: BorderRadius.circular(6)),
        child: Text(abbr,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.destructive)),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          simple,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              color: AppColors.destructive,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5),
        ),
      ),
    ]);
  }

  String _abreviatura(String label) {
    final secs = parseSong(label);
    if (secs.isNotEmpty && secs.first.abbr != 'â€¢' && secs.first.abbr.isNotEmpty) {
      return secs.first.abbr.toLowerCase();
    }
    final t = label.trim();
    return t.isEmpty ? '?' : t.length <= 2 ? t.toLowerCase() : t.substring(0, 2).toLowerCase();
  }
}
