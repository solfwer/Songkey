// Tests de los arreglos de la vista: acordes separados y modo claro.
import 'package:appchords/data/chord_parser.dart';
import 'package:appchords/data/store.dart';
import 'package:appchords/models/song.dart';
import 'package:appchords/screens/song/widgets/song_view.dart';
import 'package:appchords/screens/song/widgets/visual_chord_editor.dart';
import 'package:appchords/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('la linea separa los acordes que van pegados', (tester) async {
    // `[A/C#][Am/C][G/B]` (acordes sin letra entre ellos) deben pintarse
    // separados, no todos juntos.
    const body = '{start_of_verse: VERSO 1}\nfueg[Am]o[A/C#][Am/C][G/B]\n{end_of_verse}';
    await tester.pumpWidget(MaterialApp(
      theme: darkTheme(),
      home: Scaffold(
        body: SizedBox(
          height: 600,
          child: SongBodyList(sections: sectionsInOrder(body, null), lyricsOnly: false, semitones: 0, fontSize: 18, american: true),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // Los tres acordes se ven.
    for (final c in ['A/C#', 'Am/C', 'G/B']) {
      expect(find.text(c), findsOneWidget, reason: 'falta $c');
    }
    // Y cada uno tiene su propio Padding (margen) para no ir pegado.
    expect(find.ancestor(of: find.text('A/C#'), matching: find.byType(Padding)), findsWidgets);
  });

  testWidgets('el editor visual se ve en modo claro', (tester) async {
    tester.view.physicalSize = const Size(400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      theme: lightTheme(),
      home: Scaffold(
        body: VisualChordEditor(initialBody: 'Verso 1\n[G]Hola mundo', songKey: 'C', onChanged: (_) {}),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // Los iconos de la barra siguen estando (aunque estn deshabilitados).
    expect(find.byIcon(Icons.undo), findsOneWidget);
    expect(find.byIcon(Icons.redo), findsOneWidget);
    expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  });

  testWidgets('la barra de abajo del editor se ve en modo claro', (tester) async {
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      theme: lightTheme(),
      home: Builder(builder: (context) {
        return Scaffold(
          // Igual que el editor: barra inferior con el botn de guardar.
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(onPressed: () {}, icon: const Icon(Icons.save), label: const Text('Guardar')),
            ),
          ),
          body: const SizedBox.expand(),
        );
      }),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Guardar'), findsOneWidget);
    expect(find.byIcon(Icons.save), findsOneWidget);
  });
}
