// Importador de PDF -> ChordPro (formato cannico de SongKey).
//
// El proceso es:
//   1. extraer las palabras del PDF con su posición (syncfusion);
//   2. agrupar en líneas por Y y detectar si el PDF tiene dos columnas;
//   3. clasificar cada línea (acordes / letra / encabezado);
//   4. colocar cada acorde sobre el carácter de la letra que tiene debajo;
//   5. envolver en secciones y escribir el formato cannico.
//
// La extracción (paso 1) es la única parte que depende del PDF; el resto
// ([buildFromLines]) es Dart puro y se prueba con líneas construidas a mano.
//
// Cambios respecto a la versión anterior:
//   - Las líneas que cruzan las dos columnas se parten por palabras.
//   - El orden de lectura es (página, columna, Y): ya no se junta toda la
//     columna izquierda antes de la derecha.
//   - El título detectado tiene prioridad sobre [fallbackTitle] y su línea se
//     quita del cuerpo (antes se colaba como primera línea de letra).
//   - Un PDF sin texto (escaneado/foto) devuelve un aviso claro
//     (requiere añadir WarningKind.noText en pdf_models.dart).
//   - Se usa dart:math en lugar de una función max propia.
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../../data/chord_parser.dart';
import '../../data/chordpro.dart';
import 'chord_mapper.dart';
import 'line_classifier.dart';
import 'pdf_models.dart';

/// Resultado de convertir un PDF.
class PdfConversion {
  /// Título detectado (o el nombre del archivo si no se ha podido).
  final String title;

  /// Texto ChordPro en el formato canónico.
  final String chordPro;

  /// Tonalidad sugerida a partir de los acordes (puede ser null).
  final String? suggestedKey;

  /// Cosas que el usuario debería revisar antes de guardar.
  final List<ImportWarning> warnings;

  /// Número de columnas detectadas (1 o 2).
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
  /// ningún título en el documento.
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

