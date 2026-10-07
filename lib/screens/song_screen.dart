import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:file_picker/file_picker.dart';

import '../models.dart';
import '../pdf_import.dart';
import '../songs.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/visual_chord_editor.dart';

class SongScreen extends StatefulWidget {
  final Store store;
  final String songId;
  final String? setlistId;
  const SongScreen({super.key, required this.store, required this.songId, this.setlistId});

  @override
  State<SongScreen> createState() => _SongScreenState();
}

class _SongScreenState extends State<SongScreen> {
  int st = 0;
  late double size = widget.store.defaultFontSize;
  bool lyricsOnly = false;
  bool fitToScreen = false;
  int _fitPage = 0;
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {});
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (!fitToScreen) return KeyEventResult.ignored;
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
    if (_fitPage < pages - 1) {
      setState(() => _fitPage++);
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
    if (_fitPage > 0) {
      setState(() => _fitPage--);
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
            setlists: st.setlists.map((l) => Setlist(id: l.id, name: l.name, date: l.date, groupId: l.groupId, songIds: l.songIds.where((i) => i != song.id).toList(), members: l.members)).toList(),
          ));
      if (mounted) Navigator.of(context).pop();
    }
  }

  List<String> _currentKeyOptions() {
    const roots = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
    return [for (final r in roots) r, for (final r in roots) '${r}m'];
  }

  Color _kindColor(SectionKind k) {
    switch (k) {
      case SectionKind.verse: return AppColors.primary;
      case SectionKind.chorus: return AppColors.warm;
      case SectionKind.prechorus: return AppColors.accent;
      case SectionKind.bridge: return AppColors.bridge;
      case SectionKind.intro: return const Color(0xFFE6C15C);
      case SectionKind.outro: return const Color(0xFFE6739F);
      case SectionKind.ending: return const Color(0xFFE5606B);
      case SectionKind.other: return Colors.grey;
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

      if (mid >= 14 || neededPages <= 2) {
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

  double _fitFontSize = 16;
  bool _fitUseTwoColumns = false;
  double _fitAvailableHeight = 0;
  List<Section> _fitSections = [];

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

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(song.title, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(icon: const Icon(Icons.tune), tooltip: 'Opciones de vista', onPressed: () => _scaffoldKey.currentState?.openEndDrawer()),
        ],
      ),
      endDrawer: Drawer(
        child: SafeArea(
          child: ListView(padding: EdgeInsets.zero, children: [
            DrawerHeader(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.tune, size: 28),
                const SizedBox(height: 8),
                Text('Opciones de vista', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                Text(song.title, style: const TextStyle(color: Colors.grey), overflow: TextOverflow.ellipsis),
              ]),
            ),
            const Padding(padding: EdgeInsets.fromLTRB(16, 4, 16, 0), child: Text('MOSTRAR', style: TextStyle(letterSpacing: 1.5, color: Colors.grey, fontSize: 12))),
            ListTile(
              title: const Text('Vista'),
              subtitle: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, icon: Icon(Icons.music_note), label: Text('Acordes')),
                  ButtonSegment(value: true, icon: Icon(Icons.subject), label: Text('Solo letra')),
                ],
                selected: {lyricsOnly},
                onSelectionChanged: (v) => setState(() => lyricsOnly = v.first),
              ),
            ),
            const Divider(),
            const Padding(padding: EdgeInsets.fromLTRB(16, 4, 16, 0), child: Text('TONO Y TAMAÑO', style: TextStyle(letterSpacing: 1.5, color: Colors.grey, fontSize: 12))),
            ListTile(
              title: const Text('Tono'),
              trailing: DropdownButton<String>(
                value: _currentKeyOptions().contains(transposeChord(song.key, st)) ? transposeChord(song.key, st) : null,
                items: [for (final k in _currentKeyOptions()) DropdownMenuItem(value: k, child: Text(k))],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => st = semitoneShift(song.key, v));
                },
              ),
            ),
            ListTile(
              title: const Text('Tamaño de fuente'),
              subtitle: Slider(
                value: size,
                min: 12,
                max: 34,
                divisions: 22,
                label: size.toInt().toString(),
                onChanged: (v) => setState(() => size = v),
              ),
            ),
            const Divider(),
            const Padding(padding: EdgeInsets.fromLTRB(16, 4, 16, 0), child: Text('MODO PANTALLA', style: TextStyle(letterSpacing: 1.5, color: Colors.grey, fontSize: 12))),
            SwitchListTile(
              title: const Text('Ajustar a pantalla (Fit-to-screen)'),
              subtitle: const Text('Calcula el tamaño para que quepa toda la canción. Páginas con tap zonas ←/→ y pedal.'),
              value: fitToScreen,
              onChanged: (v) => setState(() {
                fitToScreen = v;
                _fitPage = 0;
                if (v) {
                  WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
                }
              }),
            ),
            if (fitToScreen)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    const Text('Mínimo legible: '),
                    Expanded(
                      child: Slider(
                        value: 14.0,
                        min: 10,
                        max: 18,
                        divisions: 8,
                        label: '14',
                        onChanged: (v) {}, // placeholder, se usa en _calculateFitPages
                      ),
                    ),
                  ],
                ),
              ),
            const Divider(),
            const Padding(padding: EdgeInsets.fromLTRB(16, 4, 16, 0), child: Text('CANCIÓN', style: TextStyle(letterSpacing: 1.5, color: Colors.grey, fontSize: 12))),
            ListTile(leading: const Icon(Icons.edit), title: const Text('Editar'), onTap: () async { Navigator.pop(context); await Navigator.of(context).push(MaterialPageRoute(builder: (_) => SongEditorPage(store: widget.store, song: song))); setState(() {}); }),
            ListTile(leading: const Icon(Icons.delete, color: Colors.redAccent), title: const Text('Eliminar', style: TextStyle(color: Colors.redAccent)), onTap: () async { Navigator.pop(context); _delete(song); }),
          ]),
        ),
      ),
      body: Focus(
        focusNode: _focusNode,
        onKeyEvent: _handleKeyEvent,
        child: fitToScreen
            ? _buildFitToScreen(context, song, list, idx, prev, next)
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
        child: Text('${widget.store.state.groups.where((g) => g.id == song.groupId).map((g) => g.name).firstOrNull ?? "Sin grupo"} · Tono: ${transposeChord(song.key, st)}${song.bpm != null ? " · ${song.bpm} BPM" : ""}', style: const TextStyle(color: Colors.grey)),
      ),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(children: [
          for (final sec in sections)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ActionChip(
                backgroundColor: _kindColor(sec.kind).withValues(alpha: 0.25),
                side: BorderSide(color: _kindColor(sec.kind).withValues(alpha: 0.7)),
                label: Text(sec.abbr, style: TextStyle(color: _kindColor(sec.kind), fontWeight: FontWeight.bold)),
                onPressed: () {},
              ),
            ),
        ]),
      ),
      Expanded(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          for (final sec in sections) ...[
            Row(children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: _kindColor(sec.kind).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)), child: Text(sec.abbr, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _kindColor(sec.kind)))),
              const SizedBox(width: 8),
              Text(sec.label.toUpperCase(), style: const TextStyle(color: Colors.grey, fontSize: 11, letterSpacing: 1.5)),
            ]),
            const SizedBox(height: 6),
            for (final line in sec.lines)
              line.isEmpty
                  ? const SizedBox(height: 10)
                  : lyricsOnly
                      ? Padding(padding: const EdgeInsets.symmetric(vertical: 1), child: Text(line.map((x) => x.text).join().replaceAll(RegExp(r'\s+'), ' ').trim(), style: TextStyle(fontSize: size, height: 1.35, color: Colors.white)))
                      : Padding(
                          padding: const EdgeInsets.symmetric(vertical: 1),
                          child: Wrap(spacing: 0, children: [
                            for (final seg in line)
                              Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(seg.chord != null ? transposeChord(seg.chord!, st) : (line.any((x) => x.chord != null) ? ' ' : ''), style: TextStyle(fontSize: size * 0.85, height: 1.1, fontWeight: FontWeight.bold, color: const Color(0xFF5AD1E6), fontFamily: 'monospace')),
                                Text(seg.text.isEmpty ? ' ' : seg.text, style: TextStyle(fontSize: size, height: 1.35, color: Colors.white)),
                              ]),
                          ]),
                        ),
            const SizedBox(height: 26),
          ],
          if (sections.isEmpty) const Text('Esta canción aún no tiene letra.'),
        ]),
      ),
    ]);
  }

  Widget _buildFitToScreen(BuildContext context, Song song, Setlist? list, int idx, String? prev, String? next) {
    final pages = _calculateFitPages(context);
    final pageSections = _splitSectionsForPages(_fitSections, pages, _fitAvailableHeight, _fitFontSize);
    final currentPageSections = _fitPage < pageSections.length ? pageSections[_fitPage] : <Section>[];

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
                  child: Text('Pág ${_fitPage + 1} / $pages', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                ),
            ]),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          child: Text('${widget.store.state.groups.where((g) => g.id == song.groupId).map((g) => g.name).firstOrNull ?? "Sin grupo"} · Tono: ${transposeChord(song.key, st)}${song.bpm != null ? " · ${song.bpm} BPM" : ""} · ${_fitFontSize.toInt()}sp', style: const TextStyle(color: Colors.grey, fontSize: 11)),
        ),
        // Chips de secciones
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          child: Row(children: [
            for (final sec in _fitSections)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ActionChip(
                  backgroundColor: _kindColor(sec.kind).withValues(alpha: _fitPage == pageSections.indexWhere((p) => p.any((s) => s.id == sec.id)) ? 0.3 : 0.1),
                  side: BorderSide(color: _kindColor(sec.kind).withValues(alpha: 0.7)),
                  label: Text(sec.abbr, style: TextStyle(color: _kindColor(sec.kind), fontWeight: FontWeight.bold, fontSize: 11)),
                  onPressed: () {},
                ),
              ),
          ]),
        ),
        // Contenido de la página actual
        Expanded(
          child: _fitUseTwoColumns
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _renderPageColumn(currentPageSections.take((currentPageSections.length / 2).ceil()).toList())),
                    const VerticalDivider(width: 16, thickness: 1, color: Colors.grey),
                    Expanded(child: _renderPageColumn(currentPageSections.skip((currentPageSections.length / 2).ceil()).toList())),
                  ],
                )
              : _renderPageColumn(currentPageSections),
        ),
        // Indicador de navegación inferior
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chevron_left, color: _fitPage > 0 ? AppColors.primary : Colors.grey),
                const SizedBox(width: 16),
                Text('Toca los lados ◀ ▶ | Flechas / Pedal', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                const SizedBox(width: 16),
                Icon(Icons.chevron_right, color: _fitPage < pages - 1 ? AppColors.primary : Colors.grey),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  Widget _renderPageColumn(List<Section> sections) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final sec in sections) ...[
            Row(children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: _kindColor(sec.kind).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)), child: Text(sec.abbr, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _kindColor(sec.kind)))),
              const SizedBox(width: 6),
              Text(sec.label.toUpperCase(), style: const TextStyle(color: Colors.grey, fontSize: 10, letterSpacing: 1.2)),
            ]),
            const SizedBox(height: 4),
            for (final line in sec.lines)
              line.isEmpty
                  ? const SizedBox(height: 6)
                  : lyricsOnly
                      ? Padding(padding: const EdgeInsets.symmetric(vertical: 0.5), child: Text(line.map((x) => x.text).join().replaceAll(RegExp(r'\s+'), ' ').trim(), style: TextStyle(fontSize: _fitFontSize, height: 1.25, color: Colors.white)))
                      : Padding(
                          padding: const EdgeInsets.symmetric(vertical: 0.5),
                          child: Wrap(spacing: 0, children: [
                            for (final seg in line)
                              Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(seg.chord != null ? transposeChord(seg.chord!, st) : (line.any((x) => x.chord != null) ? ' ' : ''), style: TextStyle(fontSize: _fitFontSize * 0.8, height: 1.0, fontWeight: FontWeight.bold, color: const Color(0xFF5AD1E6), fontFamily: 'monospace')),
                                Text(seg.text.isEmpty ? ' ' : seg.text, style: TextStyle(fontSize: _fitFontSize, height: 1.2, color: Colors.white)),
                              ]),
                          ]),
                        ),
            const SizedBox(height: 16),
          ],
          if (sections.isEmpty) Center(child: Padding(padding: const EdgeInsets.all(32), child: Text('Esta canción aún no tiene letra.', style: TextStyle(fontSize: _fitFontSize, color: Colors.grey)))),
        ],
      ),
    );
  }
}

