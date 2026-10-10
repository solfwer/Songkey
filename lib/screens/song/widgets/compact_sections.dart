// Secciones nicas para la vista compacta.
//
// La vista normal recorre el arreglo (arrangement) y dibuja cada referencia
// con sus repeticiones. La vista compacta hace lo contrario: ignora el
// arreglo y recorre las secciones UNA SOLA VEZ cada una, en el orden de su
// primera aparicin, con una etiqueta "x2" si suena varias veces. Las
// secciones que no estn en el arreglo se ajen al final.
//
// Estas funciones son puras: no tocan la cancin, solo la leen.
import '../../../data/chord_parser.dart';
import '../../../models/song.dart';

/// Una seccin nica con su contador de apariciones en el arreglo.
class CompactSection {
  /// Etiqueta tal como se ve ("VERSO 1", "CORO"...).
  final String label;

  /// Tipo, para el color y el badge.
  final SectionKind kind;

  /// Letra de la seccin (una sola vez, aunque se repita en el arreglo).
  final List<SongLine> lines;

  /// Veces que aparece en el arreglo (0 si no est en el arreglo).
  final int repeats;

  /// true si el arreglo la usa al menos una vez.
  bool get enArreglo => repeats > 0;

  const CompactSection({
    required this.label,
    required this.kind,
    required this.lines,
    required this.repeats,
  });

  /// true si hay que mostrar la etiqueta "x2", "x3"...
  bool get muestraRepeticion => repeats > 1;
}

/// Clave de comparacin: "VERSO 1", "verso 1" y "Verso 1" son la misma.
String _key(String s) {
  var t = s.trim().toLowerCase();
  t = t
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ü', 'u')
      .replaceAll('ñ', 'n');
  return t.replaceAll(RegExp(r'\s+'), ' ');
}

Section? _porClave(List<Section> secs, String clave) {
  for (final s in secs) {
    if (_key(s.label) == clave) return s;
  }
  return null;
}

/// Calcula las secciones nicas de una cancin con su contador de repeticiones.
///
/// [arrangement] es el orden de toque guardado (`Song.structure`): una lista
/// de etiquetas que admite repeticiones. Si es null o est vaca, se usa el
/// orden del propio cuerpo.
List<CompactSection> compactSectionsFrom(String body, List<String>? arrangement) {
  final canon = sectionsInOrder(body, null);
  if (canon.isEmpty) return const [];

  final refs = (arrangement == null || arrangement.isEmpty) ? [for (final s in canon) s.label] : arrangement;

  // Cuntas veces aparece cada seccin en el arreglo.
  final counts = <String, int>{};
  for (final r in refs) {
    final k = _key(r);
    counts[k] = (counts[k] ?? 0) + 1;
  }

  final out = <CompactSection>[];
  final vistas = <String>{};

  // 1) En el orden de su primera aparicin en el arreglo.
  for (final r in refs) {
    final k = _key(r);
    if (vistas.contains(k)) continue;
    final sec = _porClave(canon, k);
    if (sec == null) continue;
    vistas.add(k);
    out.add(CompactSection(label: sec.label, kind: sec.kind, lines: sec.lines, repeats: counts[k] ?? 1));
  }

  // 2) Las que no suenan en el arreglo, al final y en el orden del cuerpo.
  for (final sec in canon) {
    final k = _key(sec.label);
    if (vistas.contains(k)) continue;
    vistas.add(k);
    out.add(CompactSection(label: sec.label, kind: sec.kind, lines: sec.lines, repeats: 0));
  }

  return out;
}

/// Lo mismo, a partir del modelo de cancin de la app.
List<CompactSection> compactSections(Song song) => compactSectionsFrom(song.body, song.structure);

/// Total de veces que suena la cancin segn el arreglo (para el contador).
int totalRepeticiones(List<CompactSection> secs) => secs.fold(0, (a, s) => a + (s.repeats > 0 ? s.repeats : 1));
