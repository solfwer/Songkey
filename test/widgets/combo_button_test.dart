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

  testWidgets('ComboButton sin ancho fijo dentro de un Row (como la biblioteca)',
      (WidgetTester tester) async {
    var pressed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              Expanded(child: const TextField()),
              const SizedBox(width: 8),
              ComboButton<String>(
                label: 'Añadir',
                icon: Icons.add,
                onPressed: () => pressed = true,
                menuItems: [
                  PopupMenuItem(value: 'pdf', child: const Text('Importar PDF')),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.text('Añadir'));
    await tester.pumpAndSettle();

    expect(pressed, isTrue);
  });

  testWidgets('ComboButton sin ancho fijo no queda con alto infinito en Column '
      '(alto ilimitado, como la biblioteca)', (WidgetTester tester) async {
    // Column pasa a sus hijos no-flex maxHeight = Infinity. Con
    // crossAxisAlignment.stretch el Row interno forcaba tightFor(height: Infinity)
    // y la capa de pintura quedaba con matriz inválida (pantalla negra en release).
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              ComboButton<String>(
                label: 'Añadir',
                icon: Icons.add,
                onPressed: () {},
                menuItems: [
                  PopupMenuItem(value: 'pdf', child: const Text('Importar PDF')),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    final size = tester.getSize(find.byType(ComboButton<String>));
    expect(size.height.isFinite, isTrue);
    expect(size.height, equals(40));
  });

  testWidgets('ComboButton con ancho fijo respeta onPressed',
      (WidgetTester tester) async {
    var pressed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ComboButton<String>(
            label: 'Añadir',
            icon: Icons.add,
            width: 300,
            onPressed: () => pressed = true,
            menuItems: [
              PopupMenuItem(value: 'pdf', child: const Text('Importar PDF')),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.text('Añadir'));
    await tester.pumpAndSettle();

    expect(pressed, isTrue);
  });
}
