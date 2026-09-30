import 'dart:math' as math;

import '../../core/theme/app_colors.dart';
import '../../game/entities/gate.dart';
import '../../game/entities/hazard.dart';
import '../../game/entities/pickup.dart';
import '../../game/model/object_defs.dart';
import '../../game/model/powerups.dart';
import '../models/level_config.dart';
import '../models/mechanics.dart';
import '../models/objective.dart';
import '../models/spawn.dart';
import '../segments/segment_builder.dart';
import '../worlds.dart';

/// Config-driven level generation. Any of the 1000 campaign levels (and daily
/// / endless variants) is produced deterministically from its id and seed —
/// there are no hand-written level classes.
abstract final class LevelGenerator {
  static double difficultyFor(int level) => 1 - math.exp(-level / 220);

  static double speedFor(int level) => 250 + 150 * (1 - math.exp(-level / 400));

  static LevelPatterns patternsFor(Set<Mechanic> m) {
    return LevelPatterns(
      objects: [
        ObjectDefs.woodBlock,
        ObjectDefs.woodPlank,
        if (m.contains(Mechanic.melon)) ObjectDefs.melon,
        if (m.contains(Mechanic.softVariety)) ...[ObjectDefs.rope, ObjectDefs.jelly],
        if (m.contains(Mechanic.crystal)) ObjectDefs.crystal,
        if (m.contains(Mechanic.prism)) ObjectDefs.prism,
        if (m.contains(Mechanic.hardMetal)) ObjectDefs.metalCrate,
        if (m.contains(Mechanic.mystery)) ObjectDefs.mysteryBox,
      ],
      hazards: [
        HazardKind.spikes,
        HazardKind.wall,
        if (m.contains(Mechanic.pits)) HazardKind.pit,
        if (m.contains(Mechanic.sawStatic)) HazardKind.saw,
        if (m.contains(Mechanic.movingWall)) HazardKind.movingWall,
        if (m.contains(Mechanic.pendulum)) HazardKind.pendulum,
        if (m.contains(Mechanic.rotatingBar)) HazardKind.rotatingBar,
        if (m.contains(Mechanic.laser)) HazardKind.laser,
        if (m.contains(Mechanic.crusher)) HazardKind.crusher,
        if (m.contains(Mechanic.timingDoor)) HazardKind.timingDoor,
        if (m.contains(Mechanic.pushBlock)) HazardKind.pushBlock,
        if (m.contains(Mechanic.collapsingFloor)) HazardKind.collapsingFloor,
        if (m.contains(Mechanic.platformPit)) HazardKind.platformPit,
      ],
      gates: [
        if (m.contains(Mechanic.gatesBasic)) ...[GateType.add, GateType.multiply],
        if (m.contains(Mechanic.subtractGate)) GateType.subtract,
        if (m.contains(Mechanic.quantityGate)) GateType.quantity,
        if (m.contains(Mechanic.combine)) GateType.fusion,
        if (m.contains(Mechanic.relic)) GateType.preserve,
        if (m.contains(Mechanic.colorGate)) GateType.color,
        if (m.contains(Mechanic.sacrificeGate)) GateType.sacrifice,
        if (m.contains(Mechanic.rewardZone)) GateType.reward,
        if (m.contains(Mechanic.shieldMagnet)) GateType.powerUp,
      ],
      powerUps: [
        if (m.contains(Mechanic.shieldMagnet)) ...[PowerUpType.shield, PowerUpType.magnet],
        if (m.contains(Mechanic.slowPrecision)) ...[PowerUpType.slowMotion, PowerUpType.precisionCutter],
        if (m.contains(Mechanic.autoDouble)) ...[PowerUpType.autoCutter, PowerUpType.doubleReward],
        if (m.contains(Mechanic.megaCombo)) ...[PowerUpType.megaCut, PowerUpType.comboBoost],
        if (m.contains(Mechanic.beamSaver)) ...[PowerUpType.cutterBeam, PowerUpType.pieceSaver],
      ],
    );
  }

  static Map<SegmentType, double> segmentWeights(Set<Mechanic> m, double d) => {
        SegmentType.cut: 4,
        SegmentType.collection: 1.2,
        SegmentType.obstacle: 2.6,
        if (m.contains(Mechanic.gatesBasic)) SegmentType.gate: 2,
        if (m.contains(Mechanic.cutWall) || m.contains(Mechanic.multiCut)) SegmentType.multiCut: 1.6,
        if (m.contains(Mechanic.precisionSeam)) SegmentType.precisionCut: 1.5,
        if (m.contains(Mechanic.riskReward)) SegmentType.riskReward: 1.2,
        if (m.contains(Mechanic.combine)) SegmentType.combine: 1.1,
        if (m.contains(Mechanic.shieldMagnet)) SegmentType.powerUp: 1.2,
        if (m.contains(Mechanic.movingObjects)) SegmentType.challenge: 1 + d * 2,
        if (m.contains(Mechanic.rewardZone)) SegmentType.reward: 0.8,
      };

