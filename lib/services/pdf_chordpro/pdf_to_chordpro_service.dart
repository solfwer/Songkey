// Importador de PDF -> ChordPro (formato canónico de SongKey).
//
// El proceso es:
//   1. extraer las palabras del PDF con su posición (syncfusion);
//   2. aplanar todas las palabras con sus coordenadas;
//   3. detectar columnas por hueco vertical en zona central (25%-75%);
//   4. agrupar palabras en líneas por centro Y con tolerancia 0.5×altura;
//   5. ordenar líneas: página -> columna -> Y;
//   6. clasificar cada línea (acordes / letra / encabezado / compases / vacía);
//   5. colocar cada acorde sobre la sílaba usando fracción dentro de palabra;
//   6. envolver en secciones y escribir el formato canónico.
//
// La extracción (paso 1) es la única parte que depende del PDF; el resto
// ([buildFromLines]) es Dart puro y se prueba con líneas construidas a mano.
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../../data/chord_parser.dart';
import '../../data/chordpro.dart';
import 'chord_mapper.dart';
import 'layout_text_lines.dart';
import 'line_classifier.dart';
import 'pdf_line_processor.dart' show detectColumnSplit, flattenWords, groupLines;
import 'pdf_models.dart';

/// Argumentos para el isolate de conversión (top-level porque Dart no
/// permite clases anidadas dentro de otras clases).
class _PdfConvertArgs {
  final Uint8List bytes;
  final String? fallbackTitle;
  _PdfConvertArgs(this.bytes, this.fallbackTitle);
}

/// Resultado de convertir un PDF.
class PdfConversion {
  /// Título detectado (o el nombre del archivo si no se ha podido).
  final String title;

  /// Texto ChordPro en el formato canónico.
  final String chordPro;

  /// Tonalidad sugerida a partir de los acordes (puede ser null).
  final String? suggestedKey;

  /// BPM detectado (puede ser null).
  final int? bpm;

  /// Cosas que el usuario debería revisar antes de guardar.
  final List<ImportWarning> warnings;

  /// Número de columnas detectadas (1 o 2).
  final int columns;

