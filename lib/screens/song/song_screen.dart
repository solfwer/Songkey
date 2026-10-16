// Vista de canción: orquesta la cabecera (selector de tono), el cuerpo
// (vista normal) y el panel lateral de opciones. Si la canción viene de un
// setlist, el cuerpo es un PageView horizontal: se pasa de una canción a otra
// deslizando el dedo (sin botones). El dibujo de líneas/chips vive en
// widgets/song_view.dart, el panel en widgets/view_options_panel.dart y el
// editor en song_editor_page.dart.
import 'package:flutter/material.dart';

import '../../data/chord_parser.dart';
import '../../data/store.dart';
import '../../models/app_state.dart';
import '../../models/setlist.dart';
import '../../models/song.dart';
import '../../theme.dart';
import 'song_editor_page.dart';
import 'widgets/compact_song_view.dart';
import 'widgets/song_view.dart';
import 'widgets/metronome_controls.dart';
import 'widgets/view_options_panel.dart';

class SongScreen extends StatefulWidget {
  final Store store;
  final String songId;
  final String? setlistId;
  const SongScreen({super.key, required this.store, required this.songId, this.setlistId});

  @override
  State<SongScreen> createState() => _SongScreenState();
}

class _SongScreenState extends State<SongScreen> {
  late final SongViewConfig config = SongViewConfig(
    fontSize: widget.store.defaultFontSize,
    lyricsOnly: widget.store.defaultLyricsOnly,
    americanNotation: widget.store.americanNotation,
  );
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  /// Metronomo: los ajustes se comparten entre canciones, pero el BPM se
  /// adapta al de la cancion cuando esta lo tiene definido.
  late final MetronomeController _metro;

  // Navegación por deslizamiento entre canciones de un setlist.
  PageController? _pageController;
  int _pageIndex = 0;
  String _visibleSongId = '';

