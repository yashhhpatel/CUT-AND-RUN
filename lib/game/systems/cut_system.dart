import 'dart:math' as math;
import 'dart:ui';

import '../../core/theme/app_colors.dart';
import '../../core/utils/geometry.dart';
import '../effects/effects.dart';
import '../engine/game_events.dart';
import '../engine/game_world.dart';
import '../entities/body.dart';
import '../model/materials.dart';
import '../model/object_defs.dart';
import '../model/powerups.dart';

class TrailPoint {
  TrailPoint(this.pos, this.time);
  final Offset pos;
  final double time;
}

class _Stroke {
  _Stroke(this.last, {required this.mega});
  Offset last;
  final bool mega;
  bool dead = false;
  bool cutSomething = false;
  final Map<int, Offset> entered = {};
  final Set<int> rejected = {};
}

class _PendingChain {
  _PendingChain(this.center, this.due, this.depth);
  final Offset center;
  final double due;
  final int depth;
}

/// Outcome of a cut attempt, useful for tests and effects.
enum CutOutcome { split, cracked, deflected, tooSlow, missedSeam, ignored }

/// The signature system: turns swipes into cuts, splits convex bodies into
/// real polygon pieces and applies all gameplay consequences.
class CutSystem {
  CutSystem(this.world);

  final GameWorld world;

  /// Minimum swipe speed (logical px/s) for medium-resistance materials.
  static const double minMediumSpeed = 650;
  static const double seamDistTolerance = 16;
  static const double seamAngleTolerance = 0.30;

  _Stroke? _stroke;
  final List<TrailPoint> trail = [];
  final List<_PendingChain> _chains = [];
  final math.Random _rng = math.Random(99);
  double _autoTimer = 0;

  /// Visual beam for auto cutter / mega cut: (a, b, life).
  final List<(Offset, Offset, double)> beams = [];

  bool get stroking => _stroke != null;

  void begin(Offset p) {
    _stroke = _Stroke(p, mega: world.megaCharges > 0);
    trail.add(TrailPoint(p, world.time));
  }

  void move(Offset p, double screenSpeed) {
    final s = _stroke;
    if (s == null) return;
    trail.add(TrailPoint(p, world.time));
    if (!s.dead && (p - s.last).distanceSquared > 1) {
      _segment(s, s.last, p, screenSpeed);
    }
    s.last = p;
  }

  void end() {
    final s = _stroke;
    if (s != null && s.mega && s.cutSomething) {
      world.megaCharges = math.max(0, world.megaCharges - 1);
    }
    _stroke = null;
  }

  void _segment(_Stroke s, Offset q, Offset p, double speed) {
    var a = q, b = p;
    final dir = Geo.normalize(p - q);
    if (s.mega) {
      a = q - dir * 700;
      b = p + dir * 700;
      beams.add((a, b, 0.25));
    } else if (world.hasPower(PowerUpType.cutterBeam)) {
      a = q - dir * 90;
      b = p + dir * 90;
    }
    final seg = Rect.fromPoints(a, b).inflate(4);
    for (final body in List<Body>.of(world.bodies)) {
      if (body.removed || body.fall >= 0 || body.airTime > 0 || body.cutCooldown > 0) continue;
      if (!body.bounds.overlaps(seg)) continue;
      if (s.rejected.contains(body.id)) continue;
      final bInside = Geo.pointInConvex(b, body.poly);
      final entry = s.entered[body.id];
      if (entry != null) {
        if (!bInside) {
          s.entered.remove(body.id);
          _attempt(s, body, entry, b, speed);
        }
      } else if (Geo.segmentIntersectsPolygon(a, b, body.poly)) {
        if (bInside) {
          s.entered[body.id] = a;
        } else {
          _attempt(s, body, a, b, speed);
        }
      }
      if (s.dead) break;
    }
  }

  void _attempt(_Stroke s, Body body, Offset a, Offset b, double speed) {
    final outcome = attemptCut(body, a, b, speed: speed, mega: s.mega);
    switch (outcome) {
      case CutOutcome.split:
      case CutOutcome.cracked:
        s.cutSomething = true;
      case CutOutcome.deflected:
        s.dead = true;
        s.rejected.add(body.id);
      case CutOutcome.tooSlow:
      case CutOutcome.missedSeam:
        s.rejected.add(body.id);
      case CutOutcome.ignored:
        break;
    }
  }

