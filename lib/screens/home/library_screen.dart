// Biblioteca de canciones: buscador + botón "+" para añadir canciones
// (manualmente con ChordPro, desde un PDF o desde un documento ChordPro).
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../data/chordpro.dart';
import '../../data/chord_parser.dart';
import '../../data/format.dart';
import '../../data/store.dart';
import '../../models/app_state.dart';
import '../../models/song.dart';
import '../../services/pdf_chordpro/pdf_to_chordpro_service.dart';
import '../song/pdf_review_page.dart';
import '../../theme.dart';
import '../../widgets/combo_button.dart';
import '../song/song_editor_page.dart';
import '../song/song_screen.dart';

/// Formas de añadir una canción desde el menú "+".
enum _AddOption { manual, pdf, chordpro, variosChordpro }

class LibraryScreen extends StatefulWidget {
  final Store store;
  const LibraryScreen({super.key, required this.store});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  String q = '';

  List<Song> _applyFilters(List<Song> all) {
    final f = q.trim().toLowerCase();
    var list = all.where((x) {
      final title = x.title.toLowerCase();
      final author = (x.author ?? '').toLowerCase();
      final body = x.body.toLowerCase();
      return title.contains(f) || author.contains(f) || body.contains(f);
    }).toList();
    // Orden alfabético por título (A→Z, sin distinguir mayúsculas).
    list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return list;
  }

