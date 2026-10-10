// Importador de PDF -> ChordPro (formato cannico de SongKey).
//
// El proceso es:
//   1. extraer las palabras del PDF con su posicin (syncfusion);
//   2. agrupar en lneas por Y y detectar si el PDF tiene dos columnas;
//   3. clasificar cada lnea (acordes / letra / encabezado);
//   4. colocar cada acorde sobre el carcter de la letra que tiene debajo;
//   5. envolver en secciones y escribir el formato cannico.
//
// La extraccin (paso 1) es la nica parte que depende del PDF; el resto
// ([buildFromLines]) es Dart puro y se prueba con lneas construidas a mano.
import 'dart:typed_data';

import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../../data/chord_parser.dart';
import '../../data/chordpro.dart';
import 'chord_mapper.dart';
import 'line_classifier.dart';
import 'pdf_models.dart';

/// Resultado de convertir un PDF.
class PdfConversion {
  /// Ttulo detectado (o el nombre del archivo si no se ha podido).
  final String title;

  /// Texto ChordPro en el formato cannica.
  final String chordPro;

  /// Tonalidad sugerida a partir de los acordes (puede ser null).
  final String? suggestedKey;

  /// Cosas que el usuario debera revisar antes de guardar.
  final List<ImportWarning> warnings;

  /// Nmero de columnas detectadas (1 o 2).
  final int columns;

  const PdfConversion({
    required this.title,
    required this.chordPro,
    this.suggestedKey,
    this.warnings = const [],
    this.columns = 1,
  });
}

class PdfToChordProService {
  const PdfToChordProService();

  /// Convierte los bytes de un PDF. [fallbackTitle] se usa si no se encuentra
  /// ningn ttulo en el documento.
  PdfConversion convert(Uint8List bytes, {String? fallbackTitle}) {
    final doc = PdfDocument(inputBytes: bytes);
    List<PdfLine> lines;
    double pageWidth = 595;
    try {
      pageWidth = doc.pages.count > 0 ? doc.pages[0].size.width : 595;
      lines = _extractLines(doc, pageWidth);
    } finally {
      doc.dispose();
    }
    return buildFromLines(lines, fallbackTitle: fallbackTitle, pageWidth: pageWidth);
  }

  /// Convierte lneas ya extradas (separa del PDF para poder probarlo).
  PdfConversion buildFromLines(
    List<PdfLine> lines, {
    String? fallbackTitle,
    double pageWidth = 595,
  }) {
    final warnings = <ImportWarning>[];
    if (lines.isEmpty) {
      return PdfConversion(title: fallbackTitle ?? 'Cancin', chordPro: '', warnings: const [], columns: 1);
    }

    // --- Dos columnas -------------------------------------------------
    final split = _columnSplit(lines, pageWidth);
    final columns = split == null ? 1 : 2;
    if (split != null) {
      warnings.add(const ImportWarning(WarningKind.mixedColumn, 0, 'El PDF tiene dos columnas: revisa que no se hayan mezclado.'));
    }

    // Cada columna se procesa de arriba hacia abajo. Una linea es de la
    // columna en la que EMPIEZA (su borde izquierdo).
    final left = (split == null ? lines : lines.where((l) => l.left < split).toList())
      ..sort(_readingOrder);
    final right = split == null
        ? const <PdfLine>[]
        : (lines.where((l) => l.left >= split).toList()..sort(_readingOrder));

    final song = ChordProSong();
    final all = [...left, ...right];
    var title = fallbackTitle ?? '';

    for (var i = 0; i < all.length; i++) {
      final line = all[i];
      final c = classifyLine(line);
      if (c.isHeader) {
        _openSection(song, c.header!);
        if (c.header!.rest.isNotEmpty) _addLine(song, lineFor(c.header!.rest, c.line));
        continue;
      }
      if (c.isChords) {
        // Tiene letra debajo? Se colocan los acordes sobre ella.
        final next = i + 1 < all.length ? classifyLine(all[i + 1]) : null;
        if (next != null && next.isLyric && _isBelow(next.line, line)) {
          _addLine(song, placeChordsOnLyric(chordsOf(line), next.line));
          i++;
        } else {
          // Sin letra: progresin instrumental.
          final bars = chordOnlyLine(line);
          if (bars.bars.isEmpty) {
            warnings.add(ImportWarning(WarningKind.chordWithoutLyric, i + 1, 'Lnea de acordes vaca.'));
          } else if (next != null && next.isLyric && _holeBetween(next.line, line) <= _tolerance(line) * 3) {
            // Hay letra cerca pero no se ha podido emparejar (suele pasar
            // cuando el corte de columnas las ha separado).
            warnings.add(ImportWarning(WarningKind.chordWithoutLyric, i + 1, 'Acordes sin letra clara debajo: se han guardado como progresion.'));
          }
          _addLine(song, bars);
        }
        continue;
      }
      if (c.isLyric) {
        // Letra con algo de acordes en medio: se avisa por si acaso.
        final ratio = chordRatio(line.text);
        if (ratio > 0 && ratio < chordRatioThreshold) {
          warnings.add(ImportWarning(WarningKind.ambiguous, i + 1, 'Lnea con acordes y letra mezclados, revsala.'));
        }
        _addLine(song, placeChordsOnLyric(const [], line));
        continue;
      }
      // Vaca: se ignora (el serializador pone las lneas en blanco).
    }

    // --- Ttulo ---------------------------------------------------------
    if (title.trim().isEmpty) {
      title = _detectTitle(all) ?? fallbackTitle ?? 'Cancin';
    }
    song.meta.title = title;

    final chordPro = const ChordProSerializer().write(song);
    return PdfConversion(
      title: title,
      chordPro: chordPro,
      suggestedKey: suggestedKeyFromBody(chordPro),
      warnings: warnings,
      columns: columns,
    );
  }