  @override
  void initState() {
    super.initState();
    _metro = MetronomeController(widget.store);
    final s = widget.store.state;
    final ids = _setlistSongIds(s);
    var idx = ids.indexOf(widget.songId);
    if (idx < 0) idx = 0;
    _pageIndex = idx;
    _visibleSongId = ids.isEmpty ? widget.songId : ids[idx];
    if (ids.length > 1) {
      _pageController = PageController(initialPage: _pageIndex);
    }
    // Marcar como recién abierta para "Canciones recientes" del inicio.
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.store.markSongOpened(_visibleSongId));
  }

  @override
  void dispose() {
    _metro.dispose();
    super.dispose();
  }

  /// Ids visibles del setlist (ignorando canciones borradas).
  List<String> _setlistSongIds(AppState s) {
    if (widget.setlistId == null) return const [];
    final list = s.setlists.where((l) => l.id == widget.setlistId).firstOrNull;
    if (list == null) return const [];
    return list.songIds.where((id) => s.songs.any((x) => x.id == id)).toList();
  }

  /// Resuelve la canción a mostrar: si hay override en el setlist, usa ese.
  Song _resolveSong(Song original, AppState s) {
    if (widget.setlistId == null) return original;
    final list = s.setlists.where((l) => l.id == widget.setlistId).firstOrNull;
    if (list == null) return original;
    final override = list.getOverride(original.id);
    return override?.toSong() ?? original;
  }

  void _onPageChanged(int p) {
    final ids = _setlistSongIds(widget.store.state);
    if (p < 0 || p >= ids.length) return;
    setState(() {
      _pageIndex = p;
      _visibleSongId = ids[p];
    });
    widget.store.markSongOpened(ids[p]);
  }

  /// Guarda el tono de una canción en el override del setlist (no modifica la original).
  void _guardarTonoEnSetlist(String songId, String nuevoKey) {
    final s = widget.store.state;
    final list = s.setlists.where((l) => l.id == widget.setlistId).firstOrNull;
    if (list == null) return;
    final original = s.songs.where((x) => x.id == songId).firstOrNull;
    if (original == null) return;
    final override = list.getOverride(songId);
    final nuevoOverride = SongOverride(
      songId: songId,
      title: override?.title ?? original.title,
      author: override?.author ?? original.author,
      key: nuevoKey,
      bpm: override?.bpm ?? original.bpm,
      body: override?.body ?? original.body,
      style: override?.style ?? original.style,
      durationSec: override?.durationSec ?? original.durationSec,
      structure: override?.structure ?? original.structure,
      timeSignature: override?.timeSignature ?? original.timeSignature,
    );
    widget.store.update((st) => AppState(
          groups: st.groups,
          songs: st.songs,
          setlists: st.setlists.map((l) {
            if (l.id != widget.setlistId) return l;
            return l.withOverride(songId, nuevoOverride);
          }).toList(),
        ));
  }

  Future<void> _delete(Song song) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: Text('¿Eliminar "${song.title}"?'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar'))]));
    if (ok == true) {
      if (widget.setlistId != null) {
        // Desde setlist: solo quita del setlist y borra override, NO borra la canción original
        widget.store.update((st) => AppState(
              groups: st.groups,
              songs: st.songs,
              setlists: st.setlists.map((l) {
                if (l.id != widget.setlistId) return l;
                return l.copyWith(
                  songIds: l.songIds.where((i) => i != song.id).toList(),
                  readyIds: l.readyIds.where((i) => i != song.id).toList(),
                  songOverrides: {...l.songOverrides}..remove(song.id),
                );
              }).toList(),
            ));
      } else {
        // Desde biblioteca: borra la canción original y limpia setlists
        widget.store.update((st) => AppState(
              groups: st.groups,
              songs: st.songs.where((x) => x.id != song.id).toList(),
              setlists: st.setlists.map((l) => l.copyWith(songIds: l.songIds.where((i) => i != song.id).toList(), readyIds: l.readyIds.where((i) => i != song.id).toList())).toList(),
            ));
      }
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.store.state;
    final song = s.songs.where((x) => x.id == widget.songId).firstOrNull;
    if (song == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('Canción no encontrada')));
    }
    final ids = _setlistSongIds(s);
    final swipe = ids.length > 1;
    final displayed = swipe ? _resolveSong(s.songs.where((x) => x.id == _visibleSongId).firstOrNull ?? song, s) : _resolveSong(song, s);

    // El BPM del metrónomo se adapta a esta canción (si tiene BPM definido).
    _metro.syncWithSong(displayed);

    // La barra del metrónomo solo se ve mientras está sonando.
    final metroBar = ListenableBuilder(
      listenable: _metro,
      builder: (context, _) => _metro.activo ? MetronomeBar(controller: _metro) : const SizedBox.shrink(),
    );

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(displayed.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17)),
        actions: [
          _KeySelector(
            currentKey: widget.setlistId != null
                ? displayed.key
                : sharpen(transposeChord(displayed.key, config.shiftFor(displayed.id))),
            american: config.americanNotation,
            onSelected: (k) {
              if (widget.setlistId != null) {
                // Guardar el tono en el override del setlist (no toca la original)
                _guardarTonoEnSetlist(displayed.id, k);
              } else {
                setState(() => config.setShift(displayed.id, semitoneShift(displayed.key, k)));
              }
            },
          ),
          // Botón pausa/reanudar del desplazamiento automático (solo visible si está habilitado en opciones).
          if (config.autoScroll)
            IconButton(
              icon: Icon(config.autoScrollPaused ? Icons.play_circle_filled : Icons.pause_circle_filled),
              tooltip: config.autoScrollPaused ? 'Reanudar desplazamiento' : 'Pausar desplazamiento',
              color: config.autoScrollPaused ? null : AppColors.accent,
              onPressed: () => setState(() => config.toggleAutoScrollPause()),
            ),
          // Metrónomo.
          MetronomeButton(controller: _metro, song: displayed),
          IconButton(icon: const Icon(Icons.tune), tooltip: 'Opciones de vista', onPressed: () => _scaffoldKey.currentState?.openEndDrawer()),
        ],
      ),
      endDrawer: ViewOptionsPanel(
        song: displayed,
        hostContext: context,
        config: config,
        compactView: widget.store.compactView,
        onChanged: () => setState(() {}),
        onEdit: () async {
          await Navigator.of(context).push(MaterialPageRoute(builder: (_) => SongEditorPage(store: widget.store, song: displayed, setlistId: widget.setlistId)));
          if (mounted) setState(() {});
        },
        onDelete: () => _delete(displayed),
      ),
      body: Column(children: [
        metroBar,
        Expanded(
          child: swipe
              ? PageView.builder(
                  controller: _pageController,
                  itemCount: ids.length,
                  onPageChanged: _onPageChanged,
                  itemBuilder: (context, i) {
                    final pageSong = s.songs.where((x) => x.id == ids[i]).firstOrNull;
                    if (pageSong == null) return const SizedBox.shrink();
                    return _SongPage(song: _resolveSong(pageSong, s), store: widget.store, config: config);
                  },
                )
              : _SongPage(song: displayed, store: widget.store, config: config),
        ),
      ]),
    );
  }
}

