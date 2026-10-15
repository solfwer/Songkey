// Punto de entrada: crea el Store, carga los datos guardados y arranca MyApp
// (definida en app.dart con el tema y el shell de navegación).
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'app.dart';
import 'data/store.dart';
import 'models/app_state.dart';
import 'services/biblioteca_export.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = Store();
  await store.load();
  runApp(MyApp(store: store));

  // Manejar archivos .songkey compartidos desde WhatsApp, correo, etc.
  // Solo en Android.
  if (Platform.isAndroid) {
    _handleIncomingSongkeyFile(store);
  }
}

/// Escucha intenciones de compartir archivos .songkey e importa la biblioteca.
void _handleIncomingSongkeyFile(Store store) {
  // 1. Archivo compartido mientras la app ya estaba abierta (o en background)
  ReceiveSharingIntent.instance.getMediaStream().listen((List<SharedMediaFile> value) {
    _processSharedFiles(value, store);
  }, onError: (err) {
    // Silenciar errores de stream
  });

  // 2. Archivo que lanzó la app desde cero (cold start)
  ReceiveSharingIntent.instance.getInitialMedia().then((List<SharedMediaFile> value) {
    _processSharedFiles(value, store);
  });
}

void _processSharedFiles(List<SharedMediaFile> files, Store store) {
  for (final file in files) {
    final path = file.path;
    if (path == null) continue;
    if (!path.endsWith('.songkey')) continue;
    
    // Leer e importar en background para no bloquear UI
    Future.microtask(() async {
      try {
        final content = await File(path).readAsString();
        final data = jsonDecode(content) as Map<String, dynamic>;
        if (data['app'] == 'Songkey' && data['songs'] is List) {
          // Importar silenciosamente (skip duplicados por defecto)
          // El usuario puede re-importar con "Actualizar duplicados" si quiere
          final res = mergeLibrary(store.state, content, updateExisting: false);
          store.update((s) => AppState(
            groups: [...s.groups, ...res.newGroups],
            songs: [...res.newSongs, ...s.songs],
            setlists: s.setlists,
          ));
        }
      } catch (_) {
        // Silenciar errores de parsing
      }
    });
  }
}