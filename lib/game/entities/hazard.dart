import 'dart:math' as math;
import 'dart:ui';

import '../../core/utils/geometry.dart';

const double kTrackWidth = 400;

enum HazardKind {
  spikes,
  wall,
  movingWall,
  rotatingBar,
  crusher,
  laser,
  pit,
  pendulum,
  saw,
  timingDoor,
  collapsingFloor,
  pushBlock,
  platformPit,
}

const hazardNames = <HazardKind, String>{
  HazardKind.spikes: 'spikes',
  HazardKind.wall: 'a wall',
  HazardKind.movingWall: 'a moving wall',
  HazardKind.rotatingBar: 'a rotating bar',
  HazardKind.crusher: 'a crusher',
  HazardKind.laser: 'a laser',
  HazardKind.pit: 'a pit',
  HazardKind.pendulum: 'a swinging blade',
  HazardKind.saw: 'a spinning saw',
  HazardKind.timingDoor: 'a timing door',
  HazardKind.collapsingFloor: 'a collapsing floor',
  HazardKind.pushBlock: 'a piston',
  HazardKind.platformPit: 'a gap',
};

sealed class HShape {
  const HShape();
  bool hits(Offset c, double r);
  double distance(Offset c);
}

class HRect extends HShape {
  const HRect(this.rect);
  final Rect rect;
  @override
  bool hits(Offset c, double r) => Geo.circleIntersectsRect(c, r, rect);
  @override
  double distance(Offset c) => Geo.distanceToRect(c, rect);
}

class HCircle extends HShape {
  const HCircle(this.center, this.radius);
  final Offset center;
  final double radius;
  @override
  bool hits(Offset c, double r) => (c - center).distance <= r + radius;
  @override
  double distance(Offset c) => math.max(0, (c - center).distance - radius);
}

class HCapsule extends HShape {
  const HCapsule(this.a, this.b, this.radius);
  final Offset a;
  final Offset b;
  final double radius;
  @override
  bool hits(Offset c, double r) => Geo.distanceToSegment(c, a, b) <= r + radius;
  @override
  double distance(Offset c) => math.max(0, Geo.distanceToSegment(c, a, b) - radius);
}

/// Non-cuttable obstacle with deterministic, time-based behaviour so every
/// hazard is readable and predictable.
class Hazard {
  Hazard({
    required this.kind,
    required this.x,
    required this.y,
    this.w = 80,
    this.h = 40,
    this.amp = 0,
    this.freq = 1,
    this.phase = 0,
    this.gap = 110,
    this.rowMasks = const [],
  });

  final HazardKind kind;
  final double x;
  final double y;
  final double w;
  final double h;
  final double amp;
  final double freq;
  final double phase;
  final double gap;

  /// Collapsing floor: bitmask per 80-unit row of which of the 5 tiles collapse.
  final List<int> rowMasks;

  final List<HShape> shapes = [];
  final List<Rect> pits = [];
  final List<Rect> safe = [];

  // Render/state helpers.
  double angle = 0;
  double openness = 1;
  Offset bob = Offset.zero;
  Offset sawCenter = Offset.zero;
  bool laserOn = false;
  bool laserLeftOn = true;
  bool laserWarn = false;
  double extension = 0;
  double platformX = 0;
  double triggerTime = -1;
  final List<double> tileState = [];

  // Perfect-dodge tracking.
  double minDist = double.infinity;
  bool resolved = false;

  double get extentBack {
    switch (kind) {
      case HazardKind.rotatingBar:
        return w / 2 + 10;
      case HazardKind.pendulum:
        return 30;
      case HazardKind.collapsingFloor:
        return 0;
      default:
        return h / 2;
    }
  }

  double get extentFront {
    switch (kind) {
      case HazardKind.rotatingBar:
        return w / 2 + 10;
      case HazardKind.pendulum:
        return amp + 30;
      case HazardKind.collapsingFloor:
        return rowMasks.length * 80.0;
      default:
        return h / 2;
    }
  }

  bool get isFallHazard =>
      kind == HazardKind.pit || kind == HazardKind.collapsingFloor || kind == HazardKind.platformPit;

  String get label => hazardNames[kind]!;

