import 'package:flutter/material.dart';

import '../exporters.dart';
import '../seed.dart';
import '../store.dart';
import 'home_splash.dart';

class SettingsScreen extends StatelessWidget {
  final Store store;
  const SettingsScreen({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final prefs = store;
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) => ListView(children: [
        const ListTile(title: Text('Ajustes', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
        const ListTile(title: Text('Cuenta', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
        ListTile(
          title: const Text('Tu nombre'),
          subtitle: Text(prefs.profileName.isEmpty ? 'Sin definir' : prefs.profileName),
          trailing: const Icon(Icons.edit),
          onTap: () async {
            final c = TextEditingController(text: prefs.profileName);
            final v = await showDialog<String>(context: context, builder: (_) => AlertDialog(title: const Text('Tu nombre'), content: TextField(controller: c, autofocus: true), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(context, c.text), child: const Text('OK'))]));
            if (v != null) prefs.setProfileName(v.trim());
          },
        ),
        const Divider(),
        SwitchListTile(
          title: const Text('Modo oscuro'),
          subtitle: const Text('Tema de la app'),
          value: prefs.isDark,
          onChanged: (v) => prefs.setTheme(v),
        ),
        const Divider(),
        const ListTile(title: Text('Tamaño de letra por defecto')),
        Slider(value: prefs.defaultFontSize, min: 12, max: 34, divisions: 22, label: prefs.defaultFontSize.toInt().toString(), onChanged: (v) => prefs.setDefaultFontSize(v)),
        Center(child: Text('Vista previa:', style: TextStyle(fontSize: prefs.defaultFontSize))),
        const Divider(),
        const ListTile(title: Text('Exportar setlist', style: TextStyle(fontWeight: FontWeight.bold))),
        for (final l in store.state.setlists)
          ListTile(
            title: Text(l.name),
            subtitle: Text('${l.songIds.length} canciones'),
            leading: const Icon(Icons.picture_as_pdf),
            onTap: () => shareSetlistPdf(context, l, store.state.songs),
          ),
        const Divider(),
        ListTile(
          title: const Text('Restablecer datos de ejemplo'),
          leading: const Icon(Icons.refresh),
          onTap: () async {
            final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('¿Restablecer?'), content: const Text('Se borrarán canciones, grupos y setlists.'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Restablecer'))]));
            if (ok == true) store.update((_) => seedState());
          },
        ),
        ListTile(
          title: const Text('Eliminar cuenta local', style: TextStyle(color: Colors.redAccent)),
          leading: const Icon(Icons.logout, color: Colors.redAccent),
          subtitle: const Text('Borra usuario, contraseña y acceso guardado'),
          onTap: () async {
            await store.clearAccount();
            if (context.mounted) Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => HomeSplash(store: store)), (_) => false);
          },
        ),
        const Divider(),
        const AboutListTile(icon: Icon(Icons.info_outline), applicationName: 'Songkey', applicationVersion: '1.0.0', applicationLegalese: 'App de acordes, letras y setlists'),
      ]),
    );
  }
}
