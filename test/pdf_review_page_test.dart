import 'package:appchords/data/store.dart';
import 'package:appchords/screens/song/pdf_review_page.dart';
import 'package:appchords/services/pdf_chordpro/pdf_to_chordpro_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

PdfConversion _conversion({
  String title = 'A DANZAR',
  String? key,
  String body = '{start_of_verse: VERSO 1}\n[C]Tú eres [G]Dios\n{end_of_verse}',
}) {
  return PdfConversion(
    title: title,
    chordPro: body,
    suggestedKey: key,
    warnings: const [],
  );
}

void main() {
  testWidgets('PdfReviewPage abre en Datos y no duplica la vista previa', (tester) async {
    final store = Store();
    await tester.pumpWidget(MaterialApp(home: PdfReviewPage(store: store, conversion: _conversion())));
    await tester.pumpAndSettle();

    expect(find.text('A DANZAR'), findsOneWidget); // título en la página Datos
    expect(find.text('VISTA PREVIA'), findsNothing); // sin preview duplicado
    expect(find.text('1/4'), findsOneWidget);
  });

  testWidgets('navega por las 4 páginas y guarda con estructura', (tester) async {
    final store = Store();
    await tester.pumpWidget(MaterialApp(home: PdfReviewPage(store: store, conversion: _conversion())));
    await tester.pumpAndSettle();

    expect(find.text('1/4'), findsOneWidget);

    // Página 2: Editor
    await tester.tap(find.text('Siguiente'));
    await tester.pumpAndSettle();
    expect(find.text('2/4'), findsOneWidget);

    // Página 3: Vista previa
    await tester.tap(find.text('Siguiente'));
    await tester.pumpAndSettle();
    expect(find.text('3/4'), findsOneWidget);
    expect(find.text('Dios'), findsOneWidget); // letra renderizada en la preview
    expect(find.text('A DANZAR'), findsOneWidget);

    // Página 4: Estructura
    await tester.tap(find.text('Siguiente'));
    await tester.pumpAndSettle();
    expect(find.text('4/4'), findsOneWidget);

    // Guardar
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    final guardada = store.state.songs.firstWhere((s) => s.title == 'A DANZAR');
    expect(guardada.title, 'A DANZAR');
    expect(guardada.key, 'C');
    expect(guardada.body, contains('Tú eres [G]Dios'));
  });
}
