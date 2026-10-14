// Controles del metrnomo: botn para el AppBar, barra compacta mientras suena
// y panel de configuracin (BPM, comps, subdivisin, acento, sonido, vibracin).
import 'package:flutter/material.dart';

import '../../../data/store.dart';
import '../../../models/song.dart';
import '../../../services/metronome.dart';

/// Estado compartido del metrnomo dentro de la pantalla de cancin.
class MetronomeController extends ChangeNotifier {
  final Store store;
  late final Metronome metronome;
  MetronomeSettings settings;
  bool activo = false;

  /// Beat actual dentro del comps (para el indicador visual).
  int beat = 0;
  bool acento = false;

  /// Id de la ltima cancin sincronizada (para no resetear el BPM en cada build).
  String? _lastSongId;

  MetronomeController(this.store, {Metronome? metro})
      : settings = MetronomeSettings(
          bpm: store.metroBpm,
          beatsPerBar: store.metroBeats,
          beatUnit: store.metroBeatUnit,
          subdivision: Subdivision.values[store.metroSub.clamp(0, Subdivision.values.length - 1)],
          accent: store.metroAccent,
          sound: store.metroSound,
          vibration: store.metroVib,
          clickSound: ClickSound.values[store.metroClick.clamp(0, ClickSound.values.length - 1)],
        ) {
    metronome = metro ?? Metronome(settings: settings);
    // Preparamos el sonido al crear el controlador; si el usuario le da play
    // antes de que est listo, toggle() espera a que termine.
    metronome.preparar().catchError((_) => false);
    metronome.onBeat = (b, a) {
      beat = b;
      acento = a;
      notifyListeners();
    };
  }

  /// true mientras se preparan los archivos de sonido.
  bool get preparando => metronome.preparando;

  /// Ajusta el BPM al de la cancin, pero solo al cambiar de cancin y solo si
  /// la cancin tiene BPM definido (si no, se respeta el ltimo usado).
  void syncWithSong(Song song) {
    if (_lastSongId == song.id) return;
    _lastSongId = song.id;
    final bpm = song.bpm;
    if (bpm != null && bpm > 0 && bpm != settings.bpm) {
      setBpm(bpm);
    }
  }

  void setBpm(int v) {
    final valor = v.clamp(30, 300);
    settings.bpm = valor;
    store.setMetroBpm(valor);
    if (activo) {
      metronome.stop();
      metronome.start();
    }
    notifyListeners();
  }

  void setCompas(int beats, int unit) {
    settings.beatsPerBar = beats;
    settings.beatUnit = unit;
    store.setMetroTime(beats, unit);
    notifyListeners();
  }

  void setSubdivision(Subdivision s) {
    settings.subdivision = s;
    store.setMetroSubdivision(s);
    if (activo) {
      metronome.stop();
      metronome.start();
    }
    notifyListeners();
  }

  void setAccent(bool v) {
    settings.accent = v;
    store.setMetroAccent(v);
    notifyListeners();
  }

  void setSound(bool v) {
    settings.sound = v;
    store.setMetroSound(v);
    notifyListeners();
  }

  /// Cambia el tipo de sonido del click (regenera los archivos).
  Future<void> setClickSound(ClickSound v) async {
    if (settings.clickSound == v) return;
    settings.clickSound = v;
    store.setMetroClick(v);
    notifyListeners();
    await metronome.regenerarSonido();
    // Si estaba sonando, reiniciamos con el sonido nuevo.
    if (activo) {
      metronome.restart();
    }
    notifyListeners();
  }

  void setVibration(bool v) {
    settings.vibration = v;
    store.setMetroVibration(v);
    notifyListeners();
  }

  /// Arranca o para. Si el sonido an se est preparando, espera.
  Future<void> toggle() async {
    if (activo) {
      metronome.stop();
      activo = false;
      notifyListeners();
      return;
    }
    if (settings.sound && !metronome.activo) {
      final listo = await metronome.preparar();
      if (!listo) {
        // El sonido no est disponible: avisamos pero seguimos (vibra).
        onSonidoNoDisponible?.call();
      }
    }
    metronome.start();
    activo = true;
    notifyListeners();
  }

  /// Aviso cuando el sonido no se pudo preparar (para mostrar un mensaje).
  VoidCallback? onSonidoNoDisponible;

  void stop() {
    if (activo) {
      metronome.stop();
      activo = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    metronome.dispose();
    super.dispose();
  }
}

/// Botón del AppBar: menú rápido con BPM, compás y play/stop, más el panel.
class MetronomeButton extends StatelessWidget {
  final MetronomeController controller;

  const MetronomeButton({super.key, required this.controller});

  /// BPM de uso rápido en el menú.
  static const _bpsRapidos = [60, 70, 80, 90, 100, 110, 120, 140, 160];

  static const _acentoColor = Color(0xFF5AD1E6);