  // ------------------------------------------------------------- detalles

  /// Abre una seccin nueva en la cancin.
  void _openSection(ChordProSong song, HeaderMatch header) {
    song.sections.add(CpSection(
      directive: header.directive,
      label: header.label,
      kind: kindFor(header.directive, header.label),
    ));
  }

  /// Aade una lnea a la ltima seccin (o crea una annima si an no hay).
  void _addLine(ChordProSong song, CpLine line) {
    if (song.sections.isEmpty) {
      song.sections.add(CpSection(directive: 'verse', label: 'VERSO 1', kind: SectionKind.verse));
    }
    song.sections.last.lines.add(line);
  }

  /// Texto suelto (sin acordes) como lnea del modelo.
  CpLine lineFor(String text, PdfLine line) {
    final chords = chordsOf(line);
    return placeChordsOnLyric(chords, line);
  }

  /// true si [below] est justo debajo de [above] (misma columna, Y cercano).
  bool _isBelow(PdfLine below, PdfLine above) {
    if (below.page != above.page) return false;
    final gap = _holeBetween(below, above);
    if (gap < -above.height * 0.5) return false; // se solapa: no es "debajo"
    return gap <= _tolerance(above);
  }

  /// Hueco vertical entre el final de [above] y el principio de [below].
  double _holeBetween(PdfLine below, PdfLine above) => below.top - above.bottom;

  /// Cuanto puede separarse la letra del acorde segun el tamano de letra.
  double _tolerance(PdfLine line) => max(line.fontSize, 12) * 1.6;

