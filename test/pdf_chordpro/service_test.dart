// Tests del importador de PDF -> ChordPro (se prueban con lneas simuladas,
// sin necesidad de un PDF real).
import 'package:appchords/data/chord_parser.dart';
import 'package:appchords/data/chordpro.dart';
import 'package:appchords/services/pdf_chordpro/pdf_to_chordpro_service.dart';
import 'package:appchords/services/pdf_chordpro/pdf_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Linea de texto con la X de cada carcter.
PdfLine txt(
  String text, {
  required double top,
  double left = 0,
  double charWidth = 8,
  double fontSize = 12,
  int page = 0,
}) {
  final xs = [for (var i = 0; i < text.length; i++) left + i * charWidth];
  return PdfLine(words: [
    PdfWord(
      text: text,
      left: left,
      top: top,
      right: left + text.length * charWidth,
      bottom: top + fontSize,
      fontSize: fontSize,
      glyphLefts: xs,
    )
  ], page: page);
}

/// Linea de acordes: cada "acorde@X".
PdfLine chordLine(String spec, {required double top, double charWidth = 8, int page = 0, double left = 0}) {
  final words = <PdfWord>[];
  var x = left;
  for (final part in spec.split(' ')) {
    if (part.isEmpty) continue;
    final at = part.lastIndexOf('@');
    final text = at < 0 ? part : part.substring(0, at);
    final pos = at < 0 ? x : left + double.parse(part.substring(at + 1));
    words.add(PdfWord(text: text, left: pos, top: top, right: pos + text.length * charWidth, bottom: top + 12, fontSize: 12));
    x = words.last.right + charWidth;
  }
  return PdfLine(words: words, page: page);
}

/// Una lnea de acordes sobre su letra (top = donde empieza el bloque).
List<PdfLine> pareja(String chords, String lyric, {double top = 100, double charWidth = 8, double left = 0}) => [
      chordLine(chords, top: top, charWidth: charWidth, page: 0, left: left),
      txt(lyric, top: top + 16, charWidth: charWidth, left: left),
    ];