class SongEditorPage extends StatefulWidget {
  final Store store;
  final Song? song;
  final String? initialGroupId;
  const SongEditorPage({super.key, required this.store, this.song, this.initialGroupId});

  @override
  State<SongEditorPage> createState() => _SongEditorPageState();
}

class _SongEditorPageState extends State<SongEditorPage> with SingleTickerProviderStateMixin {
  late final TextEditingController title;
  late final TextEditingController key;
  late final TextEditingController bpm;
  late final TextEditingController body;
  String? groupId;
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    title = TextEditingController(text: widget.song?.title ?? '');
    key = TextEditingController(text: widget.song?.key ?? 'C');
    bpm = TextEditingController(text: widget.song?.bpm?.toString() ?? '');
    body = TextEditingController(text: widget.song?.body ?? '');
    groupId = widget.song?.groupId ?? widget.initialGroupId;
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(_syncTabs);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  void _syncTabs() {
    if (!_tabCtrl.indexIsChanging) {
      // Al cambiar de pestaña, sincronizar el cuerpo
      if (_tabCtrl.index == 1) {
        // Texto -> Visual: body ya tiene el texto actual
      } else {
        // Visual -> Texto: el VisualChordEditor ya llama onChanged
      }
    }
  }

  void _onVisualChanged(String newBody) {
    body.text = newBody;
  }

