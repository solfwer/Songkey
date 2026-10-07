// Punto de entrada: crea el Store, carga los datos guardados y arranca MyApp
// (definida en app.dart con el tema y el shell de navegación).
import 'package:flutter/material.dart';

import 'app.dart';
import 'data/store.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = Store();
  await store.load();
  runApp(MyApp(store: store));
}