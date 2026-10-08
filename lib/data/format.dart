/// Utilidades de formato para mostrar fechas y duraciones en español.
library;

const List<String> _meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
const List<String> _dias = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
const List<String> _diasLargo = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];
const List<String> _mesesLargo = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
];

/// "3:45" a partir de segundos; cadena vacía si no hay duración.
String formatDuration(int? seconds) {
  if (seconds == null || seconds <= 0) return '';
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

/// Analiza "3:45" o "225" a segundos; null si no es válido.
int? parseDuration(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return null;
  final m = RegExp(r'^(\d+):([0-5]?\d)$').firstMatch(t);
  if (m != null) return int.parse(m.group(1)!) * 60 + int.parse(m.group(2)!);
  final n = int.tryParse(t);
  return n == null || n < 0 ? null : n;
}

/// "2026-10-08" -> "8 oct 2026". Cadena vacía si no se puede interpretar.
String formatShortDate(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  return '${d.day} ${_meses[d.month - 1]} ${d.year}';
}

/// "2026-10-08" -> "jueves 8 de octubre de 2026".
String formatLongDate(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  return '${_diasLargo[d.weekday - 1]} ${d.day} de ${_mesesLargo[d.month - 1]} de ${d.year}';
}

/// "2026-10-08" -> "jue 8 oct".
String formatChipDate(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  return '${_dias[d.weekday - 1]} ${d.day} ${_meses[d.month - 1]}';
}