  static LevelConfig campaign(int level) {
    final lvl = level.clamp(1, kMaxLevel);
    if (lvl == 1) return tutorial();
    return generate(level: lvl, seed: lvl * 7919 + 17, mode: GameMode.campaign);
  }

  static LevelConfig generate({
    required int level,
    required int seed,
    required GameMode mode,
    String? title,
    Objective? specialObjective,
    int bonusCoins = 0,
  }) {
    final rng = math.Random(seed);
    final mechanics = mechanicsForLevel(level);
    final d = difficultyFor(level);
    final speed = speedFor(level);
    final patterns = patternsFor(mechanics);
    final builder = SegmentBuilder(
      rng: rng,
      difficulty: d,
      speed: speed,
      mechanics: mechanics,
      patterns: patterns,
    );
    final segments = <SegmentSpec>[];
    var y = 0.0;

    void add(SegmentType t) {
      final len = builder.build(t, y);
      segments.add(SegmentSpec(t, y, len));
      y += len;
    }

    add(SegmentType.start);
    final targetLength = speed * (30 + 24 * d);
    final weights = segmentWeights(mechanics, d);
    // Showcase the newest mechanic early so it gets noticed.
    final intro = mechanicIntroducedAt(level);
    final introSeg = intro == null ? null : _segmentShowcasing(intro);
    if (introSeg != null && weights.containsKey(introSeg)) add(introSeg);
    SegmentType? last = introSeg;
    var sinceGate = 0;
    while (y < targetLength) {
      SegmentType next;
      if (weights.containsKey(SegmentType.gate) && sinceGate >= 3) {
        next = SegmentType.gate;
      } else {
        next = _weighted(rng, weights, exclude: last);
      }
      sinceGate = next == SegmentType.gate ? 0 : sinceGate + 1;
      add(next);
      last = next;
    }
    final finishStart = y;
    add(SegmentType.finish);
    final pathLength = finishStart + (y - finishStart) - 120;

    final tally = builder.tally;
    final objectives = <Objective>[
      const Objective(ObjectiveType.reachFinish),
      ..._secondaries(rng, level, tally, mechanics, specialObjective),
    ];
    builder.spawns.sort((a, b) => a.y.compareTo(b.y));
    return LevelConfig(
      levelId: level,
      worldId: worldForLevel(level).id,
      mode: mode,
      seed: seed,
      speed: speed,
      pathLength: pathLength,
      difficulty: d,
      segments: segments,
      objectives: objectives,
      rewards: LevelRewards(baseCoins: 15 + level ~/ 5, perStar: 10, bonus: bonusCoins),
      patterns: patterns,
      specialMechanics: mechanics,
      spawns: builder.spawns,
      title: title,
      bonusStepCost: math.max(3, (tally.potentialShards * 0.07).round()),
    );
  }

  static SegmentType? _segmentShowcasing(Mechanic m) {
    switch (m) {
      case Mechanic.gatesBasic:
      case Mechanic.subtractGate:
      case Mechanic.quantityGate:
      case Mechanic.colorGate:
      case Mechanic.sacrificeGate:
        return SegmentType.gate;
      case Mechanic.cutWall:
      case Mechanic.multiCut:
      case Mechanic.hardMetal:
      case Mechanic.multiLayerWall:
        return SegmentType.multiCut;
      case Mechanic.precisionSeam:
      case Mechanic.reinforced:
      case Mechanic.diagonalSeam:
        return SegmentType.precisionCut;
      case Mechanic.combine:
        return SegmentType.combine;
      case Mechanic.riskReward:
        return SegmentType.riskReward;
      case Mechanic.shieldMagnet:
      case Mechanic.slowPrecision:
      case Mechanic.autoDouble:
      case Mechanic.megaCombo:
      case Mechanic.beamSaver:
        return SegmentType.powerUp;
      case Mechanic.rewardZone:
      case Mechanic.mystery:
      case Mechanic.relic:
        return SegmentType.reward;
      case Mechanic.movingObjects:
      case Mechanic.rollingLogs:
        return SegmentType.challenge;
      case Mechanic.softCut:
      case Mechanic.melon:
      case Mechanic.softVariety:
      case Mechanic.crystal:
      case Mechanic.prism:
      case Mechanic.energyChain:
        return SegmentType.cut;
      default:
        return SegmentType.obstacle;
    }
  }

  static SegmentType _weighted(math.Random rng, Map<SegmentType, double> w, {SegmentType? exclude}) {
    final entries = w.entries.where((e) => e.key != exclude).toList();
    final total = entries.fold<double>(0, (s, e) => s + e.value);
    var r = rng.nextDouble() * total;
    for (final e in entries) {
      r -= e.value;
      if (r <= 0) return e.key;
    }
    return entries.last.key;
  }

