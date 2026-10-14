// Definición de la app: MyApp (MaterialApp + tema según preferencia) y el
// HomeShell con la barra de navegación inferior entre las 5 secciones.
import 'package:flutter/material.dart';

import 'data/store.dart';
import 'screens/auth/login_screen.dart';
import 'screens/groups/groups_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/home/library_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/setlists/setlists_screen.dart';
import 'theme.dart';

class MyApp extends StatelessWidget {
  final Store store;
  const MyApp({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) => MaterialApp(
        title: 'Songkey',
        debugShowCheckedModeBanner: false,
        themeMode: store.isDark ? ThemeMode.dark : ThemeMode.light,
        theme: lightTheme(),
        darkTheme: darkTheme(),
        // Entrar directo a la vista Home (o al login si es la primera vez).
        home: store.setupDone ? HomeShell(store: store) : LoginScreen(store: store),
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  final Store store;
  const HomeShell({super.key, required this.store});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // Escucha cambios de ciclo de vida para la copia automática al salir.
    AppLifecycleListener(
      onPause: () async => widget.store.maybeAutoBackup(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(store: widget.store),
      LibraryScreen(store: widget.store),
      SetlistsScreen(store: widget.store),
      GroupsScreen(store: widget.store),
      SettingsScreen(store: widget.store),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [
          _Logo(),
          SizedBox(width: 10),
          Text('Songkey', style: TextStyle(fontWeight: FontWeight.bold)),
        ]),
      ),
      body: IndexedStack(index: _index, children: pages),
      // El color sale del tema: en modo claro se ve clara (con un color fijo
      // oscuro los iconos no se veian).
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
        indicatorColor: Theme.of(context).colorScheme.primaryContainer,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.library_music_outlined), label: 'Biblioteca'),
          NavigationDestination(icon: Icon(Icons.queue_music), label: 'Setlists'),
          NavigationDestination(icon: Icon(Icons.groups_outlined), label: 'Grupos'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Ajustes'),
        ],
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.primary, AppColors.accent]),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Center(
        child: Text('A', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }
}