import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_state.dart';
import 'seed.dart';

/// Estado de la app + persistencia local (SharedPreferences/JSON).
class Store extends ChangeNotifier {
  static const _key = 'Songkey-v1';
  AppState state = seedState();
  bool isDark = true;
  double defaultFontSize = 18;
  String profileName = '';
  String username = '';
  String _password = '';
  bool loggedIn = false;
  bool setupDone = false;

  bool get hasAccount => username.isNotEmpty && _password.isNotEmpty;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        state = AppState.decode(raw);
      } catch (_) {}
    }
    isDark = prefs.getBool('songkey-dark') ?? true;
    defaultFontSize = prefs.getDouble('songkey-fontsize') ?? 18;
    profileName = prefs.getString('songkey-profile') ?? '';
    username = prefs.getString('songkey-user') ?? '';
    _password = prefs.getString('songkey-pass') ?? '';
    loggedIn = prefs.getBool('songkey-session') ?? false;
    setupDone = prefs.getBool('songkey-setup') ?? false;
    notifyListeners();
  }

  Future<void> register(String user, String pass) async {
    username = user;
    _password = pass;
    loggedIn = true;
    setupDone = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('songkey-user', user);
    await prefs.setString('songkey-pass', pass);
    await prefs.setBool('songkey-session', true);
    await prefs.setBool('songkey-setup', true);
    notifyListeners();
  }

  bool login(String user, String pass) {
    if (!hasAccount || user != username || pass != _password) return false;
    loggedIn = true;
    setupDone = true;
    SharedPreferences.getInstance().then((p) {
      p.setBool('songkey-session', true);
      p.setBool('songkey-setup', true);
    });
    notifyListeners();
    return true;
  }

  Future<void> clearAccount() async {
    username = '';
    _password = '';
    loggedIn = false;
    setupDone = false;
    profileName = '';
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('songkey-user');
    await prefs.remove('songkey-pass');
    await prefs.remove('songkey-session');
    await prefs.remove('songkey-setup');
    await prefs.remove('songkey-profile');
    notifyListeners();
  }

  void update(AppState Function(AppState s) fn) {
    state = fn(state);
    _persist();
    notifyListeners();
  }

  void setTheme(bool dark) {
    isDark = dark;
    SharedPreferences.getInstance().then((p) => p.setBool('songkey-dark', dark));
    notifyListeners();
  }

  void setDefaultFontSize(double v) {
    defaultFontSize = v;
    SharedPreferences.getInstance().then((p) => p.setDouble('songkey-fontsize', v));
    notifyListeners();
  }

  void setProfileName(String v) {
    profileName = v;
    SharedPreferences.getInstance().then((p) => p.setString('songkey-profile', v));
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, state.encode());
  }
}