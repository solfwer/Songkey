// Modelo, parser y serializador ChordPro de SongKey.
//
// Hay UN solo formato para todas las canciones y UN solo parser/serializador
// que se usa en toda la app (edicin, guardado, importacin y exportacin).
//
// Formato cannico (lo que escribe siempre el serializador):
//
//   {title: A DANZAR}
//   {key: D}
//   {tempo: 72}
//
//   {start_of_introduccion: INTRODUCCIN:}
//   [C#m] | [A] | [E] | [B]
//   {end_of_introduccion}
//
//   {start_of_verse: VERSO 1}
//   Da un paso al frent[C#m]e
//   {end_of_verse}
//
//   {start_of_chorus: PRE-CORO}
//   ...
//   {end_of_chorus}
//
// El parser acepta adems variantes (encabezados en texto plano tipo "Verso 1",
// maysculas/tildes, `start_of_intro`, `sov`/`eov`, comentarios...) y las
// normaliza a este formato.
import 'chord_parser.dart';

// ---------------------------------------------------------------------------
// Modelo
// ---------------------------------------------------------------------------

/// Un acorde anclado a una posicin: [at] es el ndice de carcter de
/// [CpLine.lyric] justo delante de la slaba que acompaa.
class CpChord {
  final int at;
  final String chord;
  const CpChord(this.at, this.chord);

  CpChord copyWith({int? at, String? chord}) => CpChord(at ?? this.at, chord ?? this.chord);

  @override
  bool operator ==(Object other) => other is CpChord && other.at == at && other.chord == chord;

  @override
  int get hashCode => Object.hash(at, chord);
}

/// Una lnea de la cancin: letra con acordes anclados, o fila de acordes
/// separados por `|` (introducciones, instrumentales...).
class CpLine {
  /// Letra sin acordes. Es null si la lnea es solo una progresin de acordes.
  final String? lyric;

  /// Acordes anclados a [lyric]: cada uno suena delante de [lyric][at].
  final List<CpChord> chords;

  /// true = fila de acordes (`[C#m] | [A] | [E] | [B]`).
  final bool instrumental;

  /// Acordes de la fila instrumental, en orden.
  final List<String> bars;

  const CpLine({this.lyric, this.chords = const [], this.instrumental = false, this.bars = const []});

  /// Lnea de letra con acordes anclados.
  CpLine.lyricLine(String? lyric, [List<CpChord> chords = const []])
      : this.lyric = lyric,
        this.chords = chords,
        instrumental = false,
        bars = const [];

  /// Fila de acordes (intro, instrumental).
  CpLine.barLine(List<String> bars)
      : this.bars = bars,
        instrumental = true,
        lyric = null,
        chords = const [];

  bool get isEmpty => (lyric == null || lyric!.trim().isEmpty) && chords.isEmpty && bars.isEmpty;

  /// Texto tal como se lee (sin corchetes).
  String get plainText => instrumental ? bars.join(' ') : (lyric ?? '');

  CpLine copyWith({String? lyric, List<CpChord>? chords, bool? instrumental, List<String>? bars}) => CpLine(
        lyric: lyric ?? this.lyric,
        chords: chords ?? this.chords,
        instrumental: instrumental ?? this.instrumental,
        bars: bars ?? this.bars,
      );

  @override
  bool operator ==(Object other) =>
      other is CpLine &&
      other.lyric == lyric &&
      other.instrumental == instrumental &&
      other.bars.length == bars.length &&
      other.chords.length == chords.length &&
      _sameChords(other.chords, chords);

  static bool _sameChords(List<CpChord> a, List<CpChord> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(lyric, instrumental, Object.hashAll(bars), Object.hashAll(chords));
}

/// Seccin: directiva (verse, chorus, introduccion...), etiqueta visible
/// ("VERSO 1") y sus lneas.
class CpSection {
  /// Nombre cannico de la directiva (`verse`, `chorus`, `introduccion`...).
  String directive;

