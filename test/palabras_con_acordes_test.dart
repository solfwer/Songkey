// La letra no se parte cuando un acorde cae a mitad de palabra:
// `señ[A]or` debe verse "señor" (con la A encima), no "señ or".
import 'package:appchords/data/chord_parser.dart';
import 'package:appchords/screens/song/widgets/song_view.dart';
import 'package:appchords/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pintar(WidgetTester tester, String texto, {double ancho = 400}) async {
  await tester.pumpWidget(MaterialApp(
    theme: darkTheme(),
    home: Scaffold(
      body: SizedBox(
        width: ancho,
        child: SongLineView(
          line: parseInline(texto),
          lyricsOnly: false,
          semitones: 0,
          fontSize: 18,
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

/// Ancho que ocuparía el texto suelto, para comparar con la palabra pintada.
double _anchoTexto(String texto, double fontSize, double alto) {
  final p = TextPainter(
    text: TextSpan(text: texto, style: TextStyle(fontSize: fontSize, height: alto)),
    textDirection: TextDirection.ltr,
  )..layout();
  return p.width;
}

void main() {
  testWidgets('un acorde a mitad de palabra no abre hueco en la letra', (tester) async {
    await _pintar(tester, 'señ[A]or mi Dios');
    expect(tester.takeException(), isNull);

    // Tres palabras: no se parte "señor" en trozos sueltos.
    final wrap = tester.widget<Wrap>(find.byType(Wrap));
    expect(wrap.children.length, 3);

    final palabra = find.byWidget(wrap.children.first);
    expect(find.descendant(of: palabra, matching: find.text('señ')), findsOneWidget);
    expect(find.descendant(of: palabra, matching: find.text('or')), findsOneWidget);
    // El acorde sigue estando, encima de la palabra.
    expect(find.descendant(of: palabra, matching: find.text('A')), findsOneWidget);

    // Y la palabra ocupa lo que ocupa el texto "señor " (sin hueco añadido;
    // la diferencia de 1-2 px es el kerning entre piezas sueltas).
    final ancho = tester.getSize(palabra).width;
    expect(ancho, closeTo(_anchoTexto('señor ', 18, 1.35), 3));
  });

  testWidgets('un acorde separado por un espacio sigue pegado a su palabra', (tester) async {
    // `[C] Hola` es la forma más común: el acorde no puede quedar suelto como
    // una palabra aparte, o el salto de línea lo deja en otra línea.
    await _pintar(tester, '[C] Hola mundo');
    final wrap = tester.widget<Wrap>(find.byType(Wrap));
    expect(wrap.children.length, 2);

    final hola = find.byWidget(wrap.children.first);
    expect(find.descendant(of: hola, matching: find.text('C')), findsOneWidget);
    expect(find.descendant(of: hola, matching: find.text('Hola')), findsOneWidget);
  });

  testWidgets('dos acordes pegados sin letra no se solapan', (tester) async {
    await _pintar(tester, '[A/C#][Am/C]Hola');
    expect(tester.takeException(), isNull);
    expect(find.text('A/C#'), findsOneWidget);
    expect(find.text('Am/C'), findsOneWidget);
    expect(find.text('Hola'), findsOneWidget);
  });

  testWidgets('varias palabras con acordes mantienen cada palabra entera', (tester) async {
    await _pintar(tester, '[C]Hola [G]mun[D]do');
    final wrap = tester.widget<Wrap>(find.byType(Wrap));
    expect(wrap.children.length, 2);
    expect(find.text('Hola'), findsOneWidget);
    // "mundo" queda partido en dos piezas pero dentro de la misma palabra.
    final mundo = find.byWidget(wrap.children[1]);
    expect(find.descendant(of: mundo, matching: find.text('mun')), findsOneWidget);
    expect(find.descendant(of: mundo, matching: find.text('do')), findsOneWidget);
    final ancho = tester.getSize(mundo).width;
    expect(ancho, closeTo(_anchoTexto('mundo', 18, 1.35), 3));
  });
}
