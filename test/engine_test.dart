import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_nova/game/bot_brain.dart';
import 'package:ludo_nova/game/ludo_engine.dart';

List<LudoPlayer> seats(int n, {bool bots = false}) {
  final arms = LudoEngine.armsForPlayerCount(n);
  return [
    for (var i = 0; i < n; i++)
      LudoPlayer(name: 'P$i', arm: arms[i], colorIndex: arms[i], isBot: bots),
  ];
}

LudoState withTokens(LudoState s, List<List<int>> tokens, {int current = 0, int? dice}) =>
    s.copyWith(tokens: tokens, current: current, dice: dice);

void main() {
  group('track constants', () {
    test('classic board matches standard Ludo', () {
      expect(LudoEngine.trackLength(4), 52);
      expect(LudoEngine.lastTrackProgress(4), 50);
      expect(LudoEngine.finishProgress(4), 56);
    });
    test('hexagon board', () {
      expect(LudoEngine.trackLength(6), 78);
      expect(LudoEngine.finishProgress(6), 82);
    });
    test('board size follows player count', () {
      expect(LudoEngine.boardArmsFor(2), 4);
      expect(LudoEngine.boardArmsFor(4), 4);
      expect(LudoEngine.boardArmsFor(5), 6);
      expect(LudoEngine.boardArmsFor(6), 6);
      expect(LudoEngine.armsForPlayerCount(2), [0, 2]);
    });
    test('last track cell sits at the entry of the own home column', () {
      for (final arms in [4, 6]) {
        for (var arm = 0; arm < arms; arm++) {
          final abs = LudoEngine.absoluteCell(arms, arm, LudoEngine.lastTrackProgress(arms));
          expect(abs, arm * 13 + 6);
        }
      }
    });
  });

  group('rolling', () {
    final base = LudoEngine.newGame(players: seats(4));

    test('needs a six to leave base', () {
      final r = LudoEngine.roll(base, 4);
      expect(r.noMoves, isTrue);
      expect(r.state.current, 1);
      expect(r.state.dice, isNull);
    });

    test('six with nothing to move still grants a bonus roll', () {
      final s = withTokens(base, [
        [56, 56, 56, 53],
        [-1, -1, -1, -1],
        [-1, -1, -1, -1],
        [-1, -1, -1, -1],
      ]);
      final r = LudoEngine.roll(s, 6);
      expect(r.noMoves, isTrue);
      expect(r.bonusRoll, isTrue);
      expect(r.state.current, 0);
    });

    test('six releases tokens', () {
      final r = LudoEngine.roll(base, 6);
      expect(r.moves, [0, 1, 2, 3]);
      expect(r.state.dice, 6);
    });

    test('1 releases when the six rule is off', () {
      final s = LudoEngine.newGame(players: seats(4), rules: const GameRules(sixToRelease: false));
      expect(LudoEngine.roll(s, 1).moves, [0, 1, 2, 3]);
    });

    test('third six forfeits the turn', () {
      final s = withTokens(base, [
        [5, -1, -1, -1],
        [-1, -1, -1, -1],
        [-1, -1, -1, -1],
        [-1, -1, -1, -1],
      ]).copyWith(sixStreak: 2);
      final r = LudoEngine.roll(s, 6);
      expect(r.forfeited, isTrue);
      expect(r.state.current, 1);
      expect(r.state.sixStreak, 0);
    });

    test('exact roll needed to finish', () {
      final s = withTokens(base, [
        [54, -1, -1, -1],
        [-1, -1, -1, -1],
        [-1, -1, -1, -1],
        [-1, -1, -1, -1],
      ]);
      expect(LudoEngine.roll(s, 3).noMoves, isTrue);
      expect(LudoEngine.roll(s, 2).moves, [0]);
    });
  });

  group('moving', () {
    final base = LudoEngine.newGame(players: seats(4));

    test('leaving base lands on progress 0 and six gives another turn', () {
      final s = LudoEngine.roll(base, 6).state;
      final m = LudoEngine.move(s, 2);
      expect(m.state.tokens[0][2], 0);
      expect(m.path, [0]);
      expect(m.extraTurn, isTrue);
      expect(m.state.current, 0);
    });

    test('normal move passes the turn and reports every step', () {
      final s = withTokens(base, [
        [3, -1, -1, -1],
        [-1, -1, -1, -1],
        [-1, -1, -1, -1],
        [-1, -1, -1, -1],
      ], dice: 4);
      final m = LudoEngine.move(s, 0);
      expect(m.path, [4, 5, 6, 7]);
      expect(m.state.tokens[0][0], 7);
      expect(m.state.current, 1);
    });

    test('captures an opponent on a normal cell', () {
      // Player 0 at progress 10 → abs 18. Player 1 (arm 1, start 21) at
      // progress 49 → abs (21 + 49) % 52 = 18.
      final s = withTokens(base, [
        [7, -1, -1, -1],
        [49, -1, -1, -1],
        [-1, -1, -1, -1],
        [-1, -1, -1, -1],
      ], dice: 3);
      final m = LudoEngine.move(s, 0);
      expect(m.captured.length, 1);
      expect(m.state.tokens[1][0], -1);
      expect(m.state.captures[0], 1);
      expect(m.extraTurn, isTrue);
      expect(m.state.current, 0);
    });

    test('no capture on a star cell', () {
      // Star cell of arm 1 is abs 16 = player 0 progress 8.
      // Player 1 progress (16 - 21 + 52) = 47.
      final s = withTokens(base, [
        [5, -1, -1, -1],
        [47, -1, -1, -1],
        [-1, -1, -1, -1],
        [-1, -1, -1, -1],
      ], dice: 3);
      final m = LudoEngine.move(s, 0);
      expect(m.captured, isEmpty);
      expect(m.state.tokens[1][0], 47);
    });

    test('star capture allowed when safe stars are off', () {
      final s = LudoEngine.newGame(players: seats(4), rules: const GameRules(safeStars: false));
      final t = withTokens(s, [
        [5, -1, -1, -1],
        [47, -1, -1, -1],
        [-1, -1, -1, -1],
        [-1, -1, -1, -1],
      ], dice: 3);
      expect(LudoEngine.move(t, 0).captured.length, 1);
    });

    test('no capture on an opponent start cell', () {
      // Player 1 start = abs 21 = player 0 progress 13.
      final s = withTokens(base, [
        [10, -1, -1, -1],
        [0, -1, -1, -1],
        [-1, -1, -1, -1],
        [-1, -1, -1, -1],
      ], dice: 3);
      expect(LudoEngine.move(s, 0).captured, isEmpty);
    });

    test('tokens in the home column are never captured', () {
      final s = withTokens(base, [
        [48, -1, -1, -1],
        [-1, -1, -1, -1],
        [-1, -1, -1, -1],
        [-1, -1, -1, -1],
      ], dice: 5);
      final m = LudoEngine.move(s, 0);
      expect(m.state.tokens[0][0], 53);
      expect(m.captured, isEmpty);
    });

    test('finishing all tokens ranks the player and skips them', () {
      final s = withTokens(base, [
        [56, 56, 56, 53],
        [0, -1, -1, -1],
        [0, -1, -1, -1],
        [-1, -1, -1, -1],
      ], dice: 3);
      final m = LudoEngine.move(s, 3);
      expect(m.playerFinished, isTrue);
      expect(m.extraTurn, isFalse);
      expect(m.state.finishOrder, [0]);
      expect(m.state.current, 1);

      final later = m.state.copyWith(current: 3);
      final passed = LudoEngine.roll(later, 2);
      expect(passed.state.current, 1, reason: 'finished player 0 is skipped');
    });

    test('game ends when one player is left', () {
      final s = LudoEngine.newGame(players: seats(2));
      final t = withTokens(s, [
        [56, 56, 56, 55],
        [0, -1, -1, -1],
      ], dice: 1);
      final m = LudoEngine.move(t, 3);
      expect(m.state.isOver, isTrue);
      expect(m.state.finishOrder, [0, 1]);
    });

    test('state survives a JSON round trip', () {
      final s = withTokens(base, [
        [3, 56, -1, 51],
        [-1, 2, -1, -1],
        [-1, -1, -1, -1],
        [10, -1, -1, -1],
      ], current: 2, dice: 5);
      final back = LudoState.fromJson(s.toJson());
      expect(back.tokens, s.tokens);
      expect(back.current, 2);
      expect(back.dice, 5);
      expect(back.players.map((p) => p.arm), s.players.map((p) => p.arm));
    });
  });

  group('threats', () {
    test('counts opponents up to six cells behind', () {
      final s = LudoEngine.newGame(players: seats(4));
      // Player 1 at abs 12 (progress 43) threatens abs 18.
      final t = withTokens(s, [
        [10, -1, -1, -1],
        [43, -1, -1, -1],
        [-1, -1, -1, -1],
        [-1, -1, -1, -1],
      ]);
      expect(LudoEngine.threatsAt(t, 18, 0), 1);
      expect(LudoEngine.threatsAt(t, 19, 0), 0);
    });
  });

  group('full bot games', () {
    for (final n in [2, 3, 4, 5, 6]) {
      test('$n players always finish', () {
        final rng = math.Random(n * 101);
        final brain = BotBrain(math.Random(n));
        for (var game = 0; game < 20; game++) {
          var s = LudoEngine.newGame(players: seats(n, bots: true), firstPlayer: game % n);
          var steps = 0;
          while (!s.isOver) {
            steps++;
            expect(steps, lessThan(20000), reason: 'game should terminate');
            final r = LudoEngine.roll(s, LudoEngine.randomRoll(rng));
            s = r.state;
            if (r.moves.isNotEmpty) {
              final level = BotLevel.values[game % 3];
              s = LudoEngine.move(s, brain.chooseMove(s, r.moves, level)).state;
            }
            for (final row in s.tokens) {
              for (final p in row) {
                expect(p, inInclusiveRange(-1, LudoEngine.finishProgress(s.armCount)));
              }
            }
          }
          expect(s.finishOrder.toSet().length, n);
        }
      });
    }

    test('hard bot beats random mover most of the time', () {
      final rng = math.Random(7);
      final brain = BotBrain(math.Random(9));
      var hardWins = 0;
      const games = 60;
      for (var g = 0; g < games; g++) {
        var s = LudoEngine.newGame(players: seats(2, bots: true), firstPlayer: g % 2);
        while (!s.isOver) {
          final r = LudoEngine.roll(s, LudoEngine.randomRoll(rng));
          s = r.state;
          if (r.moves.isEmpty) continue;
          final pick = s.current == 0
              ? brain.chooseMove(s, r.moves, BotLevel.hard)
              : r.moves[rng.nextInt(r.moves.length)];
          s = LudoEngine.move(s, pick).state;
        }
        if (s.finishOrder.first == 0) hardWins++;
      }
      expect(hardWins, greaterThan(games * 0.55));
    });
  });
}
