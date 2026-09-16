// Pure Dart rules engine. No Flutter imports: everything here can be tested
// headlessly and reused anywhere.
//
// Board model
// -----------
// The board has `armCount` arms (4 = classic cross, 6 = hexagon). Each arm is
// a 3 x 6 strip of cells. 13 cells of every arm belong to the shared track, so
// the track is `13 * armCount` cells long (52 classic, 78 hexagon). The middle
// column's inner 5 cells are the owning player's home column.
//
// A token is described by its *progress*:
//   -1                        in base
//   0 .. L-2                  on the shared track (0 = the player's start cell)
//   L-1 .. L+3                in the home column (5 cells)
//   L+4                       finished (in the centre)
// where L is the track length. For the classic board that is 0..50 on the
// track, 51..55 in the home column and 56 finished.

import 'dart:math' as math;

enum BotLevel { easy, medium, hard }

class GameRules {
  const GameRules({
    this.sixToRelease = true,
    this.extraTurnOnSix = true,
    this.extraTurnOnCapture = true,
    this.extraTurnOnFinish = true,
    this.threeSixesForfeit = true,
    this.safeStars = true,
    this.turnSeconds = 15,
  });

  /// Only a 6 releases a token from base. When false, a 1 or a 6 does.
  final bool sixToRelease;
  final bool extraTurnOnSix;
  final bool extraTurnOnCapture;
  final bool extraTurnOnFinish;

  /// Rolling three sixes in a row forfeits the turn.
  final bool threeSixesForfeit;

  /// Star cells (8 steps after every start cell) are safe from capture.
  /// Start cells are always safe.
  final bool safeStars;

  /// Seconds a human has to act. 0 disables the timer.
  final int turnSeconds;

  GameRules copyWith({
    bool? sixToRelease,
    bool? extraTurnOnSix,
    bool? extraTurnOnCapture,
    bool? extraTurnOnFinish,
    bool? threeSixesForfeit,
    bool? safeStars,
    int? turnSeconds,
  }) {
    return GameRules(
      sixToRelease: sixToRelease ?? this.sixToRelease,
      extraTurnOnSix: extraTurnOnSix ?? this.extraTurnOnSix,
      extraTurnOnCapture: extraTurnOnCapture ?? this.extraTurnOnCapture,
      extraTurnOnFinish: extraTurnOnFinish ?? this.extraTurnOnFinish,
      threeSixesForfeit: threeSixesForfeit ?? this.threeSixesForfeit,
      safeStars: safeStars ?? this.safeStars,
      turnSeconds: turnSeconds ?? this.turnSeconds,
    );
  }

  Map<String, dynamic> toJson() => {
        'sixToRelease': sixToRelease,
        'extraTurnOnSix': extraTurnOnSix,
        'extraTurnOnCapture': extraTurnOnCapture,
        'extraTurnOnFinish': extraTurnOnFinish,
        'threeSixesForfeit': threeSixesForfeit,
        'safeStars': safeStars,
        'turnSeconds': turnSeconds,
      };

  factory GameRules.fromJson(Map<String, dynamic> j) => GameRules(
        sixToRelease: j['sixToRelease'] as bool? ?? true,
        extraTurnOnSix: j['extraTurnOnSix'] as bool? ?? true,
        extraTurnOnCapture: j['extraTurnOnCapture'] as bool? ?? true,
        extraTurnOnFinish: j['extraTurnOnFinish'] as bool? ?? true,
        threeSixesForfeit: j['threeSixesForfeit'] as bool? ?? true,
        safeStars: j['safeStars'] as bool? ?? true,
        turnSeconds: j['turnSeconds'] as int? ?? 15,
      );
}

class LudoPlayer {
  const LudoPlayer({
    required this.name,
    required this.arm,
    required this.colorIndex,
    this.isBot = false,
    this.botLevel = BotLevel.medium,
    this.avatar = '🙂',
  });

  final String name;

  /// Which arm of the board this player owns (their home column).
  final int arm;

  /// Index into the colour palette (red, green, yellow, blue, purple, orange).
  final int colorIndex;
  final bool isBot;
  final BotLevel botLevel;
  final String avatar;

