import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_tokens.dart';
import '../game/bot_brain.dart';
import '../game/ludo_engine.dart';
import '../services/feedback_service.dart';
import '../services/settings_service.dart';
import 'providers.dart';

enum GameEventType { capture, home, playerFinished, forfeit, noMoves, bonusRoll, gameOver }

class GameEvent {
  const GameEvent(this.id, this.type, this.message);
  final int id;
  final GameEventType type;
  final String message;
}

class Reaction {
  const Reaction({required this.id, required this.player, required this.text});
  final int id;
  final int player;
  final String text;
}

class ChatLine {
  const ChatLine(this.player, this.text);
  final int player;
  final String text;
}

const Object _keep = Object();

class GameUiState {
  const GameUiState({
    required this.game,
    required this.display,
    required this.lastFaces,
    this.rolling = false,
    this.animating = false,
    this.paused = false,
    this.selectedToken,
    this.timerFraction = 1,
    this.reactions = const {},
    this.chat = const [],
    this.event,
    this.banner,
  });

  factory GameUiState.initial(LudoState game) => GameUiState(
        game: game,
        display: [for (final r in game.tokens) [...r]],
        lastFaces: List<int>.filled(game.players.length, 6),
      );

  /// Authoritative rules state.
  final LudoState game;

  /// Token progress used for drawing; lags behind [game] while a move animates.
  final List<List<int>> display;

  /// Last face shown on each player's die.
  final List<int> lastFaces;
  final bool rolling;
  final bool animating;
  final bool paused;
  final int? selectedToken;

  /// Remaining share of the turn timer, 1 → 0.
  final double timerFraction;

  /// Latest reaction per player index.
  final Map<int, Reaction> reactions;
  final List<ChatLine> chat;
  final GameEvent? event;
  final String? banner;

  bool get busy => rolling || animating || paused;

  /// Tokens the current (human or bot) player may move right now.
  List<int> get movable => busy ? const [] : LudoEngine.legalMoves(game);

  GameUiState copyWith({
    LudoState? game,
    List<List<int>>? display,
    List<int>? lastFaces,
    bool? rolling,
    bool? animating,
    bool? paused,
    Object? selectedToken = _keep,
    double? timerFraction,
    Map<int, Reaction>? reactions,
    List<ChatLine>? chat,
    Object? event = _keep,
    Object? banner = _keep,
  }) {
    return GameUiState(
      game: game ?? this.game,
      display: display ?? this.display,
      lastFaces: lastFaces ?? this.lastFaces,
      rolling: rolling ?? this.rolling,
      animating: animating ?? this.animating,
      paused: paused ?? this.paused,
      selectedToken: identical(selectedToken, _keep) ? this.selectedToken : selectedToken as int?,
      timerFraction: timerFraction ?? this.timerFraction,
      reactions: reactions ?? this.reactions,
      chat: chat ?? this.chat,
      event: identical(event, _keep) ? this.event : event as GameEvent?,
      banner: identical(banner, _keep) ? this.banner : banner as String?,
    );
  }
}

class GameController extends Notifier<GameUiState?> {
  final _rng = math.Random();
  final _bot = BotBrain();

  Timer? _botTimer;
  Timer? _turnTimer;
  Timer? _spinTimer;
  void Function()? _pendingTransition;
  int _gen = 0;
  int _eventId = 0;
  int _reactionId = 0;
  bool _overHandled = false;

  @override
  GameUiState? build() {
    ref.onDispose(cancelTimers);
    return null;
  }

  AppSettings get _settings => ref.read(settingsProvider);
  FeedbackService get _fb => ref.read(feedbackProvider);

  Duration _delay(int ms) =>
      Duration(milliseconds: _settings.speed == GameSpeed.fast ? (ms * 0.55).round() : ms);

  GameEvent _event(GameEventType type, String message) => GameEvent(++_eventId, type, message);

  // ---------------------------------------------------------------------------
  // Lifecycle

  void start(GameSetup setup) {
    _reset();
    ref.read(lastSetupProvider.notifier).state = setup;
    final game = LudoEngine.newGame(
      players: setup.players,
      rules: setup.rules,
      firstPlayer: _rng.nextInt(setup.players.length),
    );
    state = GameUiState.initial(game)
        .copyWith(banner: '${game.currentPlayer.name} starts');
    _persist();
    _schedule();
  }

