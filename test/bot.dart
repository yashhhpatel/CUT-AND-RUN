import 'dart:ui';

import 'package:cut_and_run/game/engine/game_world.dart';
import 'package:cut_and_run/game/entities/body.dart';
import 'package:cut_and_run/game/entities/gate.dart';
import 'package:cut_and_run/game/entities/hazard.dart';
import 'package:cut_and_run/game/entities/player.dart';
import 'package:cut_and_run/game/model/object_defs.dart';

/// A simple scripted player used to smoke-test generated levels: it cuts
/// whatever blocks its lane and steers towards the safest column.
class Bot {
  Bot(this.w, {this.greedy = false});
  final GameWorld w;

  /// Greedy bots also slice off-lane objects and chase coins when safe.
  final bool greedy;

  void step() {
    _cut();
    _steer();
  }

  void _cut() {
    final p = w.player;
    Body? target;
    for (final b in w.bodies) {
      if (!b.solid || !b.def.cuttable || b.cutCooldown > 0 || b.isRelicWhole) continue;
      final ahead = b.center.dy - p.y;
      if (ahead < 20 || ahead > 420) continue;
      final inLane = !(b.bounds.right < p.x - 60 || b.bounds.left > p.x + 60);
      // Off-lane objects can be sliced too (for shards/objectives), a bit later.
      if (!inLane && (!greedy || ahead > 300)) continue;
      if (target == null || b.center.dy < target.center.dy) target = b;
    }
    if (target == null) return;
    final c = target.center;
    Offset a, b;
    if (target.seamA != null) {
      a = target.seamA!;
      b = target.seamB!;
    } else if (target.bounds.width >= target.bounds.height) {
      a = c + const Offset(0, -300);
      b = c + const Offset(0, 300);
    } else {
      a = c + const Offset(-300, 0);
      b = c + const Offset(300, 0);
    }
    w.cutter.attemptCut(target, a, b, speed: 3000);
  }

  double _danger(double x) {
    final p = w.player;
    var cost = 0.0;
    for (var dy = 0.0; dy <= 240; dy += 20) {
      final pt = Offset(x, p.y + dy);
      final weight = dy < 120 ? 3.0 : 1.0;
      for (final h in w.hazards) {
        if (h.y + h.extentFront < p.y - 20 || h.y - h.extentBack > p.y + 260) continue;
        // Predict where the hazard will be when the runner gets there.
        final f = _future(h, w.time + dy / w.speed);
        for (final s in f.shapes) {
          if (s.hits(pt, Player.radius + 8)) cost += 100 * weight;
        }
        if (h.kind == HazardKind.collapsingFloor) {
          for (var r = 0; r < h.rowMasks.length; r++) {
            for (var c = 0; c < 5; c++) {
              if (h.rowMasks[r] & (1 << c) == 0) continue;
              if (Rect.fromLTWH(c * 80.0, h.y + r * 80.0, 80, 80).inflate(10).contains(pt)) cost += 100 * weight;
            }
          }
        } else if (f.pits.any((r) => r.inflate(14).contains(pt)) && !f.safe.any((r) => r.deflate(12).contains(pt))) {
          cost += 100 * weight;
        }
      }
      for (final b in w.bodies) {
        if (!b.solid) continue;
        if (b.def.cuttable && b.def.cutResistance != CutResistance.reinforced) continue;
        if (b.bounds.inflate(Player.radius + 6).contains(pt)) cost += 100 * weight;
      }
    }
    for (final g in w.gates) {
      if (g.resolved || g.y < p.y || g.y > p.y + 300) continue;
      for (final o in g.options) {
        if (x >= o.x0 && x < o.x1 && o.type == GateType.subtract) cost += 60;
        if (x >= o.x0 && x < o.x1 && o.type == GateType.quantity && w.carry.shards < o.value) cost += 60;
      }
    }
    return cost;
  }

  Hazard _future(Hazard h, double t) {
    if (h.kind == HazardKind.collapsingFloor) return h;
    final f =
        Hazard(kind: h.kind, x: h.x, y: h.y, w: h.w, h: h.h, amp: h.amp, freq: h.freq, phase: h.phase, gap: h.gap);
    f.update(t, w.player.y);
    return f;
  }

  void _steer() {
    final p = w.player;
    var best = p.targetX;
    var bestCost = double.infinity;
    for (var x = 30.0; x <= 370; x += 10) {
      var cost = _danger(x) + (x - p.x).abs() * 0.05;
      if (greedy) {
        for (final c in w.pickups) {
          if (c.collected) continue;
          final ahead = c.pos.dy - p.y;
          if (ahead > 0 && ahead < 260 && (c.pos.dx - x).abs() < 24) cost -= 8;
        }
        for (final b in w.bodies) {
          if (!b.collectible) continue;
          final ahead = b.center.dy - p.y;
          if (ahead > 0 && ahead < 200 && (b.center.dx - x).abs() < 30) cost -= 4;
        }
      }
      if (cost < bestCost) {
        bestCost = cost;
        best = x;
      }
    }
    p.targetX = best;
  }
}
