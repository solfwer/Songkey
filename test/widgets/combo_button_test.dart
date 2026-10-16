import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../lib/widgets/combo_button.dart';
import '../../lib/theme.dart';

void main() {
  testWidgets('ComboButton ejecuta onPressed al tocar la zona principal',
      (WidgetTester tester) async {
    var pressed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ComboButton<String>(
            label: 'Añadir',
            icon: Icons.add,
            onPressed: () => pressed = true,
            menuItems: [
              PopupMenuItem(value: 'pdf', child: const Text('Importar PDF')),
              PopupMenuItem(value: 'chordpro', child: const Text('Importar ChordPro')),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.text('Añadir'));
    await tester.pumpAndSettle();

    expect(pressed, isTrue);
  });

  testWidgets('ComboButton ejecuta onSelected al tocar un ítem del menú',
      (WidgetTester tester) async {
    var selected = '';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ComboButton<String>(
            label: 'Añadir',
            icon: Icons.add,
            onPressed: () {},
            menuItems: [
              PopupMenuItem(value: 'pdf', child: const Text('Importar PDF')),
              PopupMenuItem(value: 'chordpro', child: const Text('Importar ChordPro')),
            ],
            onSelected: (v) => selected = v,
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.arrow_drop_down));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Importar PDF'));
    await tester.pumpAndSettle();

    expect(selected, 'pdf');
  });
}