/// Selector desplegable de tonalidad: muestra siempre el tono actual
/// (el de la cancin o el transpuesto) y permite cambiarlo entre los 12 tonos.
/// [currentKey] va en escritura de sostenidos para cuadrar con los items.
class _KeySelector extends StatelessWidget {
  final String currentKey;
  final bool american;
  final ValueChanged<String> onSelected;
  const _KeySelector({super.key, required this.currentKey, required this.american, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: currentKey,
          icon: const Icon(Icons.keyboard_arrow_down, size: 20),
          onChanged: (k) {
            if (k != null) onSelected(k);
          },
          items: [
            for (final k in twelveKeys)
              DropdownMenuItem<String>(value: k, child: Text(notateChord(k, american: american), style: const TextStyle(fontWeight: FontWeight.bold))),
          ],
        ),
      ),
    );
  }
}

/// Página de una canción: línea de metadatos, chips de secciones y cuerpo con
/// desplazamiento propio. Una copia por canción del setlist dentro del
/// PageView (para que cada una recuerde su scroll y sus saltos de sección).
class _SongPage extends StatefulWidget {
  final Song song;
  final Store store;
  final SongViewConfig config;
  const _SongPage({required this.song, required this.store, required this.config});

  @override
  State<_SongPage> createState() => _SongPageState();
}

class _SongPageState extends State<_SongPage> {
  final _scrollController = ScrollController();
  final _sectionKeys = <String, GlobalKey>{};

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }


  void _scrollToSection(Section sec) {
    final ctx = _sectionKeys[sec.id]?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 300), curve: Curves.easeOut, alignment: 0.06);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Secciones en orden de toque (repeticiones incluidas según la
    // estructura), con ids únicos por aparición para los saltos de sección.
    final ordered = sectionsInOrder(widget.song.body, widget.song.structure);
    final sections = <Section>[
      for (var i = 0; i < ordered.length; i++)
        Section(
          id: 'sec$i',
          kind: ordered[i].kind,
          abbr: ordered[i].abbr,
          label: ordered[i].label,
          lines: ordered[i].lines,
        ),
    ];

    // Mantener las claves de sección alineadas con las secciones actuales.
    final ids = sections.map((x) => x.id).toSet();
    _sectionKeys.removeWhere((k, _) => !ids.contains(k));
    for (final sec in sections) {
      _sectionKeys.putIfAbsent(sec.id, () => GlobalKey());
    }

    return Column(children: [
      // Mapa de la canción: una ficha por aparición, con el contador de
      // repeticiones; al tocar una se salta a ella.
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        child: Row(children: [
          Flexible(
            child: Text('MAPA DE LA CANCIÓN', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 9, letterSpacing: 1.5, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          Text('${sections.length} partes', maxLines: 1, style: TextStyle(fontSize: 9, color: Colors.grey.shade600)),
        ]),
      ),
      SectionChips(
        sections: sections,
        alphaOf: (_) => 0.25,
        onSelect: _scrollToSection,
        spacing: 8,
        fontSize: 14,
        verticalPadding: 4,
      ),
      Expanded(
        child: widget.store.compactView
            ? CompactSongView(
                song: widget.song,
                lyricsOnly: widget.config.lyricsOnly,
                semitones: widget.config.shiftFor(widget.song.id),
                american: widget.config.americanNotation,
                // El tamao lo manda el usuario desde el panel de opciones.
                autoFit: true,
                maxFontSize: widget.config.fontSize,
              )
            : widget.config.autoFit
                ? AutoFitSongBody(
                    sections: sections,
                    lyricsOnly: widget.config.lyricsOnly,
                    semitones: widget.config.shiftFor(widget.song.id),
                    american: widget.config.americanNotation,
                    maxFontSize: widget.config.fontSize,
                  )
                : SongBodyList(
                    sections: sections,
                    lyricsOnly: widget.config.lyricsOnly,
                    semitones: widget.config.shiftFor(widget.song.id),
                    fontSize: widget.config.fontSize,
                    american: widget.config.americanNotation,
                    controller: _scrollController,
                    sectionKeys: _sectionKeys,
                    autoScroll: widget.config.isAutoScrolling,
                    autoScrollSpeed: widget.config.autoScrollSpeed,
                    onFinished: widget.config.isAutoScrolling
                        ? () {
                            // Al llegar al final, pausamos y el botón pasa a ▶.
                            setState(() => widget.config.autoScrollPaused = true);
                          }
                        : null,
                  ),
      ),
    ]);
  }
}