  /// Etiqueta visible ("VERSO 1", "CORO", "INTRODUCCIN:").
  String label;

  /// Tipo para el color y el badge (se deduce de directiva + etiqueta con las
  /// reglas configurables de [kindRules]).
  SectionKind kind;

  List<CpLine> lines;

  CpSection({required this.directive, required this.label, required this.kind, List<CpLine>? lines}) : lines = lines ?? <CpLine>[];

  CpSection copy() => CpSection(
        directive: directive,
        label: label,
        kind: kind,
        lines: lines.map((l) => l.copyWith()).toList(),
      );
}

/// Metadatos del principio del archivo, en sintona con la pestaa Datos.
class CpMeta {
  String? title;
  String? key;
  String? tempo;
  String? time;
  String? artist;
  String? subtitle;

  CpMeta({this.title, this.key, this.tempo, this.time, this.artist, this.subtitle});

  CpMeta copy() => CpMeta(title: title, key: key, tempo: tempo, time: time, artist: artist, subtitle: subtitle);
}

/// Cancin completa. El [order] (orden de toque con repeticiones, lo que se
/// edita en la pestaa Estructura) NO se guarda en el texto: viaja aparte.
class ChordProSong {
  CpMeta meta;
  List<CpSection> sections;

  /// Referencias al orden de toque: (ndice de seccin, veces que suena).
  /// Es informacin de la interfaz, no del texto.
  List<({int section, int repeat})>? order;

  ChordProSong({CpMeta? meta, List<CpSection>? sections, this.order})
      : meta = meta ?? CpMeta(),
        sections = sections ?? <CpSection>[];

