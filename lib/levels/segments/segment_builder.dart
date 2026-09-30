import 'dart:math' as math;
import 'dart:ui';

import '../../core/theme/app_colors.dart';
import '../../game/entities/gate.dart';
import '../../game/entities/hazard.dart';
import '../../game/entities/pickup.dart';
import '../../game/model/object_defs.dart';
import '../../game/model/powerups.dart';
import '../models/level_config.dart';
import '../models/mechanics.dart';
import '../models/spawn.dart';

/// Content tallies used to derive fair objective targets.
class ContentTally {
  int cuttables = 0;
  int potentialShards = 0;
  int coins = 0;
  int gates = 0;
  int relics = 0;
  int mystery = 0;
  int energy = 0;
  int hazards = 0;
  int shieldPickups = 0;
  int seams = 0;
  int combineClusters = 0;
}

/// Builds reusable level segments into a spawn list. All randomness comes from
/// the supplied seeded [rng], so the same level always generates identically.
class SegmentBuilder {
  SegmentBuilder({
    required this.rng,
    required this.difficulty,
    required this.speed,
    required this.mechanics,
    required this.patterns,
  });

  final math.Random rng;
  final double difficulty;
  final double speed;
  final Set<Mechanic> mechanics;
  final LevelPatterns patterns;
  final List<Spawn> spawns = [];
  final ContentTally tally = ContentTally();

  static const lanes = [80.0, 200.0, 320.0];

  bool has(Mechanic m) => mechanics.contains(m);

  double get rowGap => speed * _lerp(1.55, 0.92, difficulty);

  static double _lerp(double a, double b, double t) => a + (b - a) * t.clamp(0.0, 1.0);

  double _range(double a, double b) => a + rng.nextDouble() * (b - a);

  T _pick<T>(List<T> list) => list[rng.nextInt(list.length)];

  double _lane() => lanes[rng.nextInt(3)] + _range(-14, 14);

  // ---------------------------------------------------------------- helpers

  void body(
    ObjectDef def,
    double x,
    double y, {
    double? width,
    double? height,
    double moveAmp = 0,
    double moveFreq = 0,
    double driftVy = 0,
    bool falling = false,
    SeamKind seam = SeamKind.none,
    bool seamIsTarget = false,
    bool asPiece = false,
    double angle = 0,
  }) {
    final w = width ?? def.size.width;
    final clampedX = moveAmp > 0 ? x : x.clamp(w / 2 + 4, kTrackWidth - w / 2 - 4).toDouble();
    spawns.add(BodySpawn(
      y: y,
      def: def,
      x: clampedX,
      width: width,
      height: height,
      moveAmp: moveAmp,
      moveFreq: moveFreq,
      movePhase: rng.nextDouble() * math.pi * 2,
      driftVy: driftVy,
      falling: falling,
      seam: seam,
      seamIsTarget: seamIsTarget,
      asPiece: asPiece,
      angle: angle,
    ));
    if (asPiece) {
      tally.potentialShards += def.value;
      return;
    }
    if (!def.cuttable) return;
    tally.cuttables++;
    final area = w * (height ?? def.size.height);
    final pieces = math.max(2, (area / (kCollectArea * 0.8)).ceil());
    tally.potentialShards += def.value * pieces;
    if (seam != SeamKind.none) tally.seams++;
    if (def.specialType == SpecialType.mystery) tally.mystery++;
    if (def.specialType == SpecialType.chain) tally.energy++;
    if (def.specialType == SpecialType.relic) tally.relics++;
  }

  void hazard(HazardSpawn h) {
    spawns.add(h);
    tally.hazards++;
  }

  void coin(double x, double y) {
    spawns.add(PickupSpawn(y: y, kind: PickupKind.coin, x: x));
    tally.coins++;
  }

  void coinLine(double x0, double y0, double x1, double y1, int n) {
    for (var i = 0; i < n; i++) {
      final t = n == 1 ? 0.0 : i / (n - 1);
      coin(x0 + (x1 - x0) * t, y0 + (y1 - y0) * t);
    }
  }

  void powerUp(PowerUpType type, double x, double y) {
    spawns.add(PickupSpawn(y: y, kind: PickupKind.powerUp, x: x, powerUp: type));
    if (type == PowerUpType.shield) tally.shieldPickups++;
  }

  void decal(String text, double x, double y, Color color) {
    spawns.add(DecalSpawn(y: y, text: text, x: x, color: color));
  }