  void _handleAdd(_AddOption opt) {
    switch (opt) {
      case _AddOption.manual:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => SongEditorPage(store: widget.store)));
      case _AddOption.pdf:
        _importPdf();
      case _AddOption.chordpro:
        _importChordPro();
      case _AddOption.variosChordpro:
        _importVariosChordpro();
    }
  }

  Future<void> _importPdf() async {
    final res = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    final file = res.firstOrNull;
    if (file == null) return;
    final base = file.name.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
    Uint8List? bytes;
    try {
      bytes = await file.readAsBytes();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo leer el archivo')));
      }
      return;
    }

    // Diálogo de carga para que no se congele la UI durante la conversión.
    BuildContext? dialogo;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) {
        dialogo = c;
        return const AlertDialog(
          content: Row(
            children: [
              SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: 16),
              Text('Leyendo el PDF…'),
            ],
          ),
        );
      },
    );
    // Ceder un frame para que el diálogo se pinte antes de empezar.
    await Future.delayed(Duration.zero);

    List<PdfConversion> conversions;
    try {
      // Se ejecuta en un isolate aparte: la UI no se bloquea aunque el PDF sea grande.
      conversions = await const PdfToChordProService().convertAllAsync(bytes, fallbackTitle: base);
    } catch (_) {
      conversions = const [];
    }
    // Cerrar solo el diálogo: si el usuario ya lo cerró con "atrás", su
    // contexto está desmontado y no se toca la pantalla que haya debajo.
    if (dialogo != null && dialogo!.mounted) Navigator.of(dialogo!).pop();
    if (!mounted) return;

    if (conversions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo leer el PDF (¿escaneado como imagen?)')));
      return;
    }

    // Una sola canción: flujo actual (revisar antes de guardar).
    if (conversions.length == 1) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PdfReviewPage(store: widget.store, conversion: conversions.first),
      ));
      return;
    }

    // Varias canciones: mostrar diálogo de selección (mismo patrón que ChordPro múltiple).
    final existingTitles = widget.store.state.songs.map((s) => s.title.trim().toLowerCase()).toSet();
    final parsedSongs = conversions.map((c) {
      return _ParsedSong(
        title: c.title,
        author: null,
        key: c.suggestedKey ?? 'C',
        bpm: c.bpm,
        body: c.chordPro,
        isDuplicate: existingTitles.contains(c.title.trim().toLowerCase()),
        duplicateReason: existingTitles.contains(c.title.trim().toLowerCase())
            ? 'Ya en la biblioteca'
            : null,
        selected: true,
      );
    }).toList();

    if (!mounted) return;
    final selected = await showDialog<List<_ParsedSong>>(
      context: context,
      builder: (_) => _MultiSongImportDialog(parsedSongs: parsedSongs),
    );

    if (selected == null || selected.isEmpty) return;

    widget.store.update((state) {
      final songs = [...state.songs, ...selected.map((p) => Song(
        id: uid(),
        title: p.title,
        author: p.author,
        key: p.key,
        bpm: p.bpm,
        body: p.body,
      ))];
      return AppState(groups: state.groups, songs: songs, setlists: state.setlists);
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Se añadieron ${selected.length} canciones')));
  }

  Future<void> _importChordPro() async {
    final res = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['cho', 'chopro', 'chordpro', 'txt']);
    final file = res.firstOrNull;
    final bytes = await file?.readAsBytes();
    if (file == null || bytes == null) return;
    String text;
    try {
      text = utf8.decode(bytes);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El archivo no está en UTF-8 y no se pudo leer.')));
      }
      return;
    }
    final fileName = file.name.replaceAll(RegExp(r'\.[^.]+$'), '');

    // Dividir en canciones individuales
    final songTexts = splitChordProSongs(text);

    // Si solo hay 1 canción, comportamiento actual: abrir editor
    if (songTexts.length == 1) {
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => SongEditorPage(store: widget.store, initialTitle: fileName, initialBody: songTexts.first)));
      return;
    }

    // Varias canciones: parsear cada una y mostrar diálogo de selección
    final parser = ChordProParser();
    final existingTitles = widget.store.state.songs.map((s) => s.title.trim().toLowerCase()).toSet();
    final seenTitles = <String>{};

    final parsedSongs = <_ParsedSong>[];
    for (var i = 0; i < songTexts.length; i++) {
      final st = songTexts[i];
      parser.issues.clear();
      final song = parser.parse(st);
      String title = song.meta.title ?? '';
      if (title.isEmpty) title = '$fileName (${i + 1})';
      final author = song.meta.artist;
      final key = song.meta.key ?? 'C';
      final bpm = int.tryParse(song.meta.tempo ?? '');
      final isDuplicateInFile = seenTitles.contains(title.trim().toLowerCase());
      final isDuplicateInLibrary = existingTitles.contains(title.trim().toLowerCase());
      seenTitles.add(title.trim().toLowerCase());
      parsedSongs.add(_ParsedSong(
        title: title,
        author: author,
        key: key,
        bpm: bpm,
        body: st,
        isDuplicate: isDuplicateInFile || isDuplicateInLibrary,
        duplicateReason: isDuplicateInFile ? 'Repetida en el archivo' : (isDuplicateInLibrary ? 'Ya en la biblioteca' : null),
      ));
    }

    if (!mounted) return;
    final selected = await showDialog<List<_ParsedSong>>(
      context: context,
      builder: (_) => _MultiSongImportDialog(parsedSongs: parsedSongs),
    );

    if (selected == null || selected.isEmpty) return;

    // Guardar las seleccionadas
    widget.store.update((state) {
      final songs = [...state.songs, ...selected.map((p) => Song(
        id: uid(),
        title: p.title,
        author: p.author,
        key: p.key,
        bpm: p.bpm,
        body: p.body,
      ))];
      return AppState(groups: state.groups, songs: songs, setlists: state.setlists);
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Se añadieron ${selected.length} canciones')));
  }

  /// Importa varios documentos ChordPro a la vez (varios archivos).
  Future<void> _importVariosChordpro() async {
    final res = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['cho', 'chopro', 'chordpro', 'txt'],
    );
    final files = res;
    if (files.isEmpty) return;

    final parser = ChordProParser();
    final existingTitles = widget.store.state.songs.map((s) => s.title.trim().toLowerCase()).toSet();
    final seenTitles = <String>{};
    final parsedSongs = <_ParsedSong>[];

    for (final file in files) {
      final bytes = await file.readAsBytes();
      if (bytes == null) continue;
      String text;
      try {
        text = utf8.decode(bytes);
      } catch (_) {
        continue;
      }
      final fileName = file.name.replaceAll(RegExp(r'\.[^.]+$'), '');
      final songTexts = splitChordProSongs(text);
      for (var i = 0; i < songTexts.length; i++) {
        final st = songTexts[i];
        parser.issues.clear();
        final song = parser.parse(st);
        String title = song.meta.title ?? '';
        if (title.isEmpty) title = '$fileName (${i + 1})';
        final author = song.meta.artist;
        final key = song.meta.key ?? 'C';
        final bpm = int.tryParse(song.meta.tempo ?? '');
        final isDuplicateInFile = seenTitles.contains(title.trim().toLowerCase());
        final isDuplicateInLibrary = existingTitles.contains(title.trim().toLowerCase());
        seenTitles.add(title.trim().toLowerCase());
        parsedSongs.add(_ParsedSong(
          title: title,
          author: author,
          key: key,
          bpm: bpm,
          body: st,
          isDuplicate: isDuplicateInFile || isDuplicateInLibrary,
          duplicateReason: isDuplicateInFile ? 'Repetida en el archivo' : (isDuplicateInLibrary ? 'Ya en la biblioteca' : null),
        ));
      }
    }

    if (!mounted) return;
    final selected = await showDialog<List<_ParsedSong>>(
      context: context,
      builder: (_) => _MultiSongImportDialog(parsedSongs: parsedSongs),
    );

    if (selected == null || selected.isEmpty) return;

    widget.store.update((state) {
      final canciones = [...state.songs, ...selected.map((p) => Song(
        id: uid(),
        title: p.title,
        author: p.author,
        key: p.key,
        bpm: p.bpm,
        body: p.body,
      ))];
      return AppState(groups: state.groups, songs: canciones, setlists: state.setlists);
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Se añadieron ${selected.length} canciones')));
  }

  /// Renombra una canción (sólo cambia el título).
  Future<void> _renombrarCancion(Song song) async {
    final controller = TextEditingController(text: song.title);
    final resultado = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Renombrar canción'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Nuevo título'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Renombrar'),
          ),
        ],
      ),
    );
    if (resultado == null || resultado.isEmpty) return;
    widget.store.update((s) {
      final canciones = s.songs.map((x) => x.id == song.id ? x.copyWith(title: resultado) : x).toList();
      return AppState(groups: s.groups, songs: canciones, setlists: s.setlists);
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Canción renombrada')));
  }

  /// Abre el editor de una canción existente.
  void _editarCancion(Song song) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => SongEditorPage(store: widget.store, song: song)));
  }

  /// Elimina una canción de la biblioteca (y de los setlists que la contienen).
  Future<void> _eliminarCancion(Song song) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿Eliminar "${song.title}"?'),
        content: const Text('Se quitará de la biblioteca y de los setlists donde aparezca.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
            style: FilledButton.styleFrom(foregroundColor: AppColors.destructive),
          ),
        ],
      ),
    );
    if (ok != true) return;
    widget.store.update((st) => AppState(
          groups: st.groups,
          songs: st.songs.where((x) => x.id != song.id).toList(),
          setlists: st.setlists.map((l) => l.copyWith(
                songIds: l.songIds.where((i) => i != song.id).toList(),
                readyIds: l.readyIds.where((i) => i != song.id).toList(),
              )).toList(),
        ));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Canción eliminada')));
  }

  /// Muestra un bottom sheet con las acciones disponibles para una canción.
  Future<void> _mostrarMenuCancion(BuildContext context, Song song) async {
    await showModalBottomSheet(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit, size: 20),
            title: const Text('Renombrar'),
            onTap: () {
              Navigator.pop(ctx);
              _renombrarCancion(song);
            },
          ),
          ListTile(
            leading: const Icon(Icons.open_in_new, size: 20),
            title: const Text('Editar'),
            onTap: () {
              Navigator.pop(ctx);
              _editarCancion(song);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, size: 20, color: AppColors.destructive),
            title: const Text('Eliminar', style: TextStyle(color: AppColors.destructive)),
            onTap: () {
              Navigator.pop(ctx);
              _eliminarCancion(song);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final s = widget.store.state;
        final list = _applyFilters(s.songs);
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Row(children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(hintText: 'Buscar canción…', prefixIcon: Icon(Icons.search)),
                  onChanged: (v) => setState(() => q = v),
                ),
              ),
              const SizedBox(width: 8),
              ComboButton<_AddOption>(
                label: 'Añadir',
                icon: Icons.add,
                tooltip: 'Añadir canción',
                onPressed: () => _handleAdd(_AddOption.manual),
                menuItems: [
                  const PopupMenuItem(
                    value: _AddOption.pdf,
                    child: ListTile(leading: Icon(Icons.picture_as_pdf), title: Text('Importar PDF'), contentPadding: EdgeInsets.zero, dense: true),
                  ),
                  const PopupMenuItem(
                    value: _AddOption.chordpro,
                    child: ListTile(leading: Icon(Icons.description), title: Text('Importar documento ChordPro'), contentPadding: EdgeInsets.zero, dense: true),
                  ),
                  const PopupMenuItem(
                    value: _AddOption.variosChordpro,
                    child: ListTile(leading: Icon(Icons.description_outlined), title: Text('Importar varios documentos ChordPro'), contentPadding: EdgeInsets.zero, dense: true),
                  ),
                ],
                onSelected: _handleAdd,
              ),
            ]),
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerRight, child: Text('${list.length} canciones', style: const TextStyle(color: Colors.grey))),
            const SizedBox(height: 8),
            Expanded(
              child: list.isEmpty
                  ? const Center(child: Text('No hay canciones. Toca + para crear o importar.'))
                  : ListView.separated(
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final song = list[i];
                        final secs = parseSong(song.body).where((x) => x.kind != SectionKind.other).toList();
                        // Vista compacta: solo secciones únicas (sin repeticiones).
                        final uniqueAbbrs = secs.map((x) => x.abbr).toSet().toList();
                        final group = s.groups.where((g) => g.id == song.groupId).map((g) => g.name).cast<String?>().firstWhere((_) => true, orElse: () => null);
                        final duration = formatDuration(song.durationSec);
                        // ¿Dónde coincide la búsqueda?
                        final f = q.trim().toLowerCase();
                        final inTitle = song.title.toLowerCase().contains(f);
                        final inAuthor = (song.author ?? '').toLowerCase().contains(f);
                        final inBody = song.body.toLowerCase().contains(f);
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                            foregroundColor: AppColors.primary,
                            child: Text(notateChord(song.key, american: widget.store.americanNotation), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                          title: Row(children: [
                            Expanded(child: Text(song.title)),
                            if (f.isNotEmpty && !inTitle && (inAuthor || inBody))
                              Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: AppColors.accent.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    inAuthor && inBody ? 'autor + letra' : inAuthor ? 'autor' : 'letra',
                                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.accent),
                                  ),
                                ),
                              ),
                          ]),
                          isThreeLine: song.style != null || duration.isNotEmpty,
                          subtitle: Text(
                            [
                              group ?? 'Sin grupo',
                              if (song.style != null && song.style!.isNotEmpty) song.style!,
                              if (song.bpm != null) '${song.bpm} BPM',
                              if (duration.isNotEmpty) duration,
                              uniqueAbbrs.join(' · '),
                            ].join(' · '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SongScreen(store: widget.store, songId: song.id))),
                          trailing: IconButton(
                            icon: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
                            tooltip: 'Acciones de la canción',
                            onPressed: () => _mostrarMenuCancion(context, song),
                          ),
                        );
                      },
                    ),
            ),
          ]),
        );
      },
    );
  }
}