  ChordProSong copy() => ChordProSong(
        meta: meta.copy(),
        sections: sections.map((s) => s.copy()).toList(),
        order: order?.map((o) => (section: o.section, repeat: o.repeat)).toList(),
      );
}

// ---------------------------------------------------------------------------
// Tipos de seccin (mapa configurable directiva+etiqueta -> tipo)
// ---------------------------------------------------------------------------

/// Regla para deducir el tipo de seccin. [label] permite afinar por etiqueta
/// (p. ej. `chorus` + `PRE-CORO` -> pre-coro, que tiene color propio).
class KindRule {
  final String directive;
  final String? label;
  final SectionKind kind;
  const KindRule(this.directive, this.label, this.kind);
}

/// Reglas por defecto. Se pueden sustituir para cambiar colores/badges sin
/// tocar el parser.
const List<KindRule> defaultKindRules = [
  KindRule('introduccion', null, SectionKind.intro),
  KindRule('verse', null, SectionKind.verse),
  KindRule('chorus', 'PRE-CORO', SectionKind.prechorus),
  KindRule('chorus', null, SectionKind.chorus),
  KindRule('bridge', null, SectionKind.bridge),
  KindRule('outro', null, SectionKind.outro),
  KindRule('final', null, SectionKind.ending),
  KindRule('instrumental', null, SectionKind.other),
];

/// Directivas que se escriben siempre con el mismo nombre.
const Map<String, String> canonicalDirectives = {
  'intro': 'introduccion',
  'introduccion': 'introduccion',
  // erratas habituales del cancionero (le falta la O)
  'intruduccion': 'introduccion',
  'introduccin': 'introduccion',
  'presentacion': 'introduccion',
  'verse': 'verse',
  'verso': 'verse',
  'estrofa': 'verse',
  'chorus': 'chorus',
  'coro': 'chorus',
  'estribillo': 'chorus',
  'prechorus': 'chorus',
  'precoro': 'chorus',
  'bridge': 'bridge',
  'puente': 'bridge',
  'outro': 'outro',
  'final': 'final',
  'ending': 'final',
  'tag': 'final',
  'instrumental': 'instrumental',
  'interludio': 'interludio',
  'transicion': 'transicion',
};

/// Formas cortas de abrir (`sov`, `soc`, `sob`...) y de cerrar (`eov`, `eoc`...).
const Map<String, String> shortOpeners = {
  'sov': 'verse',
  'soverse': 'verse',
  'soc': 'chorus',
  'sochorus': 'chorus',
  'sob': 'bridge',
  'sobridge': 'bridge',
  'soi': 'intro',
  'sointro': 'intro',
  'sop': 'prechorus',
  'sofinal': 'final',
  'sooutro': 'outro',
};

const Map<String, String> shortClosers = {
  'eov': 'verse',
  'eoverse': 'verse',
  'eoc': 'chorus',
  'eochorus': 'chorus',
  'eob': 'bridge',
  'eobridge': 'bridge',
  'eoi': 'intro',
  'eointro': 'intro',
  'eop': 'prechorus',
  'eofinal': 'final',
  'eooutro': 'outro',
};

/// Resuelve el nombre de una directiva de apertura (acepta `start_of_verse`,
/// `sov`, `verso`, `START_OF_CORO`...) y devuelve el nombre cannico.
/// Minusculas sin tildes ni signos (para comparar nombres de directivas).
String _plain(String raw) => raw
    .toLowerCase()
    .replaceAll('á', 'a')
    .replaceAll('é', 'e')
    .replaceAll('í', 'i')
    .replaceAll('ó', 'o')
    .replaceAll('ú', 'u')
    .replaceAll('ü', 'u')
    .replaceAll('ñ', 'n')
    .replaceAll(RegExp('[^a-z]'), '');

String? resolveSectionWord(String raw) {
  final w = _plain(raw);
  if (w.isEmpty) return null;
  if (shortOpeners.containsKey(w)) return canonicalDirectives[shortOpeners[w]!];
  if (canonicalDirectives.containsKey(w)) return canonicalDirectives[w];
  for (final prefix in const ['startof', 'start', 'so']) {
    if (!w.startsWith(prefix)) continue;
    final body = w.substring(prefix.length);
    if (body.length < 3) continue;
    final canon = canonicalDirectives[body];
    if (canon != null) return canon;
  }
  return null;
}

/// true si la palabra es un cierre de seccion (`end_of_verse`, `eov`...).
bool isCloseWord(String raw) {
  final w = _plain(raw);
  if (shortClosers.containsKey(w)) return true;
  for (final prefix in const ['endof', 'end', 'eo']) {
    if (w.startsWith(prefix) && resolveSectionWord(w.substring(prefix.length)) != null) return true;
  }
  return false;
}

/// Tipo de seccin segn las reglas configurables.
SectionKind kindFor(String directive, String label, {List<KindRule> rules = defaultKindRules}) {
  final d = directive.trim().toLowerCase();
  final l = _normLabel(label);
  for (final r in rules) {
    if (r.directive != d) continue;
    if (r.label != null && _normLabel(r.label!) != l) continue;
    return r.kind;
  }
  return SectionKind.other;
}

String _normLabel(String s) => s.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

/// Etiqueta por defecto de una directiva cuando no viene escrita.
String defaultLabel(String directive) {
  switch (directive) {
    case 'introduccion':
      return 'INTRODUCCIN';
    case 'verse':
      return 'VERSO';
    case 'chorus':
      return 'CORO';
    case 'bridge':
      return 'PUENTE';
    case 'outro':
      return 'OUTRO';
    case 'final':
      return 'FINAL';
    case 'instrumental':
      return 'INSTRUMENTAL';
    case 'interludio':
      return 'INTERLUDIO';
    case 'transicion':
      return 'TRANSICIN';
    default:
      return directive.toUpperCase();
  }
}

// ---------------------------------------------------------------------------
// Parser
// ---------------------------------------------------------------------------

class ChordProParseIssue {
  final int line;
  final String message;
  const ChordProParseIssue(this.line, this.message);