  void gate(double y, List<GateOption> options) {
    spawns.add(GateSpawn(y: y, options: options));
    tally.gates++;
  }

  ObjectDef _regularObject() {
    final pool = patterns.objects;
    var total = 0.0;
    for (final d in pool) {
      total += _weight(d);
    }
    var r = rng.nextDouble() * total;
    for (final d in pool) {
      r -= _weight(d);
      if (r <= 0) return d;
    }
    return pool.last;
  }

  double _weight(ObjectDef d) {
    switch (d.rarity) {
      case Rarity.common:
        return 6;
      case Rarity.uncommon:
        return 3;
      case Rarity.rare:
        return 1.2;
      case Rarity.epic:
        return 0.5;
    }
  }

  SeamKind _seamKind() {
    if (has(Mechanic.diagonalSeam) && rng.nextDouble() < 0.4) {
      return rng.nextBool() ? SeamKind.diagonal : SeamKind.antiDiagonal;
    }
    return rng.nextDouble() < 0.7 ? SeamKind.vertical : SeamKind.horizontal;
  }

  // ------------------------------------------------------------- segments

  double build(SegmentType type, double y0) {
    switch (type) {
      case SegmentType.start:
        return _start(y0);
      case SegmentType.collection:
        return _collection(y0);
      case SegmentType.cut:
        return _cut(y0);
      case SegmentType.multiCut:
        return _multiCut(y0);
      case SegmentType.precisionCut:
        return _precision(y0);
      case SegmentType.obstacle:
        return _obstacle(y0);
      case SegmentType.gate:
        return _gate(y0);
      case SegmentType.riskReward:
        return _riskReward(y0);
      case SegmentType.combine:
        return _combine(y0);
      case SegmentType.powerUp:
        return _powerUp(y0);
      case SegmentType.challenge:
        return _challenge(y0);
      case SegmentType.reward:
        return _reward(y0);
      case SegmentType.finish:
        return _finish(y0);
    }
  }

  double _start(double y0) {
    coinLine(200, y0 + 260, 200, y0 + 420, 4);
    return 520;
  }

  double _collection(double y0) {
    const n = 10;
    final phase = rng.nextDouble() * math.pi;
    for (var i = 0; i < n; i++) {
      final y = y0 + 80 + i * 60;
      coin(200 + math.sin(phase + i * 0.55) * 120, y);
    }
    final y = y0 + 80 + n * 60 + rowGap * 0.6;
    body(_regularObject(), _lane(), y);
    return y - y0 + rowGap * 0.9;
  }

  double _cut(double y0) {
    final rows = 3 + (difficulty * 3).round() + rng.nextInt(2);
    var y = y0 + rowGap * 0.6;
    for (var r = 0; r < rows; r++) {
      final roll = rng.nextDouble();
      if (has(Mechanic.movingObjects) && roll < 0.22) {
        final def = _regularObject();
        body(def, 200, y, moveAmp: _range(60, 90 + 40 * difficulty), moveFreq: _range(1.1, 1.6 + difficulty));
      } else if (roll < 0.55 + difficulty * 0.2) {
        // Two blockers leave one open lane: dodge it or cut through.
        final open = rng.nextInt(3);
        for (var l = 0; l < 3; l++) {
          if (l == open) {
            if (rng.nextBool()) coinLine(lanes[l], y - 40, lanes[l], y + 40, 3);
            continue;
          }
          if (rng.nextDouble() < 0.75) body(_regularObject(), lanes[l] + _range(-8, 8), y);
        }
      } else {
        final def = _regularObject();
        final seam = has(Mechanic.precisionSeam) && rng.nextDouble() < 0.3;
        body(def, _lane(), y, seam: seam ? _seamKind() : SeamKind.none, seamIsTarget: true);
      }
      if (has(Mechanic.energyChain) && rng.nextDouble() < 0.12) {
        body(ObjectDefs.energyCell, lanes[rng.nextInt(3)], y + rowGap * 0.45);
      }
      y += rowGap;
    }
    return y - y0;
  }

  double _cutWall(double y, ObjectDef def) {
    // Three panels span the track; slice the one in your path.
    for (final x in [67.0, 200.0, 333.0]) {
      body(def, x, y, width: 128, height: def == ObjectDefs.metalCrate ? 64 : 56);
    }
    return y;
  }

