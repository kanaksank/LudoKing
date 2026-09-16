import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_tokens.dart';
import '../game/ludo_engine.dart';
import '../state/game_controller.dart';
import '../state/providers.dart';
import '../widgets/effects.dart';
import '../widgets/neo.dart';
import 'game_screen.dart';

class VictoryScreen extends ConsumerWidget {
  const VictoryScreen({super.key, required this.result});
  final LudoState result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = SurfaceTokens.of(context);
    final order = result.finishOrder;
    final players = result.players;
    final winner = players[order.first];
    final winnerColor = LudoPalette.of(winner.colorIndex);

    void rematch() {
      final setup = ref.read(lastSetupProvider) ??
          GameSetup(players: result.players, rules: result.rules);
      ref.read(gameControllerProvider.notifier).start(setup);
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const GameScreen()));
    }

    void home() {
      ref.read(gameControllerProvider.notifier).leave();
      Navigator.of(context).pop();
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) home();
      },
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.5),
                    radius: 1.1,
                    colors: [winnerColor.withValues(alpha: 0.45), t.background],
                  ),
                ),
              ),
            ),
            const Positioned.fill(child: Confetti()),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(Space.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: Space.lg),
                    const Icon(Icons.emoji_events_rounded, size: 64, color: LudoPalette.gold),
                    Text(
                      '${winner.name} wins!',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
                    ),
                    Text(
                      '${result.turnNumber} turns played',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: t.textSecondary),
                    ),
                    const SizedBox(height: Space.xl),
                    SizedBox(
                      height: 190,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (order.length > 1) _podium(players[order[1]], 2, 110),
                          _podium(players[order[0]], 1, 150),
                          if (order.length > 2) _podium(players[order[2]], 3, 80),
                        ],
                      ),
                    ),
                    const SizedBox(height: Space.lg),
                    Expanded(
                      child: NeoBox(
                        padding: const EdgeInsets.symmetric(vertical: Space.sm),
                        child: ListView(
                          children: [
                            for (var i = 0; i < order.length; i++)
                              ListTile(
                                dense: true,
                                leading: CircleAvatar(
                                  backgroundColor: LudoPalette.of(players[order[i]].colorIndex),
                                  child: Text(players[order[i]].avatar),
                                ),
                                title: Text(
                                  players[order[i]].name,
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                                subtitle: Text(
                                  '${result.captures[order[i]]} captures'
                                  '${players[order[i]].isBot ? ' · bot' : ''}',
                                ),
                                trailing: Text(
                                  _ordinal(i + 1),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: i == 0 ? LudoPalette.gold : t.textSecondary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: Space.lg),
                    NeoButton(
                      onPressed: rematch,
                      gradient: glossy(LudoPalette.green),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.replay_rounded, color: Colors.white),
                          SizedBox(width: Space.sm),
                          Text(
                            'Rematch',
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Space.md),
                    NeoButton(
                      onPressed: home,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.home_rounded),
                          SizedBox(width: Space.sm),
                          Text('Main menu', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _ordinal(int n) => switch (n) {
        1 => '1st',
        2 => '2nd',
        3 => '3rd',
        _ => '${n}th',
      };

  Widget _podium(LudoPlayer p, int place, double height) {
    final color = LudoPalette.of(p.colorIndex);
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            width: place == 1 ? 58 : 48,
            height: place == 1 ? 58 : 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: glossy(color),
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: Text(p.avatar, style: TextStyle(fontSize: place == 1 ? 28 : 22)),
          ),
          const SizedBox(height: 4),
          Text(
            p.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
          const SizedBox(height: 4),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: height - 60),
            duration: Duration(milliseconds: 500 + 150 * place),
            curve: Curves.easeOutBack,
            builder: (context, h, _) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              height: h < 34 ? 34 : h,
              decoration: BoxDecoration(
                gradient: glossy(color),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.sm)),
              ),
              alignment: Alignment.center,
              child: Text(
                '$place',
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