  @override
  String toString() => 'Lnea $line: $message';
}

/// Convierte texto ChordPro (en cualquiera de sus variantes) al modelo.
class ChordProParser {
  /// Problemas encontrados (no detienen el anlisis): lneas que no se han
  /// podido interpretar del todo.
  final List<ChordProParseIssue> issues = [];

  /// Reglas de tipo de seccin (por defecto [defaultKindRules]).
  final List<KindRule> rules;

  ChordProParser({this.rules = defaultKindRules});

  final _directiveLine = RegExp(r'^[{ ]*([A-Za-z_]+)[ :=]*(.*?)[} ]*$');
  final _close = RegExp(r'^\s*\{\s*(?:end[_ ]?of[_ ]?|end[_ ]?|eo[_ ]?)([a-z]+)\s*\}\s*$', caseSensitive: false);
  final _meta = RegExp(r'^\s*\{\s*(title|t|key|k|tempo|bpm|time|artist|author|composer|subtitle|st|album|capo)\s*[:=]\s*(.*?)\s*\}\s*$', caseSensitive: false);
  final _comment = RegExp(r'^\s*\{\s*(?:comment|c|comment_italic|gc|guitar_comment)\s*[:=]\s*(.*?)\s*\}\s*$', caseSensitive: false);
  final _word = RegExp(r'\S+');

  /// Encabezado en texto libre, con su contenido opcional detrs.
  final _headerStart = RegExp(
    r'^\s*[\[\(\{]?\s*(INTR[A-ZÁÉÍÓÚÜÑ]{0,6}CCI[OÓ]N|INTRO|VERSO|ESTROFA|CORO|ESTRIBILLO|PRECORO|PRE-?CORO|PUENTE|BRIDGE|FINAL|TAG|OUTRO|INTERLUDIO|INSTRUMENTAL|TRANSICI[OÓ]N|PRESENTACI[OÓ]N)\s*(\d*)\s*[\]\)\}]?\s*:?\s*(.*)$',
    caseSensitive: false,
  );