  /// Applies a cut along the infinite line a-b to [body], honouring its
  /// resistance. Public so auto cutters, chains and tests share one path.
  CutOutcome attemptCut(Body body, Offset a, Offset b, {double speed = 99999, bool mega = false, bool auto = false}) {
    final def = body.def;
    final chord = Geo.clipLine(body.poly, a, b);
    if (chord == null) return CutOutcome.ignored;
    final mid = (chord.$1 + chord.$2) / 2;
    switch (def.cutResistance) {
      case CutResistance.uncuttable:
        _deflect(body, mid, 'BLOCKED');
        return CutOutcome.deflected;
      case CutResistance.reinforced:
        if (!mega && !_onSeam(body, a, b)) {
          _deflect(body, mid, 'CUT THE SEAM');
          return CutOutcome.missedSeam;
        }
      case CutResistance.medium:
        if (!mega && !auto && speed < minMediumSpeed) {
          world.particles.alongLine(chord.$1, chord.$2, materialStyles[def.material]!.light, count: 6);
          world.floatText('SWIPE FASTER', mid, AppColors.warning);
          world.emit(GameEventType.tooSlow);
          return CutOutcome.tooSlow;
        }
      case CutResistance.hard:
        if (!mega && body.hitsLeft > 1) {
          body.hitsLeft--;
          body.cracks.add(chord);
          body.flash = 1;
          body.cutCooldown = 0.12;
          world.particles.alongLine(chord.$1, chord.$2, const Color(0xFFFFE0A0), count: 10);
          world.camera.addShake(2);
          world.addScore(5);
          world.floatText('CRACK!', mid, AppColors.textMuted);
          world.emit(GameEventType.crack);
          return CutOutcome.cracked;
        }
      case CutResistance.soft:
        break;
    }
    return split(body, a, b, auto: auto) ? CutOutcome.split : CutOutcome.ignored;
  }

  bool _onSeam(Body body, Offset a, Offset b) {
    final sa = body.seamA, sb = body.seamB;
    if (sa == null || sb == null) return false;
    final tol = world.hasPower(PowerUpType.precisionCutter) ? 2.0 : 1.0;
    final seamMid = Offset.lerp(sa, sb, 0.5)!;
    final dist = Geo.distanceToLine(seamMid, a, b);
    final ang = Geo.lineAngleDiff(b - a, sb - sa);
    return dist <= seamDistTolerance * 1.3 * tol && ang <= seamAngleTolerance * 1.3 * tol;
  }

  void _deflect(Body body, Offset at, String text) {
    body.flash = 1;
    body.cutCooldown = 0.2;
    world.particles.emit(
        at: at, color: const Color(0xFFFFE9A8), kind: ParticleKind.spark, count: 12, speed: 260, life: 0.3, size: 2);
    world.floatText(text, at, AppColors.danger);
    world.camera.addShake(1.5);
    world.emit(GameEventType.deflect);
  }

