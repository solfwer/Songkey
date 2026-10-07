import 'package:flutter/material.dart';

import '../theme.dart';
import '../main.dart' show HomeShell;
import '../store.dart';
import 'login_screen.dart';

class HomeSplash extends StatelessWidget {
  final Store store;
  const HomeSplash({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF221533), Color(0xFF10101A)])),
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.primary, AppColors.accent]), borderRadius: BorderRadius.circular(24)),
              child: const Center(child: Text('A', style: TextStyle(fontSize: 44, fontWeight: FontWeight.bold, color: Colors.white))),
            ),
          ),
          const SizedBox(height: 24),
          const Center(child: Text('Songkey', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold))),
          const SizedBox(height: 8),
          const Center(child: Text('Letras, acordes y setlists para tu banda', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey))),
          const SizedBox(height: 48),
          FilledButton(
            onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => store.setupDone ? HomeShell(store: store) : LoginScreen(store: store))),
            child: const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Text('Entrar', style: TextStyle(fontSize: 16))),
          ),
        ]),
      ),
    );
  }
}