  ChordProSong parse(String text) {
    final song = ChordProSong();
    final sections = <CpSection>[];
    CpSection? current;

    void open(String directive, String rawLabel, int lineNo) {
      if (directive.isEmpty) {
        issues.add(ChordProParseIssue(lineNo, 'Directiva de seccion desconocida: {}'));
        return;
      }
      var label = rawLabel.trim();
      if (label.isEmpty) {
        label = defaultLabel(directive);
      } else {
        label = _canonicalLabel(label, directive);
      }
      final sec = CpSection(directive: directive, label: label, kind: kindFor(directive, label, rules: rules));
      current = sec;
      sections.add(sec);
      _restTarget = sec;
    }

    final lines = text.replaceAll('\r', '').split('\n');
    for (var i = 0; i < lines.length; i++) {
      final raw = lines[i];
      final line = raw.trim();
      if (line.isEmpty) continue;

      // 1) Metadatos.
      final m = _meta.firstMatch(line);
      if (m != null) {
        final value = (m.group(2) ?? '').trim();
        switch (m.group(1)!.toLowerCase()) {
          case 'title':
          case 't':
            song.meta.title = _emptyToNull(value);
          case 'subtitle':
          case 'st':
            song.meta.subtitle = _emptyToNull(value);
          case 'key':
          case 'k':
            song.meta.key = _emptyToNull(value);
          case 'tempo':
          case 'bpm':
            song.meta.tempo = _emptyToNull(value);
          case 'time':
            song.meta.time = _emptyToNull(value);
          case 'artist':
          case 'author':
          case 'composer':
            song.meta.artist = _emptyToNull(value);
          default:
            break;
        }
        continue;
      }

      // 2) Directivas entre llaves: apertura de seccin (en cualquiera de sus
      //    variantes) o cierre. Se resuelve el nombre antes de descartar.
      if (line.startsWith('{') && line.endsWith('}')) {
        final d = _directiveLine.firstMatch(line);
        final word = d?.group(1) ?? '';
        final value = (d?.group(2) ?? '').trim();
        final asOpen = resolveSectionWord(word);
        if (asOpen != null) {
          open(asOpen, value, i + 1);
          continue;
        }
        if (isCloseWord(word)) continue;
      }

      // 4) Comentarios: los que son en realidad encabezados ("INTRODUCCIN:")
      // se convierten en seccin; el resto se conserva como letra.
      final c = _comment.firstMatch(line);
      if (c != null) {
        final inside = (c.group(1) ?? '').trim();
        final header = _matchPlainHeader(inside);
        if (header != null) {
          open(header.directive, header.label, i + 1);
          _addRestAsLine(header.rest);
          continue;
        }
        if (inside.isEmpty) continue;
        var sec = current;
        if (sec == null) {
          sec = CpSection(directive: 'verse', label: 'VERSO 1', kind: SectionKind.verse);
          current = sec;
          sections.add(sec);
        }
        // No es un encabezado: se conserva como letra, pero parseando sus
        // acordes (si no, los corchetes se quedarian como texto).
        final parsedComment = parseLine(inside);
        if (parsedComment != null) sec.lines.add(parsedComment);
        continue;
      }

      // 5) Encabezado en texto plano ("Verso 1", "CORO", "[Puente]").
      final plain = _matchPlainHeader(line);
      if (plain != null) {
        open(plain.directive, plain.label, i + 1);
        _addRestAsLine(plain.rest);
        continue;
      }

      // 5b) Errores de sintaxis que s se pueden detectar (se avisan, no se
      // ocultan): corchetes sin cerrar y directivas que no se conocen.
      if (line.contains('[') && line.split('[').length != line.split(']').length) {
        issues.add(ChordProParseIssue(i + 1, 'Hay un corchete sin cerrar: $line'));
      }
      if (line.startsWith('{') && line.endsWith('}') && !_meta.hasMatch(line) && !_comment.hasMatch(line)) {
        final w = _directiveLine.firstMatch(line)?.group(1) ?? '';
        if (w.isNotEmpty && resolveSectionWord(w) == null && !isCloseWord(w)) {
          issues.add(ChordProParseIssue(i + 1, 'Directiva desconocida: {$w}'));
          continue;
        }
      }

      // 6) Lnea de contenido.
      var sec = current;
      if (sec == null) {
        // Texto sin encabezados: se agrupa en una seccin annima para no
        // perder nada (el serializador le pone etiqueta por defecto).
        sec = CpSection(directive: 'verse', label: 'VERSO 1', kind: SectionKind.verse);
        current = sec;
        sections.add(sec);
      }
      final parsed = parseLine(line);
      if (parsed != null) sec.lines.add(parsed);
    }

    song.sections = sections;
    return song;
  }

  static String? _emptyToNull(String v) => v.isEmpty ? null : v;

  /// El texto que vena detrs de un encabezado ("CORO: C | G") se aade como
  /// primera lnea de la seccin recin abierta.
  void _addRestAsLine(String rest) {
    if (rest.trim().isEmpty) return;
    final parsed = parseLine(rest);
    if (parsed != null && _restTarget != null) _restTarget!.lines.add(parsed);
  }

  CpSection? _restTarget;

  /// Etiqueta normalizada: siempre en maysculas y con el nmero al final
  /// ("verso  2" -> "VERSO 2"). Si la directiva es chorus y la etiqueta es
  /// "PRE-CORO", se deja (as el tipo sale pre-coro).
  String _canonicalLabel(String label, String directive) {
    // Siempre en maysculas y con espacios de ms recortados. Se conservan los
    // dos puntos finales ("INTRODUCCIN:") porque forman parte de la etiqueta.
    return label.trim().replaceAll(RegExp(r'\s+'), ' ').toUpperCase();
  }