  /// Splits [body] into two real polygon pieces along line a-b.
  bool split(Body body, Offset a, Offset b, {bool auto = false, bool chain = false, bool silent = false}) {
    final res = Geo.splitConvex(body.poly, a, b);
    if (res == null) return false;
    final chord = Geo.clipLine(body.poly, a, b) ?? (a, b);
    final (left, right) = res;
    final areaL = Geo.area(left), areaR = Geo.area(right);
    final ratio = math.min(areaL, areaR) / math.max(areaL, areaR);
    final style = materialStyles[body.def.material]!;

    var perfect = false;
    if (!auto && !chain && !silent) {
      if (body.seamA != null) {
        perfect = _onSeam(body, a, b);
      } else {
        final threshold = world.hasPower(PowerUpType.precisionCutter) ? 0.62 : 0.8;
        perfect = ratio >= threshold && body.area >= 2400;
      }
    }

    world.removeBody(body, RemoveReason.split);
    final d = Geo.normalize(b - a);
    final n = Geo.perp(d);
    final small = body.area < 7000;
    for (final (poly, sign) in [(left, 1.0), (right, -1.0)]) {
      final piece = Body(
        id: world.nextId(),
        def: body.def,
        poly: poly,
        groupId: body.groupId,
        generation: body.generation + 1,
        isPiece: true,
        hitsLeft: 1,
      );
      final sep = (small ? 95.0 : 80.0) + _rng.nextDouble() * 25;
      piece.vel = body.vel * 0.4 + n * (sign * sep) + d * ((_rng.nextDouble() - 0.5) * 50);
      piece.spin = sign * (0.9 + _rng.nextDouble() * 1.4) * (small ? 1.4 : 1.0);
      piece.flash = 1;
      piece.cutCooldown = 0.1;
      world.addBody(piece);
    }

    if (!silent) {
      world.particles.alongLine(chord.$1, chord.$2, style.light, count: chain ? 8 : 14);
      world.particles.emit(
        at: (chord.$1 + chord.$2) / 2,
        color: style.interior,
        kind: ParticleKind.debris,
        count: chain ? 5 : 9,
        speed: 170,
        life: 0.6,
        size: 5,
      );
      if (!auto && !chain) world.hitStop = perfect ? 0.07 : 0.045;
      world.camera.addShake(perfect ? 3.5 : 2.2);
      if (perfect || body.area > 9000) world.camera.punch(0.018);
      world.onCut(body, perfect: perfect, auto: auto, chain: chain, at: (chord.$1 + chord.$2) / 2);
    }

    switch (body.def.splitBehavior) {
      case SplitBehavior.chain:
        if (!silent) _chains.add(_PendingChain(body.center, world.time + 0.12, chain ? 1 : 0));
      case SplitBehavior.reveal:
        if (!silent) world.revealMystery(body.center);
      case SplitBehavior.relic:
        if (!body.isPiece && !silent) world.onRelicBroken(body.center);
      case SplitBehavior.shatter:
        if (body.generation == 0) {
          // Shatter each half into smaller shards.
          for (final piece in world.bodies.where((p) => p.groupId == body.groupId && !p.removed).toList()) {
            final c = piece.center;
            final ang = _rng.nextDouble() * math.pi;
            split(piece, c, c + Offset(math.cos(ang), math.sin(ang)), silent: true);
          }
        }
      case SplitBehavior.normal:
        break;
    }
    return true;
  }

  void update(double dt) {
    // Trail fades after 0.2s.
    trail.removeWhere((t) => world.time - t.time > 0.2);
    for (var i = beams.length - 1; i >= 0; i--) {
      final (a, b, life) = beams[i];
      if (life - dt <= 0) {
        beams.removeAt(i);
      } else {
        beams[i] = (a, b, life - dt);
      }
    }
    _processChains();
    if (world.hasPower(PowerUpType.autoCutter)) {
      _autoTimer -= dt;
      if (_autoTimer <= 0) _autoCut();
    }
  }

  void _processChains() {
    if (_chains.isEmpty) return;
    final due = _chains.where((c) => c.due <= world.time).toList();
    for (final c in due) {
      _chains.remove(c);
      const radius = 175.0;
      var hits = 0;
      world.particles.ring(c.center, AppColors.accent, size: radius, life: 0.35);
      for (final body in List<Body>.of(world.bodies)) {
        if (body.removed || body.airTime > 0 || body.fall >= 0) continue;
        final r = body.def.cutResistance;
        if (r == CutResistance.uncuttable || r == CutResistance.reinforced) continue;
        if (body.isRelicWhole) continue;
        final off = body.center - c.center;
        if (off.distance > radius || off.distance < 1) continue;
        if (body.collectible) continue;
        final dir = Geo.normalize(off);
        if (split(body, body.center, body.center + dir, chain: true)) {
          hits++;
          world.particles.alongLine(c.center, body.center, AppColors.accent, count: 5);
        }
      }
      world.onChain(c.center, hits);
    }
  }

  void _autoCut() {
    final p = world.player;
    Body? target;
    var best = double.infinity;
    for (final body in world.bodies) {
      if (!body.solid || !body.def.cuttable) continue;
      if (body.def.cutResistance == CutResistance.reinforced || body.isRelicWhole) continue;
      final dy = body.center.dy - p.y;
      if (dy < 40 || dy > 280) continue;
      if ((body.center.dx - p.x).abs() > 110 + body.bounds.width / 2) continue;
      if (dy < best) {
        best = dy;
        target = body;
      }
    }
    if (target == null) {
      _autoTimer = 0.08;
      return;
    }
    final c = target.center;
    final vertical = target.generation.isEven;
    final dir = vertical ? const Offset(0, 1) : const Offset(1, 0);
    beams.add((Offset(p.x, p.y), c, 0.15));
    if (target.def.cutResistance == CutResistance.hard) target.hitsLeft = 1;
    attemptCut(target, c - dir, c + dir, auto: true);
    _autoTimer = 0.22;
  }

  void reset() {
    _stroke = null;
    trail.clear();
    _chains.clear();
    beams.clear();
  }
}