class _ParsedSong {
  final String title;
  final String? author;
  final String key;
  final int? bpm;
  final String body;
  final bool isDuplicate;
  final String? duplicateReason;
  final bool selected;

  _ParsedSong({
    required this.title,
    required this.author,
    required this.key,
    required this.bpm,
    required this.body,
    required this.isDuplicate,
    required this.duplicateReason,
    this.selected = true,
  });

  _ParsedSong copyWith({bool? selected}) => _ParsedSong(
    title: title,
    author: author,
    key: key,
    bpm: bpm,
    body: body,
    isDuplicate: isDuplicate,
    duplicateReason: duplicateReason,
    selected: selected ?? this.selected,
  );
}

class _MultiSongImportDialog extends StatefulWidget {
  final List<_ParsedSong> parsedSongs;
  const _MultiSongImportDialog({required this.parsedSongs});

  @override
  State<_MultiSongImportDialog> createState() => _MultiSongImportDialogState();
}

class _MultiSongImportDialogState extends State<_MultiSongImportDialog> {
  late List<_ParsedSong> _songs;

  @override
  void initState() {
    super.initState();
    _songs = List.from(widget.parsedSongs);
  }

  int get _selectedCount => _songs.where((s) => s.selected).length;

  void _toggle(int i) {
    setState(() => _songs[i] = _songs[i].copyWith(selected: !_songs[i].selected));
  }