  const PdfConversion({
    required this.title,
    required this.chordPro,
    this.suggestedKey,
    this.bpm,
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
    bool hadExplicitHeader = false;

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

    // --- Aplanar palabras y detectar columnas ---------------------------
    // Las líneas del modo layout ya vienen separadas como se ven en la
    // página: no hay nada que agrupar ni columnas que buscar.
    final unpositioned = lines.isNotEmpty && !lines.first.positioned;
    final allWords = flattenWords(lines);
    final splitX = unpositioned ? null : detectColumnSplit(allWords, pageWidth);
    final columns = splitX == null ? 1 : 2;
    if (splitX != null) {
      warnings.add(const ImportWarning(
        WarningKind.mixedColumn,
        0,
        'El PDF tiene dos columnas: revisa que no se hayan mezclado.',
      ));
    }

    // Agrupar en líneas (ya separadas por columna si hay split)
    final working =
        unpositioned ? lines : groupLines(allWords, splitX ?? pageWidth);

    // groupLines ya devuelve el orden de lectura: página -> columna (la
    // izquierda entera y luego la derecha) -> de arriba abajo. Ordenar otra vez
    // por `left` rompía parejas acorde/letra cuando el acorde iba sangrado.
    final ordered = working;

    // --- Título --------------------------------------------------------
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

    // La línea del título no forma parte del cuerpo.
    final body = ordered.where((l) => !identical(l, titleLine)).toList();
    final cls = [for (final l in body) classifyLine(l)];

    // --- Cuerpo --------------------------------------------------------
    final song = ChordProSong();
    int versoIdx = 1;

    for (var i = 0; i < body.length; i++) {
      final line = body[i];
      final c = cls[i];

      // Salto de párrafo: nueva sección VERSO (solo si no hay encabezados).
      if (!hadExplicitHeader && i > 0 && _esSaltoDeParrafo(i, body) && (song.sections.isEmpty || song.sections.last.lines.isNotEmpty)) {
        song.sections.add(CpSection(
          directive: 'verse',
          label: 'VERSO $versoIdx',
          kind: SectionKind.verse,
        ));
        versoIdx++;
      }

      if (c.isHeader) {
        hadExplicitHeader = true;
        _openSection(song, c.header!);
        final rest = _restLine(line, c.header!);
        if (rest.words.isNotEmpty) {
          _addLine(song, chordRatio(rest.text) >= chordRatioThreshold
              ? chordOnlyLine(rest)
              : placeChordsOnLyric(const [], rest));
        }
        continue;
      }

      if (c.isChords) {
        // Los acordes van con la línea de debajo: su letra, o el texto que
        // sigue a una etiqueta ("[D] [G] VERSO 1 Nos humillamos...").
        final next = i + 1 < body.length ? cls[i + 1] : null;
        if (next != null && (next.isLyric || next.isHeader) && _isBelow(next.line, line)) {
          if (next.isHeader) {
            hadExplicitHeader = true;
            _openSection(song, next.header!);
            final rest = _restLine(next.line, next.header!);
            _addLine(song, rest.words.isEmpty
                ? chordOnlyLine(line)
                : placeChordsOnLyric(chordsOf(line), rest));
          } else {
            _addLine(song, placeChordsOnLyric(chordsOf(line), next.line));
          }
          i++;
          continue;
        }
        // Sin letra: progresión instrumental.
        final bars = chordOnlyLine(line);
        if (bars.bars.isEmpty) {
          warnings.add(ImportWarning(WarningKind.chordWithoutLyric, i + 1, 'Línea de acordes vacía.'));
        } else if (next != null && next.isLyric && _holeBetween(next.line, line) <= _tolerance(line) * 3) {
          warnings.add(ImportWarning(
            WarningKind.chordWithoutLyric,
            i + 1,
            'Acordes sin letra clara debajo: se han guardado como progresión.',
          ));
        }
        _addLine(song, bars);
        continue;
      }

      if (c.isLyric) {
        final ratio = chordRatio(line.text);
        if (ratio >= 0.3 && ratio < chordRatioThreshold) {
          warnings.add(ImportWarning(
            WarningKind.ambiguous,
            i + 1,
            'acordes y letra mezclados en esta línea, revísala.',
          ));
        }
        _addLine(song, placeChordsOnLyric(const [], line));
        continue;
      }
      // Vacía o compases: se ignoran (el serializador pone líneas en blanco).
    }

    song.meta.title = title;

    // Sin encabezados explícitos: se dividió por párrafos.
    if (!hadExplicitHeader && versoIdx > 1) {
      warnings.add(const ImportWarning(
        WarningKind.noTitle,
        0,
        'No se detectaron encabezados de sección. Se dividió por párrafos (VERSO 1, VERSO 2, …); revisa y corrige si hace falta.',
      ));
    }

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

  /// Palabras de [line] que vienen después del encabezado.
  PdfLine _restLine(PdfLine line, HeaderMatch header) => PdfLine(
        words: line.words.skip(header.wordCount).toList(),
        page: line.page,
        positioned: line.positioned,
      );

  /// true si [below] está justo debajo de [above] (misma columna, Y cercano).
  bool _isBelow(PdfLine below, PdfLine above) {
    if (below.page != above.page) return false;
    final gap = _holeBetween(below, above);
    if (gap < -above.height * 0.5) return false;
    return gap <= _tolerance(above);
  }

  /// Hueco vertical entre el final de [above] y el principio de [below].
  double _holeBetween(PdfLine below, PdfLine above) => below.top - above.bottom;

  /// Cuánto puede separarse la letra del acorde según el tamaño de letra.
  double _tolerance(PdfLine line) => math.max(line.fontSize, 12.0) * 1.6;

  /// true si entre [body[i-1]] y [body[i]] hay un salto de párrafo.
  bool _esSaltoDeParrafo(int i, List<PdfLine> body) {
    final prev = body[i - 1];
    final cur = body[i];
    if (cur.page != prev.page) return true;
    final gap = cur.top - prev.bottom;
    return gap > math.max(prev.height * 0.75, 8.0);
  }

  /// Título: la línea más probable de ser el título, en la primera página.
  ///
  /// Puntúa por: fuente más grande que la mediana, texto en mayúsculas y
  /// posición temprana en el documento. Así evita tomar como título un acorde
  /// suelto o una letra que casualmente sea grande.
  PdfLine? _detectTitleLine(List<PdfLine> lines) {
    if (lines.isEmpty) return null;
    final firstPage = lines.first.page;
    final firstPageLines = lines.where((l) => l.page == firstPage).toList();
    if (firstPageLines.isEmpty) return null;

    final sizes = firstPageLines.map((l) => l.fontSize).toList()..sort();
    final mediana = sizes.length % 2 == 1
        ? sizes[sizes.length ~/ 2]
        : (sizes[sizes.length ~/ 2 - 1] + sizes[sizes.length ~/ 2]) / 2;

    PdfLine? best;
    double bestScore = -1;
    for (var i = 0; i < firstPageLines.length; i++) {
      final l = firstPageLines[i];
      final t = l.text.trim();
      if (t.length < 2 || t.length > 80) continue;
      if (chordRatio(t) >= chordRatioThreshold) continue;
      if (matchHeader(t) != null) continue;

      double score = 0;
      if (l.fontSize > mediana * 1.15) score += 3;
      else if (l.fontSize > mediana) score += 1;
      if (t == t.toUpperCase() && t != t.toLowerCase()) score += 2;
      if (i < 10) score += 1; // cuanto más arriba, más probable es título

      if (score > bestScore) {
        bestScore = score;
        best = l;
      }
    }
    if (best != null) return best;

    // Fallback: primera línea en mayúsculas sin tamaño distinto.
    for (final l in firstPageLines) {
      final t = l.text.trim();
      if (t.length < 2 || t.length > 60) continue;
      if (chordRatio(t) >= chordRatioThreshold) continue;
      if (matchHeader(t) != null) continue;
      if (t == t.toUpperCase()) return l;
    }
    return null;
  }

  // ---------------------------------------------------------- extracción

  /// Extrae las líneas del PDF.
  ///
  /// Se intenta primero la vía geométrica (palabras con coordenadas). Si
  /// Syncfusion devuelve acordes y letra fundidos en la misma fila —pasa en
  /// "Serviremos al Señor"—, la geometría no sirve y se rehace con el texto en
  /// modo layout, que sí respeta las filas que ve una persona.
  List<PdfLine> _extractLines(PdfDocument doc, double pageWidth) {
    final geometric = _linesFromGeometry(doc, pageWidth);
    if (_geometryIsReliable(geometric)) return geometric;
    final laid = _linesFromLayout(doc);
    return laid.isNotEmpty ? laid : geometric;
  }



  /// Fracción de líneas que mezclan acordes con letra a partir de la cual la
  /// extracción por coordenadas no es fiable.
  static const double _maxMixedLines = 0.25;

  /// true si las coordenadas explican bien el documento.
  bool _geometryIsReliable(List<PdfLine> lines) {
    if (lines.isEmpty) return true;
    var mixed = 0;
    for (final l in lines) {
      for (final w in l.words) {
        // Ancho negativo = bounds corruptos.
        if (w.right < w.left - 0.5) return false;
      }
      final toks = chordTokens(l.text);
      if (toks.length < 4) continue;
      final chords = toks.where(looksLikeChord).length;
      if (chords >= 2 && chords < toks.length) mixed++;
    }
    return mixed / lines.length <= _maxMixedLines;
  }

  /// Líneas tal como las ve el lector (texto en modo layout).
  ///
  /// No hay coordenadas verticales, pero SÍ columnas: la posición de cada
  /// palabra en la fila se conserva para que cada acorde quede sobre su sílaba
  /// (ver [linesFromLayoutText]).
  List<PdfLine> _linesFromLayout(PdfDocument doc) {
    final extractor = PdfTextExtractor(doc);
    final out = <PdfLine>[];
    for (var page = 0; page < doc.pages.count; page++) {
      final text = extractor.extractText(
        startPageIndex: page,
        endPageIndex: page,
        layoutText: true,
      );
      out.addAll(linesFromLayoutText(text, page: page));
    }
    return out;
  }



  /// Extrae palabras del PDF con posición, filtra números de página y marcas.
  List<PdfLine> _linesFromGeometry(PdfDocument doc, double pageWidth) {
    final textLines = PdfTextExtractor(doc).extractTextLines();
    final allWords = <({PdfWord word, int page})>[];
    for (final l in textLines) {
      for (final w in l.wordCollection) {
        var wt = w.text;
        if (wt.isEmpty) {
          wt = w.glyphs.map((g) => g.text).join();
        }
        if (wt.trim().isEmpty) continue;
        allWords.add((
          word: PdfWord(
            text: wt,
            left: w.bounds.left,
            top: w.bounds.top,
            right: w.bounds.right,
            bottom: w.bounds.bottom,
            fontSize: l.fontSize,
            glyphLefts: w.glyphs.map((g) => g.bounds.left).toList(),
            page: l.pageIndex,
          ),
          page: l.pageIndex,
        ));
      }
    }

    // Orden bruto: de arriba abajo, luego izquierda a derecha.
    allWords.sort((a, b) {
      final t = a.word.top.compareTo(b.word.top);
      if (t != 0) return t;
      return a.word.left.compareTo(b.word.left);
    });

    // Aplanar palabras
    final words = allWords.map((w) => w.word).toList();

    // Detectar corte de columnas
    final splitX = detectColumnSplit(words, pageWidth);

    // Agrupar en líneas (ya separadas por columna si hay split)
    final lines = groupLines(words, splitX ?? pageWidth);

    // Filtrar ruido
    final result = <PdfLine>[];
    for (final l in lines) {
      final raw = l.text.trim();
      if (raw.isEmpty) continue;
      if (RegExp(r'^\d{1,3}$').hasMatch(raw)) continue;
      if (l.fontSize <= 11.5 && raw.length <= 8 && l.left > pageWidth * 0.8) continue;
      result.add(l);
    }
    return result;
  }

  // ============================================================================
  // Versión asíncrona: no bloquea la UI (PDF grande -> isolate aparte).
  // ============================================================================

  /// Función de nivel superior que corre en el isolate aparte.
  static PdfConversion _convertPdfIsolate(_PdfConvertArgs args) =>
      const PdfToChordProService().convert(args.bytes, fallbackTitle: args.fallbackTitle);

  /// Función de nivel superior para el isolate: varias canciones por PDF.
  static List<PdfConversion> _convertAllPdfIsolate(_PdfConvertArgs args) =>
      const PdfToChordProService().convertAll(args.bytes, fallbackTitle: args.fallbackTitle);

  /// Como [convert] pero sin bloquear la UI: ejecuta el parsing en un isolate.
  Future<PdfConversion> convertAsync(Uint8List bytes, {String? fallbackTitle}) async =>
      compute(_convertPdfIsolate, _PdfConvertArgs(bytes, fallbackTitle));

  /// Como [convertAll] pero sin bloquear la UI: ejecuta el parsing en un isolate.
  Future<List<PdfConversion>> convertAllAsync(Uint8List bytes, {String? fallbackTitle}) async =>
      compute(_convertAllPdfIsolate, _PdfConvertArgs(bytes, fallbackTitle));

  // ============================================================================
  // Varias canciones en un mismo PDF.
  // ============================================================================

  /// Como [convert] pero devuelve una conversión por canción detectada en el PDF.
  List<PdfConversion> convertAll(Uint8List bytes, {String? fallbackTitle}) {
    final doc = PdfDocument(inputBytes: bytes);
    List<PdfLine> lines;
    double pageWidth = 595;
    try {
      pageWidth = doc.pages.count > 0 ? doc.pages[0].size.width : 595;
      lines = _extractLines(doc, pageWidth);
    } finally {
      doc.dispose();
    }
    return buildAllFromLines(lines, fallbackTitle: fallbackTitle, pageWidth: pageWidth);
  }

  /// Como [buildFromLines] pero devuelve una conversión por canción detectada.
  List<PdfConversion> buildAllFromLines(
    List<PdfLine> lines, {
    String? fallbackTitle,
    double pageWidth = 595,
  }) {
    if (lines.isEmpty) {
      return [buildFromLines(lines, fallbackTitle: fallbackTitle, pageWidth: pageWidth)];
    }

    final boundaries = _detectSongBoundaries(lines);
    if (boundaries.length <= 1) {
      return [buildFromLines(lines, fallbackTitle: fallbackTitle, pageWidth: pageWidth)];
    }

    final conversions = <PdfConversion>[];
    for (var i = 0; i < boundaries.length; i++) {
      final start = boundaries[i];
      final end = i + 1 < boundaries.length ? boundaries[i + 1] : lines.length;
      final group = lines.sublist(start, end);
      // Solo al primero se le pasa el fallbackTitle; el resto detecta su propio título.
      final conv = buildFromLines(
        group,
        fallbackTitle: i == 0 ? fallbackTitle : null,
        pageWidth: pageWidth,
      );
      conversions.add(conv);
    }
    return conversions;
  }

  /// Detecta índices de inicio de cada canción dentro de [lines].
  ///
  /// Una nueva canción empieza cuando hay una línea que parece título
  /// (mayúsculas y/o fuente grande) y hay un salto de página o un gran hueco
  /// vertical respecto a la línea anterior.
  List<int> _detectSongBoundaries(List<PdfLine> lines) {
    final boundaries = <int>[0];
    double prevBottom = 0;
    int? prevPage;
    for (var i = 0; i < lines.length; i++) {
      final l = lines[i];
      if (i == 0) {
        prevBottom = l.bottom;
        prevPage = l.page;
        continue;
      }
      final isNewPage = prevPage != null && l.page != prevPage;
      final gap = isNewPage ? double.infinity : l.top - prevBottom;
      if (_looksLikeSongTitle(l) && (isNewPage || gap > l.height * 2.5)) {
        boundaries.add(i);
      }
      prevBottom = l.bottom;
      prevPage = l.page;
    }
    return boundaries;
  }

  /// Heurística rápida: ¿[line] parece el título de una canción nueva?
  bool _looksLikeSongTitle(PdfLine line) {
    final t = line.text.trim();
    if (t.length < 2 || t.length > 80) return false;
    if (chordRatio(t) >= chordRatioThreshold) return false;
    if (matchHeader(t) != null) return false;
    final isUpper = t == t.toUpperCase() && t != t.toLowerCase();
    final isLarge = line.fontSize > 14;
    return isUpper || isLarge;
  }
}

/// Tonalidad sugerida: el primer acorde que acompaña a letra.
String suggestedKeyFromBody(String body) {
  final lines = body.split('\n');
  bool tieneLetra(String l) =>
      l.replaceAll(RegExp(r'\[[^\]]*\]'), '').replaceAll(RegExp(r'[^A-Za-z]'), '').isNotEmpty;
  String raizCompleta(String acorde) {
    final m = RegExp(r'^([A-G][#b]?)(m|min)?').firstMatch(acorde);
    if (m == null) return 'C';
    return m.group(2) != null ? '${m.group(1)}m' : m.group(1)!;
  }

  for (final l in lines) {
    final acordes = RegExp(r'\[([A-G][#b]?[^\]]*)\]').allMatches(l).map((m) => m.group(1)!).toList();
    if (acordes.isNotEmpty && tieneLetra(l)) return raizCompleta(acordes.first);
  }
  for (final l in lines) {
    final m = RegExp(r'^\s*\[([A-G][#b]?[^\]]*)\]').firstMatch(l);
    if (m != null) return raizCompleta(m.group(1)!);
  }
  final m = RegExp(r'\[([A-G][#b]?[^\]]*)\]').firstMatch(body);
  return m == null ? 'C' : raizCompleta(m.group(1)!);
}

/// Detecta la tonalidad a partir del cuerpo: primera línea solo acordes.
String keyFromBody(String body) {
  for (final l in body.split('\n')) {
    final toks = l.trim().split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    if (toks.isEmpty || !toks.every(isChord)) continue;
    final m = RegExp(r'^\(?([A-G][#b]?)(m|min)?').firstMatch(toks.first.trim());
    if (m != null) return m.group(1)! + (m.group(2) != null ? 'm' : '');
  }
  return 'C';
}