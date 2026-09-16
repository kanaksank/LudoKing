import 'package:flutter/material.dart';

import '../core/theme/app_tokens.dart';
import '../widgets/neo.dart';

class HowToPlayScreen extends StatelessWidget {
  const HowToPlayScreen({super.key});

  static const _rules = [
    (Icons.casino_rounded, 'Roll', 'Tap your die (or the big die at the bottom) when your pod glows.'),
    (Icons.logout_rounded, 'Leave base', 'A 6 moves a token onto your coloured start cell.'),
    (Icons.touch_app_rounded, 'Move', 'Glowing tokens can move. Tap once to preview the route, tap again to go.'),
    (Icons.replay_rounded, 'Bonus rolls', 'Rolling a 6, capturing, or reaching home gives another roll. Three 6s in a row lose the turn.'),
    (Icons.flash_on_rounded, 'Capture', 'Land exactly on an opponent to send it back to base.'),
    (Icons.star_rounded, 'Safe cells', 'Start cells and star cells cannot be captured on.'),
    (Icons.home_rounded, 'Home', 'After a full lap, enter your coloured column. You need the exact number to finish.'),
    (Icons.emoji_events_rounded, 'Win', 'Bring all four tokens home first. Play continues for the other places.'),
    (Icons.hexagon_rounded, 'Hexagon board', '5 and 6 player games use a 78-cell hexagon. Pinch or use the zoom buttons.'),
  ];

  @override
  Widget build(BuildContext context) {
    final t = SurfaceTokens.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('How to play')),
      body: ListView.separated(
        padding: const EdgeInsets.all(Space.lg),
        itemCount: _rules.length,
        separatorBuilder: (context, index) => const SizedBox(height: Space.md),
        itemBuilder: (context, i) {
          final (icon, title, body) = _rules[i];
          final color = LudoPalette.all[i % LudoPalette.all.length];
          return NeoBox(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(gradient: glossy(color), shape: BoxShape.circle),
                  child: Icon(icon, color: Colors.white, size: 22),
                ),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      const SizedBox(height: 2),
                      Text(body, style: TextStyle(color: t.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