  double _multiCut(double y0) {
    var y = y0 + rowGap * 0.6;
    final rows = 2 + (difficulty * 2).round();
    for (var r = 0; r < rows; r++) {
      final options = <int>[
        if (has(Mechanic.cutWall)) 0,
        if (has(Mechanic.multiCut)) 1,
        if (has(Mechanic.hardMetal)) 2,
        if (has(Mechanic.multiLayerWall)) 3,
      ];
      final choice = options.isEmpty ? 0 : _pick(options);
      switch (choice) {
        case 0:
          _cutWall(y, _pick([ObjectDefs.woodBlock, if (has(Mechanic.softVariety)) ObjectDefs.jelly]));
        case 1:
          body(ObjectDefs.bigCrate, _lane(), y);
          if (rng.nextBool()) coinLine(lanes[rng.nextInt(3)], y + 90, lanes[1], y + 160, 3);
        case 2:
          final open = rng.nextInt(3);
          for (var l = 0; l < 3; l++) {
            if (l != open) body(ObjectDefs.metalCrate, lanes[l], y);
          }
        case 3:
          _cutWall(y, ObjectDefs.woodBlock);
          y += rowGap * 0.6;
          _cutWall(y, has(Mechanic.hardMetal) ? ObjectDefs.metalCrate : ObjectDefs.jelly);
      }
      y += rowGap * 1.15;
    }
    return y - y0;
  }

  double _precision(double y0) {
    var y = y0 + rowGap * 0.6;
    final rows = 3 + (difficulty * 2).round();
    for (var r = 0; r < rows; r++) {
      final roll = rng.nextDouble();
      if (has(Mechanic.reinforced) && roll < 0.35) {
        body(ObjectDefs.steelSafe, _lane(), y, seam: _seamKind());
      } else if (has(Mechanic.cutWall) && roll < 0.6) {
        // Weak-point wall: pillars everywhere except one cuttable panel.
        final weak = rng.nextInt(5);
        for (var i = 0; i < 5; i++) {
          final x = 40.0 + i * 80;
          if (i == weak) {
            body(ObjectDefs.woodBlock, x, y, width: 76, height: 58, seam: SeamKind.vertical, seamIsTarget: true);
          } else {
            body(ObjectDefs.pillar, x, y, width: 74, height: 58);
          }
        }
      } else {
        body(_regularObject(), _lane(), y, seam: _seamKind(), seamIsTarget: true);
      }
      y += rowGap;
    }
    return y - y0;
  }