void main() {
  const service = PdfToChordProService();

  group('cancion de una columna', () {
    test('convierte acordes sobre letra en ChordPro canonico', () {
      final lines = <PdfLine>[
        txt('MI CANCION', top: 60, fontSize: 22),
        txt('INTRODUCCION:', top: 100),
        chordLine('C#m@0 A@60 E@120', top: 116),
        ...pareja('Am@0 C@40', 'Hola mundo de gracia', top: 140),
      ];
      final res = service.buildFromLines(lines);
      expect(res.title, 'MI CANCION');
      expect(res.suggestedKey, 'Am');
      expect(res.chordPro, contains('{title: MI CANCION}'));
      expect(res.chordPro, contains('{start_of_introduccion: INTRODUCCIÓN}'));
      expect(res.chordPro, contains('[C#m] | [A] | [E]'));
      // La línea del título se excluye del cuerpo: no hay encabezado de verso,
      // así que no debe aparecer {start_of_verse: VERSO 1}.
      expect(res.chordPro, isNot(contains('{start_of_verse: VERSO 1}')));
      // El acorde queda en su sílaba (dentro de la sección de introducción).
      expect(res.chordPro, contains('[Am]Hola'));
      expect(res.warnings.where((w) => w.kind == WarningKind.chordWithoutLyric), isEmpty);
    });

    test('los acodes al final de linea se ponen al final', () {
      final lines = pareja('G@200', 'Hola mundo', top: 100);
      final res = service.buildFromLines(lines);
      expect(res.chordPro, contains('Hola mundo[G]'));
    });

    test('lnea de acodes sin letra debajo es instrumental', () {
      final lines = <PdfLine>[
        txt('INTRODUCCION:', top: 100),
        chordLine('C@0 G@40 Am@80', top: 116),
        txt('VERSO 1', top: 150),
        txt('Y ahora si la letra', top: 170),
      ];
      final res = service.buildFromLines(lines);
      expect(res.chordPro, contains('[C] | [G] | [Am]'));
      expect(res.chordPro, contains('Y ahora si la letra'));
    });

    test('avisa cuando una lnea de acordes no encuentra letra', () {
      final lines = <PdfLine>[
        txt('VERSO 1', top: 100),
        chordLine('C@0 G@40', top: 116),
        // La letra est demasiado lejos para emparejarla, pero lo suficiente
        // como para sospechar que se ha perdido.
        txt('Y ahora si la letra', top: 180),
      ];
      final res = service.buildFromLines(lines);
      final aviso = res.warnings.where((w) => w.kind == WarningKind.chordWithoutLyric);
      expect(aviso.length, 1);
      expect(aviso.first.message, contains('sin letra clara'));
      // La letra se conserva igualmente.
      expect(res.chordPro, contains('Y ahora si la letra'));
    });

    test('avisa de letra con acordes mezclados', () {
      final lines = <PdfLine>[
        txt('VERSO 1', top: 100),
        txt('Canta C fuerte G hoy', top: 120),
      ];
      final res = service.buildFromLines(lines);
      expect(res.warnings.where((w) => w.kind == WarningKind.ambiguous), isNotEmpty);
    });
  });

  group('encabezados con distintas escrituras', () {
    test('se normalizan al formato canonico', () {
      final lines = <PdfLine>[
        txt('Verso 1', top: 100),
        txt('primera linea', top: 120),
        txt('PRE-CORO', top: 160),
        txt('segunda linea', top: 180),
        txt('CORO', top: 220),
        txt('tercera linea', top: 240),
        txt('Puente', top: 280),
        txt('cuarta linea', top: 300),
      ];
      final res = service.buildFromLines(lines);
      expect(res.chordPro, contains('{start_of_verse: VERSO 1}'));
      expect(res.chordPro, contains('{start_of_chorus: PRE-CORO}'));
      expect(res.chordPro, contains('{start_of_chorus: CORO}'));
      expect(res.chordPro, contains('{start_of_bridge: PUENTE}'));

      // Los tipos salen bien para pintar el color.
      final song = ChordProParser().parse(res.chordPro);
      expect(song.sections.map((s) => s.label).toList(), ['VERSO 1', 'PRE-CORO', 'CORO', 'PUENTE']);
      expect(song.sections.first.kind, SectionKind.verse);
      expect(song.sections[1].kind, SectionKind.prechorus);
      expect(song.sections[2].kind, SectionKind.chorus);
      expect(song.sections[3].kind, SectionKind.bridge);
    });

    test('una linea que solo parece encabezado no rompe nada', () {
      final lines = <PdfLine>[
        txt('Coro de angeles cantan', top: 100),
        txt('linea suelta', top: 120),
      ];
      final res = service.buildFromLines(lines);
      expect(res.chordPro, contains('Coro de angeles cantan'));
      expect(res.chordPro, isNot(contains('{start_of_chorus')));
    });
  });

  group('dos columnas', () {
    test('procesa cada columna de arriba hacia abajo', () {
      final lines = <PdfLine>[
        // Columna izquierda
        txt('VERSO 1', top: 100, left: 0),
        ...pareja('C@0 G@40', 'letra de la izquierda uno', top: 120, left: 0),
        ...pareja('Am@0', 'letra de la izquierda dos', top: 180, left: 0),
        // Columna derecha
        txt('CORO', top: 100, left: 300),
        ...pareja('F@0 C@40', 'letra de la derecha uno', top: 120, left: 300),
        ...pareja('Dm@0', 'letra de la derecha dos', top: 180, left: 300),
      ];
      final res = service.buildFromLines(lines, pageWidth: 600);
      expect(res.columns, 2);
      expect(res.warnings.where((w) => w.kind == WarningKind.mixedColumn), isNotEmpty);
      // Cada letra se queda con sus propios acordes, no con los de la otra
      // columna.
      final song = ChordProParser().parse(res.chordPro);
      final izq = song.sections.firstWhere((s) => s.label == 'VERSO 1');
      final der = song.sections.firstWhere((s) => s.label == 'CORO');
      expect(izq.lines.first.chords.map((c) => c.chord).toList(), ['C', 'G']);
      expect(der.lines.first.chords.map((c) => c.chord).toList(), ['F', 'C']);
      // Y las dos letras no se han mezclado en la misma lnea.
      expect(izq.lines.first.lyric, 'letra de la izquierda uno');
      expect(der.lines.first.lyric, 'letra de la derecha uno');
    });
  });

  group('tonalidad y titulo', () {
    test('sugiere la tonalidad del primer acorde', () {
      final res = service.buildFromLines([
        chordLine('D@0 A@40 Bm@80', top: 116, page: 0),
        txt('algo de letra', top: 140),
      ]);
      expect(res.suggestedKey, 'D');
    });

    test('usa el nombre del archivo si no hay titulo', () {
      final res = service.buildFromLines([
        txt('letra sin encabezar', top: 100),
      ], fallbackTitle: 'archivo.pdf');
      expect(res.title, 'archivo.pdf');
    });

    test('el titulo detectado gana sobre el nombre del archivo', () {
      final res = service.buildFromLines([
        txt('MI CANCION', top: 60, fontSize: 22),
        txt('letra de la cancion', top: 100),
      ], fallbackTitle: 'archivo.pdf');
      expect(res.title, 'MI CANCION');
    });

    test('avisa noTitle si no hay ni detectado ni fallback', () {
      final res = service.buildFromLines([
        txt('letra sin encabezar', top: 100),
      ]);
      expect(res.title, 'Canción');
      final avisos = res.warnings.where((w) => w.kind == WarningKind.noTitle);
      expect(avisos, isNotEmpty);
    });

    test('la línea del título no aparece en el cuerpo', () {
      final res = service.buildFromLines([
        txt('MI CANCION', top: 60, fontSize: 22),
        txt('letra de la cancion', top: 100),
      ]);
      // La línea del título no está en el cuerpo (solo en el metadato {title:}).
      expect(res.chordPro, contains('{title: MI CANCION}'));
      expect(res.chordPro, isNot(contains('\nMI CANCION\n')));
      expect(res.chordPro, contains('letra de la cancion'));
    });

    test('PDF sin texto devuelve aviso noText', () {
      final res = service.buildFromLines([]);
      expect(res.title, 'Canción');
      expect(res.chordPro, isEmpty);
      final avisos = res.warnings.where((w) => w.kind == WarningKind.noText);
      expect(avisos, isNotEmpty);
      expect(avisos.first.message, contains('escaneado'));
    });
  });

  group('titulo y mezcla por posicion', () {
    test('titulo en mayusculas sin tamaño distinto no se vuelve verso', () {
      final lines = <PdfLine>[
        txt('CIELO EN LA TIERRA', top: 60, fontSize: 12),
        txt('VERSO 1', top: 100),
        txt('El cielo y la tierra creó', top: 120),
      ];
      final res = service.buildFromLines(lines);
      expect(res.title, 'CIELO EN LA TIERRA');
      expect(res.chordPro, contains('{title: CIELO EN LA TIERRA}'));
      // La línea del título no cuela como primer verso.
      expect(res.chordPro, isNot(contains('{start_of_verse: VERSO 1}\nCIELO')));
      expect(res.chordPro, contains('El cielo y la tierra creó'));
    });

    test('acorde se coloca sobre la sílaba cuya X es la más cercana (glifos)', () {
      // 'Hola mundo' con charWidth 8: H=0 o=8 l=16 a=24 ' '=32 m=40 u=48 n=56 d=64 o=72
      final lines = pareja('G@16', 'Hola mundo', top: 100, charWidth: 8, left: 0);
      final res = service.buildFromLines(lines);
      expect(res.chordPro, contains('Ho[G]la mundo'));
    });

    test('acorde sin letra debajo es línea de compases', () {
      final lines = <PdfLine>[
        txt('INTRO x2', top: 100),
        chordLine('C#m@0 A@40 E@80 B@120', top: 116),
        txt('VERSO 1', top: 160),
        txt('letra de prueba', top: 180),
      ];
      final res = service.buildFromLines(lines);
      expect(res.chordPro, contains('{start_of_introduccion: INTRODUCCIÓN x2}'));
      expect(res.chordPro, contains('[C#m] | [A] | [E] | [B]'));
      expect(res.chordPro, contains('letra de prueba'));
    });
  });
}