  /// Convierte líneas ya extraídas (separado del PDF para poder probarlo).
  PdfConversion buildFromLines(
    List<PdfLine> lines, {
    String? fallbackTitle,
    double pageWidth = 595,
  }) {
    final warnings = <ImportWarning>[];

    // --- PDF sin texto (escaneado o foto) -------------------------------
    if (lines.isEmpty) {
      return PdfConversion(
        title: fallbackTitle ?? 'Canción',
        chordPro: '',
        warnings: const [
          ImportWarning(
            WarningKind.noText,
            0,
            'Este PDF no tiene texto (parece escaneado o una foto). '
            'La importación por OCR todavía no está disponible.',
          ),
        ],
        columns: 1,
      );
    }

    // --- Dos columnas -------------------------------------------------
    final split = _columnSplit(lines, pageWidth);
    final columns = split == null ? 1 : 2;
    if (split != null) {
      warnings.add(const ImportWarning(
        WarningKind.mixedColumn,
        0,
        'El PDF tiene dos columnas: revisa que no se hayan mezclado.',
      ));
    }

    // Syncfusion agrupa por baseline, así que una línea puede cruzar las dos
    // columnas. Se parte por palabras antes de asignarlas a una columna.
    final working = split == null ? lines : _splitByColumn(lines, split);

    int col(PdfLine l) => split != null && l.left >= split ? 1 : 0;

    // Orden de lectura: página -> columna -> de arriba hacia abajo.
    final ordered = [...working]
      ..sort((a, b) {
        final p = a.page.compareTo(b.page);
        if (p != 0) return p;
        final c = col(a).compareTo(col(b));
        if (c != 0) return c;
        final t = a.top.compareTo(b.top);
        if (t != 0) return t;
        return a.left.compareTo(b.left);
      });

    // --- Título --------------------------------------------------------
    // El título detectado manda; el nombre del archivo es solo el respaldo.
    final titleLine = _detectTitleLine(ordered);
    final detected = titleLine?.text.replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';
    final fb = (fallbackTitle ?? '').trim();
    final title = detected.isNotEmpty ? detected : (fb.isNotEmpty ? fb : 'Canción');
    if (detected.isEmpty && fb.isEmpty) {
      warnings.add(const ImportWarning(
        WarningKind.noTitle,
        0,
        'No se ha podido detectar el título: ponle uno antes de guardar.',
      ));
    }

    // La línea del título no forma parte del cuerpo de la canción.
    final body = ordered.where((l) => !identical(l, titleLine)).toList();
    final cls = [for (final l in body) classifyLine(l)];

    // --- Cuerpo --------------------------------------------------------
    final song = ChordProSong();

    for (var i = 0; i < body.length; i++) {
      final line = body[i];
      final c = cls[i];

      if (c.isHeader) {
        _openSection(song, c.header!);
        if (c.header!.rest.isNotEmpty) _addLine(song, lineFor(c.header!.rest, c.line));
        continue;
      }

      if (c.isChords) {
        // ¿Tiene letra debajo? Se colocan los acordes sobre ella.
        final next = i + 1 < body.length ? cls[i + 1] : null;
        if (next != null && next.isLyric && _isBelow(next.line, line)) {
          _addLine(song, placeChordsOnLyric(chordsOf(line), next.line));
          i++;
        } else {
          // Sin letra: progresión instrumental.
          final bars = chordOnlyLine(line);
          if (bars.bars.isEmpty) {
            warnings.add(ImportWarning(WarningKind.chordWithoutLyric, i + 1, 'Línea de acordes vacía.'));
          } else if (next != null && next.isLyric && _holeBetween(next.line, line) <= _tolerance(line) * 3) {
            // Hay letra cerca pero no se ha podido emparejar.
            warnings.add(ImportWarning(
              WarningKind.chordWithoutLyric,
              i + 1,
              'Acordes sin letra clara debajo: se han guardado como progresión.',
            ));
          }
          _addLine(song, bars);
        }
        continue;
      }

      if (c.isLyric) {
        // Letra con algo de acordes en medio: se avisa por si acaso.
        final ratio = chordRatio(line.text);
        if (ratio > 0 && ratio < chordRatioThreshold) {
          warnings.add(ImportWarning(WarningKind.ambiguous, i + 1, 'Línea con acordes y letra mezclados, revísala.'));
        }
        _addLine(song, placeChordsOnLyric(const [], line));
        continue;
      }
      // Vacía: se ignora (el serializador pone las líneas en blanco).
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

  /// Abre una sección nueva en la canción.
  void _openSection(ChordProSong song, HeaderMatch header) {
    song.sections.add(CpSection(
      directive: header.directive,
      label: header.label,
      kind: kindFor(header.directive, header.label),
    ));
  }

  /// Añade una línea a la última sección (o crea una anónima si aún no hay).
  void _addLine(ChordProSong song, CpLine line) {
    if (song.sections.isEmpty) {
      song.sections.add(CpSection(directive: 'verse', label: 'VERSO 1', kind: SectionKind.verse));
    }
    song.sections.last.lines.add(line);
  }

  /// Texto suelto como línea del modelo.
  /// OJO: [text] no se usa, se coloca sobre toda la [line]. Si el encabezado
  /// ("CORO: ...") queda dentro de la línea, habría que quitarlo aquí.
  CpLine lineFor(String text, PdfLine line) {
    final chords = chordsOf(line);
    return placeChordsOnLyric(chords, line);
  }

  /// true si [below] está justo debajo de [above] (misma columna, Y cercano).
  bool _isBelow(PdfLine below, PdfLine above) {
    if (below.page != above.page) return false;
    final gap = _holeBetween(below, above);
    if (gap < -above.height * 0.5) return false; // se solapa: no es "debajo"
    return gap <= _tolerance(above);
  }

  /// Hueco vertical entre el final de [above] y el principio de [below].
  double _holeBetween(PdfLine below, PdfLine above) => below.top - above.bottom;

  /// Cuánto puede separarse la letra del acorde según el tamaño de letra.
  double _tolerance(PdfLine line) => math.max(line.fontSize, 12.0) * 1.6;

  /// Título: la línea con la letra claramente más grande que el resto, en la
  /// primera página, que no sea de acordes ni un encabezado. Si ninguna
  /// destaca, no hay título.
  PdfLine? _detectTitleLine(List<PdfLine> lines) {
    if (lines.isEmpty) return null;
    final firstPage = lines.first.page;
    final sizes = lines.map((l) => l.fontSize).toList()..sort();
    // Mediana estadística: promedio de los dos del medio si hay cantidad par,
    // así con 2 líneas [12, 22] la mediana es 17 y no el propio máximo.
    final mediana = sizes.length % 2 == 1
        ? sizes[sizes.length ~/ 2]
        : (sizes[sizes.length ~/ 2 - 1] + sizes[sizes.length ~/ 2]) / 2;
    var bestSize = mediana * 1.15;
    PdfLine? best;
    for (final l in lines) {
      if (l.page != firstPage) continue;
      final t = l.text.trim();
      if (t.length < 2) continue;
      if (chordRatio(t) >= chordRatioThreshold) continue;
      if (matchHeader(t) != null) continue;
      if (l.fontSize > bestSize) {
        bestSize = l.fontSize;
        best = l;
      }
    }
    return best;
  }

  /// Parte cada línea en dos según el corte de columnas, por palabras.
  List<PdfLine> _splitByColumn(List<PdfLine> lines, double split) {
    final out = <PdfLine>[];
    for (final l in lines) {
      final a = l.words.where((w) => w.left < split).toList();
      final b = l.words.where((w) => w.left >= split).toList();
      if (a.isNotEmpty) out.add(PdfLine(words: a, page: l.page));
      if (b.isNotEmpty) out.add(PdfLine(words: b, page: l.page));
    }
    return out;
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

  // ---------------------------------------------------------- extracción

  /// Saca las palabras del PDF con su posición, filtrando números de página y
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
      // Marca de agua o logo en el margen derecho con letra pequeña.
      if (l.fontSize <= 11.5 && raw.trim().length <= 8 && l.bounds.left > pageWidth * 0.8) continue;

      result.add(PdfLine(words: words, page: l.pageIndex));
    }
    result.sort(_readingOrder);
    return result;
  }
}

/// Tonalidad sugerida: el primer acorde que acompaña a letra (no el de la
/// introducción, que a veces está en otro tono). Si no hay ninguno con letra,
/// se usa el primero que aparezca.
String suggestedKeyFromBody(String body) {
  final lines = body.split('\n');
  bool tieneLetra(String l) =>
      l.replaceAll(RegExp(r'\[[^\]]*\]'), '').replaceAll(RegExp(r'[^A-Za-z]'), '').isNotEmpty;
  String raizCompleta(String acorde) {
    final m = RegExp(r'^([A-G][#b]?)(m|min)?').firstMatch(acorde);
    if (m == null) return 'C';
    return m.group(2) != null ? '${m.group(1)}m' : m.group(1)!;
  }

  // 1) Primera línea con letra y acordes.
  for (final l in lines) {
    final acordes = RegExp(r'\[([A-G][#b]?[^\]]*)\]').allMatches(l).map((m) => m.group(1)!).toList();
    if (acordes.isNotEmpty && tieneLetra(l)) return raizCompleta(acordes.first);
  }
  // 2) Primera línea que sea solo acordes.
  for (final l in lines) {
    final m = RegExp(r'^\s*\[([A-G][#b]?[^\]]*)\]').firstMatch(l);
    if (m != null) return raizCompleta(m.group(1)!);
  }
  // 3) Primer acorde inline.
  final m = RegExp(r'\[([A-G][#b]?[^\]]*)\]').firstMatch(body);
  return m == null ? 'C' : raizCompleta(m.group(1)!);
}

/// Detecta la tonalidad a partir del cuerpo: la primera línea que sea
/// exclusivamente acordes (sin corchetes, ej. "C#m  A  E  B").
String keyFromBody(String body) {
  for (final l in body.split('\n')) {
    final toks = l.trim().split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    if (toks.isEmpty || !toks.every(isChord)) continue;
    final m = RegExp(r'^\(?([A-G][#b]?)(m|min)?').firstMatch(toks.first.trim());
    if (m != null) return m.group(1)! + (m.group(2) != null ? 'm' : '');
  }
  return 'C';
}
