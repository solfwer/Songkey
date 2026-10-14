// Panel lateral (drawer) de opciones de vista de la canción: acordes/letra,
// tamaño de fuente, compartir/exportar y acciones de edición/eliminación.
// Mutan [config] y avisan con [onChanged].
// El tono se ajusta desde el selector desplegable de la barra superior.
import 'package:flutter/material.dart';

import '../../../models/song.dart';
import '../../../services/song_export.dart';
import '../../../theme.dart';

/// Estado ajustable de la vista de canción (vive en el estado de la pantalla).
class SongViewConfig {
  double fontSize;
  bool lyricsOnly;

  /// Auto-ajuste: baja el tamaño de letra y usa hasta 3 columnas para que la
  /// canción entera quepa en pantalla; si no cabe, la reparte en páginas.
  bool autoFit = false;

  /// true = notación americana (C, G, Am); false = latina (Do, Sol, Lam).
  bool americanNotation;

  /// Auto-desplazamiento (auto-scroll) para lectura manos libres.
  /// True = habilitado en Opciones de vista. False = deshabilitado.
  bool autoScroll = false;

  /// True = el scroll está pausado por el usuario (botón del AppBar).
  /// Solo tiene sentido si [autoScroll] es true.
  bool autoScrollPaused = false;

  /// Velocidad de auto-scroll en px/s (10-100, por defecto 25).
  double autoScrollSpeed = 25.0;

  /// Transposición (en semitonos) elegida para cada canción. Se guarda por id
  /// de canción para que al cambiar el tono dentro de un setlist solo se
  /// mueva esa canción y las demás se queden en su tono original.
  final Map<String, int> _shiftBySong = {};

  SongViewConfig({required this.fontSize, this.lyricsOnly = false, this.americanNotation = true});

  /// Semitonos de transposición de una canción (0 = su tono original).
  int shiftFor(String songId) => _shiftBySong[songId] ?? 0;

  void setShift(String songId, int semitones) => _shiftBySong[songId] = semitones;

  /// Activa el desplazamiento automático (desde Opciones de vista).
  void enableAutoScroll() {
    autoScroll = true;
    autoScrollPaused = false;
  }

  /// Desactiva el desplazamiento automático (desde Opciones de vista).
  void disableAutoScroll() {
    autoScroll = false;
    autoScrollPaused = false;
  }

  /// Alterna la pausa del auto-scroll (desde el botón del AppBar).
  void toggleAutoScrollPause() => autoScrollPaused = !autoScrollPaused;

  /// Indica si el scroll está realmente moviéndose ahora.
  bool get isAutoScrolling => autoScroll && !autoScrollPaused;
}

class ViewOptionsPanel extends StatelessWidget {
  final Song song;

  /// true si la cancin se ve en vista compacta (Ajustes > Vista compacta).
  final bool compactView;

  /// Contexto de la pantalla (no del drawer): sigue montado tras cerrar el
  /// panel y se usa para compartir/exportar y para navegar al editor.
  final BuildContext hostContext;
  final SongViewConfig config;
  final VoidCallback onChanged;
  final Future<void> Function() onEdit;
  final VoidCallback onDelete;

  const ViewOptionsPanel({
    super.key,
    required this.song,
    required this.hostContext,
    required this.config,
    required this.onChanged,
    required this.onEdit,
    required this.onDelete,
    this.compactView = false,
  });