  @override
  Widget build(BuildContext context) {
    final groups = widget.store.state.groups;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.song == null ? 'Nueva canción' : 'Editar canción'),
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(icon: Icon(Icons.code), text: 'Texto (ChordPro)'),
            Tab(icon: Icon(Icons.touch_app), text: 'Editor visual'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          // Pestaña 1: Editor de texto clásico
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TextField(controller: title, decoration: const InputDecoration(labelText: 'Título')),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextField(controller: key, decoration: const InputDecoration(labelText: 'Tono'))),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: bpm, decoration: InputDecoration(labelText: 'BPM', suffixIcon: _TapTempoIcon(controller: bpm)), keyboardType: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(child: DropdownButtonFormField<String?>(initialValue: groupId, decoration: const InputDecoration(labelText: 'Grupo'), items: [null, ...groups.map((g) => g.id)].map((id) => DropdownMenuItem(value: id, child: Text(id == null ? 'Sin grupo' : groups.firstWhere((g) => g.id == id).name))).toList(), onChanged: (v) => setState(() => groupId = v))),
              ]),
              const SizedBox(height: 12),
              TextField(controller: body, decoration: const InputDecoration(labelText: 'Letra con acordes', alignLabelWithHint: true), maxLines: 18, style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
              const SizedBox(height: 12),
              const Text('Secciones: toca los iconos para reordenar, repetir, renombrar o eliminar cada parte.', style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 8),
              _SectionsManager(controller: body, store: widget.store),
              const SizedBox(height: 12),
              OutlinedButton.icon(icon: const Icon(Icons.picture_as_pdf), label: const Text('Importar letra desde PDF'), onPressed: importPdf),
              const SizedBox(height: 12),
              FilledButton(onPressed: save, child: const Text('Guardar')),
            ]),
          ),
          // Pestaña 2: Editor visual
          Column(
            children: [
              // Cabecera común (título, tono, BPM, grupo) - compacta
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  TextField(controller: title, decoration: const InputDecoration(labelText: 'Título', isDense: true)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: TextField(controller: key, decoration: const InputDecoration(labelText: 'Tono', isDense: true))),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: bpm, decoration: InputDecoration(labelText: 'BPM', isDense: true, suffixIcon: _TapTempoIcon(controller: bpm)), keyboardType: TextInputType.number)),
                    const SizedBox(width: 8),
                    Expanded(child: DropdownButtonFormField<String?>(initialValue: groupId, decoration: const InputDecoration(labelText: 'Grupo', isDense: true), items: [null, ...groups.map((g) => g.id)].map((id) => DropdownMenuItem(value: id, child: Text(id == null ? 'Sin grupo' : groups.firstWhere((g) => g.id == id).name))).toList(), onChanged: (v) => setState(() => groupId = v))),
                  ]),
                ]),
              ),
              const Divider(height: 1),
              Expanded(
                child: VisualChordEditor(
                  initialBody: body.text,
                  songKey: key.text,
                  onChanged: _onVisualChanged,
                ),
              ),
              // Botón guardar fijo abajo
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: FilledButton(onPressed: save, child: const Text('Guardar')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> importPdf() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf'], withData: true);
    final file = res?.files.firstOrNull;
    final bytes = file?.bytes;
    if (file == null || bytes == null) return;
    try {
      final draft = await pdfToDraft(file.name, bytes);
      setState(() {
        if (title.text.trim().isEmpty) title.text = draft.title;
        body.text = draft.body;
      });
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo leer el PDF (¿escaneado?)')));
    }
  }

  void save() {
    if (title.text.trim().isEmpty) return;
    final id = widget.song?.id ?? uid();
    final song = Song(id: id, title: title.text.trim(), key: key.text.trim().isEmpty ? 'C' : key.text.trim(), bpm: int.tryParse(bpm.text), groupId: groupId, body: body.text);
    widget.store.update((s) {
      final songs = s.songs.any((x) => x.id == id) ? s.songs.map((x) => x.id == id ? song : x).toList() : [song, ...s.songs];
      return AppState(groups: s.groups, songs: songs, setlists: s.setlists);
    });
    Navigator.of(context).pop();
  }
}