  LudoPlayer copyWith({String? name, bool? isBot, BotLevel? botLevel, String? avatar}) {
    return LudoPlayer(
      name: name ?? this.name,
      arm: arm,
      colorIndex: colorIndex,
      isBot: isBot ?? this.isBot,
      botLevel: botLevel ?? this.botLevel,
      avatar: avatar ?? this.avatar,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'arm': arm,
        'color': colorIndex,
        'bot': isBot,
        'level': botLevel.name,
        'avatar': avatar,
      };

  factory LudoPlayer.fromJson(Map<String, dynamic> j) => LudoPlayer(
        name: j['name'] as String,
        arm: j['arm'] as int,
        colorIndex: j['color'] as int,
        isBot: j['bot'] as bool? ?? false,
        botLevel: BotLevel.values.firstWhere(
          (l) => l.name == j['level'],
          orElse: () => BotLevel.medium,
        ),
        avatar: j['avatar'] as String? ?? '🙂',
      );
}

const Object _unset = Object();

class LudoState {
  const LudoState({
    required this.armCount,
    required this.players,
    required this.tokens,
    required this.current,
    required this.rules,
    required this.captures,
    this.dice,
    this.sixStreak = 0,
    this.finishOrder = const [],
    this.turnNumber = 0,
  });

  final int armCount;
  final List<LudoPlayer> players;

  /// tokens[player][token] = progress (see the file header).
  final List<List<int>> tokens;

  /// Index into [players] of whoever is acting.
  final int current;

  /// The rolled value waiting to be used, or null when a roll is needed.
  final int? dice;
  final int sixStreak;

  /// Player indices in the order they finished.
  final List<int> finishOrder;

  /// Captures made by each player.
  final List<int> captures;
  final GameRules rules;
  final int turnNumber;

  bool get isOver => finishOrder.length >= players.length;
  bool get awaitingRoll => !isOver && dice == null;
  bool get awaitingMove => !isOver && dice != null;
  LudoPlayer get currentPlayer => players[current];

  LudoState copyWith({
    List<List<int>>? tokens,
    int? current,
    Object? dice = _unset,
    int? sixStreak,
    List<int>? finishOrder,
    List<int>? captures,
    int? turnNumber,
  }) {
    return LudoState(
      armCount: armCount,
      players: players,
      rules: rules,
      tokens: tokens ?? this.tokens,
      current: current ?? this.current,
      dice: identical(dice, _unset) ? this.dice : dice as int?,
      sixStreak: sixStreak ?? this.sixStreak,
      finishOrder: finishOrder ?? this.finishOrder,
      captures: captures ?? this.captures,
      turnNumber: turnNumber ?? this.turnNumber,
    );
  }

  Map<String, dynamic> toJson() => {
        'v': 1,
        'arms': armCount,
        'players': [for (final p in players) p.toJson()],
        'tokens': tokens,
        'current': current,
        'dice': dice,
        'sixStreak': sixStreak,
        'finishOrder': finishOrder,
        'captures': captures,
        'rules': rules.toJson(),
        'turn': turnNumber,
      };

  factory LudoState.fromJson(Map<String, dynamic> j) {
    final players = [
      for (final p in j['players'] as List) LudoPlayer.fromJson(Map<String, dynamic>.from(p as Map)),
    ];
    return LudoState(
      armCount: j['arms'] as int,
      players: players,
      tokens: [
        for (final row in j['tokens'] as List) [for (final t in row as List) t as int],
      ],
      current: j['current'] as int,
      dice: j['dice'] as int?,
      sixStreak: j['sixStreak'] as int? ?? 0,
      finishOrder: [for (final i in j['finishOrder'] as List) i as int],
      captures: [for (final i in j['captures'] as List) i as int],
      rules: GameRules.fromJson(Map<String, dynamic>.from(j['rules'] as Map)),
      turnNumber: j['turn'] as int? ?? 0,
    );
  }
}

class CapturedToken {
  const CapturedToken(this.player, this.token);
  final int player;
  final int token;
}

class RollResult {
  const RollResult({
    required this.state,
    required this.value,
    required this.moves,
    this.forfeited = false,
    this.noMoves = false,
    this.bonusRoll = false,
  });

  final LudoState state;
  final int value;
  final List<int> moves;

  /// Third six in a row: the turn is lost.
  final bool forfeited;

  /// Nothing can move with this value.
  final bool noMoves;

