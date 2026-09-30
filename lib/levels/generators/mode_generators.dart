import 'dart:math' as math;

import '../models/level_config.dart';
import '../models/mechanics.dart';
import '../models/objective.dart';
import '../models/spawn.dart';
import '../segments/segment_builder.dart';
import 'level_generator.dart';

/// Endless mode: segments are generated on the fly, getting gradually harder
/// with distance (more mechanics, denser layouts, faster speed).
class EndlessGenerator {
  EndlessGenerator({int? seed}) : _rng = math.Random(seed ?? DateTime.now().millisecondsSinceEpoch);

  final math.Random _rng;
  double _cursor = 0;
  SegmentType? _last;

  double get generatedUntil => _cursor;

  static int levelEquivalent(double distance) => (8 + distance / 140).floor().clamp(8, 1000);

  static double speedAt(double distance) => LevelGenerator.speedFor(levelEquivalent(distance)) + 10;

  LevelConfig initialConfig() {
    final spawns = extend(4000);
    final lvl = levelEquivalent(0);
    return LevelConfig(
      levelId: 0,
      worldId: 1,
      mode: GameMode.endless,
      seed: 0,
      speed: speedAt(0),
      pathLength: double.infinity,
      difficulty: LevelGenerator.difficultyFor(lvl),
      segments: const [],
      objectives: const [Objective(ObjectiveType.reachFinish)],
      rewards: const LevelRewards(baseCoins: 0, perStar: 0),
      patterns: LevelGenerator.patternsFor(mechanicsForLevel(lvl)),
      specialMechanics: mechanicsForLevel(lvl),
      spawns: spawns,
      title: 'Endless',
    );
  }

  /// Generates segments until content exists up to [toY].
  List<Spawn> extend(double toY) {
    final out = <Spawn>[];
    while (_cursor < toY) {
      final lvl = levelEquivalent(_cursor);
      final m = mechanicsForLevel(lvl);
      final d = LevelGenerator.difficultyFor(lvl);
      final b = SegmentBuilder(
        rng: _rng,
        difficulty: d,
        speed: speedAt(_cursor),
        mechanics: m,
        patterns: LevelGenerator.patternsFor(m),
      );
      final type =
          _cursor == 0 ? SegmentType.start : _pick(LevelGenerator.segmentWeights(m, d)..remove(SegmentType.finish));
      final len = b.build(type, _cursor);
      _cursor += len;
      _last = type;
      out.addAll(b.spawns);
    }
    out.sort((a, b) => a.y.compareTo(b.y));
    return out;
  }

  SegmentType _pick(Map<SegmentType, double> w) {
    final entries = w.entries.where((e) => e.key != _last).toList();
    final total = entries.fold<double>(0, (s, e) => s + e.value);
    var r = _rng.nextDouble() * total;
    for (final e in entries) {
      r -= e.value;
      if (r <= 0) return e.key;
    }
    return entries.last.key;
  }
}

/// Daily challenge: a unique, date-seeded level with a special objective.
abstract final class DailyGenerator {
  static int seedFor(DateTime date) => date.year * 10000 + date.month * 100 + date.day;

  static String keyFor(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  static const bonusCoins = 150;

  static LevelConfig forDate(DateTime date) {
    final seed = seedFor(date);
    final rng = math.Random(seed);
    final levelEq = 25 + rng.nextInt(175);
    final specials = <Objective>[
      const Objective(ObjectiveType.perfectCuts, 4),
      const Objective(ObjectiveType.reachCombo, 3),
      const Objective(ObjectiveType.makeCuts, 14),
      const Objective(ObjectiveType.perfectDodges, 2),
      const Objective(ObjectiveType.noCollision),
    ];
    return LevelGenerator.generate(
      level: levelEq,
      seed: seed,
      mode: GameMode.daily,
      title: 'Daily Challenge',
      specialObjective: specials[rng.nextInt(specials.length)],
      bonusCoins: bonusCoins,
    );
  }
}