  HazardSpawn _makeHazard(HazardKind kind, double y) {
    final d = difficulty;
    switch (kind) {
      case HazardKind.spikes:
        final open = rng.nextInt(3);
        final x = open == 0 ? 260.0 : (open == 2 ? 140.0 : _pick([90.0, 310.0]));
        return HazardSpawn(y: y, kind: kind, x: x, w: open == 1 ? 150 : 250, h: 34);
      case HazardKind.wall:
        final left = rng.nextBool();
        final w = _range(150, 220 + 40 * d);
        return HazardSpawn(y: y, kind: kind, x: left ? w / 2 : kTrackWidth - w / 2, w: w, h: 34);
      case HazardKind.movingWall:
        return HazardSpawn(y: y, kind: kind, x: 200, w: 170 + 30 * d, h: 34, amp: 95, freq: _range(1.0, 1.4 + d));
      case HazardKind.rotatingBar:
        return HazardSpawn(
            y: y,
            kind: kind,
            x: 200,
            w: _range(220, 260),
            h: 30,
            freq: _range(1.1, 1.5 + d),
            phase: rng.nextDouble() * 6);
      case HazardKind.crusher:
        return HazardSpawn(
            y: y,
            kind: kind,
            x: _range(140, 260),
            w: 400,
            h: 64,
            gap: 150,
            freq: _range(1.5, 2.0 + d),
            phase: rng.nextDouble() * 6);
      case HazardKind.laser:
        final period = _range(3.0, 3.6) - d;
        return HazardSpawn(
            y: y, kind: kind, x: 200, w: 400, h: 10, freq: 2 * math.pi / period, phase: rng.nextDouble() * 6);
      case HazardKind.pit:
        final w = _range(120, 170 + 60 * d);
        final x = _pick([w / 2 + 10, 200.0, kTrackWidth - w / 2 - 10]);
        return HazardSpawn(y: y, kind: kind, x: x, w: w, h: _range(90, 130));
      case HazardKind.pendulum:
        return HazardSpawn(
            y: y, kind: kind, x: _range(150, 250), amp: 120, freq: _range(1.6, 2.2 + d), phase: rng.nextDouble() * 6);
      case HazardKind.saw:
        final moving = has(Mechanic.sawMoving) && rng.nextDouble() < 0.65;
        return HazardSpawn(
          y: y,
          kind: kind,
          x: moving ? 200 : _lane(),
          w: _range(48, 58),
          amp: moving ? _range(100, 140) : 0,
          freq: _range(1.3, 1.9 + d),
          phase: rng.nextDouble() * 6,
        );
      case HazardKind.timingDoor:
        return HazardSpawn(
            y: y, kind: kind, x: 200, h: 38, gap: 130, freq: _range(1.2, 1.7 + d * 0.6), phase: rng.nextDouble() * 6);
      case HazardKind.pushBlock:
        final left = rng.nextBool();
        return HazardSpawn(
            y: y,
            kind: kind,
            x: left ? 0 : 400,
            w: 260,
            h: 60,
            amp: _range(220, 270),
            freq: _range(1.4, 2.0 + d),
            phase: rng.nextDouble() * 6);
      case HazardKind.collapsingFloor:
        final rows = 3 + rng.nextInt(2);
        var col = rng.nextInt(5);
        final masks = <int>[];
        for (var r = 0; r < rows; r++) {
          var mask = 0x1F & ~(1 << col);
          if (difficulty < 0.75) {
            // Keep a second safe tile beside the path on easier levels.
            final side = col == 0 ? 1 : (col == 4 ? 3 : col + (rng.nextBool() ? 1 : -1));
            mask &= ~(1 << side);
          }
          masks.add(mask);
          col = (col + rng.nextInt(3) - 1).clamp(0, 4);
        }
        return HazardSpawn(y: y, kind: kind, x: 200, rowMasks: masks);
      case HazardKind.platformPit:
        return HazardSpawn(y: y, kind: kind, x: 200, h: 100, gap: 160, amp: 100, freq: _range(0.8, 1.15));
    }
  }

  double _obstacle(double y0) {
    var y = y0 + rowGap * 0.7;
    final count = 2 + (difficulty * 2.5).round();
    for (var i = 0; i < count; i++) {
      final kind = _pick(patterns.hazards);
      final h = _makeHazard(kind, y);
      hazard(h);
      if (kind == HazardKind.collapsingFloor) {
        y += h.rowMasks.length * 80.0;
      }
      // Occasional coin reward for a clean line through.
      if (rng.nextDouble() < 0.4) coin(_lane(), y + rowGap * 0.5);
      if (has(Mechanic.fallingBlocks) && rng.nextDouble() < 0.25) {
        body(_pick([ObjectDefs.woodBlock, if (has(Mechanic.hardMetal)) ObjectDefs.metalCrate]), _lane(),
            y + rowGap * 0.55,
            falling: true);
      }
      if (has(Mechanic.rollingLogs) && rng.nextDouble() < 0.2) {
        body(ObjectDefs.log, _lane(), y + rowGap * 0.6, driftVy: -_range(90, 130));
      }
      y += rowGap * 1.1;
    }
    return y - y0;
  }

