import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_tokens.dart';
import '../state/game_controller.dart';
import '../state/providers.dart';
import '../widgets/dice.dart';
import '../widgets/neo.dart';
import 'game_screen.dart';
import 'how_to_play_screen.dart';
import 'lobby_screen.dart';
import 'settings_screen.dart';

class MenuScreen extends ConsumerWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(saveVersionProvider);
    final hasSave = ref.read(saveServiceProvider).hasSave;
    final stats = ref.watch(statsProvider);
    final t = SurfaceTokens.of(context);

    void open(Widget screen) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    }

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: _FloatingDice()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(flex: 2),
                  const _Title(),
                  const SizedBox(height: Space.sm),
                  Text(
                    'Classic & hexagon boards · 2–6 players · fully offline',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: t.textSecondary),
                  ),
                  const SizedBox(height: Space.xl),
                  NeoBox(
                    padding: const EdgeInsets.symmetric(vertical: Space.md),
                    child: Row(
                      children: [
                        _Stat(label: 'Played', value: stats.played),
                        _Stat(label: 'Wins', value: stats.wins),
                        _Stat(label: 'Captures', value: stats.captures),
                      ],
                    ),
                  ),
                  const Spacer(flex: 3),
                  // Primary actions live in the lower third, within thumb reach.
                  if (hasSave) ...[
                    _MenuButton(
                      icon: Icons.play_circle_fill_rounded,
                      label: 'Continue game',
                      color: LudoPalette.green,
                      onTap: () {
                        final ok = ref.read(gameControllerProvider.notifier).resume();
                        if (ok) {
                          open(const GameScreen());
                        } else {
                          ref.read(saveVersionProvider.notifier).state++;
                        }
                      },
                    ),
                    const SizedBox(height: Space.md),
                  ],
                  _MenuButton(
                    icon: Icons.smart_toy_rounded,
                    label: 'Play vs Computer',
                    color: LudoPalette.blue,
                    onTap: () => open(const LobbyScreen(mode: LobbyMode.computer)),
                  ),
                  const SizedBox(height: Space.md),
                  _MenuButton(
                    icon: Icons.groups_rounded,
                    label: 'Pass & Play',
                    color: LudoPalette.orange,
                    onTap: () => open(const LobbyScreen(mode: LobbyMode.local)),
                  ),
                  const SizedBox(height: Space.md),
                  Row(
                    children: [
                      Expanded(
                        child: _SmallButton(
                          icon: Icons.menu_book_rounded,
                          label: 'How to play',
                          onTap: () => open(const HowToPlayScreen()),
                        ),
                      ),
                      const SizedBox(width: Space.md),
                      Expanded(
                        child: _SmallButton(
                          icon: Icons.tune_rounded,
                          label: 'Settings',
                          onTap: () => open(const SettingsScreen()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Space.xl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title();

  @override
  Widget build(BuildContext context) {
    const letters = 'LUDO';
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < letters.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Container(
                  width: 58,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: glossy(LudoPalette.all[i]),
                    borderRadius: BorderRadius.circular(Radii.md),
                    boxShadow: [
                      BoxShadow(
                        color: LudoPalette.all[i].withValues(alpha: 0.45),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Text(
                    letters[i],
                    style: const TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: Space.sm),
        ShaderMask(
          shaderCallback: (r) => const LinearGradient(
            colors: [LudoPalette.purple, LudoPalette.orange],
          ).createShader(r),
          child: const Text(
            'N O V A',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white),
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final t = SurfaceTokens.of(context);
    return Expanded(
      child: Column(
        children: [
          Text('$value', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          Text(label, style: TextStyle(fontSize: 12, color: t.textSecondary)),
        ],
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({required this.icon, required this.label, required this.color, required this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return NeoButton(
      onPressed: onTap,
      gradient: glossy(color),
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: Space.xl),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(width: Space.lg),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const Spacer(),
          const Icon(Icons.chevron_right_rounded, color: Colors.white),
        ],
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  const _SmallButton({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return NeoButton(
      onPressed: onTap,
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: Space.sm),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// Soft, slowly drifting dice in the menu background.
class _FloatingDice extends StatefulWidget {
  const _FloatingDice();

  @override
  State<_FloatingDice> createState() => _FloatingDiceState();
}

class _FloatingDiceState extends State<_FloatingDice> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const spots = [
      (0.08, 0.08, 3, 0),
      (0.78, 0.12, 5, 1),
      (0.86, 0.42, 6, 3),
      (0.05, 0.46, 1, 4),
    ];
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, box) => AnimatedBuilder(
          animation: _c,
          builder: (context, _) => Stack(
            children: [
              for (final (x, y, face, color) in spots)
                Positioned(
                  left: x * box.maxWidth,
                  top: y * box.maxHeight + math.sin((_c.value + x) * 2 * math.pi) * 10,
                  child: Transform.rotate(
                    angle: math.sin((_c.value + y) * 2 * math.pi) * 0.3,
                    child: Opacity(
                      opacity: 0.35,
                      child: DiceFace(value: face, size: 44, accent: LudoPalette.all[color]),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
