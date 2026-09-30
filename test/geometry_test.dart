import 'dart:ui';

import 'package:cut_and_run/core/utils/geometry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final square = Geo.rectPoly(const Offset(0, 0), 100, 100);

  test('area and centroid of a square', () {
    expect(Geo.area(square), closeTo(10000, 1e-6));
    final c = Geo.centroid(square);
    expect(c.dx, closeTo(0, 1e-6));
    expect(c.dy, closeTo(0, 1e-6));
  });

  test('vertical split produces two equal halves that sum to the whole', () {
    final res = Geo.splitConvex(square, const Offset(0, -10), const Offset(0, 10));
    expect(res, isNotNull);
    final (a, b) = res!;
    expect(Geo.area(a), closeTo(5000, 1e-6));
    expect(Geo.area(b), closeTo(5000, 1e-6));
  });

  test('diagonal split keeps total area', () {
    final res = Geo.splitConvex(square, const Offset(-50, -50), const Offset(50, 50))!;
    expect(Geo.area(res.$1) + Geo.area(res.$2), closeTo(10000, 1e-6));
    expect(res.$1.length, 3);
  });

  test('a line missing the polygon does not split it', () {
    expect(Geo.splitConvex(square, const Offset(200, -10), const Offset(200, 10)), isNull);
  });

  test('point containment and chord clipping', () {
    expect(Geo.pointInConvex(const Offset(10, 10), square), isTrue);
    expect(Geo.pointInConvex(const Offset(60, 10), square), isFalse);
    final chord = Geo.clipLine(square, const Offset(-200, 0), const Offset(200, 0))!;
    expect((chord.$1 - chord.$2).distance, closeTo(100, 1e-6));
  });

  test('circle overlap tests', () {
    expect(Geo.circleIntersectsPolygon(const Offset(60, 0), 12, square), isTrue);
    expect(Geo.circleIntersectsPolygon(const Offset(70, 0), 12, square), isFalse);
    expect(Geo.circleIntersectsRect(const Offset(0, 0), 5, const Rect.fromLTWH(4, -1, 10, 2)), isTrue);
  });

  test('line angle difference is undirected', () {
    expect(Geo.lineAngleDiff(const Offset(0, 1), const Offset(0, -1)), closeTo(0, 1e-9));
    expect(Geo.lineAngleDiff(const Offset(1, 0), const Offset(0, 1)), closeTo(1.5708, 1e-3));
  });
}
