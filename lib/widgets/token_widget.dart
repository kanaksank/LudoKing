import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/app_tokens.dart';

/// A shiny 3D-style pawn. Movable pawns bounce gently.
class TokenWidget extends StatefulWidget {
  const TokenWidget({
    super.key,
    required this.color,
    required this.size,
    this.movable = false,
    this.selected = false,
    this.safeBadge = false,
    this.onTap,
  });

  final Color color;
  final double size;
  final bool movable;
  final bool selected;
  final bool safeBadge;
  final VoidCallback? onTap;

  @override
  State<TokenWidget> createState() => _TokenWidgetState();
}

class _TokenWidgetState extends State<TokenWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 720),
  );

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(TokenWidget old) {
    super.didUpdateWidget(old);
    if (old.movable != widget.movable || old.selected != widget.selected) _sync();
  }

  void _sync() {
    if (widget.movable || widget.selected) {
      if (!_c.isAnimating) _c.repeat(reverse: true);
    } else {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    return Semantics(
      button: widget.onTap != null,
      label: widget.movable ? 'Movable token' : 'Token',
      child: IgnorePointer(
        ignoring: widget.onTap == null,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, child) {
                final t = Curves.easeInOut.transform(_c.value);
                final lift = widget.movable ? -size * 0.14 * t : 0.0;
                final glow = widget.movable || widget.selected ? 0.35 + 0.35 * t : 0.0;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    if (glow > 0)
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: (widget.selected ? Colors.white : widget.color)
                                    .withValues(alpha: glow),
                                blurRadius: size * 0.45,
                                spreadRadius: size * 0.06,
                              ),
                            ],
                          ),
                        ),
                      ),
                    Positioned.fill(
                      child: Transform.translate(
                        offset: Offset(0, lift),
                        child: CustomPaint(
                          painter: _PawnPainter(
                            color: widget.color,
                            lift: -lift / size,
                            ring: widget.selected,
                          ),
                        ),
                      ),
                    ),
                    if (widget.safeBadge)
                      Positioned(
                        right: -size * 0.08,
                        top: -size * 0.1 + lift,
                        child: Container(
                          width: size * 0.42,
                          height: size * 0.42,
                          decoration: BoxDecoration(
                            color: LudoPalette.gold,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: math.max(1.0, size * 0.04)),
                          ),
                          child: Icon(Icons.star_rounded, size: size * 0.3, color: Colors.white),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _PawnPainter extends CustomPainter {
  _PawnPainter({required this.color, required this.lift, required this.ring});

  final Color color;
  final double lift;
  final bool ring;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final c = Offset(w / 2, w / 2);
    final r = w * 0.4;

    // Ground shadow shrinks as the pawn lifts.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w / 2, w * 0.86 + lift * w),
        width: w * (0.7 - lift),
        height: w * 0.2,
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.3 - lift)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.04),
    );

    final body = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.45),
          radius: 0.95,
          colors: [
            LudoPalette.shade(color, 0.22),
            color,
            LudoPalette.shade(color, -0.2),
          ],
          stops: const [0, 0.55, 1],
        ).createShader(body),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * (ring ? 0.1 : 0.07)
        ..color = Colors.white,
    );
    // Inner crown dimple.
    canvas.drawCircle(c, r * 0.42, Paint()..color = LudoPalette.shade(color, -0.12));
    canvas.drawCircle(c, r * 0.18, Paint()..color = Colors.white.withValues(alpha: 0.9));
    // Specular highlight.
    canvas.drawOval(
      Rect.fromCenter(center: c + Offset(-r * 0.32, -r * 0.45), width: r * 0.7, height: r * 0.36),
      Paint()..color = Colors.white.withValues(alpha: 0.55),
    );
  }

  @override
  bool shouldRepaint(_PawnPainter old) => old.color != color || old.lift != lift || old.ring != ring;
}