  /// Encabezado escrito como texto ("Verso 1", "CORO", "INTRODUCCIN: ..."),
  /// con o sin contenido detrs (lo que sobra va como primera lnea).
  ({String directive, String label, String rest})? _matchPlainHeader(String line) {
    final m = _headerStart.firstMatch(line);
    if (m == null) return null;
    final directive = resolveSectionWord(m.group(1)!);
    if (directive == null) return null;
    final num = (m.group(2) ?? '').trim();
    final colon = line.contains(':') ? ':' : '';
    final label = _canonicalLabel('${m.group(1)}${num.isEmpty ? '' : ' $num'}$colon', directive);
    return (directive: directive, label: label, rest: (m.group(3) ?? '').trim());
  }
  String _wordFromLabel(String label) {
    final first = label.trim().split(RegExp(r'\s+')).first;
    return first;
  }

  /// Convierte una lnea de texto en [CpLine] (letra con acordes o fila de
  /// acordes). Devuelve null si la lnea est vaca.
  static CpLine? parseLine(String raw) {
    if (raw.trim().isEmpty) return null;
    final hasBrackets = raw.contains('[');

    // Acordes entre corchetes y texto sin ellos.
    final chords = <CpChord>[];
    final plain = StringBuffer();
    final bracketRe = RegExp(r'\[([^\]]+)\]');
    var cursor = 0;
    for (final m in bracketRe.allMatches(raw)) {
      plain.write(raw.substring(cursor, m.start));
      final at = plain.length;
      chords.add(CpChord(at, m.group(1)!.trim()));
      cursor = m.end;
    }
    plain.write(raw.substring(cursor));
    var text = plain.toString();

    // Fila de solo acordes y separadores (`[C#m] | [A] | [E]`, o `C  D`):
    // se guarda como progresin, no como letra.
    final tokens = _tokensWithPos(text);
    final everyTokIsChord = tokens.isNotEmpty && tokens.every((t) => _isChordWord(t.word));
    if (everyTokIsChord || text.replaceAll(RegExp(r'[|\-/,.;: ]'), '').isEmpty) {
      final bars = <String>[];
      bars.addAll(chords.map((c) => c.chord));
      for (final t in _tokensWithPos(text)) {
        bars.addAll(_splitOnSeparators(t.word));
      }
      if (bars.isNotEmpty) return CpLine.barLine(bars);
    }

    // Acordes escritos como palabras sueltas ("frent C#m e"): se anclan a la
    // slaba siguiente y se quitan del texto.
    final loose = <({int from, int to, String chord})>[];
    final asList = _tokensWithPos(text);
    for (var i = 0; i < asList.length; i++) {
      final t = asList[i];
      if (!_looksLikeLooseChord(t.word, hasBrackets)) continue;
      loose.add((from: t.from, to: t.to, chord: _firstChord(t.word)!));
    }
    if (loose.isNotEmpty) {
      final rebuilt = StringBuffer();
      var pos = 0;
      for (final l in loose) {
        rebuilt.write(text.substring(pos, l.from));
        pos = l.to;
      }
      rebuilt.write(text.substring(pos));
      text = rebuilt.toString();
      for (var i = 0; i < loose.length; i++) {
        final l = loose[i];
        final removed = l.to - l.from;
        final shift = (l.from - i * removed).clamp(0, text.length);
        final target = _nextSyllableStart(text, shift) ?? text.length;
        chords.add(CpChord(target.clamp(0, text.length), l.chord));
      }
      chords.sort((a, b) => a.at.compareTo(b.at));
    }

    // Normalizacin de espacios (sin desplazar los acordes).
    final normalized = _normalizeSpaces(text, chords);

    final trimmed = normalized.text.trimRight();
    // Los acordes que quedaran fuera del texto recortado se anclan al final
    // (pasaba con los acordes que iban detrs de la ltima slaba).
    final kept = normalized.chords.map((c) => CpChord(c.at.clamp(0, trimmed.length), c.chord)).toList();
    if (trimmed.isEmpty && kept.isEmpty) return null;
    return CpLine.lyricLine(trimmed, kept);
  }