  /// Loads the saved game. Returns false when there is nothing to resume.
  bool resume() {
    final saved = ref.read(saveServiceProvider).load();
    if (saved == null) return false;
    _reset();
    ref.read(lastSetupProvider.notifier).state = GameSetup(players: saved.players, rules: saved.rules);
    state = GameUiState.initial(saved).copyWith(banner: 'Welcome back!');
    _schedule();
    return true;
  }

  void leave() {
    _pendingTransition?.call();
    _pendingTransition = null;
    final s = state;
    if (s != null && !s.animating && !s.rolling) _persist();
    cancelTimers();
    _gen++;
    state = null;
  }

  void _reset() {
    cancelTimers();
    _gen++;
    _overHandled = false;
    _pendingTransition = null;
  }

  void cancelTimers() {
    _botTimer?.cancel();
    _turnTimer?.cancel();
    _spinTimer?.cancel();
  }

  void pause() {
    final s = state;
    if (s == null || s.paused) return;
    _turnTimer?.cancel();
    _botTimer?.cancel();
    final pending = _pendingTransition;
    _pendingTransition = null;
    pending?.call();
    state = state!.copyWith(paused: true, selectedToken: null);
    if (!state!.animating && !state!.rolling) _persist();
  }

  void resumePlay() {
    final s = state;
    if (s == null || !s.paused) return;
    state = s.copyWith(paused: false);
    _schedule();
  }

  // ---------------------------------------------------------------------------
  // Rolling

  /// Roll requested from the UI; ignored unless a human is up.
  void humanRoll() {
    final s = state;
    if (s == null || s.game.currentPlayer.isBot) return;
    _roll();
  }

  void _roll() {
    final s = state;
    if (s == null || s.busy || !s.game.awaitingRoll || _pendingTransition != null) return;
    _turnTimer?.cancel();
    _botTimer?.cancel();
    final gen = _gen;
    final player = s.game.current;
    _fb.diceRoll();
    state = s.copyWith(rolling: true, selectedToken: null, timerFraction: 1);
    var elapsed = 0;
    _spinTimer?.cancel();
    _spinTimer = Timer.periodic(const Duration(milliseconds: 70), (t) {
      final cur = state;
      if (cur == null || gen != _gen) {
        t.cancel();
        return;
      }
      elapsed += 70;
      if (elapsed < Motion.diceRoll.inMilliseconds) {
        final faces = [...cur.lastFaces];
        faces[player] = _rng.nextInt(6) + 1;
        state = cur.copyWith(lastFaces: faces);
        return;
      }
      t.cancel();
      _finishRoll(gen);
    });
  }

  void _finishRoll(int gen) {
    final s = state!;
    final value = LudoEngine.randomRoll(_rng);
    final result = LudoEngine.roll(s.game, value);
    final faces = [...s.lastFaces];
    faces[s.game.current] = value;
    final name = s.game.currentPlayer.name;

    if (result.forfeited || result.noMoves) {
      final type = result.forfeited
          ? GameEventType.forfeit
          : result.bonusRoll
              ? GameEventType.bonusRoll
              : GameEventType.noMoves;
      final msg = result.forfeited
          ? 'Three sixes! $name loses the turn'
          : result.bonusRoll
              ? 'No move for $name, but a 6 rolls again'
              : 'No moves for $name';
      state = s.copyWith(
        rolling: false,
        lastFaces: faces,
        banner: msg,
        event: _event(type, msg),
      );
      _pendingTransition = () {
        final cur = state;
        if (cur == null) return;
        state = cur.copyWith(game: result.state);
      };
      _botTimer = Timer(_delay(950), () {
        if (gen != _gen) return;
        final pending = _pendingTransition;
        _pendingTransition = null;
        pending?.call();
        _settled();
      });
      return;
    }

    state = s.copyWith(game: result.state, rolling: false, lastFaces: faces);
    if (state!.paused) return;

    if (result.state.currentPlayer.isBot) {
      _botTimer = Timer(_delay(500), () => _botMove(gen));
      return;
    }
    if (_settings.autoMove && _allEquivalent(result.state, result.moves)) {
      _botTimer = Timer(_delay(320), () {
        if (gen == _gen && !(state?.paused ?? true)) _performMove(result.moves.first);
      });
      return;
    }
    _startTurnTimer();
  }

  static bool _allEquivalent(LudoState g, List<int> moves) {
    final froms = {for (final m in moves) g.tokens[g.current][m]};
    return froms.length == 1;
  }

