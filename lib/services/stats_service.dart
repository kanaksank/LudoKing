import 'package:shared_preferences/shared_preferences.dart';

class GameStats {
  const GameStats({this.played = 0, this.wins = 0, this.captures = 0});
  final int played;

  /// Games in which a human player finished first.
  final int wins;

  /// Captures made by human players.
  final int captures;
}

class StatsService {
  StatsService(this._prefs);
  final SharedPreferences _prefs;

  GameStats load() => GameStats(
        played: _prefs.getInt('st_played') ?? 0,
        wins: _prefs.getInt('st_wins') ?? 0,
        captures: _prefs.getInt('st_caps') ?? 0,
      );

  Future<GameStats> record({required bool humanWon, required int humanCaptures}) async {
    final s = load();
    final next = GameStats(
      played: s.played + 1,
      wins: s.wins + (humanWon ? 1 : 0),
      captures: s.captures + humanCaptures,
    );
    await _prefs.setInt('st_played', next.played);
    await _prefs.setInt('st_wins', next.wins);
    await _prefs.setInt('st_caps', next.captures);
    return next;
  }

  Future<GameStats> reset() async {
    await _prefs.remove('st_played');
    await _prefs.remove('st_wins');
    await _prefs.remove('st_caps');
    return const GameStats();
  }
}