  Widget _marca(bool ok) => ok ? const Icon(Icons.check, size: 18, color: _acentoColor) : const SizedBox.shrink();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final s = controller.settings;
        return PopupMenuButton<String>(
          tooltip: controller.activo ? 'Metrónomo sonando' : 'Metrónomo',
          icon: Icon(controller.activo ? Icons.timer : Icons.timer_outlined),
          color: controller.activo ? _acentoColor : null,
          itemBuilder: (context) => [
            PopupMenuItem<String>(
              value: 'play',
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(controller.activo ? Icons.stop : Icons.play_arrow),
                title: Text(controller.activo ? 'Parar' : 'Iniciar'),
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem<String>(enabled: false, child: Text('BPM')),
            for (final bpm in _bpsRapidos)
              PopupMenuItem<String>(
                value: 'bpm-$bpm',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.speed, size: 18),
                  title: Text('$bpm BPM'),
                  trailing: _marca(s.bpm == bpm),
                ),
              ),
            const PopupMenuDivider(),
            const PopupMenuItem<String>(enabled: false, child: Text('Comps')),
            for (final t in timeSignatures)
              PopupMenuItem<String>(
                value: 'compas-${t.beats}-${t.unit}',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.music_note, size: 18),
                  title: Text(t.label),
                  trailing: _marca(s.beatsPerBar == t.beats && s.beatUnit == t.unit),
                ),
              ),
            const PopupMenuDivider(),
            const PopupMenuItem<String>(
              value: 'mas',
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.tune, size: 18),
                title: Text('Ms ajustes...'),
              ),
            ),
          ],
          onSelected: (v) async {
            if (v == 'play') {
              await controller.toggle();
            } else if (v == 'mas') {
              _openSheet(context);
            } else if (v.startsWith('bpm-')) {
              controller.setBpm(int.parse(v.substring(4)));
            } else if (v.startsWith('compas-')) {
              final p = v.split('-');
              controller.setCompas(int.parse(p[1]), int.parse(p[2]));
            }
          },
        );
      },
    );
  }

  void _openSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => MetronomeSheet(controller: controller),
    );
  }
}

/// Barra compacta que se muestra mientras el metrnomo suena.
/// Círculos de los tiempos del compás: el actual se ilumina, el del acento es
/// ms grande y de otro color. Sirve para guiarse de un vistazo.
class BeatDots extends StatelessWidget {
  /// Cuntos tiempos tiene el compás (4 en 4/4, 3 en 3/4...).
  final int beats;

  /// Tiempo que est sonando ahora (0 = primero).
  final int actual;

  /// true si el click actual es el del acento.
  final bool acento;

  const BeatDots({super.key, required this.beats, required this.actual, this.acento = false});

  static const _colorActivo = Color(0xFF5AD1E6);
  static const _colorApagado = Color(0xFF3A3A44);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < beats; i++) ...[
          AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            width: i == actual && acento ? 16 : 12,
            height: i == actual && acento ? 16 : 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i == actual ? _colorActivo : _colorApagado,
              border: Border.all(
                color: i == actual ? _colorActivo : Colors.white24,
                width: i == actual && acento ? 2 : 1,
              ),
            ),
          ),
          if (i < beats - 1) const SizedBox(width: 5),
        ],
      ],
    );
  }
}
class MetronomeBar extends StatelessWidget {
  final MetronomeController controller;
  const MetronomeBar({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final s = controller.settings;
        return Container(
          width: double.infinity,
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              // Circulos: uno por tiempo del compas.
              BeatDots(
                beats: s.beatsPerBar,
                actual: controller.beat,
                acento: controller.acento,
              ),
              const SizedBox(width: 8),
              // BPM con - y +
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.remove, size: 18),
                tooltip: 'Ms lento',
                onPressed: () => controller.setBpm(s.bpm - 1),
              ),
              Text('${s.bpm}', style: const TextStyle(fontWeight: FontWeight.bold)),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.add, size: 18),
                tooltip: 'Ms rpido',
                onPressed: () => controller.setBpm(s.bpm + 1),
              ),
              const SizedBox(width: 4),
              // Comps
              DropdownButton<int>(
                value: s.beatsPerBar,
                isDense: true,
                underline: const SizedBox.shrink(),
                items: [
                  for (final t in timeSignatures)
                    if (s.beatUnit == 8 ? t.unit == 8 : t.unit == 4) DropdownMenuItem(value: t.beats, child: Text(t.label)),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  final unit = s.beatUnit == 8
                      ? timeSignatures.firstWhere((t) => t.beats == v && t.unit == 8, orElse: () => timeSignatures.first).unit
                      : timeSignatures.firstWhere((t) => t.beats == v && t.unit == 4, orElse: () => timeSignatures.first).unit;
                  controller.setCompas(v, unit);
                },
              ),
              const SizedBox(width: 4),
              // Subdivisin
              DropdownButton<Subdivision>(
                value: s.subdivision,
                isDense: true,
                underline: const SizedBox.shrink(),
                items: [for (final sub in Subdivision.values) DropdownMenuItem(value: sub, child: Text(sub.label))],
                onChanged: (v) {
                  if (v != null) controller.setSubdivision(v);
                },
              ),
              const SizedBox(width: 4),
              // Interruptores
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: s.accent ? 'Acento activado' : 'Acento desactivado',
                icon: Icon(s.accent ? Icons.arrow_upward : Icons.remove, size: 18, color: s.accent ? const Color(0xFF5AD1E6) : Colors.grey),
                onPressed: () => controller.setAccent(!s.accent),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: s.sound ? 'Silenciar' : 'Activar sonido',
                icon: Icon(s.sound ? Icons.volume_up : Icons.volume_off, size: 18, color: s.sound ? null : Colors.grey),
                onPressed: () => controller.setSound(!s.sound),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: s.vibration ? 'Quitar vibracin' : 'Activar vibracin',
                icon: Icon(s.vibration ? Icons.vibration : Icons.notifications_off, size: 18, color: s.vibration ? null : Colors.grey),
                onPressed: () => controller.setVibration(!s.vibration),
              ),
              const SizedBox(width: 4),
              TextButton.icon(
                onPressed: controller.stop,
                icon: const Icon(Icons.stop, size: 18),
                label: const Text('Parar'),
              ),
            ]),
          ),
        );
      },
    );
  }
}