  static String? _firstChord(String token) {
    final parts = _splitOnSeparators(token);
    return parts.isEmpty ? null : parts.first;
  }

  static List<String> _splitOnSeparators(String token) {
    final out = <String>[];
    for (final part in token.split(RegExp(r'[|,\-–—/]'))) {
      final c = part.trim();
      if (c.isNotEmpty) out.add(c);
    }
    return out;
  }

  /// ndice del primer carcter no espacio a partir de [from] (o null).
  static int? _nextSyllableStart(String text, int from) {
    final start = from < 0 ? 0 : from;
    for (var i = start; i < text.length; i++) {
      if (text[i].trim().isNotEmpty) return i;
    }
    return null;
  }

  /// Acorde escrito como palabra suelta. Solo se interpreta as cuando la lnea
  /// NO lleva corchetes (si los lleva, el acorde va entre ellos y una letra
  /// suelta como "A" es la vocal de la palabra, no un acorde).
  static bool _looksLikeLooseChord(String token, bool lineHasBrackets) {
    if (lineHasBrackets) return false;
    final t = token.trim();
    if (t.length < 2) return false;
    return _isChordWord(t);
  }

  static bool _isChordWord(String token) {
    final t = token.trim();
    if (t.isEmpty) return false;
    // Un token suelto puede traer varios acordes unidos ("C#m|A|E").
    if (!t.contains('|') && !t.contains('-')) return isChord(t);
    final parts = t.split(RegExp(r'[|]'));
    return parts.isNotEmpty && parts.every((p) => isChord(p.trim()));
  }

  static List<({int from, int to, String word})> _tokensWithPos(String text) {
    final out = <({int from, int to, String word})>[];
    final re = RegExp('[^ ]+');
    for (final m in re.allMatches(text)) {
      out.add((from: m.start, to: m.end, word: m.group(0)!));
    }
    return out;
  }

  /// Colapsa espacios dobles y ajusta las posiciones de los acordes.
  static ({String text, List<CpChord> chords}) _normalizeSpaces(String text, List<CpChord> chords) {
    final sb = StringBuffer();
    final map = List<int>.filled(text.length + 1, 0);
    var out = 0;
    var pendingSpace = false;
    for (var i = 0; i <= text.length; i++) {
      final ch = i < text.length ? text[i] : '';
      if (i < text.length && ch == ' ') {
        // Un espacio no cambia de sitio: solo se colapsa si estaba repetido.
        map[i] = out;
        if (out > 0) pendingSpace = true;
        continue;
      }
      if (pendingSpace && out > 0) {
        sb.write(' ');
        out++;
        pendingSpace = false;
      }
      // ndice que ocupar el carcter i en el texto normalizado.
      map[i] = out;
      if (i < text.length) {
        sb.write(ch);
        out++;
      }
    }
    final mapped = chords.map((c) => CpChord(map[c.at.clamp(0, text.length)], c.chord)).toList();
    return (text: sb.toString().trimRight(), chords: mapped);
  }
}

// ---------------------------------------------------------------------------
// Serializador
// ---------------------------------------------------------------------------

/// Escribe el modelo en el formato cannico. Siempre escribe igual, venga de
/// donde venga el texto original.
class ChordProSerializer {
  const ChordProSerializer();

  String write(ChordProSong song) {
    final out = <String>[];

    // Metadatos primero, en orden fijo (solo los que existan).
    final meta = song.meta;
    if (_has(meta.title)) out.add('{title: ${meta.title}}');
    if (_has(meta.artist)) out.add('{artist: ${meta.artist}}');
    if (_has(meta.key)) out.add('{key: ${meta.key}}');
    if (_has(meta.tempo)) out.add('{tempo: ${meta.tempo}}');
    if (_has(meta.time)) out.add('{time: ${meta.time}}');
    if (_has(meta.subtitle)) out.add('{subtitle: ${meta.subtitle}}');

    for (final sec in song.sections) {
      if (out.isNotEmpty) out.add('');
      final directive = resolveSectionWord(sec.directive) ?? sec.directive;
      out.add('{start_of_$directive: ${sec.label}}');
      for (final line in sec.lines) {
        final text = _writeLine(line);
        if (text.isNotEmpty) out.add(text);
      }
      out.add('{end_of_$directive}');
    }

    return out.join('\n');
  }