  /// Ttulo: la lnea con la letra claramente ms grande que el resto y que no
  /// sea de acordes ni un encabezado. Si ninguna destaca, no hay ttulo.
  String? _detectTitle(List<PdfLine> lines) {
    final sizes = lines.map((l) => l.fontSize).toList()..sort();
    final mediana = sizes[sizes.length ~/ 2];
    String? best;
    var bestSize = mediana * 1.15;
    for (final l in lines) {
      final t = l.text.trim();
      if (t.length < 2) continue;
      if (chordRatio(t) >= chordRatioThreshold) continue;
      if (matchHeader(t) != null) continue;
      if (l.fontSize > bestSize) {
        bestSize = l.fontSize;
        best = t;
      }
    }
    return best?.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Punto de corte entre dos columnas (null si solo hay una).
  double? _columnSplit(List<PdfLine> lines, double pageWidth) {
    final lefts = <double>[];
    for (final l in lines) {
      for (final w in l.words) {
        if (w.text.trim().isNotEmpty) lefts.add(w.left);
      }
    }
    if (lefts.length < 8) return null;
    lefts.sort();
    var bestGap = 0.0;
    var bestAt = 0.0;
    for (var i = 0; i < lefts.length - 1; i++) {
      final gap = lefts[i + 1] - lefts[i];
      if (gap > bestGap) {
        bestGap = gap;
        bestAt = lefts[i];
      }
    }
    if (bestGap < pageWidth * 0.18) return null;
    final leftCount = lefts.where((x) => x <= bestAt).length;
    if (leftCount < 3 || lefts.length - leftCount < 3) return null;
    return bestAt + bestGap / 2;
  }

  int _readingOrder(PdfLine a, PdfLine b) {
    final p = a.page.compareTo(b.page);
    if (p != 0) return p;
    final t = a.top.compareTo(b.top);
    if (t != 0) return t;
    return a.left.compareTo(b.left);
  }

  // ---------------------------------------------------------- extraccin

  /// Saca las palabras del PDF con su posicin, filtrando nmeros de pgina y
  /// marcas de agua.
  List<PdfLine> _extractLines(PdfDocument doc, double pageWidth) {
    final textLines = PdfTextExtractor(doc).extractTextLines();
    final result = <PdfLine>[];
    for (final l in textLines) {
      final raw = l.text;
      if (raw.trim().isEmpty) continue;
      if (RegExp(r'^\d{1,3}$').hasMatch(raw.trim())) continue;

      final words = <PdfWord>[];
      for (final w in l.wordCollection) {
        var wt = w.text;
        if (wt.isEmpty) {
          wt = w.glyphs.map((g) => g.text).join();
        }
        if (wt.trim().isEmpty) continue;
        words.add(PdfWord(
          text: wt,
          left: w.bounds.left,
          top: w.bounds.top,
          right: w.bounds.right,
          bottom: w.bounds.bottom,
          fontSize: l.fontSize,
          glyphLefts: w.glyphs.map((g) => g.bounds.left).toList(),
        ));
      }
      if (words.isEmpty) continue;
      // Marca de agua o logo en el margen derecho con letra pequea.
      if (l.fontSize <= 11.5 && raw.trim().length <= 8 && l.bounds.left > pageWidth * 0.8) continue;

      result.add(PdfLine(words: words, page: l.pageIndex));
    }
    result.sort(_readingOrder);
    return result;
  }
}

/// Tonalidad sugerida: el primer acorde que acompaa a letra (no el de la
/// introduccin, que a veces est en otro tono). Si no hay ninguno con letra,
/// se usa el primero que aparezca.
String suggestedKeyFromBody(String body) {
  final lines = body.split('\n');
  bool tieneLetra(String l) => l.replaceAll(RegExp(r'\[[^\]]*\]'), '').replaceAll(RegExp(r'[^A-Za-z]'), '').isNotEmpty;
  String raizCompleta(String acorde) {
    final m = RegExp(r'^([A-G][#b]?)(m|min)?').firstMatch(acorde);
    if (m == null) return 'C';
    return m.group(2) != null ? '${m.group(1)}m' : m.group(1)!;
  }

  // 1) Primera lnea con letra y acordes.
  for (final l in lines) {
    final acordes = RegExp(r'\[([A-G][#b]?[^\]]*)\]').allMatches(l).map((m) => m.group(1)!).toList();
    if (acordes.isNotEmpty && tieneLetra(l)) return raizCompleta(acordes.first);
  }
  // 2) Primera lnea que sea solo acordes.
  for (final l in lines) {
    final m = RegExp(r'^\s*\[([A-G][#b]?[^\]]*)\]').firstMatch(l);
    if (m != null) return raizCompleta(m.group(1)!);
  }
  // 3) Primer acorde inline.
  final m = RegExp(r'\[([A-G][#b]?[^\]]*)\]').firstMatch(body);
  return m == null ? 'C' : raizCompleta(m.group(1)!);
}

/// mximo de dos nmeros (para las tolerancias).
double max(double a, double b) => a > b ? a : b;
