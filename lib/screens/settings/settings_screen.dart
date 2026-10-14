import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../data/seed.dart';
import '../../data/store.dart';
import '../../services/biblioteca_export.dart';
import '../../theme.dart';
import '../home/home_splash.dart';
import 'legal_screen.dart';

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
        const ListTile(title: Text('Biblioteca', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
        ListTile(
          leading: const Icon(Icons.ios_share, color: AppColors.accent),
          title: const Text('Compartir biblioteca'),
          subtitle: const Text('Comparte tus canciones o guarda una copia en el telfono'),
          onTap: () => shareLibrary(context, store),
        ),
        ListTile(
          leading: const Icon(Icons.file_download_outlined, color: AppColors.warm),
          title: const Text('Importar biblioteca'),
          subtitle: const Text('Añade canciones desde un archivo compartido'),
          onTap: () => importLibrary(context, store),
        ),
        // Copia de seguridad
        const Divider(),
        const ListTile(title: Text('Copia de seguridad', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
        _BackupSection(store: store),
        const Divider(),
        const ListTile(title: Text('Preferencias', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
        SwitchListTile(
          title: const Text('Vista compacta'),
          subtitle: const Text('Cuando esté habilitado, las secciones se mostrarán en un diseño condensado, ignorando la estructura original de la canción'),
          value: prefs.compactView,
          onChanged: (v) => prefs.setCompactView(v),
        ),
        SwitchListTile(
          title: const Text('Notación americana'),
          subtitle: const Text('Acordes como C, G, Am — apaga para Do, Sol, Lam'),
          value: prefs.americanNotation,
          onChanged: (v) => prefs.setAmericanNotation(v),
        ),
        SwitchListTile(
          title: const Text('Mostrar acordes por defecto'),
          subtitle: const Text('Al abrir una canción: con acordes o solo la letra'),
          value: !prefs.defaultLyricsOnly,
          onChanged: (v) => prefs.setDefaultLyricsOnly(!v),
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
        const ListTile(title: Text('Legal', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
        ListTile(
          leading: const Icon(Icons.gavel, color: AppColors.warm),
          title: const Text('Aviso legal'),
          subtitle: const Text('Derechos sobre las letras y los acordes'),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LegalScreen(topic: LegalTopic.aviso))),
        ),
        ListTile(
          leading: const Icon(Icons.privacy_tip_outlined, color: AppColors.accent),
          title: const Text('Política de privacidad'),
          subtitle: const Text('Tus datos se quedan en tu dispositivo'),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LegalScreen(topic: LegalTopic.privacidad))),
        ),
        const _AboutSection(),
      ]),
    );
  }
}

/// Carga la versión real (pubspec) y muestra las secciones de licencias y
/// "Acerca de" con datos correctos en lugar de valores fijos.
class _AboutSection extends StatefulWidget {
  const _AboutSection();

  @override
  State<_AboutSection> createState() => _AboutSectionState();
}

class _AboutSectionState extends State<_AboutSection> {
  String _version = '1.0.0';
  String _build = '1';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _version = info.version;
          _build = info.buildNumber;
        });
      }
    } catch (_) {
      // En entornos de prueba la versión puede no estar disponible; se usa el valor por defecto.
    }
  }

  String get _versionLabel => '$_version ($_build)';

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      ListTile(
        leading: const Icon(Icons.menu_book_outlined, color: AppColors.bridge),
        title: const Text('Licencias de código abierto'),
        subtitle: const Text('Componentes que usa la app'),
        onTap: () => showLicensePage(
          context: context,
          applicationName: 'Songkey',
          applicationVersion: _versionLabel,
        ),
      ),
      ListTile(
        leading: const Icon(Icons.info_outline),
        title: const Text('Acerca de'),
        subtitle: Text('Versión $_versionLabel'),
        onTap: () => showAboutDialog(
          context: context,
          applicationName: 'Songkey',
          applicationVersion: 'Versión $_versionLabel',
          applicationLegalese: '© 2026 Songkey\nLas letras y los acordes pertenecen a sus autores.',
          children: const [SizedBox(height: 8)],
        ),
      ),
    ]);
  }
}

/// Sección de copia de seguridad en Ajustes.
class _BackupSection extends StatelessWidget {
  final Store store;
  const _BackupSection({required this.store});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final last = store.lastBackupAt;
        final auto = store.autoBackupOnExit;
        final now = DateTime.now();
        final daysSince = last != null ? now.difference(last).inDays : null;
        final showWarning = last == null || (daysSince != null && daysSince > 14);

        return Column(children: [
          // Aviso ámbar si no hay copia o es antigua
          if (showWarning)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                border: Border.all(color: Colors.amber.shade700),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                Icon(Icons.warning_amber_rounded, color: Colors.amber.shade800),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  last == null
                      ? 'No hay copia de seguridad. Usa "Crear copia ahora" para proteger tus canciones.'
                      : 'La última copia tiene $daysSince días. Haz una nueva para estar tranquilo.',
                  style: TextStyle(color: Colors.amber.shade900, fontSize: 13),
                )),
              ]),
            ),

          // Última copia
          ListTile(
            leading: Icon(Icons.history, color: last != null ? AppColors.accent : Colors.grey),
            title: const Text('Última copia'),
            subtitle: Text(last != null
                ? '${_formatDate(last!)} (hace ${daysSince ?? 0} día${daysSince == 1 ? '' : 's'})'
                : 'Nunca'),
          ),

          // Botón crear copia ahora
          ListTile(
            leading: const Icon(Icons.backup, color: AppColors.accent),
            title: const Text('Crear copia ahora'),
            subtitle: const Text('Exporta toda la biblioteca a JSON y la guarda en el dispositivo'),
            onTap: () async {
              Navigator.of(context).pop(); // cierra el drawer de ajustes
              await shareLibrary(context, store);
              store.recordBackup();
            },
          ),

          // Switch copia automática al salir
          SwitchListTile(
            title: const Text('Copia automática al salir'),
            subtitle: const Text('Al cerrar la app, si hay cambios, guarda una copia en segundo plano'),
            value: store.autoBackupOnExit,
            onChanged: (v) => store.setAutoBackupOnExit(v),
            secondary: const Icon(Icons.autorenew, color: AppColors.accent),
          ),
        ]);
      },
    );
  }

  String _formatDate(DateTime d) {
    final months = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}
