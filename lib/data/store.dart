import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_state.dart';
import '../services/metronome.dart' show Subdivision;
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

  /// Notación de acordes: true = americana (C, G, Am), false = latina (Do, Sol, Lam).
  bool americanNotation = true;

  /// Abrir canciones solo con letra (sin acordes) por defecto.
  bool defaultLyricsOnly = false;

  /// Modo del editor de contenido: true = visual, false = ChordPro.
  bool editorVisualMode = true;

  /// Vista compacta: secciones nicas una sola vez (sin repeticiones).
  bool compactView = false;

  // --- Metrnomo ---
  int metroBpm = 120;
  int metroBeats = 4;
  int metroBeatUnit = 4;
  int metroSub = 0;
  bool metroAccent = true;
  bool metroSound = true;
  bool metroVib = true;

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
    americanNotation = prefs.getBool('songkey-american') ?? true;
    defaultLyricsOnly = prefs.getBool('songkey-lyricsonly') ?? false;
    editorVisualMode = prefs.getBool('songkey-editorvisual') ?? true;
    compactView = prefs.getBool('songkey-compact') ?? false;
    metroBpm = prefs.getInt('songkey-metro-bpm') ?? 120;
    metroBeats = prefs.getInt('songkey-metro-beats') ?? 4;
    metroBeatUnit = prefs.getInt('songkey-metro-unit') ?? 4;
    metroSub = prefs.getInt('songkey-metro-sub') ?? 0;
    metroAccent = prefs.getBool('songkey-metro-accent') ?? true;
    metroSound = prefs.getBool('songkey-metro-sound') ?? true;
    metroVib = prefs.getBool('songkey-metro-vib') ?? true;
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

  /// Recuerda el ltimo modo del editor de contenido (visual o ChordPro).
  void setEditorVisualMode(bool visual) {
    editorVisualMode = visual;
    SharedPreferences.getInstance().then((p) => p.setBool('songkey-editorvisual', visual));
    notifyListeners();
  }

  /// Vista compacta: secciones nicas, sin repetir el contenido.
  void setCompactView(bool v) {
    compactView = v;
    SharedPreferences.getInstance().then((p) => p.setBool('songkey-compact', v));
    notifyListeners();
  }

  // --- Metrnomo ---
  void setMetroBpm(int v) {
    metroBpm = v;
    SharedPreferences.getInstance().then((p) => p.setInt('songkey-metro-bpm', v));
    notifyListeners();
  }

  void setMetroTime(int beats, int unit) {
    metroBeats = beats;
    metroBeatUnit = unit;
    final prefs = SharedPreferences.getInstance();
    prefs.then((p) {
      p.setInt('songkey-metro-beats', beats);
      p.setInt('songkey-metro-unit', unit);
    });
    notifyListeners();
  }

  void setMetroSubdivision(Subdivision s) {
    metroSub = s.index;
    SharedPreferences.getInstance().then((p) => p.setInt('songkey-metro-sub', s.index));
    notifyListeners();
  }

  void setMetroAccent(bool v) {
    metroAccent = v;
    SharedPreferences.getInstance().then((p) => p.setBool('songkey-metro-accent', v));
    notifyListeners();
  }

  void setMetroSound(bool v) {
    metroSound = v;
    SharedPreferences.getInstance().then((p) => p.setBool('songkey-metro-sound', v));
    notifyListeners();
  }

  void setMetroVibration(bool v) {
    metroVib = v;
    SharedPreferences.getInstance().then((p) => p.setBool('songkey-metro-vib', v));
    notifyListeners();
  }

  void setProfileName(String v) {
    profileName = v;
    SharedPreferences.getInstance().then((p) => p.setString('songkey-profile', v));
    notifyListeners();
  }

  void setAmericanNotation(bool v) {
    americanNotation = v;
    SharedPreferences.getInstance().then((p) => p.setBool('songkey-american', v));
    notifyListeners();
  }

  void setDefaultLyricsOnly(bool v) {
    defaultLyricsOnly = v;
    SharedPreferences.getInstance().then((p) => p.setBool('songkey-lyricsonly', v));
    notifyListeners();
  }

  /// Marca una canción como recién abierta (alimenta "Recientes" del inicio).
  void markSongOpened(String songId, {String? at}) {
    final stamp = at ?? DateTime.now().toIso8601String();
    final changed = state.songs.any((x) => x.id == songId && x.lastOpenedAt != stamp);
    if (!changed) return;
    update((s) {
      final songs = s.songs.map((x) => x.id == songId ? x.copyWith(lastOpenedAt: stamp) : x).toList();
      return AppState(groups: s.groups, songs: songs, setlists: s.setlists);
    });
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, state.encode());
  }
}