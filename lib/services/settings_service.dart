import 'package:shared_preferences/shared_preferences.dart';

enum GameSpeed { normal, fast }

class AppSettings {
  const AppSettings({
    this.sound = true,
    this.haptics = true,
    this.darkMode = true,
    this.pathPreview = true,
    this.autoMove = true,
    this.speed = GameSpeed.normal,
  });

  final bool sound;
  final bool haptics;
  final bool darkMode;

  /// First tap on a token previews its path, second tap moves it.
  final bool pathPreview;

  /// Move automatically when every legal move is equivalent.
  final bool autoMove;
  final GameSpeed speed;

  AppSettings copyWith({
    bool? sound,
    bool? haptics,
    bool? darkMode,
    bool? pathPreview,
    bool? autoMove,
    GameSpeed? speed,
  }) {
    return AppSettings(
      sound: sound ?? this.sound,
      haptics: haptics ?? this.haptics,
      darkMode: darkMode ?? this.darkMode,
      pathPreview: pathPreview ?? this.pathPreview,
      autoMove: autoMove ?? this.autoMove,
      speed: speed ?? this.speed,
    );
  }
}

class SettingsService {
  SettingsService(this._prefs);
  final SharedPreferences _prefs;

  AppSettings load() => AppSettings(
        sound: _prefs.getBool('s_sound') ?? true,
        haptics: _prefs.getBool('s_haptics') ?? true,
        darkMode: _prefs.getBool('s_dark') ?? true,
        pathPreview: _prefs.getBool('s_preview') ?? true,
        autoMove: _prefs.getBool('s_auto') ?? true,
        speed: (_prefs.getInt('s_speed') ?? 0) == 1 ? GameSpeed.fast : GameSpeed.normal,
      );

  Future<void> save(AppSettings s) async {
    await _prefs.setBool('s_sound', s.sound);
    await _prefs.setBool('s_haptics', s.haptics);
    await _prefs.setBool('s_dark', s.darkMode);
    await _prefs.setBool('s_preview', s.pathPreview);
    await _prefs.setBool('s_auto', s.autoMove);
    await _prefs.setInt('s_speed', s.speed.index);
  }
}
