// Barra rpida de acordes para el editor visual.
//
// Sirve para que nadie tenga que aprenderse la sintaxis ChordPro: se toca una
// linea de la letra y luego un acorde de la barra, y se coloca solo. Tiene
// tres grupos (los de la tonalidad, las inversiones y las variantes del
// acorde marcado) y un boton de corchete `[]` para escribir el acorde a mano
// los que prefieran hacerlo asi.
import 'package:flutter/material.dart';

import '../../../data/chord_parser.dart';
import '../../../theme.dart';

class ChordQuickBar extends StatelessWidget {
  /// Tonalidad de la cancin (para calcular los acordes que entran).
  final String songKey;

  /// Acorde seleccionado en la linea, si hay uno (sus variantes se muestran).
  final String? selectedChord;

  /// Lnea sobre la que se va a insertar (null = an no se ha tocado ninguna).
  final int? lineNumber;

  /// Se llama con el acorde elegido.
  final ValueChanged<String> onPick;

  /// Abre el campo para escribir el acorde a mano.
  final VoidCallback onManual;

  const ChordQuickBar({
    super.key,
    required this.songKey,
    required this.onPick,
    required this.onManual,
    this.selectedChord,
    this.lineNumber,
  });

  @override
  Widget build(BuildContext context) {
    final grupos = quickBarChords(songKey, selected: selectedChord);
    return Container(
      decoration: BoxDecoration(color: AppColors.card, border: Border(bottom: BorderSide(color: Colors.grey[800]!))),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(children: [
              const Icon(Icons.music_note, size: 14, color: AppColors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  lineNumber == null
                      ? 'Toca una linea y luego un acorde'
                      : 'Insertar en la linea ${lineNumber! + 1}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ),
              TextButton.icon(
                onPressed: onManual,
                icon: const Text('[]', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                label: const Text('A mano'),
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 8)),
              ),
            ]),
          ),
          const SizedBox(height: 2),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              children: [
                for (final grupo in [
                  (titulo: 'Tonalidad', acordes: grupos.scale),
                  (titulo: 'Inversiones', acordes: grupos.slash),
                  (titulo: selectedChord == null ? 'Variantes' : 'Variantes de $selectedChord', acordes: grupos.variants),
                ]) ...[
                  _GrupoLabel(grupo.titulo),
                  for (final acorde in grupo.acordes)
                    _ChipAcorde(
                      acorde: acorde,
                      marcado: acorde == selectedChord,
                      onTap: () => onPick(acorde),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GrupoLabel extends StatelessWidget {
  final String texto;
  const _GrupoLabel(this.texto);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Center(
          child: Text(texto.toUpperCase(), style: const TextStyle(fontSize: 8, letterSpacing: 1, color: Colors.white38)),
        ),
      );
}

class _ChipAcorde extends StatelessWidget {
  final String acorde;
  final bool marcado;
  final VoidCallback onTap;
  const _ChipAcorde({required this.acorde, required this.marcado, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minWidth: 42),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: marcado ? AppColors.primary.withValues(alpha: 0.85) : Colors.white10,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: marcado ? AppColors.primary : Colors.white24),
          ),
          child: Text(
            acorde,
            style: TextStyle(fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.bold, color: marcado ? Colors.white : Colors.white70),
          ),
        ),
      ),
    );
  }
}

/// Campo para escribir un acorde a mano (el `[]` de la barra).
class ManualChordField extends StatefulWidget {
  final ValueChanged<String> onSubmit;
  const ManualChordField({super.key, required this.onSubmit});

  @override
  State<ManualChordField> createState() => _ManualChordFieldState();
}

class _ManualChordFieldState extends State<ManualChordField> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _enviar() {
    final v = _ctrl.text.trim();
    if (v.isEmpty) return;
    widget.onSubmit(v);
    _ctrl.clear();
  }

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
          child: TextField(
            controller: _ctrl,
            autofocus: true,
            style: const TextStyle(fontFamily: 'monospace'),
            decoration: const InputDecoration(
              isDense: true,
              hintText: 'Escribe el acorde: Bm7, F#sus4...',
              hintStyle: TextStyle(fontFamily: 'monospace', fontSize: 13),
            ),
            onSubmitted: (_) => _enviar(),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(onPressed: _enviar, child: const Text('Insertar')),
      ]);
}
