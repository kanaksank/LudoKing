// Board geometry in abstract "cell" units, centred on (0, 0), y pointing down
// (screen convention). Pure Dart: widgets scale these points to pixels.
//
// Every arm is drawn as if it pointed straight up and is then rotated into
// place. The centre is a regular polygon with side 3 (a square for the classic
// board, a hexagon for 5–6 players); arms attach to its edges and each home
// base sits in the wedge clockwise of its arm.

import 'dart:math' as math;

import 'ludo_engine.dart';

class BoardPoint {
  const BoardPoint(this.x, this.y);
  final double x;
  final double y;

  BoardPoint operator +(BoardPoint o) => BoardPoint(x + o.x, y + o.y);
  BoardPoint operator -(BoardPoint o) => BoardPoint(x - o.x, y - o.y);
  BoardPoint operator *(double f) => BoardPoint(x * f, y * f);
  double distanceTo(BoardPoint o) => math.sqrt((x - o.x) * (x - o.x) + (y - o.y) * (y - o.y));

  @override
  String toString() => '(${x.toStringAsFixed(2)}, ${y.toStringAsFixed(2)})';
}

class BoardGeometry {
  BoardGeometry(this.arms)
      : assert(arms == 4 || arms == 6),
        apothem = 3 / (2 * math.tan(math.pi / arms)) {
    _computeExtents();
  }

  static final Map<int, BoardGeometry> _cache = {};
  factory BoardGeometry.of(int arms) => _cache.putIfAbsent(arms, () => BoardGeometry(arms));

  final int arms;

  /// Distance from the centre to where the arms start.
  final double apothem;
  static const armLength = 6;

  late final double extentX;
  late final double extentY;

  bool get isClassic => arms == 4;

  /// Distance from the centre to each base's centre.
  double get baseDistance => isClassic ? 4.5 * math.sqrt2 : 7.6;

  /// Half side (classic, square base) or radius (hexagon, round base).
  double get baseHalfSize => isClassic ? 2.8 : 2.15;

  double armAngle(int k) => math.pi + 2 * math.pi * k / arms;
  double baseAngle(int k) => armAngle(k) + math.pi / arms;

  /// Rotation that turns an up-pointing arm into arm [k].
  double armRotation(int k) => armAngle(k) - 1.5 * math.pi;

  /// A point in arm [k]'s local frame: [u] sideways (-1.5..1.5), [w] outward
  /// distance from the centre.
  BoardPoint local(int k, double u, double w) {
    final t = armRotation(k);
    final x = u;
    final y = -w;
    return BoardPoint(
      x * math.cos(t) - y * math.sin(t),
      x * math.sin(t) + y * math.cos(t),
    );
  }

  BoardPoint polar(double angle, double r) => BoardPoint(r * math.cos(angle), r * math.sin(angle));

  /// Centre of the cell at [col] (-1, 0, 1) and [row] (0 = nearest centre).
  BoardPoint cellCenter(int k, int col, int row) => local(k, col.toDouble(), apothem + row + 0.5);

  /// Track local index 0..12 → (col, row). Clockwise: out along the left
  /// column, across the tip, back in along the right column.
  static (int, int) trackLocal(int i) {
    if (i <= 5) return (-1, i);
    if (i == 6) return (0, 5);
    return (1, 12 - i);
  }

  BoardPoint trackCell(int abs) {
    final k = abs ~/ LudoEngine.cellsPerArm;
    final (c, r) = trackLocal(abs % LudoEngine.cellsPerArm);
    return cellCenter(k, c, r);
  }

  /// Home column step 0..4 (0 = first cell after leaving the track).
  BoardPoint homeCell(int k, int step) => cellCenter(k, 0, 4 - step);

  BoardPoint baseCenter(int k) => polar(baseAngle(k), baseDistance);

  BoardPoint baseSlot(int k, int slot) {
    final c = baseCenter(k);
    final off = isClassic ? 1.15 : 0.95;
    const dirs = [(-1, -1), (1, -1), (-1, 1), (1, 1)];
    final (dx, dy) = dirs[slot % 4];
    return c + BoardPoint(dx * off, dy * off);
  }

  /// Where finished tokens rest inside the centre polygon.
  BoardPoint finishSpot(int k, int slot) => local(k, (slot - 1.5) * 0.38, apothem * 0.5);

  /// The two inner corners of arm [k] (they are centre polygon vertices).
  (BoardPoint, BoardPoint) innerCorners(int k) => (local(k, -1.5, apothem), local(k, 1.5, apothem));

  BoardPoint tokenPoint({required int arm, required int progress, required int token}) {
    final last = LudoEngine.lastTrackProgress(arms);
    final fin = LudoEngine.finishProgress(arms);
    if (progress < 0) return baseSlot(arm, token);
    if (progress <= last) return trackCell(LudoEngine.absoluteCell(arms, arm, progress));
    if (progress < fin) return homeCell(arm, progress - last - 1);
    return finishSpot(arm, token);
  }

  void _computeExtents() {
    var mx = 0.0;
    var my = 0.0;
    void add(double x, double y) {
      mx = math.max(mx, x.abs());
      my = math.max(my, y.abs());
    }

    for (var k = 0; k < arms; k++) {
      for (final u in const [-1.5, 1.5]) {
        for (final w in [apothem, apothem + armLength]) {
          final p = local(k, u, w);
          add(p.x, p.y);
        }
      }
      final c = baseCenter(k);
      add(c.x.abs() + baseHalfSize, c.y.abs() + baseHalfSize);
    }
    extentX = mx + 0.25;
    extentY = my + 0.25;
  }

  /// Base indices whose pods sit above the board, left to right.
  List<int> get topArms => _podArms((a) => math.sin(a) < 0);

  /// Base indices whose pods sit below the board, left to right.
  List<int> get bottomArms => _podArms((a) => math.sin(a) > 0);

  List<int> _podArms(bool Function(double angle) test) {
    final list = [
      for (var k = 0; k < arms; k++)
        if (test(baseAngle(k))) k,
    ];
    list.sort((a, b) => math.cos(baseAngle(a)).compareTo(math.cos(baseAngle(b))));
    return list;
  }
}