  List<GateOption> _gateOptions() {
    final pool = patterns.gates.where((g) => g != GateType.risk).toList();
    final good = <GateOption Function(double, double)>[];
    final other = <GateOption Function(double, double)>[];
    final small = 2 + (difficulty * 6).round() + rng.nextInt(3);
    for (final g in pool) {
      switch (g) {
        case GateType.add:
          good.add((a, b) => GateOption(x0: a, x1: b, type: g, value: small + 2));
        case GateType.multiply:
          good.add((a, b) => GateOption(x0: a, x1: b, type: g, value: rng.nextDouble() < 0.8 ? 2 : 3));
        case GateType.subtract:
          other.add((a, b) => GateOption(x0: a, x1: b, type: g, value: small));
        case GateType.quantity:
          good.add((a, b) => GateOption(x0: a, x1: b, type: g, value: 6 + (difficulty * 20).round() + rng.nextInt(5)));
        case GateType.sacrifice:
          other.add((a, b) => GateOption(
                x0: a,
                x1: b,
                type: g,
                value: 4 + rng.nextInt(4),
                powerUp: _pick([PowerUpType.shield, PowerUpType.magnet, PowerUpType.doubleReward]),
              ));
        case GateType.preserve:
          if (tally.relics > 0) good.add((a, b) => GateOption(x0: a, x1: b, type: g));
        case GateType.color:
          final mats = patterns.objects.map((d) => d.material).toSet().toList();
          good.add((a, b) => GateOption(x0: a, x1: b, type: g, material: _pick(mats)));
        case GateType.fusion:
          good.add((a, b) => GateOption(x0: a, x1: b, type: g));
        case GateType.reward:
          good.add((a, b) => GateOption(x0: a, x1: b, type: g, value: 5 + rng.nextInt(6)));
        case GateType.powerUp:
          if (patterns.powerUps.isNotEmpty) {
            other.add((a, b) => GateOption(x0: a, x1: b, type: g, powerUp: _pick(patterns.powerUps)));
          }
        case GateType.risk:
          break;
      }
    }
    if (good.isEmpty) good.add((a, b) => GateOption(x0: a, x1: b, type: GateType.add, value: small));
    final three = difficulty > 0.35 && rng.nextDouble() < 0.4;
    final makers = <GateOption Function(double, double)>[];
    makers.add(_pick(good));
    makers.add(other.isNotEmpty && rng.nextDouble() < 0.6 ? _pick(other) : _pick(good));
    if (three) makers.add(_pick([...good, ...other]));
    makers.shuffle(rng);
    final n = makers.length;
    return [for (var i = 0; i < n; i++) makers[i](i * 400 / n, (i + 1) * 400 / n)];
  }

  double _gate(double y0) {
    var y = y0 + rowGap * 0.6;
    // Earn some shards before the choice.
    for (var r = 0; r < 2; r++) {
      body(_regularObject(), _lane(), y);
      y += rowGap * 0.9;
    }
    gate(y, _gateOptions());
    return y - y0 + rowGap * 0.8;
  }

  double _riskReward(double y0) {
    var y = y0 + rowGap * 0.5;
    body(_regularObject(), _lane(), y);
    y += rowGap * 0.9;
    final riskLeft = rng.nextBool();
    final safeRange = riskLeft ? (200.0, 400.0) : (0.0, 200.0);
    final riskRange = riskLeft ? (0.0, 200.0) : (200.0, 400.0);
    gate(
        y,
        [
          GateOption(x0: safeRange.$1, x1: safeRange.$2, type: GateType.add, value: 3),
          GateOption(x0: riskRange.$1, x1: riskRange.$2, type: GateType.risk, value: difficulty > 0.4 ? 3 : 2),
        ]..sort((a, b) => a.x0.compareTo(b.x0)));
    decal('SAFE', (safeRange.$1 + safeRange.$2) / 2, y - 70, AppColors.success);
    decal('RISK', (riskRange.$1 + riskRange.$2) / 2, y - 70, AppColors.danger);
    final laneLen = rowGap * 3.2;
    final divStart = y + 40;
    hazard(HazardSpawn(y: divStart + laneLen / 2, kind: HazardKind.wall, x: 200, w: 18, h: laneLen));
    final safeX = (safeRange.$1 + safeRange.$2) / 2;
    final riskX = (riskRange.$1 + riskRange.$2) / 2;
    // Safe lane: gentle.
    body(ObjectDefs.woodBlock, safeX, divStart + laneLen * 0.35, width: 110);
    coinLine(safeX, divStart + laneLen * 0.6, safeX, divStart + laneLen * 0.8, 3);
    // Risk lane: hazards + riches.
    hazard(HazardSpawn(
        y: divStart + laneLen * 0.2,
        kind: HazardKind.saw,
        x: riskX,
        w: 44,
        amp: 44,
        freq: 2.2 + difficulty,
        phase: rng.nextDouble() * 6));
    body(has(Mechanic.crystal) ? ObjectDefs.crystal : ObjectDefs.melon, riskX, divStart + laneLen * 0.45);
    hazard(HazardSpawn(
        y: divStart + laneLen * 0.68, kind: HazardKind.spikes, x: riskX + (rng.nextBool() ? 45 : -45), w: 90, h: 30));
    coinLine(riskX, divStart + laneLen * 0.78, riskX, divStart + laneLen * 0.95, 5);
    if (has(Mechanic.energyChain)) body(ObjectDefs.energyCell, riskX, divStart + laneLen * 0.9);
    return divStart + laneLen + rowGap * 0.6 - y0;
  }