  /// Nothing could move, but the six still earns another roll.
  final bool bonusRoll;
}

class MoveResult {
  const MoveResult({
    required this.state,
    required this.player,
    required this.token,
    required this.path,
    required this.captured,
    required this.reachedHome,
    required this.extraTurn,
    required this.playerFinished,
  });

  final LudoState state;
  final int player;
  final int token;

  /// Every progress value the token passes through, in order, ending at the
  /// destination. Used for step-by-step animation.
  final List<int> path;
  final List<CapturedToken> captured;
  final bool reachedHome;
  final bool extraTurn;
  final bool playerFinished;
}

class LudoEngine {
  LudoEngine._();

  static const tokensPerPlayer = 4;
  static const cellsPerArm = 13;
  static const homeColumnLength = 5;

  /// Local index (0..12) of a player's start cell inside their own arm.
  static const startLocal = 8;

  /// Local index of the star cell inside every arm (8 steps after the
  /// previous arm's start cell).
  static const starLocal = 3;

  static int trackLength(int arms) => arms * cellsPerArm;
  static int lastTrackProgress(int arms) => trackLength(arms) - 2;
  static int finishProgress(int arms) => trackLength(arms) + homeColumnLength - 1;

  static int boardArmsFor(int playerCount) => playerCount <= 4 ? 4 : 6;

  /// Which arms seat 2..6 players. Two players sit opposite each other.
  static List<int> armsForPlayerCount(int count) {
    switch (count) {
      case 2:
        return const [0, 2];
      case 3:
        return const [0, 1, 2];
      case 4:
        return const [0, 1, 2, 3];
      case 5:
        return const [0, 1, 2, 3, 4];
      case 6:
        return const [0, 1, 2, 3, 4, 5];
    }
    throw ArgumentError.value(count, 'count', 'Ludo supports 2 to 6 players');
  }

  static int startCell(int arm) => arm * cellsPerArm + startLocal;

  static int absoluteCell(int arms, int arm, int progress) =>
      (startCell(arm) + progress) % trackLength(arms);

  static bool isSafeCell(int abs, GameRules rules) {
    final local = abs % cellsPerArm;
    return local == startLocal || (rules.safeStars && local == starLocal);
  }

  static bool isOnTrack(int arms, int progress) =>
      progress >= 0 && progress <= lastTrackProgress(arms);

  static LudoState newGame({
    required List<LudoPlayer> players,
    GameRules rules = const GameRules(),
    int firstPlayer = 0,
  }) {
    if (players.length < 2 || players.length > 6) {
      throw ArgumentError('Ludo supports 2 to 6 players');
    }
    return LudoState(
      armCount: boardArmsFor(players.length),
      players: List.unmodifiable(players),
      tokens: [
        for (var i = 0; i < players.length; i++) List<int>.filled(tokensPerPlayer, -1),
      ],
      current: firstPlayer % players.length,
      rules: rules,
      captures: List<int>.filled(players.length, 0),
    );
  }

  /// Destination progress for [token] with [dice], or null if it cannot move.
  static int? targetProgress(LudoState s, int player, int token, int dice) {
    final p = s.tokens[player][token];
    final fin = finishProgress(s.armCount);
    if (p >= fin) return null;
    if (p < 0) {
      final release = s.rules.sixToRelease ? dice == 6 : (dice == 6 || dice == 1);
      return release ? 0 : null;
    }
    final t = p + dice;
    return t <= fin ? t : null;
  }

  static List<int> legalMoves(LudoState s, [int? dice]) {
    final d = dice ?? s.dice;
    if (d == null || s.isOver) return const [];
    return [
      for (var t = 0; t < tokensPerPlayer; t++)
        if (targetProgress(s, s.current, t, d) != null) t,
    ];
  }

  static List<int> pathFor(LudoState s, int player, int token, int dice) {
    final from = s.tokens[player][token];
    final to = targetProgress(s, player, token, dice);
    if (to == null) return const [];
    if (from < 0) return const [0];
    return [for (var i = from + 1; i <= to; i++) i];
  }

