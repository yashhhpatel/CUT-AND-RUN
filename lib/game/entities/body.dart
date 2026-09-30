import 'dart:math' as math;
import 'dart:ui';

import '../../core/utils/geometry.dart';
import '../model/object_defs.dart';

enum RemoveReason { none, collected, split, lost, destroyed }

/// A cuttable object or one of its pieces. Pieces are full gameplay objects:
/// they slide, spin, fall off edges, block the player or get collected.
class Body {
  Body({
    required this.id,
    required this.def,
    required List<Offset> poly,
    required this.groupId,
    this.generation = 0,
    this.isPiece = false,
    int? hitsLeft,
  })  : _poly = poly,
        hitsLeft = hitsLeft ?? def.durability {
    _recompute();
  }

  final int id;
  final ObjectDef def;
  final int groupId;
  final int generation;
  final bool isPiece;

  List<Offset> _poly;
  List<Offset> get poly => _poly;

  int hitsLeft;
  Offset vel = Offset.zero;
  double spin = 0;
  double friction = 3.4;

  /// Cracks from hits on hard objects (world coords, move with the body).
  final List<(Offset, Offset)> cracks = [];

  /// Weak seam / precision target line.
  Offset? seamA;
  Offset? seamB;

  /// True when the seam is only a bonus target (cuts elsewhere still work).
  bool seamIsTarget = false;

  // Sideways oscillation for moving objects.
  double moveAmp = 0;
  double moveFreq = 0;
  double movePhase = 0;
  double _lastMove = 0;

  /// Constant drift (rolling logs roll towards the player).
  double driftVy = 0;

  /// Falling objects: >0 while in the air, not solid until they land.
  double airTime = 0;
  bool pendingDrop = false;

  double cutCooldown = 0;
  double flash = 0;
  double age = 0;

  /// >= 0 while falling off the track edge (0..1 progress).
  double fall = -1;
  bool removed = false;
  RemoveReason removeReason = RemoveReason.none;

  /// Magnet pull target.
  bool magnetized = false;

  late double area;
  late Offset center;
  late Rect bounds;

  void _recompute() {
    area = Geo.area(_poly);
    center = Geo.centroid(_poly);
    bounds = Geo.bounds(_poly);
  }

  void setPoly(List<Offset> p) {
    _poly = p;
    _recompute();
  }

  bool get isRelicWhole => def.splitBehavior == SplitBehavior.relic && !isPiece;

  bool get collectible {
    if (removed || fall >= 0 || airTime > 0) return false;
    if (isRelicWhole) return true;
    if (!isPiece) return false;
    return area <= kCollectArea || def.splitBehavior == SplitBehavior.shatter;
  }

  bool get solid => !removed && fall < 0 && airTime <= 0 && !collectible;

  bool get moving => moveAmp > 0 || driftVy != 0;

  void translate(Offset d) {
    if (d == Offset.zero) return;
    _poly = [for (final p in _poly) p + d];
    center += d;
    bounds = bounds.shift(d);
    if (seamA != null) {
      seamA = seamA! + d;
      seamB = seamB! + d;
    }
    for (var i = 0; i < cracks.length; i++) {
      cracks[i] = (cracks[i].$1 + d, cracks[i].$2 + d);
    }
  }

  void rotate(double angle) {
    if (angle == 0) return;
    final pivot = center;
    _poly = Geo.rotateAround(_poly, pivot, angle);
    if (seamA != null) {
      final s = Geo.rotateAround([seamA!, seamB!], pivot, angle);
      seamA = s[0];
      seamB = s[1];
    }
    for (var i = 0; i < cracks.length; i++) {
      final c = Geo.rotateAround([cracks[i].$1, cracks[i].$2], pivot, angle);
      cracks[i] = (c[0], c[1]);
    }
    bounds = Geo.bounds(_poly);
  }

  /// Advances motion. [t] is world time.
  void update(double dt, double t) {
    age += dt;
    if (cutCooldown > 0) cutCooldown -= dt;
    if (flash > 0) flash = math.max(0, flash - dt * 3);
    if (airTime > 0) {
      airTime = math.max(0, airTime - dt);
    }
    if (moveAmp > 0) {
      final m = moveAmp * math.sin(moveFreq * t + movePhase);
      translate(Offset(m - _lastMove, 0));
      _lastMove = m;
    }
    if (driftVy != 0) translate(Offset(0, driftVy * dt));
    if (vel != Offset.zero) {
      translate(vel * dt);
      final k = math.exp(-friction * dt);
      vel = vel * k;
      if (vel.distanceSquared < 1) vel = Offset.zero;
    }
    if (spin != 0) {
      rotate(spin * dt);
      spin *= math.exp(-2.4 * dt);
      if (spin.abs() < 0.02) spin = 0;
    }
    if (fall >= 0) fall += dt * 2.2;
  }

  /// Initialises oscillation so the current position is the centre of motion.
  void startMoving(double amp, double freq, double phase, double t) {
    moveAmp = amp;
    moveFreq = freq;
    movePhase = phase;
    _lastMove = amp * math.sin(freq * t + phase);
    translate(Offset(_lastMove, 0));
  }

  void stopMoving() {
    moveAmp = 0;
    driftVy = 0;
  }
}
