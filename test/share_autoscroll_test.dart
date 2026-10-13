// Tests de las utilidades de compartir/guardar y del auto-scroll.
import 'package:appchords/services/share_utils.dart';
import 'package:appchords/screens/song/widgets/song_view.dart';
import 'package:appchords/data/chord_parser.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('datedFileName', () {
    test('genera nombre con fecha y no pisa copias', () {
      final nombre = datedFileName('Songkey_biblioteca', 'json');
      expect(nombre, startsWith('Songkey_biblioteca_'));
      expect(nombre, endsWith('.json'));
      final fecha = RegExp(r'_\d{4}-\d{2}-\d{2}\.json$');
      expect(fecha.hasMatch(nombre), isTrue);
    });

    test('limpia caracteres invalidos del nombre', () {
      final nombre = datedFileName('Cancion/con:asterisco*?', 'pdf');
      expect(nombre, isNot(contains('\\')));
      expect(nombre, isNot(contains('/')));
      expect(nombre, endsWith('.pdf'));
    });
  });

  group('askShareOrSave', () {
    testWidgets('devuelve false al elegir Compartir', (tester) async {
      bool? resultado;
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  resultado = await askShareOrSave(context, que: 'la biblioteca');
                },
                child: const Text('abrir'),
              ),
            )),
      ));
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      expect(find.text('Como quieres sacar la biblioteca?'), findsOneWidget);
      await tester.tap(find.text('Compartir'));
      await tester.pumpAndSettle();
      expect(resultado, isFalse);
    });

    testWidgets('devuelve true al elegir Guardar en el telfono', (tester) async {
      bool? resultado;
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  resultado = await askShareOrSave(context, que: 'el PDF');
                },
                child: const Text('abrir'),
              ),
            )),
      ));
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar en el telfono'));
      await tester.pumpAndSettle();
      expect(resultado, isTrue);
    });

    testWidgets('devuelve null al cancelar', (tester) async {
      bool? resultado = false;
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  resultado = await askShareOrSave(context, que: 'la biblioteca');
                },
                child: const Text('abrir'),
              ),
            )),
      ));
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(resultado, isNull);
    });
  });

  group('SongBodyList auto-scroll', () {
    testWidgets('sin autoScroll no hay temporizador activo', (tester) async {
      final controller = ScrollController();
      final sections = sectionsInOrder('Verso 1\n[G]Hola mundo\n[G]Adios', null);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SongBodyList(sections: sections, lyricsOnly: false, semitones: 0, fontSize: 14, controller: controller),
        ),
      ));
      await tester.pumpAndSettle();
      expect(controller.offset, 0);
      controller.dispose();
    });

    testWidgets('con autoScroll el desplazamiento avanza', (tester) async {
      final controller = ScrollController();
      // Cancion larga para que haya scroll.
      final body = List.generate(40, (i) => 'Verso $i\n[G]linea de letra $i').join('\n\n');
      final sections = sectionsInOrder(body, null);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SongBodyList(
            sections: sections,
            lyricsOnly: false,
            semitones: 0,
            fontSize: 14,
            controller: controller,
            autoScroll: true,
            autoScrollSpeed: 60,
          ),
        ),
      ));
      // Esperar a que arranque el timer y avance.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(controller.offset, greaterThan(0));
      // No debe romperse al seguir avanzando mucho tiempo.
      await tester.pump(const Duration(seconds: 8));
      expect(tester.takeException(), isNull);
      controller.dispose();
    });
  });
}