  /// Applies a die roll of [value] for the current player.
  static RollResult roll(LudoState s, int value) {
    if (!s.awaitingRoll) {
      throw StateError('Not waiting for a roll');
    }
    if (value < 1 || value > 6) {
      throw ArgumentError.value(value, 'value');
    }
    final streak = value == 6 ? s.sixStreak + 1 : 0;
    if (s.rules.threeSixesForfeit && streak >= 3) {
      return RollResult(state: _passTurn(s), value: value, moves: const [], forfeited: true);
    }
    final withDice = s.copyWith(dice: value, sixStreak: streak);
    final moves = legalMoves(withDice);
    if (moves.isEmpty) {
      if (value == 6 && s.rules.extraTurnOnSix) {
        return RollResult(
          state: s.copyWith(dice: null, sixStreak: streak, turnNumber: s.turnNumber + 1),
          value: value,
          moves: const [],
          noMoves: true,
          bonusRoll: true,
        );
      }
      return RollResult(state: _passTurn(s), value: value, moves: const [], noMoves: true);
    }
    return RollResult(state: withDice, value: value, moves: moves);
  }

  /// Moves [token] of the current player by the rolled value.
  static MoveResult move(LudoState s, int token) {
    final d = s.dice;
    if (d == null) throw StateError('Roll before moving');
    final player = s.current;
    final target = targetProgress(s, player, token, d);
    if (target == null) {
      throw ArgumentError('Token $token cannot move $d');
    }
    final path = pathFor(s, player, token, d);
    final arms = s.armCount;
    final tokens = [for (final row in s.tokens) [...row]];
    tokens[player][token] = target;

    final captured = <CapturedToken>[];
    if (isOnTrack(arms, target)) {
      final abs = absoluteCell(arms, s.players[player].arm, target);
      if (!isSafeCell(abs, s.rules)) {
        for (var o = 0; o < s.players.length; o++) {
          if (o == player) continue;
          for (var t = 0; t < tokensPerPlayer; t++) {
            final p = tokens[o][t];
            if (isOnTrack(arms, p) && absoluteCell(arms, s.players[o].arm, p) == abs) {
              tokens[o][t] = -1;
              captured.add(CapturedToken(o, t));
            }
          }
        }
      }
    }

    final fin = finishProgress(arms);
    final reachedHome = target == fin;
    final finishOrder = [...s.finishOrder];
    final playerFinished = tokens[player].every((p) => p == fin);
    if (playerFinished && !finishOrder.contains(player)) {
      finishOrder.add(player);
    }
    final remaining = [
      for (var i = 0; i < s.players.length; i++)
        if (!finishOrder.contains(i)) i,
    ];
    if (remaining.length == 1) finishOrder.add(remaining.first);

    final captures = [...s.captures];
    captures[player] += captured.length;

    var next = s.copyWith(
      tokens: tokens,
      dice: null,
      finishOrder: finishOrder,
      captures: captures,
    );

    final over = next.isOver;
    final extra = !over &&
        !playerFinished &&
        ((d == 6 && s.rules.extraTurnOnSix) ||
            (captured.isNotEmpty && s.rules.extraTurnOnCapture) ||
            (reachedHome && s.rules.extraTurnOnFinish));

    if (!over) {
      next = extra ? next.copyWith(turnNumber: s.turnNumber + 1) : _passTurn(next);
    }

    return MoveResult(
      state: next,
      player: player,
      token: token,
      path: path,
      captured: captured,
      reachedHome: reachedHome,
      extraTurn: extra,
      playerFinished: playerFinished,
    );
  }

  static LudoState _passTurn(LudoState s) {
    if (s.isOver) return s.copyWith(dice: null);
    var next = s.current;
    for (var i = 0; i < s.players.length; i++) {
      next = (next + 1) % s.players.length;
      if (!s.finishOrder.contains(next)) break;
    }
    return s.copyWith(
      current: next,
      dice: null,
      sixStreak: 0,
      turnNumber: s.turnNumber + 1,
    );
  }

  /// Opponent tokens that could land on [abs] with a single roll.
  static int threatsAt(LudoState s, int abs, int me) {
    final arms = s.armCount;
    final len = trackLength(arms);
    final last = lastTrackProgress(arms);
    var threats = 0;
    for (var o = 0; o < s.players.length; o++) {
      if (o == me) continue;
      for (final p in s.tokens[o]) {
        if (!isOnTrack(arms, p)) continue;
        final from = absoluteCell(arms, s.players[o].arm, p);
        final dist = (abs - from + len) % len;
        if (dist >= 1 && dist <= 6 && p + dist <= last) threats++;
      }
    }
    return threats;
  }

  static int randomRoll(math.Random rng) => rng.nextInt(6) + 1;
}