  static List<Objective> _secondaries(
    math.Random rng,
    int level,
    ContentTally t,
    Set<Mechanic> m,
    Objective? special,
  ) {
    final pool = <Objective>[
      Objective(ObjectiveType.makeCuts, math.max(3, (t.cuttables * 0.6).round())),
      Objective(ObjectiveType.collectShards, math.max(5, (t.potentialShards * 0.4).round())),
      Objective(ObjectiveType.reachCombo, level < 40 ? 2 : (level < 200 ? 3 : 4)),
      if (t.coins >= 8) Objective(ObjectiveType.collectCoins, (t.coins * 0.6).round()),
      if (t.seams > 0 || level >= 12)
        Objective(ObjectiveType.perfectCuts, math.max(1, math.min(6, (t.cuttables * 0.15).round()))),
      if (t.energy > 0) const Objective(ObjectiveType.chainCut),
      if (t.relics > 0) const Objective(ObjectiveType.preserveRelic),
      if (t.mystery > 0) Objective(ObjectiveType.cutSpecial, math.min(2, t.mystery)),
      if (m.contains(Mechanic.combine) && t.potentialShards >= 12)
        Objective(ObjectiveType.combine, math.max(1, math.min(4, t.potentialShards ~/ 14))),
      if (t.shieldPickups > 0) const Objective(ObjectiveType.finishWithShield),
      if (t.gates >= 2) const Objective(ObjectiveType.perfectRoute),
      if (t.hazards >= 5) Objective(ObjectiveType.perfectDodges, math.min(4, t.hazards ~/ 4)),
      Objective(ObjectiveType.reachScore, ((t.cuttables * 30 + t.potentialShards * 12) * 0.55).round() ~/ 50 * 50),
    ];
    pool.shuffle(rng);
    final picked = <Objective>[];
    if (special != null) picked.add(special);
    for (final o in pool) {
      if (picked.length >= 2) break;
      if (picked.any((p) => p.type == o.type)) continue;
      picked.add(o);
    }
    return picked;
  }

  /// Level 1: an interactive tutorial built from real gameplay.
  static LevelConfig tutorial() {
    const speed = 225.0;
    final s = <Spawn>[];
    // 1. Move: coins weave left and right.
    s.add(const HintSpawn(y: 250, step: TutorialStep.move));
    for (var i = 0; i < 6; i++) {
      s.add(PickupSpawn(y: 560.0 + i * 70, kind: PickupKind.coin, x: i < 3 ? 90 : 310));
    }
    // 2. Collect: ready-cut pieces.
    s.add(const HintSpawn(y: 1050, step: TutorialStep.collect));
    for (var i = 0; i < 4; i++) {
      s.add(BodySpawn(
          y: 1330.0 + i * 55,
          def: ObjectDefs.woodBlock,
          x: 200 + (i.isEven ? -26 : 26),
          width: 46,
          height: 36,
          asPiece: true));
    }
    // 3. Cut: a block in the middle of the track.
    s.add(const HintSpawn(y: 1650, step: TutorialStep.cut));
    s.add(const BodySpawn(y: 2050, def: ObjectDefs.woodBlock, x: 200, width: 130, height: 66));
    s.add(const BodySpawn(y: 2550, def: ObjectDefs.melon, x: 200));
    // 4. Avoid: spikes cannot be cut.
    s.add(const HintSpawn(y: 2750, step: TutorialStep.avoid));
    s.add(const HazardSpawn(y: 3120, kind: HazardKind.spikes, x: 110, w: 220, h: 34));
    s.add(const HazardSpawn(y: 3480, kind: HazardKind.spikes, x: 290, w: 220, h: 34));
    // 5. Use pieces: gates change what you carry.
    s.add(const HintSpawn(y: 3650, step: TutorialStep.pieces));
    s.add(const BodySpawn(y: 3850, def: ObjectDefs.woodPlank, x: 200));
    s.add(GateSpawn(y: 4250, options: [
      GateOption(x0: 0, x1: 200, type: GateType.multiply, value: 2),
      GateOption(x0: 200, x1: 400, type: GateType.subtract, value: 3),
    ]));
    // 6. Finish.
    s.add(const HintSpawn(y: 4450, step: TutorialStep.finish));
    s.add(const DecalSpawn(y: 4300, text: 'GOOD CHOICE?', x: 200, color: AppColors.textMuted));
    for (var i = 0; i < 3; i++) {
      s.add(PickupSpawn(y: 4600.0 + i * 60, kind: PickupKind.coin, x: 200));
    }
    s.sort((a, b) => a.y.compareTo(b.y));
    return LevelConfig(
      levelId: 1,
      worldId: 1,
      mode: GameMode.campaign,
      seed: 1,
      speed: speed,
      pathLength: 4900,
      difficulty: 0,
      segments: const [SegmentSpec(SegmentType.start, 0, 4900)],
      objectives: const [
        Objective(ObjectiveType.reachFinish),
        Objective(ObjectiveType.makeCuts, 2),
        Objective(ObjectiveType.collectShards, 6),
      ],
      rewards: const LevelRewards(baseCoins: 25, perStar: 10),
      patterns: patternsFor(mechanicsForLevel(1)),
      specialMechanics: mechanicsForLevel(1),
      spawns: s,
      isTutorial: true,
      bonusStepCost: 3,
    );
  }
}