  double _combine(double y0) {
    var y = y0 + rowGap * 0.6;
    final def = _pick([ObjectDefs.melon, ObjectDefs.woodBlock, if (has(Mechanic.crystal)) ObjectDefs.crystal]);
    tally.combineClusters++;
    for (var r = 0; r < 3; r++) {
      final x = _lane();
      body(def, x, y, width: def == ObjectDefs.woodBlock ? 110 : null);
      y += rowGap * 0.75;
    }
    if (has(Mechanic.gatesBasic)) {
      gate(
          y + rowGap * 0.2,
          [
            GateOption(x0: 0, x1: 200, type: GateType.fusion),
            GateOption(x0: 200, x1: 400, type: GateType.add, value: 3 + rng.nextInt(3)),
          ]..shuffle(rng));
      y += rowGap;
    }
    return y - y0;
  }

  double _powerUp(double y0) {
    if (patterns.powerUps.isEmpty) return _cut(y0);
    var y = y0 + rowGap * 0.5;
    final type = _pick(patterns.powerUps);
    powerUp(type, _lane(), y);
    y += rowGap * 0.8;
    switch (type) {
      case PowerUpType.magnet:
        for (var i = 0; i < 12; i++) {
          coin(_range(40, 360), y + i * 45.0);
        }
        y += 12 * 45;
      case PowerUpType.autoCutter:
        for (var i = 0; i < 4; i++) {
          body(_regularObject(), _lane(), y);
          y += rowGap * 0.55;
        }
      default:
        for (var i = 0; i < 2; i++) {
          body(_regularObject(), _lane(), y);
          y += rowGap * 0.9;
        }
    }
    return y - y0 + rowGap * 0.4;
  }

  double _challenge(double y0) {
    var y = y0 + rowGap * 0.6;
    final rows = 3 + (difficulty * 2).round();
    for (var r = 0; r < rows; r++) {
      if (rng.nextBool() && patterns.hazards.isNotEmpty) {
        final kind = _pick(patterns.hazards.where((h) => h != HazardKind.collapsingFloor).toList());
        hazard(_makeHazard(kind, y));
        body(_regularObject(), _lane(), y + rowGap * 0.5, moveAmp: has(Mechanic.movingObjects) ? 70 : 0, moveFreq: 1.4);
      } else {
        body(_regularObject(), 200, y, moveAmp: 110, moveFreq: _range(1.2, 1.8 + difficulty));
        if (has(Mechanic.rollingLogs) && rng.nextBool()) {
          body(ObjectDefs.log, _lane(), y + rowGap * 0.5, driftVy: -_range(100, 150));
        } else if (has(Mechanic.fallingBlocks)) {
          body(ObjectDefs.woodBlock, _lane(), y + rowGap * 0.5, falling: true);
        }
      }
      y += rowGap * 1.05;
    }
    return y - y0;
  }

  double _reward(double y0) {
    var y = y0 + rowGap * 0.4;
    for (var r = 0; r < 3; r++) {
      for (final x in lanes) {
        coin(x, y + r * 55);
      }
    }
    y += 3 * 55 + rowGap * 0.5;
    if (has(Mechanic.mystery)) {
      body(ObjectDefs.mysteryBox, _lane(), y);
      y += rowGap * 0.9;
    }
    if (has(Mechanic.relic)) {
      final rx = _lane();
      body(ObjectDefs.relic, rx, y);
      y += rowGap * 0.9;
      if (has(Mechanic.gatesBasic)) {
        gate(
            y,
            [
              GateOption(x0: 0, x1: 200, type: GateType.preserve),
              GateOption(x0: 200, x1: 400, type: GateType.add, value: 4),
            ]..shuffle(rng));
        y += rowGap * 0.8;
      }
    } else {
      // Shard shower: ready-cut pieces to scoop up.
      for (var i = 0; i < 6; i++) {
        body(ObjectDefs.woodBlock, _range(60, 340), y + i * 40, width: 46, height: 36, asPiece: true);
      }
      y += 6 * 40 + rowGap * 0.4;
    }
    return y - y0;
  }

  double _finish(double y0) {
    var y = y0 + rowGap * 0.4;
    for (var i = 0; i < 5; i++) {
      body(_pick([ObjectDefs.woodBlock, ObjectDefs.melon]), 80.0 + (i % 3) * 120, y + i * 50,
          width: 44, height: 40, asPiece: true);
    }
    coinLine(200, y + 280, 200, y + 420, 4);
    return y - y0 + 560;
  }
}
