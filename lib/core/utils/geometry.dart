import 'dart:math' as math;
import 'dart:ui';

/// Small, allocation-light 2D helpers used by the cutting and collision systems.
/// All polygons are convex and wound consistently (any direction).
abstract final class Geo {
  static double cross(Offset a, Offset b) => a.dx * b.dy - a.dy * b.dx;
  static double dot(Offset a, Offset b) => a.dx * b.dx + a.dy * b.dy;

  static double signedArea(List<Offset> poly) {
    var s = 0.0;
    for (var i = 0; i < poly.length; i++) {
      final a = poly[i];
      final b = poly[(i + 1) % poly.length];
      s += a.dx * b.dy - b.dx * a.dy;
    }
    return s / 2;
  }

  static double area(List<Offset> poly) => signedArea(poly).abs();

  static Offset centroid(List<Offset> poly) {
    final a = signedArea(poly);
    if (a.abs() < 1e-6) {
      var sx = 0.0, sy = 0.0;
      for (final p in poly) {
        sx += p.dx;
        sy += p.dy;
      }
      return Offset(sx / poly.length, sy / poly.length);
    }
    var cx = 0.0, cy = 0.0;
    for (var i = 0; i < poly.length; i++) {
      final p = poly[i];
      final q = poly[(i + 1) % poly.length];
      final f = p.dx * q.dy - q.dx * p.dy;
      cx += (p.dx + q.dx) * f;
      cy += (p.dy + q.dy) * f;
    }
    return Offset(cx / (6 * a), cy / (6 * a));
  }

  static Rect bounds(List<Offset> poly) {
    var minX = double.infinity, minY = double.infinity;
    var maxX = -double.infinity, maxY = -double.infinity;
    for (final p in poly) {
      if (p.dx < minX) minX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy > maxY) maxY = p.dy;
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  static bool pointInConvex(Offset p, List<Offset> poly) {
    var sign = 0;
    for (var i = 0; i < poly.length; i++) {
      final a = poly[i];
      final b = poly[(i + 1) % poly.length];
      final c = cross(b - a, p - a);
      if (c.abs() < 1e-9) continue;
      final s = c > 0 ? 1 : -1;
      if (sign == 0) {
        sign = s;
      } else if (s != sign) {
        return false;
      }
    }
    return true;
  }

  /// Intersection point of segments p1-p2 and q1-q2, or null.
  static Offset? segmentIntersection(Offset p1, Offset p2, Offset q1, Offset q2) {
    final r = p2 - p1;
    final s = q2 - q1;
    final denom = cross(r, s);
    if (denom.abs() < 1e-9) return null;
    final t = cross(q1 - p1, s) / denom;
    final u = cross(q1 - p1, r) / denom;
    if (t < 0 || t > 1 || u < 0 || u > 1) return null;
    return p1 + r * t;
  }

  static bool segmentIntersectsPolygon(Offset a, Offset b, List<Offset> poly) {
    if (pointInConvex(a, poly) || pointInConvex(b, poly)) return true;
    for (var i = 0; i < poly.length; i++) {
      if (segmentIntersection(a, b, poly[i], poly[(i + 1) % poly.length]) != null) {
        return true;
      }
    }
    return false;
  }

  /// Returns the chord of [poly] cut by the infinite line through a-b, if any.
  static (Offset, Offset)? clipLine(List<Offset> poly, Offset a, Offset b) {
    final d = b - a;
    final len = d.distance;
    if (len < 1e-9) return null;
    final hits = <Offset>[];
    for (var i = 0; i < poly.length; i++) {
      final p = poly[i];
      final q = poly[(i + 1) % poly.length];
      final sp = cross(d, p - a) / len;
      final sq = cross(d, q - a) / len;
      // A vertex lying exactly on the line counts as a crossing point.
      if (sp.abs() < 1e-6) {
        hits.add(p);
      } else if ((sp > 0 && sq < -1e-6) || (sp < 0 && sq > 1e-6)) {
        final t = sp / (sp - sq);
        hits.add(p + (q - p) * t);
      }
    }
    if (hits.length < 2) return null;
    // Use the two most distant hits as the chord.
    var best = 0.0;
    (Offset, Offset)? chord;
    for (var i = 0; i < hits.length; i++) {
      for (var j = i + 1; j < hits.length; j++) {
        final dd = (hits[i] - hits[j]).distanceSquared;
        if (dd > best) {
          best = dd;
          chord = (hits[i], hits[j]);
        }
      }
    }
    if (best < 1) return null;
    return chord;
  }

  /// Splits a convex polygon by the infinite line through a-b.
  /// Returns null when the line does not properly divide the polygon.
  static (List<Offset>, List<Offset>)? splitConvex(List<Offset> poly, Offset a, Offset b) {
    final d = b - a;
    if (d.distanceSquared < 1e-9) return null;
    final left = <Offset>[];
    final right = <Offset>[];
    for (var i = 0; i < poly.length; i++) {
      final p = poly[i];
      final q = poly[(i + 1) % poly.length];
      final sp = cross(d, p - a);
      final sq = cross(d, q - a);
      if (sp >= 0) left.add(p);
      if (sp <= 0) right.add(p);
      if ((sp > 0 && sq < 0) || (sp < 0 && sq > 0)) {
        final t = sp / (sp - sq);
        final x = p + (q - p) * t;
        left.add(x);
        right.add(x);
      }
    }
    if (left.length < 3 || right.length < 3) return null;
    if (area(left) < 1 || area(right) < 1) return null;
    return (left, right);
  }

  static double distanceToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final len2 = ab.distanceSquared;
    if (len2 < 1e-9) return (p - a).distance;
    final t = (dot(p - a, ab) / len2).clamp(0.0, 1.0);
    return (p - (a + ab * t)).distance;
  }

