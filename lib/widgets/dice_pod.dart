import 'package:flutter/material.dart';

import '../core/theme/app_tokens.dart';
import '../game/ludo_engine.dart';
import '../state/game_controller.dart';
import 'dice.dart';
import 'effects.dart';
import 'neo.dart';

/// Player pod beside a home base: avatar, name, die, turn ring and timer.
class DicePod extends StatelessWidget {
  const DicePod({
    super.key,
    required this.player,
    required this.face,
    required this.isCurrent,
    required this.rolling,
    required this.timerFraction,
    required this.canRoll,
    required this.onRoll,
    this.reaction,
    this.rank,
    this.mirrored = false,
    this.width = 116,
  });

  final LudoPlayer player;
  final int face;
  final bool isCurrent;
  final bool rolling;
  final double timerFraction;
  final bool canRoll;
  final VoidCallback onRoll;
  final Reaction? reaction;

  /// 1-based finishing place once the player is done.
  final int? rank;

  /// Die on the left, avatar on the right.
  final bool mirrored;
  final double width;

  @override
  Widget build(BuildContext context) {
    final t = SurfaceTokens.of(context);
    final color = LudoPalette.of(player.colorIndex);
    final avatar = _Avatar(player: player, color: color, active: isCurrent, rank: rank);
    // Inner width = width - padding (12) - border (4); avatar + gap take 46.
    final ringSize = width - 64;
    final dieSize = ringSize / 1.34;
    final die = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: canRoll ? onRoll : null,
      child: TimerRing(
        size: ringSize,
        fraction: timerFraction,
        color: color,
        active: isCurrent,
        child: AnimatedScale(
          scale: canRoll ? 1.08 : 1,
          duration: Motion.press,
          child: DiceFace(
            value: face,
            size: dieSize,
            accent: color,
            rolling: rolling && isCurrent,
            dimmed: !isCurrent,
          ),
        ),
      ),
    );

    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: mirrored ? [die, const SizedBox(width: 4), avatar] : [avatar, const SizedBox(width: 4), die],
    );

    return Semantics(
      label: '${player.name}${isCurrent ? ', current turn' : ''}',
      child: SizedBox(
        width: width,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              opacity: isCurrent || rank != null ? 1 : 0.8,
              child: NeoBox(
                radius: Radii.lg,
                padding: const EdgeInsets.fromLTRB(6, 6, 6, 4),
                border: Border.all(
                  color: isCurrent ? color : Colors.transparent,
                  width: 2,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    row,
                    const SizedBox(height: 2),
                    Text(
                      player.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                        color: isCurrent ? t.textPrimary : t.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (reaction != null)
              Positioned(
                top: -18,
                child: IgnorePointer(
                  child: FloatingReaction(key: ValueKey(reaction!.id), text: reaction!.text),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.player, required this.color, required this.active, this.rank});
  final LudoPlayer player;
  final Color color;
  final bool active;
  final int? rank;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 42,
      height: 42,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: glossy(color),
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                if (active) BoxShadow(color: color.withValues(alpha: 0.7), blurRadius: 12, spreadRadius: 1),
              ],
            ),
            alignment: Alignment.center,
            child: Text(player.avatar, style: const TextStyle(fontSize: 20)),
          ),
          if (player.isBot)
            Positioned(
              bottom: -3,
              left: -3,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(color: Color(0xFF232838), shape: BoxShape.circle),
                child: const Icon(Icons.smart_toy_rounded, size: 11, color: Colors.white),
              ),
            ),
          if (rank != null)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                width: 18,
                height: 18,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: rank == 1 ? LudoPalette.gold : Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$rank',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF1B2130)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
