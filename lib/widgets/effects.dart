import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/app_tokens.dart';

/// Shakes its child whenever [trigger] changes (token capture "rumble").
class ShakeBox extends StatefulWidget {
  const ShakeBox({super.key, required this.trigger, required this.child});
  final int trigger;
  final Widget child;

  @override
  State<ShakeBox> createState() => _ShakeBoxState();
}

class _ShakeBoxState extends State<ShakeBox> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: Motion.shake);

  @override
  void didUpdateWidget(ShakeBox old) {
    super.didUpdateWidget(old);
    if (old.trigger != widget.trigger) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final t = _c.value;
        final dx = math.sin(t * math.pi * 9) * 9 * (1 - t);
        final dy = math.cos(t * math.pi * 7) * 4 * (1 - t);
        return Transform.translate(offset: Offset(dx, dy), child: child);
      },
    );
  }
}

/// A reaction bubble that floats up and fades. Keyed by reaction id.
class FloatingReaction extends StatelessWidget {
  const FloatingReaction({super.key, required this.text});
  final String text;

  bool get _isEmoji => text.runes.length <= 2;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Motion.emojiFloat,
      builder: (context, t, child) {
        final opacity = t < 0.15 ? t / 0.15 : (t > 0.7 ? (1 - t) / 0.3 : 1.0);
        final scale = t < 0.15 ? 0.6 + 0.4 * (t / 0.15) : 1.0;
        return Transform.translate(
          offset: Offset(0, -34 * t),
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0).toDouble(),
            child: Transform.scale(scale: scale, child: child),
          ),
        );
      },
      child: _isEmoji
          ? Text(text, style: const TextStyle(fontSize: 30))
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              constraints: const BoxConstraints(maxWidth: 130),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(Radii.md),
                boxShadow: const [BoxShadow(color: Color(0x44000000), blurRadius: 8, offset: Offset(0, 3))],
              ),
              child: Text(
                text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF1B2130), fontWeight: FontWeight.w600, fontSize: 12),
              ),
            ),
    );
  }
}

/// Lightweight confetti for the victory screen.
class Confetti extends StatefulWidget {
  const Confetti({super.key});

  @override
  State<Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<Confetti> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();
  final _pieces = List.generate(90, (i) => _Piece(math.Random(i * 7919)));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          size: Size.infinite,
          painter: _ConfettiPainter(_pieces, _c.value),
        ),
      ),
    );
  }
}

class _Piece {
  _Piece(math.Random r)
      : x = r.nextDouble(),
        offset = r.nextDouble(),
        speed = 0.6 + r.nextDouble() * 0.8,
        sway = r.nextDouble() * 2 * math.pi,
        size = 5 + r.nextDouble() * 7,
        spin = r.nextDouble() * 6,
        color = LudoPalette.all[r.nextInt(LudoPalette.all.length)];
  final double x, offset, speed, sway, size, spin;
  final Color color;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.t);
  final List<_Piece> pieces;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in pieces) {
      final progress = (t * p.speed + p.offset) % 1.0;
      final y = progress * (size.height + 40) - 20;
      final x = p.x * size.width + math.sin(progress * 8 + p.sway) * 18;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(progress * p.spin * 2 * math.pi);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.55),
        Paint()..color = p.color,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