  static double distanceToLine(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final len = ab.distance;
    if (len < 1e-9) return (p - a).distance;
    return cross(ab, p - a).abs() / len;
  }

  /// Circle-vs-convex-polygon overlap test.
  static bool circleIntersectsPolygon(Offset c, double r, List<Offset> poly) {
    if (pointInConvex(c, poly)) return true;
    for (var i = 0; i < poly.length; i++) {
      if (distanceToSegment(c, poly[i], poly[(i + 1) % poly.length]) <= r) return true;
    }
    return false;
  }

  static double distanceToPolygon(Offset c, List<Offset> poly) {
    if (pointInConvex(c, poly)) return 0;
    var best = double.infinity;
    for (var i = 0; i < poly.length; i++) {
      final d = distanceToSegment(c, poly[i], poly[(i + 1) % poly.length]);
      if (d < best) best = d;
    }
    return best;
  }

  static bool circleIntersectsRect(Offset c, double r, Rect rect) {
    final nx = c.dx.clamp(rect.left, rect.right);
    final ny = c.dy.clamp(rect.top, rect.bottom);
    final dx = c.dx - nx, dy = c.dy - ny;
    return dx * dx + dy * dy <= r * r;
  }

  static double distanceToRect(Offset c, Rect rect) {
    final nx = c.dx.clamp(rect.left, rect.right);
    final ny = c.dy.clamp(rect.top, rect.bottom);
    return (c - Offset(nx.toDouble(), ny.toDouble())).distance;
  }

  static List<Offset> rectPoly(Offset center, double w, double h) {
    final hw = w / 2, hh = h / 2;
    return [
      Offset(center.dx - hw, center.dy - hh),
      Offset(center.dx + hw, center.dy - hh),
      Offset(center.dx + hw, center.dy + hh),
      Offset(center.dx - hw, center.dy + hh),
    ];
  }

  static List<Offset> regularPoly(Offset center, double radius, int sides, [double rotation = 0]) {
    return List.generate(sides, (i) {
      final a = rotation + i * 2 * math.pi / sides;
      return Offset(center.dx + math.cos(a) * radius, center.dy + math.sin(a) * radius);
    });
  }

  static List<Offset> rotateAround(List<Offset> poly, Offset pivot, double angle) {
    final c = math.cos(angle), s = math.sin(angle);
    return [
      for (final p in poly)
        Offset(
          pivot.dx + (p.dx - pivot.dx) * c - (p.dy - pivot.dy) * s,
          pivot.dy + (p.dx - pivot.dx) * s + (p.dy - pivot.dy) * c,
        ),
    ];
  }

  /// Smallest angle between two undirected lines, in radians [0, pi/2].
  static double lineAngleDiff(Offset d1, Offset d2) {
    final a1 = math.atan2(d1.dy, d1.dx);
    final a2 = math.atan2(d2.dy, d2.dx);
    var diff = (a1 - a2).abs() % math.pi;
    if (diff > math.pi / 2) diff = math.pi - diff;
    return diff;
  }

  static Offset normalize(Offset v) {
    final d = v.distance;
    return d < 1e-9 ? Offset.zero : v / d;
  }

  static Offset perp(Offset v) => Offset(-v.dy, v.dx);
}
