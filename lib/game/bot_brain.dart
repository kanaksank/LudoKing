import 'dart:math' as math;

import 'ludo_engine.dart';

/// Picks moves for computer players. Pure Dart.
class BotBrain {
  BotBrain([math.Random? rng]) : _rng = rng ?? math.Random();

  final math.Random _rng;

  int chooseMove(LudoState s, List<int> moves, BotLevel level) {
    if (moves.isEmpty) throw ArgumentError('No moves to choose from');
    if (moves.length == 1) return moves.first;
    if (level == BotLevel.easy && _rng.nextDouble() < 0.5) {
      return moves[_rng.nextInt(moves.length)];
    }
    final noise = switch (level) {
      BotLevel.easy => 40.0,
      BotLevel.medium => 18.0,
      BotLevel.hard => 0.0,
    };
    var best = moves.first;
    var bestScore = double.negativeInfinity;
    for (final m in moves) {
      final sc = score(s, m) + _rng.nextDouble() * noise;
      if (sc > bestScore) {
        bestScore = sc;
        best = m;
      }
    }
    return best;
  }

  /// Heuristic value of moving [token] with the current die.
  static double score(LudoState s, int token) {
    final me = s.current;
    final d = s.dice!;
    final arms = s.armCount;
    final len = LudoEngine.trackLength(arms);
    final last = LudoEngine.lastTrackProgress(arms);
    final fin = LudoEngine.finishProgress(arms);
    final myArm = s.players[me].arm;
    final from = s.tokens[me][token];
    final to = LudoEngine.targetProgress(s, me, token, d);
    if (to == null) return double.negativeInfinity;

    var sc = 0.0;
    if (to == fin) sc += 90;
    if (from < 0) sc += 45;
    if (from <= last && to > last && to != fin) sc += 35;

    if (to <= last) {
      final abs = LudoEngine.absoluteCell(arms, myArm, to);
      final safe = LudoEngine.isSafeCell(abs, s.rules);
      if (safe) {
        sc += 20;
      } else {
        for (var o = 0; o < s.players.length; o++) {
          if (o == me) continue;
          for (final p in s.tokens[o]) {
            if (LudoEngine.isOnTrack(arms, p) &&
                LudoEngine.absoluteCell(arms, s.players[o].arm, p) == abs) {
              sc += 70 + 30 * p / len;
            }
          }
        }
        sc -= 35 * LudoEngine.threatsAt(s, abs, me);
      }
    }

    if (LudoEngine.isOnTrack(arms, from)) {
      final absFrom = LudoEngine.absoluteCell(arms, myArm, from);
      if (!LudoEngine.isSafeCell(absFrom, s.rules)) {
        sc += 25 * LudoEngine.threatsAt(s, absFrom, me);
      }
    }

    sc += to * 0.3;
    return sc;
  }
}
