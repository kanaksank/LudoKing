import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/app_tokens.dart';

/// A tactile 3D die. When [rolling] it wobbles; the face is driven by the
/// controller so every client sees the same spin.
class DiceFace extends StatefulWidget {
  const DiceFace({
    super.key,
    required this.value,
    required this.size,
    required this.accent,
    this.rolling = false,
    this.dimmed = false,
  });

  final int value;
  final double size;
  final Color accent;
  final bool rolling;
  final bool dimmed;

  @override
  State<DiceFace> createState() => _DiceFaceState();
}

class _DiceFaceState extends State<DiceFace> with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );

  @override
  void initState() {
    super.initState();
    if (widget.rolling) _spin.repeat();
  }

  @override
  void didUpdateWidget(DiceFace old) {
    super.didUpdateWidget(old);
    if (widget.rolling && !_spin.isAnimating) {
      _spin.repeat();
    } else if (!widget.rolling && _spin.isAnimating) {
      _spin.stop();
      _spin.animateTo(1, duration: const Duration(milliseconds: 160), curve: Curves.easeOut)
          .then((_) {
        if (mounted) _spin.value = 0;
      });
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _spin,
      builder: (context, _) {
        final a = _spin.value * 2 * math.pi;
        final m = Matrix4.identity()
          ..setEntry(3, 2, 0.002)
          ..rotateX(widget.rolling ? math.sin(a) * 0.5 : 0)
          ..rotateY(widget.rolling ? math.cos(a) * 0.5 : 0)
          ..rotateZ(widget.rolling ? a : 0);
        return Transform(
          alignment: Alignment.center,
          transform: m,
          child: Opacity(
            opacity: widget.dimmed ? 0.55 : 1,
            child: SizedBox.square(
              dimension: widget.size,
              child: CustomPaint(painter: _DicePainter(widget.value, widget.accent)),
            ),
          ),
        );
      },
    );
  }
}

class _DicePainter extends CustomPainter {
  _DicePainter(this.value, this.accent);
  final int value;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final rect = Rect.fromLTWH(0, 0, w, w);
    final r = RRect.fromRectAndRadius(rect.deflate(w * 0.04), Radius.circular(w * 0.24));
    // Bottom edge gives the 3D thickness.
    canvas.drawRRect(
      r.shift(Offset(0, w * 0.06)),
      Paint()..color = LudoPalette.shade(accent, -0.25),
    );
    canvas.drawRRect(
      r,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Color(0xFFE6E9F0)],
        ).createShader(rect),
    );
    canvas.drawRRect(
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.035
        ..color = accent.withValues(alpha: 0.85),
    );

    const pips = {
      1: [(0, 0)],
      2: [(-1, -1), (1, 1)],
      3: [(-1, -1), (0, 0), (1, 1)],
      4: [(-1, -1), (1, -1), (-1, 1), (1, 1)],
      5: [(-1, -1), (1, -1), (0, 0), (-1, 1), (1, 1)],
      6: [(-1, -1), (1, -1), (-1, 0), (1, 0), (-1, 1), (1, 1)],
    };
    final pipPaint = Paint()..color = value == 1 ? LudoPalette.red : const Color(0xFF232838);
    final off = w * 0.24;
    final pr = w * (value == 1 ? 0.12 : 0.085);
    for (final (x, y) in pips[math.max(1, math.min(6, value))]!) {
      canvas.drawCircle(Offset(w / 2 + x * off, w / 2 + y * off), pr, pipPaint);
    }
  }

  @override
  bool shouldRepaint(_DicePainter old) => old.value != value || old.accent != accent;
}

/// Circular turn-timer that drains clockwise.
class TimerRing extends StatelessWidget {
  const TimerRing({
    super.key,
    required this.fraction,
    required this.color,
    required this.size,
    required this.child,
    this.active = false,
  });

  final double fraction;
  final Color color;
  final double size;
  final Widget child;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _RingPainter(
          fraction: active ? fraction : 0,
          color: fraction < 0.3 ? LudoPalette.red : color,
          track: SurfaceTokens.of(context).shadowDark.withValues(alpha: 0.25),
          glow: active,
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.fraction, required this.color, required this.track, required this.glow});
  final double fraction;
  final Color color;
  final Color track;
  final bool glow;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final stroke = size.width * 0.07;
    final r = size.width / 2 - stroke;
    if (glow) {
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke * 2.2
          ..color = color.withValues(alpha: 0.35)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, stroke * 1.4),
      );
    }
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = track,
    );
    if (fraction > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        -math.pi / 2,
        2 * math.pi * fraction.clamp(0.0, 1.0).toDouble(),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = stroke
          ..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction || old.color != color || old.glow != glow || old.track != track;
}
