import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../game/ludo_engine.dart';

/// Keeps one in-progress game on the device so it can be resumed.
class SaveService {
  SaveService(this._prefs);
  final SharedPreferences _prefs;
  static const _key = 'saved_game_v1';

  bool get hasSave => _prefs.containsKey(_key);

  Future<void> save(LudoState s) => _prefs.setString(_key, jsonEncode(s.toJson()));

  LudoState? load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return null;
    try {
      final state = LudoState.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
      return state.isOver ? null : state;
    } catch (_) {
      _prefs.remove(_key);
      return null;
    }
  }

  Future<void> clear() => _prefs.remove(_key);
}
