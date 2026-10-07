import 'package:flutter/material.dart';

import 'screens/groups_screen.dart';
import 'screens/home_screen.dart';
import 'screens/home_splash.dart';
import 'screens/library_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/setlists_screen.dart';
import 'store.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = Store();
  await store.load();
  runApp(MyApp(store: store));
}

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
        home: HomeSplash(store: store),
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
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: AppColors.card,
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

