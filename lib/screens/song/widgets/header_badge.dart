// Distinguir visualmente los encabezados de seccin en el editor visual
// (mismo color que en la vista y en la vista previa).
import 'package:flutter/material.dart';

import '../../../data/chord_parser.dart';
import 'song_view.dart';

/// Insignia con el tipo y el nombre de la seccin ("V1 VERSO 1").
class HeaderBadge extends StatelessWidget {
  final String line;
  const HeaderBadge({required this.line});

  @override
  Widget build(BuildContext context) {
    Section? sec;
    try {
      final parsed = parseSong(line);
      sec = parsed.isEmpty ? null : parsed.first;
    } catch (_) {
      sec = null;
    }
    final kind = sec?.kind ?? SectionKind.other;
    final abbr = sec?.abbr ?? '';
    final color = sectionKindColor(kind);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (abbr.isNotEmpty)
          Text(abbr.toLowerCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
        if (abbr.isNotEmpty) const SizedBox(width: 6),
        Flexible(
          child: Text(
            line.trim().toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color, letterSpacing: 1.1),
          ),
        ),
      ]),
    );
  }
}
