// Vista de canción: orquesta la cabecera (selector de tono, BPM, modo
// presentación), las chips de secciones (salto al tocar), el cuerpo (vista
// "página" o "ajustar todo"/presentación) y el panel lateral de opciones.
// El dibujo de líneas/chips vive en widgets/song_view.dart, el panel en
// widgets/view_options_panel.dart y el editor en song_editor_page.dart.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/chord_parser.dart';
import '../../data/format.dart';
import '../../data/store.dart';
import '../../models/app_state.dart';
import '../../models/setlist.dart';
import '../../models/song.dart';
import '../../theme.dart';
import 'song_editor_page.dart';
import 'widgets/song_view.dart';
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
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();
  final Map<String, GlobalKey> _sectionKeys = {};

  // Estado calculado del modo "ajustar todo" (se regenera en cada build).
  double _fitFontSize = 16;
  bool _fitUseTwoColumns = false;
  double _fitAvailableHeight = 0;
  List<Section> _fitSections = [];

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {});
    // Marcar como recién abierta para "Canciones recientes" del inicio.
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.store.markSongOpened(widget.songId));
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _scrollController.dispose();
    if (config.fitToScreen) _setSystemUiMode(false);
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (!config.fitToScreen) return KeyEventResult.ignored;
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowRight || event.logicalKey == LogicalKeyboardKey.pageDown) {
        _nextFitPage();
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft || event.logicalKey == LogicalKeyboardKey.pageUp) {
        _prevFitPage();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  void _nextFitPage() {
    final pages = _calculateFitPages(context);
    if (config.fitPage < pages - 1) {
      setState(() => config.fitPage++);
    } else if (widget.setlistId != null) {
      // Avanzar a siguiente canción en setlist
      final s = widget.store.state;
      final list = s.setlists.where((l) => l.id == widget.setlistId).firstOrNull;
      final idx = list?.songIds.indexOf(widget.songId) ?? -1;
      final next = list != null && idx >= 0 && idx < list.songIds.length - 1 ? list.songIds[idx + 1] : null;
      if (next != null) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => SongScreen(store: widget.store, songId: next, setlistId: list!.id)));
      }
    }
  }

  void _prevFitPage() {
    if (config.fitPage > 0) {
      setState(() => config.fitPage--);
    } else if (widget.setlistId != null) {
      // Retroceder a canción anterior en setlist
      final s = widget.store.state;
      final list = s.setlists.where((l) => l.id == widget.setlistId).firstOrNull;
      final idx = list?.songIds.indexOf(widget.songId) ?? -1;
      final prev = list != null && idx > 0 ? list.songIds[idx - 1] : null;
      if (prev != null) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => SongScreen(store: widget.store, songId: prev, setlistId: list!.id)));
      }
    }
  }

  Future<void> _delete(Song song) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: Text('¿Eliminar "${song.title}"?'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar'))]));
    if (ok == true) {
      widget.store.update((st) => AppState(
            groups: st.groups,
            songs: st.songs.where((x) => x.id != song.id).toList(),
            setlists: st.setlists.map((l) => l.copyWith(songIds: l.songIds.where((i) => i != song.id).toList(), readyIds: l.readyIds.where((i) => i != song.id).toList())).toList(),
          ));
      if (mounted) Navigator.of(context).pop();
    }
  }

  // --- Tono y modo presentación ---

  String _displayedKey(Song song) =>
      notateChord(sharpen(transposeChord(song.key, config.semitones)), american: config.americanNotation);

  void _setSystemUiMode(bool immersive) {
    unawaited(SystemChrome.setEnabledSystemUIMode(immersive ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge).catchError((Object _) {}));
  }

  void _togglePresentation() {
    setState(() {
      config.fitToScreen = !config.fitToScreen;
      config.fitPage = 0;
    });
    _setSystemUiMode(config.fitToScreen);
  }

  String _metaLine(Song song) {
    final group = widget.store.state.groups.where((g) => g.id == song.groupId).map((g) => g.name).firstOrNull;
    final parts = <String>[
      group ?? 'Sin grupo',
      if (song.style != null && song.style!.isNotEmpty) song.style!,
      'Tono: ${_displayedKey(song)}',
      if (song.bpm != null) '${song.bpm} BPM',
      if (formatDuration(song.durationSec).isNotEmpty) formatDuration(song.durationSec),
    ];
    return parts.join(' · ');
  }

  void _scrollToSection(Section sec) {
    if (config.fitToScreen) {
      final pages = _calculateFitPages(context);
      final pageSections = _splitSectionsForPages(_fitSections, pages, _fitAvailableHeight, _fitFontSize);
      final page = pageSections.indexWhere((p) => p.any((s) => s.id == sec.id));
      if (page >= 0 && page != config.fitPage) setState(() => config.fitPage = page);
      return;
    }
    final ctx = _sectionKeys[sec.id]?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 300), curve: Curves.easeOut, alignment: 0.06);
    }
  }

  // --- Fit-to-screen helpers ---
  int _calculateFitPages(BuildContext context) {
    final song = widget.store.state.songs.where((x) => x.id == widget.songId).firstOrNull;
    final sections = parseSong(song?.body ?? '');
    if (sections.isEmpty) return 1;

    final mediaQuery = MediaQuery.of(context);
    final availableHeight = mediaQuery.size.height - mediaQuery.padding.top - mediaQuery.padding.bottom - kToolbarHeight - 80;
    final availableWidth = mediaQuery.size.width - 32;
    final isLandscape = mediaQuery.orientation == Orientation.landscape;
    final useTwoColumns = isLandscape && availableWidth > 600;

    const baseFontSize = 16.0;
    const lineHeight = 1.35;
    const sectionGap = 26.0;
    const headerHeight = 24.0;

    double totalHeight = 0;
    for (final sec in sections) {
      totalHeight += headerHeight;
      for (final line in sec.lines) {
        totalHeight += line.isEmpty ? 10 : (baseFontSize * lineHeight + 2);
      }
      totalHeight += sectionGap;
    }

    double minFont = 10;
    double maxFont = 28;
    int pages = 1;
    double bestFont = baseFontSize;

    while (minFont <= maxFont) {
      final mid = (minFont + maxFont) / 2;
      final scale = mid / baseFontSize;
      final scaledHeight = totalHeight * scale;
      final cols = useTwoColumns ? 2 : 1;
      final neededPages = (scaledHeight / (availableHeight / cols)).ceil().clamp(1, 10);

      if (mid >= config.fitMinFont || neededPages <= 2) {
        bestFont = mid;
        pages = neededPages;
        minFont = mid + 1;
      } else {
        maxFont = mid - 1;
      }
    }

    _fitFontSize = bestFont;
    _fitUseTwoColumns = useTwoColumns;
    _fitAvailableHeight = availableHeight / (useTwoColumns ? 2 : 1);
    _fitSections = sections;
    return pages;
  }

  List<List<Section>> _splitSectionsForPages(List<Section> sections, int pages, double availableHeight, double fontSize) {
    if (pages <= 1) return [sections];
    const lineHeight = 1.35;
    const sectionGap = 26.0;
    const headerHeight = 24.0;

    final result = <List<Section>>[];
    var currentPage = <Section>[];
    double currentHeight = 0;
    final targetHeight = availableHeight * 0.95;

    for (final sec in sections) {
      double secHeight = headerHeight;
      for (final line in sec.lines) {
        secHeight += line.isEmpty ? 10 : (fontSize * lineHeight + 2);
      }
      secHeight += sectionGap;

      if (currentPage.isNotEmpty && currentHeight + secHeight > targetHeight && result.length < pages - 1) {
        result.add(currentPage);
        currentPage = [];
        currentHeight = 0;
      }
      currentPage.add(sec);
      currentHeight += secHeight;
    }
    if (currentPage.isNotEmpty) result.add(currentPage);
    while (result.length < pages) {
      result.add([]);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.store.state;
    final song = s.songs.where((x) => x.id == widget.songId).firstOrNull;
    if (song == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('Canción no encontrada')));
    }
    final list = s.setlists.where((l) => l.id == widget.setlistId).firstOrNull;
    final idx = list?.songIds.indexOf(widget.songId) ?? -1;
    final prev = list != null && idx > 0 ? list.songIds[idx - 1] : null;
    final next = list != null && idx >= 0 && idx < list.songIds.length - 1 ? list.songIds[idx + 1] : null;
    final sections = parseSong(song.body);

    // Mantener las claves de sección alineadas con las secciones actuales.
    final ids = sections.map((x) => x.id).toSet();
    _sectionKeys.removeWhere((k, _) => !ids.contains(k));
    for (final sec in sections) {
      _sectionKeys.putIfAbsent(sec.id, () => GlobalKey());
    }

    return Scaffold(
      key: _scaffoldKey,
      appBar: config.fitToScreen
          ? null
          : AppBar(
              title: Text(song.title, overflow: TextOverflow.ellipsis),
              actions: [
                _KeySelector(song: song, value: sharpen(transposeChord(song.key, config.semitones)), american: config.americanNotation, onSelected: (k) => setState(() => config.semitones = semitoneShift(song.key, k))),
                IconButton(icon: const Icon(Icons.present_to_all), tooltip: 'Modo presentación', onPressed: _togglePresentation),
                IconButton(icon: const Icon(Icons.tune), tooltip: 'Opciones de vista', onPressed: () => _scaffoldKey.currentState?.openEndDrawer()),
              ],
            ),
      endDrawer: ViewOptionsPanel(
        song: song,
        hostContext: context,
        config: config,
        focusNode: _focusNode,
        onChanged: () {
          setState(() {});
          _setSystemUiMode(config.fitToScreen);
        },
        onEdit: () async {
          await Navigator.of(context).push(MaterialPageRoute(builder: (_) => SongEditorPage(store: widget.store, song: song)));
          if (mounted) setState(() {});
        },
        onDelete: () => _delete(song),
      ),
      body: Focus(
        focusNode: _focusNode,
        onKeyEvent: _handleKeyEvent,
        child: config.fitToScreen
            ? SafeArea(bottom: false, child: _buildFitToScreen(context, song, list, idx, prev, next))
            : _buildNormalView(context, song, list, idx, prev, next, sections),
      ),
    );
  }

  Widget _buildNormalView(BuildContext context, Song song, Setlist? list, int idx, String? prev, String? next, List<Section> sections) {
    return Column(children: [
      if (list != null)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(children: [
            Text('${idx + 1} / ${list.songIds.length}'),
            const Spacer(),
            TextButton(onPressed: prev != null ? () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => SongScreen(store: widget.store, songId: prev, setlistId: list.id))) : null, child: const Text('Anterior')),
            TextButton(onPressed: next != null ? () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => SongScreen(store: widget.store, songId: next, setlistId: list.id))) : null, child: const Text('Siguiente')),
          ]),
        ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Text(_metaLine(song), style: const TextStyle(color: Colors.grey)),
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
        child: SongBodyList(
          sections: sections,
          lyricsOnly: config.lyricsOnly,
          semitones: config.semitones,
          fontSize: config.fontSize,
          american: config.americanNotation,
          controller: _scrollController,
          sectionKeys: _sectionKeys,
        ),
      ),
    ]);
  }

  Widget _buildFitToScreen(BuildContext context, Song song, Setlist? list, int idx, String? prev, String? next) {
    final pages = _calculateFitPages(context);
    final pageSections = _splitSectionsForPages(_fitSections, pages, _fitAvailableHeight, _fitFontSize);
    final currentPageSections = config.fitPage < pageSections.length ? pageSections[config.fitPage] : <Section>[];

    int activePageOf(Section sec) => pageSections.indexWhere((p) => p.any((s) => s.id == sec.id));

    return GestureDetector(
      // Zonas de toque grandes: mitad izquierda = anterior, derecha = siguiente
      onTapDown: (details) {
        final width = MediaQuery.of(context).size.width;
        if (details.globalPosition.dx < width / 2) {
          _prevFitPage();
        } else {
          _nextFitPage();
        }
      },
      child: Column(children: [
        // Cabecera compacta
        if (list != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(children: [
              Text('${idx + 1} / ${list.songIds.length}'),
              const Spacer(),
              if (pages > 1)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                  child: Text('Pág ${config.fitPage + 1} / $pages', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                ),
            ]),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          child: Text('${_metaLine(song)} · ${_fitFontSize.toInt()}sp', style: const TextStyle(color: Colors.grey, fontSize: 11)),
        ),
        // Chips de secciones
        SectionChips(
          sections: _fitSections,
          alphaOf: (sec) => config.fitPage == activePageOf(sec) ? 0.3 : 0.1,
          onSelect: _scrollToSection,
          spacing: 6,
          fontSize: 11,
          verticalPadding: 2,
        ),
        // Contenido de la página actual
        Expanded(
          child: _fitUseTwoColumns
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: FitPageColumn(sections: currentPageSections.take((currentPageSections.length / 2).ceil()).toList(), lyricsOnly: config.lyricsOnly, semitones: config.semitones, fontSize: _fitFontSize, american: config.americanNotation)),
                    const VerticalDivider(width: 16, thickness: 1, color: Colors.grey),
                    Expanded(child: FitPageColumn(sections: currentPageSections.skip((currentPageSections.length / 2).ceil()).toList(), lyricsOnly: config.lyricsOnly, semitones: config.semitones, fontSize: _fitFontSize, american: config.americanNotation)),
                  ],
                )
              : FitPageColumn(sections: currentPageSections, lyricsOnly: config.lyricsOnly, semitones: config.semitones, fontSize: _fitFontSize, american: config.americanNotation),
        ),
        // Indicador de navegación inferior + salir del modo presentación
        FitNavBar(fitPage: config.fitPage, pages: pages, onExit: _togglePresentation),
      ]),
    );
  }
}

/// Selector desplegable de tonalidad (12 tonos) en la barra superior.
/// [value] siempre viene con escritura de sostenidos para cuadrar con los items.
class _KeySelector extends StatelessWidget {
  final Song song;
  final String value;
  final bool american;
  final ValueChanged<String> onSelected;
  const _KeySelector({required this.song, required this.value, required this.american, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          icon: const Icon(Icons.keyboard_arrow_down, size: 20),
          onChanged: (k) => onSelected(k!),
          items: [
            for (final k in twelveKeys)
              DropdownMenuItem(value: k, child: Text(notateChord(k, american: american), style: const TextStyle(fontWeight: FontWeight.bold))),
          ],
        ),
      ),
    );
  }
}