  // ---------------------------------------------------------------------------
  // Moving

  void tapToken(int player, int token) {
    final s = state;
    if (s == null || s.busy) return;
    final g = s.game;
    if (!g.awaitingMove || g.current != player || g.currentPlayer.isBot) return;
    if (!LudoEngine.legalMoves(g).contains(token)) return;
    if (_settings.pathPreview && s.selectedToken != token) {
      _fb.select();
      state = s.copyWith(selectedToken: token);
      return;
    }
    _performMove(token);
  }

  void confirmSelection() {
    final t = state?.selectedToken;
    if (t != null) tapToken(state!.game.current, t);
  }

  void clearSelection() {
    final s = state;
    if (s?.selectedToken != null) state = s!.copyWith(selectedToken: null);
  }

  void _botMove(int gen) {
    final s = state;
    if (s == null || gen != _gen || s.busy || !s.game.awaitingMove) return;
    final moves = LudoEngine.legalMoves(s.game);
    if (moves.isEmpty) return;
    _performMove(_bot.chooseMove(s.game, moves, s.game.currentPlayer.botLevel));
  }

  Future<void> _performMove(int token) async {
    final s = state;
    if (s == null || s.animating || s.rolling || !s.game.awaitingMove) return;
    if (!LudoEngine.legalMoves(s.game).contains(token)) return;
    _turnTimer?.cancel();
    _botTimer?.cancel();
    final gen = _gen;
    final result = LudoEngine.move(s.game, token);
    final player = result.player;
    final players = s.game.players;
    state = s.copyWith(animating: true, selectedToken: null, banner: null, timerFraction: 1);

    final step = _settings.speed == GameSpeed.fast ? Motion.tokenStepFast : Motion.tokenStep;
    for (final p in result.path) {
      final cur = state;
      if (cur == null || gen != _gen) return;
      final display = [for (final r in cur.display) [...r]];
      display[player][token] = p;
      state = cur.copyWith(display: display);
      _fb.tokenStep();
      await Future<void>.delayed(step);
    }
    if (state == null || gen != _gen) return;

    String? banner;
    GameEvent? event;
    final name = players[player].name;
    if (result.captured.isNotEmpty) {
      _fb.capture();
      final victims = {for (final c in result.captured) players[c.player].name}.join(', ');
      banner = '$name captured $victims!';
      event = _event(GameEventType.capture, banner);
    } else if (result.playerFinished) {
      _fb.win();
      banner = '$name brought every token home!';
      event = _event(GameEventType.playerFinished, banner);
    } else if (result.reachedHome) {
      _fb.home();
      banner = '$name reached home';
      event = _event(GameEventType.home, banner);
    } else if (result.extraTurn) {
      banner = 'Six! $name rolls again';
    }

    final cur = state!;
    state = cur.copyWith(
      game: result.state,
      display: [for (final r in result.state.tokens) [...r]],
      animating: false,
      banner: banner,
      event: event,
    );

    if (result.captured.isNotEmpty) {
      if (players[player].isBot && _rng.nextDouble() < 0.6) {
        react(player, _pick(const ['😎', '💥', '😈', '🎯']));
      }
      for (final victim in {for (final c in result.captured) c.player}) {
        if (players[victim].isBot && _rng.nextDouble() < 0.5) {
          react(victim, _pick(const ['😤', '😭', '🙄', '😱']));
        }
      }
    } else if (result.reachedHome && players[player].isBot && _rng.nextDouble() < 0.4) {
      react(player, _pick(const ['🎉', '🏠', '✨']));
    }

    _settled();
  }

  // ---------------------------------------------------------------------------
  // Scheduling

  void _settled() {
    final s = state;
    if (s == null) return;
    _maybeResolveBotsOnly();
    _persist();
    _schedule();
  }

  /// Once every human has finished, rank the remaining bots by progress
  /// instead of making the player watch them play it out.
  void _maybeResolveBotsOnly() {
    final s = state!;
    final g = s.game;
    if (g.isOver) return;
    final humans = [
      for (var i = 0; i < g.players.length; i++)
        if (!g.players[i].isBot) i,
    ];
    if (humans.isEmpty || !humans.every(g.finishOrder.contains)) return;
    final rest = [
      for (var i = 0; i < g.players.length; i++)
        if (!g.finishOrder.contains(i)) i,
    ];
    int total(int p) => g.tokens[p].fold(0, (a, b) => a + b);
    rest.sort((a, b) => total(b).compareTo(total(a)));
    state = s.copyWith(game: g.copyWith(finishOrder: [...g.finishOrder, ...rest], dice: null));
  }