class _SectionsManager extends StatefulWidget {
  final TextEditingController controller;
  final Store store;
  const _SectionsManager({required this.controller, required this.store});

  @override
  State<_SectionsManager> createState() => _SectionsManagerState();
}

class _SectionsManagerState extends State<_SectionsManager> {
  late List<_Block> blocks;

  @override
  void initState() {
    super.initState();
    blocks = _parseBlocks(widget.controller.text);
  }

  @override
  void didUpdateWidget(covariant _SectionsManager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller.text != oldWidget.controller.text) {
      setState(() => blocks = _parseBlocks(widget.controller.text));
    }
  }

  void _rebuildBody() {
    widget.controller.text = blocks.map((b) => b.toString()).join('\n');
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Estructura de la canción', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          if (blocks.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Sin secciones detectadas. Escribe "Verso 1", "Coro", etc. en el editor.',
                  style: TextStyle(color: Colors.grey)),
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: blocks.length,
              onReorderItem: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex--;
                  final item = blocks.removeAt(oldIndex);
                  blocks.insert(newIndex, item);
                  _rebuildBody();
                });
              },
              itemBuilder: (context, index) {
                final b = blocks[index];
                return Card(
                  key: ValueKey(b.id),
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: ListTile(
                    leading: ReorderableDragStartListener(
                      index: index,
                      child: const Icon(Icons.drag_handle, color: Colors.grey),
                    ),
                    title: Text(b.header, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${b.lines.length} líneas'),
                    trailing: Wrap(spacing: 4, children: [
                      IconButton(
                        tooltip: 'Repetir (duplicar)',
                        icon: const Icon(Icons.content_copy),
                        onPressed: () => setState(() {
                          blocks.insert(index + 1, b.copy());
                          _rebuildBody();
                        }),
                      ),
                      IconButton(
                        tooltip: 'Renombrar',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _rename(b),
                      ),
                      IconButton(
                        tooltip: 'Eliminar',
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        onPressed: () => setState(() {
                          blocks.removeAt(index);
                          _rebuildBody();
                        }),
                      ),
                    ]),
                    onTap: () => _editLines(b),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  void _rename(_Block b) {
    final c = TextEditingController(text: b.header);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Renombrar sección'),
        content: TextField(controller: c, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: () { setState(() { b.header = c.text.trim(); _rebuildBody(); }); Navigator.pop(context); }, child: const Text('OK')),
        ],
      ),
    );
  }

  void _editLines(_Block b) {
    final c = TextEditingController(text: b.body);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Editar: ${b.header}'),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: c,
            maxLines: 12,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            decoration: const InputDecoration(hintText: 'Letra y acordes…'),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: () { setState(() { b.body = c.text.trim(); _rebuildBody(); }); Navigator.pop(context); }, child: const Text('Guardar')),
        ],
      ),
    );
  }
}