  void update(double t, double playerY) {
    shapes.clear();
    pits.clear();
    safe.clear();
    final tt = freq * t + phase;
    switch (kind) {
      case HazardKind.spikes:
      case HazardKind.wall:
        shapes.add(HRect(Rect.fromCenter(center: Offset(x, y), width: w, height: h)));
      case HazardKind.movingWall:
        final cx = x + amp * math.sin(tt);
        shapes.add(HRect(Rect.fromCenter(center: Offset(cx, y), width: w, height: h)));
      case HazardKind.rotatingBar:
        angle = tt;
        final d = Offset(math.cos(angle), math.sin(angle)) * (w / 2);
        final c = Offset(x, y);
        shapes.add(HCapsule(c - d, c + d, 9));
        shapes.add(HCircle(c, 13));
      case HazardKind.crusher:
        // Mostly open, snaps down to a narrow (still passable) slot each cycle.
        final s = math.sin(tt);
        openness = 0.4 + 0.6 * ((s + 0.35) / 0.9).clamp(0.0, 1.0);
        final half = gap / 2 * openness;
        final top = y - h / 2, bottom = y + h / 2;
        shapes.add(HRect(Rect.fromLTRB(-20, top, x - half, bottom)));
        shapes.add(HRect(Rect.fromLTRB(x + half, top, kTrackWidth + 20, bottom)));
      case HazardKind.laser:
        // Two half-width beams alternate, so one side is always safe.
        // Each beam blinks a warning before it fires.
        final cycle = (tt / (2 * math.pi)) % 1.0;
        laserLeftOn = cycle < 0.5;
        laserOn = true;
        laserWarn = laserLeftOn ? cycle >= 0.3 : cycle >= 0.8;
        final half = laserLeftOn
            ? Rect.fromLTRB(0, y - 5, kTrackWidth / 2, y + 5)
            : Rect.fromLTRB(kTrackWidth / 2, y - 5, kTrackWidth, y + 5);
        shapes.add(HRect(half));
      case HazardKind.pit:
        pits.add(Rect.fromCenter(center: Offset(x, y), width: w, height: h));
      case HazardKind.platformPit:
        pits.add(Rect.fromCenter(center: Offset(kTrackWidth / 2, y), width: kTrackWidth + 40, height: h));
        platformX = x + amp * math.sin(tt);
        safe.add(Rect.fromCenter(center: Offset(platformX, y), width: gap, height: h + 30));
      case HazardKind.pendulum:
        angle = 1.1 * math.sin(tt);
        final len = amp;
        bob = Offset(x + len * math.sin(angle), y + len - len * math.cos(angle));
        shapes.add(HCircle(bob, 22));
      case HazardKind.saw:
        sawCenter = Offset(x + amp * math.sin(tt), y);
        angle = t * 9;
        shapes.add(HCircle(sawCenter, w / 2));
      case HazardKind.timingDoor:
        // Two doors open and close in turn; one is always at least half open.
        openness = (math.sin(tt) + 1) / 2;
        final a = gap / 2 * openness;
        final b = gap / 2 * (1 - openness);
        final top = y - h / 2, bottom = y + h / 2;
        shapes.add(HRect(Rect.fromLTRB(-20, top, 100 - a, bottom)));
        shapes.add(HRect(Rect.fromLTRB(100 + a, top, 300 - b, bottom)));
        shapes.add(HRect(Rect.fromLTRB(300 + b, top, kTrackWidth + 20, bottom)));
      case HazardKind.pushBlock:
        final cycle = (tt / (2 * math.pi)) % 1.0;
        // Fast punch out, slow retract.
        extension = cycle < 0.15 ? cycle / 0.15 : (cycle < 0.45 ? 1 : math.max(0, 1 - (cycle - 0.45) / 0.4));
        final fromLeft = x < kTrackWidth / 2;
        final reach = extension * amp;
        final rect = fromLeft
            ? Rect.fromLTRB(-w + reach, y - h / 2, reach, y + h / 2)
            : Rect.fromLTRB(kTrackWidth - reach, y - h / 2, kTrackWidth + w - reach, y + h / 2);
        shapes.add(HRect(rect));
      case HazardKind.collapsingFloor:
        if (tileState.isEmpty) {
          tileState.addAll(List.filled(rowMasks.length * 5, 0));
        }
        if (triggerTime < 0 && playerY > y - 460) triggerTime = t;
        for (var r = 0; r < rowMasks.length; r++) {
          for (var c = 0; c < 5; c++) {
            final i = r * 5 + c;
            if (rowMasks[r] & (1 << c) == 0) continue;
            if (triggerTime >= 0) {
              // Rows crumble in sequence: crack (0..1) then drop.
              tileState[i] = ((t - triggerTime - r * 0.12) / 0.7).clamp(0.0, 1.0);
            }
            if (tileState[i] >= 1) {
              pits.add(Rect.fromLTWH(c * 80.0, y + r * 80.0, 80, 80));
            }
          }
        }
    }
  }

  /// Distance from the player to the nearest deadly shape (for perfect dodges).
  double distanceTo(Offset c) {
    var best = double.infinity;
    for (final s in shapes) {
      final d = s.distance(c);
      if (d < best) best = d;
    }
    return best;
  }
}