/// Panel de configuracin del metrnomo.
class MetronomeSheet extends StatelessWidget {
  final MetronomeController controller;
  const MetronomeSheet({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final s = controller.settings;
        return Padding(
          padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 16 + MediaQuery.of(context).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                const Icon(Icons.timer_outlined),
                const SizedBox(width: 8),
                const Text('Metrónomo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  icon: Icon(controller.activo ? Icons.stop_circle : Icons.play_circle_fill),
                  iconSize: 32,
                  color: controller.activo ? Colors.redAccent : const Color(0xFF5AD1E6),
                  tooltip: controller.activo ? 'Parar' : 'Iniciar',
                  onPressed: controller.toggle,
                ),
              ]),
              const SizedBox(height: 8),
              // BPM
              Row(children: [
                Text('${s.bpm}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(width: 4),
                const Text('BPM', style: TextStyle(color: Colors.grey)),
                const Spacer(),
                IconButton.filledTonal(onPressed: () => controller.setBpm(s.bpm - 1), icon: const Icon(Icons.remove)),
                const SizedBox(width: 8),
                IconButton.filledTonal(onPressed: () => controller.setBpm(s.bpm + 1), icon: const Icon(Icons.add)),
              ]),
              Slider(
                value: s.bpm.toDouble().clamp(30, 300),
                min: 30,
                max: 300,
                divisions: 270,
                label: '${s.bpm} BPM',
                onChanged: (v) => controller.setBpm(v.round()),
              ),
              const Divider(),
              // Comps
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.music_note),
                title: const Text('Comps'),
                trailing: DropdownButton<int>(
                  value: s.beatsPerBar,
                  items: [for (final t in timeSignatures) DropdownMenuItem(value: t.beats, child: Text(t.label))],
                  onChanged: (v) {
                    if (v == null) return;
                    final t = timeSignatures.firstWhere((t) => t.beats == v, orElse: () => timeSignatures.first);
                    controller.setCompas(t.beats, t.unit);
                  },
                ),
              ),
              // Subdivisin
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.grid_4x4),
                title: const Text('Subdivisin'),
                trailing: DropdownButton<Subdivision>(
                  value: s.subdivision,
                  items: [for (final sub in Subdivision.values) DropdownMenuItem(value: sub, child: Text(sub.label))],
                  onChanged: (v) {
                    if (v != null) controller.setSubdivision(v);
                  },
                ),
              ),
              const Divider(),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.arrow_upward),
                title: const Text('Primer tiempo ms fuerte'),
                subtitle: const Text('Acento en el primer pulso del comps'),
                value: s.accent,
                onChanged: controller.setAccent,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.volume_up),
                title: const Text('Sonido'),
                value: s.sound,
                onChanged: controller.setSound,
              ),
              // Tipo de sonido del click.
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.graphic_eq),
                title: const Text('Tipo de sonido'),
                trailing: DropdownButton<ClickSound>(
                  value: s.clickSound,
                  items: [for (final c in ClickSound.values) DropdownMenuItem(value: c, child: Text(c.label))],
                  onChanged: (v) {
                    if (v != null) controller.setClickSound(v);
                  },
                ),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.vibration),
                title: const Text('Vibracin'),
                value: s.vibration,
                onChanged: controller.setVibration,
              ),
            ]),
          ),
        );
      },
    );
  }
}