class _Block {
  final String id;
  String header;
  String body;
  _Block({required this.id, required this.header, required this.body});
  _Block copy() => _Block(id: uid(), header: header, body: body);

  List<String> get lines => body.split('\n').where((l) => l.trim().isNotEmpty).toList();

  @override
  String toString() => '$header\n$body';
}

List<_Block> _parseBlocks(String text) {
  final lines = text.replaceAll('\r', '').split('\n');
  final blocks = <_Block>[];
  _Block? cur;
  for (final line in lines) {
    if (isSectionHeader(line)) {
      if (cur != null) blocks.add(cur);
      cur = _Block(id: uid(), header: line.trim(), body: '');
    } else if (cur != null) {
      cur.body = '${cur.body.isEmpty ? '' : '\n'}$line';
    } else if (line.trim().isNotEmpty) {
      // Líneas antes del primer encabezado -> crear bloque "Intro"
      if (blocks.isEmpty || blocks.last.header != 'Intro') {
        cur = _Block(id: uid(), header: 'Intro', body: line);
      } else {
        cur!.body = '${cur.body}\n$line';
      }
    }
  }
  if (cur != null) blocks.add(cur);
  return blocks;
}

/// Botón de "tap tempo": toca al ritmo de la canción y calcula el BPM promedio.
/// Funciona sin internet. Tras 3 s sin tocar, reinicia la medición.
class _TapTempoIcon extends StatefulWidget {
  final TextEditingController controller;
  const _TapTempoIcon({required this.controller});
  @override
  State<_TapTempoIcon> createState() => _TapTempoIconState();
}

class _TapTempoIconState extends State<_TapTempoIcon> {
  final List<DateTime> _taps = [];

  void _tap() {
    final now = DateTime.now();
    if (_taps.isNotEmpty && now.difference(_taps.last).inMilliseconds > 3000) _taps.clear();
    _taps.add(now);
    if (_taps.length > 8) _taps.removeAt(0);
    if (_taps.length >= 2) {
      final intervals = <int>[];
      for (var i = 1; i < _taps.length; i++) {
        intervals.add(_taps[i].difference(_taps[i - 1]).inMilliseconds);
      }
      final avg = intervals.reduce((a, b) => a + b) / intervals.length;
      widget.controller.text = (60000 / avg).round().toString();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: 'Tap tempo: toca al ritmo (reinicia tras 3 s)',
        icon: const Icon(Icons.touch_app),
        onPressed: _tap,
      );
}