import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../game/ludo_engine.dart';
import '../services/feedback_service.dart';
import '../services/save_service.dart';
import '../services/settings_service.dart';
import '../services/stats_service.dart';

/// Overridden in main() with the real instance.
final prefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('prefsProvider must be overridden'),
);

final settingsServiceProvider = Provider((ref) => SettingsService(ref.watch(prefsProvider)));
final statsServiceProvider = Provider((ref) => StatsService(ref.watch(prefsProvider)));
final saveServiceProvider = Provider((ref) => SaveService(ref.watch(prefsProvider)));

final feedbackProvider = Provider<FeedbackService>((ref) {
  final fb = FeedbackService();
  final s = ref.watch(settingsProvider);
  fb
    ..haptics = s.haptics
    ..sound = s.sound;
  return fb;
});

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.read(settingsServiceProvider).load();

  void apply(AppSettings next) {
    state = next;
    ref.read(settingsServiceProvider).save(next);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

class StatsNotifier extends Notifier<GameStats> {
  @override
  GameStats build() => ref.read(statsServiceProvider).load();

  Future<void> record({required bool humanWon, required int humanCaptures}) async {
    state = await ref.read(statsServiceProvider).record(
          humanWon: humanWon,
          humanCaptures: humanCaptures,
        );
  }

  Future<void> reset() async {
    state = await ref.read(statsServiceProvider).reset();
  }
}

final statsProvider = NotifierProvider<StatsNotifier, GameStats>(StatsNotifier.new);

/// The lobby setup of the most recent game, used for rematches.
class GameSetup {
  const GameSetup({required this.players, required this.rules});
  final List<LudoPlayer> players;
  final GameRules rules;
}

final lastSetupProvider = StateProvider<GameSetup?>((ref) => null);

/// Bumped whenever the saved game changes so the menu can refresh.
final saveVersionProvider = StateProvider<int>((ref) => 0);
