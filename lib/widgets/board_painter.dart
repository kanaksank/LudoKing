import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/app_tokens.dart';
import '../game/board_geometry.dart';
import '../game/ludo_engine.dart';

/// Paints the static board plus the optional path preview. Tokens are
/// separate widgets layered on top.
class BoardPainter extends CustomPainter {
  BoardPainter({
    required this.geo,
    required this.armColors,
    required this.surface,
    required this.safeStars,
    this.path = const [],
    this.pathColor,
    this.pulse = 0,
  });

  final BoardGeometry geo;

  /// Colour per arm, or null for an unused seat.
  final List<Color?> armColors;
  final SurfaceTokens surface;
  final bool safeStars;
  final List<BoardPoint> path;
  final Color? pathColor;

  /// 0..1, animates the destination ring.
  final double pulse;

  Color _arm(int k) => armColors[k] ?? LudoPalette.inactive;

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width / (2 * geo.extentX), size.height / (2 * geo.extentY));
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(s);

    _plate(canvas);
    for (var k = 0; k < geo.arms; k++) {
      _base(canvas, k);
    }
    for (var k = 0; k < geo.arms; k++) {
      _arms(canvas, k);
    }
    _centre(canvas);
    _markers(canvas);
    _path(canvas);

    canvas.restore();
  }

  void _plate(Canvas canvas) {
    final r = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: geo.extentX * 2, height: geo.extentY * 2),
      const Radius.circular(0.9),
    );
    canvas.drawRRect(r, Paint()..color = surface.boardPlate);
    canvas.drawRRect(
      r.deflate(0.04),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.08
        ..color = surface.shadowLight,
    );
  }

  void _base(Canvas canvas, int k) {
    final c = geo.baseCenter(k);
    final centre = Offset(c.x, c.y);
    final color = _arm(k);
    final h = geo.baseHalfSize;
    final active = armColors[k] != null;

    final gradient = RadialGradient(
      center: const Alignment(-0.4, -0.5),
      radius: 1.1,
      colors: [LudoPalette.shade(color, 0.12), color, LudoPalette.shade(color, -0.14)],
    );
    final outerRect = Rect.fromCircle(center: centre, radius: h);
    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.28)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.25);
    final fill = Paint()..shader = gradient.createShader(outerRect);
    final inner = Paint()..color = surface.tile;

    if (geo.isClassic) {
      final outer = RRect.fromRectAndRadius(outerRect, const Radius.circular(0.8));
      canvas.drawRRect(outer.shift(const Offset(0.1, 0.14)), shadow);
      canvas.drawRRect(outer, fill);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCircle(center: centre, radius: h * 0.72), const Radius.circular(0.6)),
        inner,
      );
    } else {
      canvas.drawCircle(centre.translate(0.1, 0.14), h, shadow);
      canvas.drawCircle(centre, h, fill);
      canvas.drawCircle(centre, h * 0.74, inner);
    }

    for (var slot = 0; slot < 4; slot++) {
      final p = geo.baseSlot(k, slot);
      final o = Offset(p.x, p.y);
      canvas.drawCircle(o, 0.42, Paint()..color = color.withValues(alpha: active ? 0.28 : 0.2));
      canvas.drawCircle(
        o,
        0.42,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.06
          ..color = color.withValues(alpha: 0.7),
      );
    }
  }

  void _arms(Canvas canvas, int k) {
    final color = _arm(k);
    canvas.save();
    canvas.rotate(geo.armRotation(k));
    final tile = Paint()..color = surface.tile;
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.035
      ..color = surface.tileBorder;
    for (var col = -1; col <= 1; col++) {
      for (var row = 0; row < BoardGeometry.armLength; row++) {
        final centre = Offset(col.toDouble(), -(geo.apothem + row + 0.5));
        final rect = RRect.fromRectAndRadius(
          Rect.fromCenter(center: centre, width: 0.94, height: 0.94),
          const Radius.circular(0.16),
        );
        var paint = tile;
        final isHome = col == 0 && row <= 4;
        final isStart = col == 1 && row == 4;
        if (isHome || isStart) {
          paint = Paint()
            ..shader = LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [LudoPalette.shade(color, 0.1), LudoPalette.shade(color, -0.06)],
            ).createShader(rect.outerRect);
        }
        canvas.drawRRect(rect, paint);
        canvas.drawRRect(rect, border);
      }
    }
    canvas.restore();
  }

  void _centre(Canvas canvas) {
    for (var k = 0; k < geo.arms; k++) {
      final (a, b) = geo.innerCorners(k);
      final path = Path()
        ..moveTo(0, 0)
        ..lineTo(a.x, a.y)
        ..lineTo(b.x, b.y)
        ..close();
      final color = _arm(k);
      final bounds = path.getBounds();
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            colors: [LudoPalette.shade(color, 0.1), LudoPalette.shade(color, -0.1)],
          ).createShader(bounds),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.04
          ..color = Colors.white.withValues(alpha: 0.55),
      );
    }
    canvas.drawCircle(Offset.zero, geo.apothem * 0.28, Paint()..color = Colors.white.withValues(alpha: 0.9));
    _star(canvas, Offset.zero, geo.apothem * 0.18, LudoPalette.gold);
  }

  void _markers(Canvas canvas) {
    final rules = GameRules(safeStars: safeStars);
    for (var k = 0; k < geo.arms; k++) {
      final startAbs = k * LudoEngine.cellsPerArm + LudoEngine.startLocal;
      final s = geo.trackCell(startAbs);
      _star(canvas, Offset(s.x, s.y), 0.3, Colors.white);
      if (LudoEngine.isSafeCell(k * LudoEngine.cellsPerArm + LudoEngine.starLocal, rules)) {
        final p = geo.trackCell(k * LudoEngine.cellsPerArm + LudoEngine.starLocal);
        _star(canvas, Offset(p.x, p.y), 0.3, const Color(0xFFB6BDCB));
      }
      // Arrow showing where the home column starts.
      final entry = geo.cellCenter(k, 0, 5);
      final inward = geo.cellCenter(k, 0, 4) - entry;
      _arrow(canvas, Offset(entry.x, entry.y), Offset(inward.x, inward.y), _arm(k));
    }
  }

  void _arrow(Canvas canvas, Offset at, Offset dir, Color color) {
    final len = dir.distance;
    if (len == 0) return;
    final d = dir / len;
    final n = Offset(-d.dy, d.dx);
    final tip = at + d * 0.28;
    final left = at - d * 0.18 + n * 0.22;
    final right = at - d * 0.18 - n * 0.22;
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(left.dx, left.dy)
      ..lineTo(right.dx, right.dy)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  void _star(Canvas canvas, Offset c, double r, Color color) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final rr = i.isEven ? r : r * 0.45;
      final a = -math.pi / 2 + i * math.pi / 5;
      final p = c + Offset(math.cos(a) * rr, math.sin(a) * rr);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(
      path.shift(const Offset(0.02, 0.03)),
      Paint()..color = Colors.black.withValues(alpha: 0.25),
    );
    canvas.drawPath(path, Paint()..color = color);
  }

  void _path(Canvas canvas) {
    if (path.isEmpty || pathColor == null) return;
    final c = pathColor!;
    final dot = Paint()..color = c.withValues(alpha: 0.55);
    for (var i = 0; i < path.length - 1; i++) {
      canvas.drawCircle(Offset(path[i].x, path[i].y), 0.16, dot);
    }
    final end = Offset(path.last.x, path.last.y);
    canvas.drawCircle(end, 0.44, Paint()..color = c.withValues(alpha: 0.25 + 0.15 * pulse));
    canvas.drawCircle(
      end,
      0.36 + 0.08 * pulse,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.08
        ..color = c,
    );
  }

  @override
  bool shouldRepaint(BoardPainter old) =>
      old.geo != geo ||
      old.surface != surface ||
      old.safeStars != safeStars ||
      old.pulse != pulse ||
      old.pathColor != pathColor ||
      !_samePath(old.path, path) ||
      !_sameColors(old.armColors, armColors);

  static bool _samePath(List<BoardPoint> a, List<BoardPoint> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].x != b[i].x || a[i].y != b[i].y) return false;
    }
    return true;
  }

  static bool _sameColors(List<Color?> a, List<Color?> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
