import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_nova/game/board_geometry.dart';
import 'package:ludo_nova/game/ludo_engine.dart';

void main() {
  for (final arms in [4, 6]) {
    group('$arms-arm board', () {
      final geo = BoardGeometry.of(arms);
      final len = LudoEngine.trackLength(arms);

      test('consecutive track cells are neighbours', () {
        for (var i = 0; i < len; i++) {
          final d = geo.trackCell(i).distanceTo(geo.trackCell((i + 1) % len));
          expect(d, lessThan(1.5), reason: 'cells $i and ${i + 1}');
          expect(d, greaterThan(0.9));
        }
      });

      test('every track and home cell is unique', () {
        final seen = <String>{};
        String k(BoardPoint p) => '${(p.x * 100).round()}:${(p.y * 100).round()}';
        for (var i = 0; i < len; i++) {
          expect(seen.add(k(geo.trackCell(i))), isTrue);
        }
        for (var a = 0; a < arms; a++) {
          for (var h = 0; h < 5; h++) {
            expect(seen.add(k(geo.homeCell(a, h))), isTrue);
          }
        }
      });

      test('home column continues from the last track cell', () {
        for (var a = 0; a < arms; a++) {
          final last = geo.tokenPoint(arm: a, progress: LudoEngine.lastTrackProgress(arms), token: 0);
          final first = geo.tokenPoint(arm: a, progress: LudoEngine.lastTrackProgress(arms) + 1, token: 0);
          expect(last.distanceTo(first), closeTo(1, 0.01));
        }
      });

      test('bases stay clear of the arms and inside the extents', () {
        for (var b = 0; b < arms; b++) {
          final c = geo.baseCenter(b);
          expect(c.x.abs() + geo.baseHalfSize, lessThanOrEqualTo(geo.extentX));
          expect(c.y.abs() + geo.baseHalfSize, lessThanOrEqualTo(geo.extentY));
          for (var i = 0; i < len; i++) {
            final p = geo.trackCell(i);
            // Cells are 1 x 1, so their centres must be at least half a cell
            // outside the base shape.
            if (geo.isClassic) {
              final inside = (p.x - c.x).abs() < geo.baseHalfSize + 0.45 &&
                  (p.y - c.y).abs() < geo.baseHalfSize + 0.45;
              expect(inside, isFalse);
            } else {
              expect(p.distanceTo(c), greaterThan(geo.baseHalfSize + 0.45));
            }
          }
        }
      });

      test('pods split evenly above and below the board', () {
        expect(geo.topArms.length + geo.bottomArms.length, arms);
        expect(geo.topArms.length, arms ~/ 2);
        expect(geo.topArms.first, 0, reason: 'red sits top-left');
      });
    });
  }
}
