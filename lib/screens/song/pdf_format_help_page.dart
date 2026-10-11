// Pantalla de ayuda: cmo tiene que ser un PDF para que la importacin salga
// bien. Se abre desde el botn de importar.
import 'package:flutter/material.dart';

class PdfFormatHelpPage extends StatelessWidget {
  const PdfFormatHelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Cmo preparar el PDF')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Para que los acordes caigan en su slaba', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          const Text(
            'El PDF tiene que tener TEXTO real (no una foto escaneada) y los acordes escritos JUSTO ENCIMA de la letra que acompaan. Si los acordes estn en una lnea aparte o desplazados, la app no sabe a qu slaba va cada uno.',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 16),
          _Ejemplo(
            scheme: scheme,
            titulo: 'As S funciona',
            lineas: const [
              'INTRODUCCIN:',
              'C#m | A | E | B',
              '',
              'VERSO 1',
              'Da un paso al frent[C#m]e',
              'Demos toda gloria a Jes[A]s',
            ],
            bueno: true,
          ),
          const SizedBox(height: 12),
          _Ejemplo(
            scheme: scheme,
            titulo: 'As NO funciona',
            lineas: const [
              'VERSO 1',
              'C#m A',
              'Da un paso al frente',   // acordes lejos de su slaba
              'Demos toda gloria a Jess',
            ],
            bueno: false,
          ),
          const SizedBox(height: 20),
          Text('Las secciones se detectan solas', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          const Text(
            'Escribe el nombre de la seccin en su propia lnea, con o sin nmero. Se reconocen todas estas formas:',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 8),
          const Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _ChipTexto('VERSO 1'),
              _ChipTexto('Verso'),
              _ChipTexto('ESTROFA 2'),
              _ChipTexto('CORO'),
              _ChipTexto('Coro:'),
              _ChipTexto('PRE-CORO'),
              _ChipTexto('PUENTE'),
              _ChipTexto('INTRODUCCIN:'),
              _ChipTexto('Interludio'),
              _ChipTexto('FINAL'),
            ],
          ),
          const SizedBox(height: 20),
          Text('Al importar', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          const Text(
            'La cancin se abre en una pantalla de revisin: ah ves el ChordPro generado, la vista previa y los avisos de lo que no ha quedado claro. Corriges lo que haga falta y le das a Guardar.',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 24),
          Card(
            color: scheme.secondaryContainer.withValues(alpha: 0.3),
            child: const Padding(
              padding: EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [Icon(Icons.lightbulb_outline, size: 18), SizedBox(width: 8), Text('Truco')]),
                SizedBox(height: 6),
                Text(
                  'Si el PDF est escaneado (es una imagen), prubalo con otro archivo. La app necesita poder seleccionar el texto del PDF para leerlo.',
                  style: TextStyle(fontSize: 12.5),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipTexto extends StatelessWidget {
  final String texto;
  const _ChipTexto(this.texto);

  @override
  Widget build(BuildContext context) => Chip(
        label: Text(texto, style: const TextStyle(fontSize: 12)),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      );
}

class _Ejemplo extends StatelessWidget {
  final ColorScheme scheme;
  final String titulo;
  final List<String> lineas;
  final bool bueno;

  const _Ejemplo({required this.scheme, required this.titulo, required this.lineas, required this.bueno});

  @override
  Widget build(BuildContext context) {
    final color = bueno ? Colors.green : Colors.redAccent;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(bueno ? Icons.check_circle_outline : Icons.cancel_outlined, size: 16, color: color),
        const SizedBox(width: 6),
        Text(titulo, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
      ]),
      const SizedBox(height: 6),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withValues(alpha: 0.5))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final l in lineas)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Text(
                  l.isEmpty ? ' ' : l,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12.5,
                    height: 1.5,
                    color: l.contains('[') ? const Color(0xFF5AD1E6) : Colors.white70,
                  ),
                ),
              ),
          ],
        ),
      ),
    ]);
  }
}
