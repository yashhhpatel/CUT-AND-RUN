import '../../game/entities/hazard.dart';
import '../../game/entities/gate.dart';
import '../../game/model/object_defs.dart';
import '../../game/model/powerups.dart';
import 'mechanics.dart';
import 'objective.dart';
import 'spawn.dart';

enum GameMode { campaign, daily, endless }

enum SegmentType {
  start,
  collection,
  cut,
  multiCut,
  precisionCut,
  obstacle,
  gate,
  riskReward,
  combine,
  powerUp,
  challenge,
  reward,
  finish,
}

class SegmentSpec {
  const SegmentSpec(this.type, this.startY, this.length);
  final SegmentType type;
  final double startY;
  final double length;
}

/// Pools the generator may draw from for a given level.
class LevelPatterns {
  const LevelPatterns({
    required this.objects,
    required this.hazards,
    required this.gates,
    required this.powerUps,
  });

  final List<ObjectDef> objects;
  final List<HazardKind> hazards;
  final List<GateType> gates;
  final List<PowerUpType> powerUps;
}

class LevelRewards {
  const LevelRewards({required this.baseCoins, required this.perStar, this.bonus = 0});
  final int baseCoins;
  final int perStar;

  /// Extra coins (daily challenge bonus).
  final int bonus;
}

class LevelConfig {
  const LevelConfig({
    required this.levelId,
    required this.worldId,
    required this.mode,
    required this.seed,
    required this.speed,
    required this.pathLength,
    required this.difficulty,
    required this.segments,
    required this.objectives,
    required this.rewards,
    required this.patterns,
    required this.specialMechanics,
    required this.spawns,
    this.isTutorial = false,
    this.title,
  });

  final int levelId;
  final int worldId;
  final GameMode mode;
  final int seed;

  /// Forward speed in world units / second.
  final double speed;

  /// Distance to the finish line. Infinite for endless.
  final double pathLength;

  /// 0..1 difficulty scalar.
  final double difficulty;
  final List<SegmentSpec> segments;

  /// First objective is always the primary one (reach finish / survive).
  final List<Objective> objectives;
  final LevelRewards rewards;
  final LevelPatterns patterns;
  final Set<Mechanic> specialMechanics;

  /// Spawns sorted by y.
  final List<Spawn> spawns;
  final bool isTutorial;
  final String? title;

  bool get isEndless => mode == GameMode.endless;

  List<Objective> get secondaryObjectives => objectives.skip(1).toList();
}
