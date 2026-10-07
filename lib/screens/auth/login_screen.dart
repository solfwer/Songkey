import 'package:flutter/material.dart';

import '../../app.dart' show HomeShell;
import '../../data/store.dart';
import '../../theme.dart';

class LoginScreen extends StatefulWidget {
  final Store store;
  const LoginScreen({super.key, required this.store});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final userCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final pass2Ctrl = TextEditingController();
  String? error;
  bool obscure = true;

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final isRegister = !store.hasAccount;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.primary, AppColors.accent]), borderRadius: BorderRadius.circular(20)),
                child: const Center(child: Text('A', style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Colors.white))),
              ),
            ),
            const SizedBox(height: 20),
            Center(child: Text(isRegister ? 'Crea tu cuenta' : 'Iniciar sesión', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold))),
            const SizedBox(height: 6),
            Center(child: Text(isRegister ? 'Solo en este dispositivo por ahora' : 'Sesión guardada en este dispositivo', style: const TextStyle(color: Colors.grey))),
            const SizedBox(height: 28),
            TextField(
              controller: userCtrl,
              textCapitalization: TextCapitalization.none,
              decoration: const InputDecoration(labelText: 'Usuario', prefixIcon: Icon(Icons.person_outline), border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passCtrl,
              obscureText: obscure,
              decoration: InputDecoration(
                labelText: 'Contraseña',
                prefixIcon: const Icon(Icons.lock_outline),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(icon: Icon(obscure ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => obscure = !obscure)),
              ),
            ),
            if (isRegister) ...[
              const SizedBox(height: 12),
              TextField(
                controller: pass2Ctrl,
                obscureText: obscure,
                decoration: const InputDecoration(labelText: 'Repetir contraseña', prefixIcon: Icon(Icons.lock_outline), border: OutlineInputBorder()),
              ),
            ],
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(error!, style: const TextStyle(color: Colors.redAccent)),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: submit,
              child: Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Text(isRegister ? 'Crear cuenta' : 'Entrar', style: const TextStyle(fontSize: 16))),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> submit() async {
    final user = userCtrl.text.trim();
    final pass = passCtrl.text;
    final store = widget.store;
    if (user.isEmpty || pass.isEmpty) {
      setState(() => error = 'Completa usuario y contraseña');
      return;
    }
    if (!store.hasAccount) {
      if (pass.length < 4) {
        setState(() => error = 'La contraseña debe tener al menos 4 caracteres');
        return;
      }
      if (pass != pass2Ctrl.text) {
        setState(() => error = 'Las contraseñas no coinciden');
        return;
      }
      await store.register(user, pass);
    } else {
      if (!store.login(user, pass)) {
        setState(() => error = 'Usuario o contraseña incorrectos');
        return;
      }
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => HomeShell(store: store)));
  }
}