  static bool _has(String? v) => v != null && v.trim().isNotEmpty;

  String _writeLine(CpLine line) {
    if (line.instrumental) {
      return line.bars.map((c) => '[$c]').join(' | ');
    }
    final lyric = line.lyric ?? '';
    if (line.chords.isEmpty) return lyric;
    // Se insertan de derecha a izquierda para no desplazar las posiciones.
    // A igual posicin se respeta el orden original (sort estable a mano).
    final marked = <({int i, CpChord c})>[
      for (var i = 0; i < line.chords.length; i++) (i: i, c: line.chords[i]),
    ];
    marked.sort((a, b) {
      final byPos = b.c.at.compareTo(a.c.at);
      return byPos != 0 ? byPos : b.i.compareTo(a.i);
    });
    var out = lyric;
    for (final m in marked) {
      final at = m.c.at.clamp(0, out.length);
      out = '${out.substring(0, at)}[${m.c.chord}]${out.substring(at)}';
    }
    return out;
  }
}

/// Ida y vuelta cmoda para los tests: texto -> modelo -> texto.
String roundTrip(String text) {
  final parser = ChordProParser();
  final song = parser.parse(text);
  return const ChordProSerializer().write(song);
}

/// Divide un archivo ChordPro que puede contener varias canciones
/// en una lista de textos, uno por canción.
/// Reglas de división:
/// 1. Si existe la directiva `{new_song}` -> divide ahí.
/// 2. Si no, divide en cada `{title:}` / `{t:}` posterior al primero.
/// 3. Descarta chunks vacíos (solo metadatos, sin líneas de contenido).
/// 4. Sin separadores claros -> devuelve el texto original como 1 canción.
List<String> splitChordProSongs(String text) {
  final lines = text.replaceAll('\r', '').split('\n');
  final splits = <int>[];

  // Buscar {new_song} primero
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i].trim().toLowerCase();
    if (line.startsWith('{new_song') || line == 'new_song') {
      splits.add(i);
    }
  }

  // Si no hay new_song, buscar {title:} / {t:} después del primero
  if (splits.isEmpty) {
    bool firstTitleFound = false;
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim().toLowerCase();
      if (line.startsWith('{title:') || line.startsWith('{t:')) {
        if (firstTitleFound) {
          splits.add(i);
        } else {
          firstTitleFound = true;
        }
      }
    }
  }

  // Si no hay divisiones, devolver el texto original
  if (splits.isEmpty) return [text];

  // Añadir el final del texto como límite
  splits.add(lines.length);

  // Construir chunks
  final chunks = <String>[];
  var start = 0;
  for (final end in splits) {
    final chunkLines = lines.sublist(start, end);
    final chunk = chunkLines.join('\n').trim();
    // Solo mantener si tiene contenido real (líneas no vacías que no sean solo metadatos)
    if (_hasRealContent(chunkLines)) {
      chunks.add(chunk);
    }
    start = end;
  }

  return chunks.isEmpty ? [text] : chunks;
}

/// Verifica si un chunk tiene contenido real (líneas de letra/acordes, no solo metadatos).
bool _hasRealContent(List<String> lines) {
  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;
    // Saltar líneas de metadatos y directivas de sección
    if (trimmed.startsWith('{') && (trimmed.contains(':') || trimmed.contains('start_of') || trimmed.contains('end_of') || trimmed.contains('comment') || trimmed.contains('new_song'))) continue;
    // Si hay algo que parece letra o acordes, es contenido real
    return true;
  }
  return false;
}