  Widget _panelLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
      child: Row(children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 8),
        Expanded(child: Text(text.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(letterSpacing: 1.5, color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold))),
      ]),
    );
  }

  Widget _panelCard(List<Widget> children) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Column(children: children)),
    );
  }

  Widget _choiceChip(BuildContext context, String label, IconData icon, bool selected, VoidCallback onTap) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: ChoiceChip(
        avatar: Icon(icon, size: 16, color: selected ? scheme.onPrimary : scheme.onSurfaceVariant),
        label: Text(label, style: TextStyle(fontSize: 12.5, color: selected ? scheme.onPrimary : scheme.onSurface)),
        selected: selected,
        selectedColor: AppColors.primary,
        showCheckmark: false,
        onSelected: (_) => onTap(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = (MediaQuery.of(hostContext).size.width * 0.95).clamp(0.0, 340.0).toDouble();
    return Drawer(
      width: width,
      child: SafeArea(
        child: ListView(padding: EdgeInsets.zero, children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppColors.primary.withValues(alpha: 0.95), AppColors.card]),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.tune, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Opciones de pantalla', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 2),
                Text(song.title, style: const TextStyle(color: Colors.white70, fontSize: 12.5), overflow: TextOverflow.ellipsis),
              ])),
            ]),
          ),
          _panelLabel('Visual'),
          _panelCard([
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Row(children: [
                _choiceChip(context, 'Acordes', Icons.music_note, !config.lyricsOnly, () {
                  config.lyricsOnly = false;
                  onChanged();
                }),
                const SizedBox(width: 8),
                _choiceChip(context, 'Solo letra', Icons.subject, config.lyricsOnly, () {
                  config.lyricsOnly = true;
                  onChanged();
                }),
              ]),
            ),
          ]),
          _panelLabel('Tamaño de letra'),
          _panelCard([
            SwitchListTile(
              secondary: const Icon(Icons.fit_screen, color: AppColors.accent),
              title: const Text('Ajuste automático'),
              subtitle: const Text('Baja el tamaño y usa columnas hasta que la canción completa quepa en pantalla'),
              value: config.autoFit,
              onChanged: (v) {
                config.autoFit = v;
                onChanged();
              },
            ),
            // El control de tamao se ve siempre, salvo cuando el auto-ajuste
            // manda del todo en la vista normal. En la compacta s se ve (es
            // el tamao mximo que se busca).
            if (!config.autoFit || compactView)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                child: Column(children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Icon(Icons.format_size, size: 20),
                      Text(compactView ? 'Tamaño máximo' : 'Tamaño de fuente'),
                      Text('${config.fontSize.round()}px', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.accent)),
                    ],
                  ),
                  Slider(value: config.fontSize, min: 12, max: 34, divisions: 22, label: config.fontSize.round().toString(), onChanged: (v) {
                    config.fontSize = v;
                    onChanged();
                  }),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Vista previa: AaGg', style: TextStyle(fontSize: config.fontSize.clamp(14.0, 24.0), color: AppColors.primary, fontWeight: FontWeight.bold)),
                  ),
                ]),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Ajuste automático activo: tamaño máximo ${config.fontSize.round()}px, mínimo 11px.', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ),
              ),
          ]),
          // Auto-scroll (desplazamiento automático)
          _panelLabel('Desplazamiento automático'),
          _panelCard([
            SwitchListTile(
              secondary: const Icon(Icons.play_circle_outline, color: AppColors.accent),
              title: const Text('Desplazamiento automático'),
              subtitle: Text(config.autoScroll
                  ? (config.autoScrollPaused ? 'Pausado — toca el botón ▶ en la barra superior' : 'Activo — toca el botón ⏸ en la barra superior para pausar')
                  : 'Desplaza la letra automáticamente para lectura manos libres'),
              value: config.autoScroll,
              onChanged: (v) {
                if (v) {
                  config.enableAutoScroll();
                } else {
                  config.disableAutoScroll();
                }
                onChanged();
              },
            ),
            if (config.autoScroll)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                child: Column(children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Icon(Icons.speed, size: 20),
                      const Text('Velocidad'),
                      Text('${config.autoScrollSpeed.round()} px/s', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.accent)),
                    ],
                  ),
                  Slider(value: config.autoScrollSpeed, min: 10, max: 100, divisions: 18, label: '${config.autoScrollSpeed.round()} px/s', onChanged: (v) {
                    config.autoScrollSpeed = v;
                    onChanged();
                  }),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Vista previa: ${config.autoScrollSpeed.round()} px/s', style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold)),
                  ),
                ]),
              ),
          ]),
          _panelLabel('Compartir y exportar'),
          _panelCard([
            ListTile(
              leading: const Icon(Icons.ios_share, color: AppColors.accent),
              title: const Text('Compartir letra'),
              subtitle: const Text('Texto con acordes en el tono actual'),
              onTap: () async {
                Navigator.pop(context);
                await shareSongText(hostContext, song, semitones: config.shiftFor(song.id), lyricsOnly: config.lyricsOnly);
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: AppColors.warm),
              title: const Text('Exportar PDF'),
              subtitle: const Text('Cancion en el tono actual; puedes compartirla o guardarla en el telfono'),
              onTap: () async {
                Navigator.pop(context);
                await shareSongPdf(hostContext, song, semitones: config.shiftFor(song.id), lyricsOnly: config.lyricsOnly);
              },
            ),
          ]),
          _panelLabel('Canción'),
          _panelCard([
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Editar letra y acordes'),
              onTap: () async {
                Navigator.pop(context);
                await onEdit();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.redAccent),
              title: const Text('Eliminar', style: TextStyle(color: Colors.redAccent)),
              onTap: () {
                Navigator.pop(context);
                onDelete();
              },
            ),
          ]),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }
}