  void _selectAll() {
    setState(() => _songs = _songs.map((s) => s.copyWith(selected: true)).toList());
  }

  void _selectNone() {
    setState(() => _songs = _songs.map((s) => s.copyWith(selected: false)).toList());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Importar canciones'),
      content: SizedBox(
        width: double.maxFinite,
        height: 500,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: _selectAll, child: const Text('Todas')),
                const SizedBox(width: 8),
                TextButton(onPressed: _selectNone, child: const Text('Ninguna')),
              ],
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _songs.length,
                itemBuilder: (context, i) {
                  final song = _songs[i];
                  return ExpansionTile(
                    initiallyExpanded: false,
                    leading: Checkbox(
                      value: song.selected,
                      onChanged: (_) => _toggle(i),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            song.title,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: song.isDuplicate ? Colors.orange : null,
                              decoration: song.isDuplicate ? TextDecoration.lineThrough : null,
                            ),
                          ),
                        ),
                        if (song.bpm != null) Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text('${song.bpm} BPM', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                        if (song.isDuplicate) Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(song.duplicateReason!, style: const TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text('Tono: ${song.key} · ${song.author ?? 'Sin autor'}'),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          song.body.length > 500 ? '${song.body.substring(0, 500)}...' : song.body,
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const Divider(),
            Text('Se añadirán $_selectedCount canciones', style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, <_ParsedSong>[]), child: const Text('Cancelar')),
        FilledButton(
          onPressed: _selectedCount == 0 ? null : () => Navigator.pop(context, _songs.where((s) => s.selected).toList()),
          child: Text('Importar $_selectedCount'),
        ),
      ],
    );
  }
}