  void _schedule() {
    _turnTimer?.cancel();
    _botTimer?.cancel();
    final s = state;
    if (s == null || s.busy) return;
    final g = s.game;
    final gen = _gen;
    if (g.isOver) {
      _gameOver();
      return;
    }
    if (g.currentPlayer.isBot) {
      _botTimer = Timer(_delay(g.dice == null ? 750 : 450), () {
        if (gen != _gen) return;
        final cur = state;
        if (cur == null) return;
        if (cur.game.awaitingRoll) {
          _roll();
        } else {
          _botMove(gen);
        }
      });
    } else {
      _startTurnTimer();
    }
  }

  void _startTurnTimer() {
    _turnTimer?.cancel();
    final s = state;
    if (s == null) return;
    final secs = s.game.rules.turnSeconds;
    if (secs <= 0) {
      if (s.timerFraction != 1) state = s.copyWith(timerFraction: 1);
      return;
    }
    final total = secs * 1000;
    var elapsed = 0;
    final gen = _gen;
    state = s.copyWith(timerFraction: 1);
    _turnTimer = Timer.periodic(const Duration(milliseconds: 100), (t) {
      final cur = state;
      if (cur == null || gen != _gen || cur.paused) {
        t.cancel();
        return;
      }
      elapsed += 100;
      if (elapsed >= total) {
        t.cancel();
        _onTimeout();
        return;
      }
      state = cur.copyWith(timerFraction: 1 - elapsed / total);
    });
  }

  void _onTimeout() {
    final s = state;
    if (s == null || s.busy) return;
    final g = s.game;
    if (g.awaitingRoll) {
      state = s.copyWith(banner: 'Time up, rolling for ${g.currentPlayer.name}');
      _roll();
    } else if (g.awaitingMove) {
      final moves = LudoEngine.legalMoves(g);
      if (moves.isEmpty) return;
      state = s.copyWith(banner: 'Time up, moving for ${g.currentPlayer.name}');
      _performMove(_bot.chooseMove(g, moves, BotLevel.medium));
    }
  }

  void _gameOver() {
    if (_overHandled) return;
    _overHandled = true;
    final g = state!.game;
    final humanWon = !g.players[g.finishOrder.first].isBot;
    var humanCaps = 0;
    for (var i = 0; i < g.players.length; i++) {
      if (!g.players[i].isBot) humanCaps += g.captures[i];
    }
    ref.read(statsProvider.notifier).record(humanWon: humanWon, humanCaptures: humanCaps);
    _fb.win();
    state = state!.copyWith(event: _event(GameEventType.gameOver, 'Game over'));
  }

  void _persist() {
    final s = state;
    if (s == null) return;
    final save = ref.read(saveServiceProvider);
    if (s.game.isOver) {
      save.clear();
    } else {
      save.save(s.game);
    }
    ref.read(saveVersionProvider.notifier).state++;
  }

  // ---------------------------------------------------------------------------
  // Chat & reactions

  void react(int player, String text) {
    final s = state;
    if (s == null) return;
    final r = Reaction(id: ++_reactionId, player: player, text: text);
    final chat = [...s.chat, ChatLine(player, text)];
    if (chat.length > 40) chat.removeRange(0, chat.length - 40);
    state = s.copyWith(reactions: {...s.reactions, player: r}, chat: chat);
  }

  /// A human sends a quick message; a bot may answer.
  void sendFromHuman(int player, String text) {
    react(player, text);
    final s = state;
    if (s == null) return;
    final bots = [
      for (var i = 0; i < s.game.players.length; i++)
        if (s.game.players[i].isBot) i,
    ];
    if (bots.isEmpty || _rng.nextDouble() > 0.45) return;
    final gen = _gen;
    Timer(const Duration(milliseconds: 1200), () {
      if (gen != _gen) return;
      react(bots[_rng.nextInt(bots.length)], _pick(const ['😄', '👍', '🤖', '😏', 'GG!', 'Bring it!']));
    });
  }

  String _pick(List<String> options) => options[_rng.nextInt(options.length)];
}

final gameControllerProvider =
    NotifierProvider<GameController, GameUiState?>(GameController.new);
