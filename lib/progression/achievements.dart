/// Lifetime totals persisted across runs; achievements read from these.
class LifetimeStats {
  int cuts = 0;
  int perfectCuts = 0;
  int chainCuts = 0;
  int pieces = 0;
  int combines = 0;
  int bestComboCount = 0;
  int riskRoutes = 0;
  int relicsSaved = 0;
  int levelsCompleted = 0;
  int noCollisionLevels = 0;
  int runs = 0;

  Map<String, dynamic> toJson() => {
        'cuts': cuts,
        'perfectCuts': perfectCuts,
        'chainCuts': chainCuts,
        'pieces': pieces,
        'combines': combines,
        'bestComboCount': bestComboCount,
        'riskRoutes': riskRoutes,
        'relicsSaved': relicsSaved,
        'levelsCompleted': levelsCompleted,
        'noCollisionLevels': noCollisionLevels,
        'runs': runs,
      };

  static LifetimeStats fromJson(Map<String, dynamic> j) {
    int v(String k) => (j[k] is num) ? (j[k] as num).toInt() : 0;
    return LifetimeStats()
      ..cuts = v('cuts')
      ..perfectCuts = v('perfectCuts')
      ..chainCuts = v('chainCuts')
      ..pieces = v('pieces')
      ..combines = v('combines')
      ..bestComboCount = v('bestComboCount')
      ..riskRoutes = v('riskRoutes')
      ..relicsSaved = v('relicsSaved')
      ..levelsCompleted = v('levelsCompleted')
      ..noCollisionLevels = v('noCollisionLevels')
      ..runs = v('runs');
  }
}

/// Snapshot of everything achievements can measure.
class AchievementContext {
  const AchievementContext({
    required this.stats,
    required this.highestLevelCompleted,
    required this.totalStars,
    required this.endlessBestDistance,
    required this.dailyStreak,
  });

  final LifetimeStats stats;
  final int highestLevelCompleted;
  final int totalStars;
  final double endlessBestDistance;
  final int dailyStreak;
}

class Achievement {
  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.target,
    required this.reward,
    required this.measure,
  });

  final String id;
  final String title;
  final String description;
  final int target;
  final int reward;
  final int Function(AchievementContext c) measure;

  int progress(AchievementContext c) => measure(c).clamp(0, target);
  bool isComplete(AchievementContext c) => measure(c) >= target;
}

final achievements = <Achievement>[
  Achievement(
      id: 'first_cut',
      title: 'First Cut',
      description: 'Slice your first object.',
      target: 1,
      reward: 25,
      measure: (c) => c.stats.cuts),
  Achievement(
      id: 'cuts_10',
      title: '10 Cuts',
      description: 'Make 10 cuts.',
      target: 10,
      reward: 50,
      measure: (c) => c.stats.cuts),
  Achievement(
      id: 'cuts_100',
      title: '100 Cuts',
      description: 'Make 100 cuts.',
      target: 100,
      reward: 150,
      measure: (c) => c.stats.cuts),
  Achievement(
      id: 'cuts_1000',
      title: 'Blade Storm',
      description: 'Make 1,000 cuts.',
      target: 1000,
      reward: 500,
      measure: (c) => c.stats.cuts),
  Achievement(
      id: 'perfect_10',
      title: 'Perfect Cutter',
      description: 'Land 10 Perfect Cuts.',
      target: 10,
      reward: 100,
      measure: (c) => c.stats.perfectCuts),
  Achievement(
      id: 'perfect_100',
      title: 'Precision Artist',
      description: 'Land 100 Perfect Cuts.',
      target: 100,
      reward: 400,
      measure: (c) => c.stats.perfectCuts),
  Achievement(
      id: 'combo_master',
      title: 'Combo Master',
      description: 'Build a combo of 20 actions.',
      target: 20,
      reward: 200,
      measure: (c) => c.stats.bestComboCount),
  Achievement(
      id: 'chain_cutter',
      title: 'Chain Cutter',
      description: 'Trigger 5 Cut Chains.',
      target: 5,
      reward: 150,
      measure: (c) => c.stats.chainCuts),
  Achievement(
      id: 'no_collision',
      title: 'Untouchable',
      description: 'Finish 5 levels without a collision.',
      target: 5,
      reward: 150,
      measure: (c) => c.stats.noCollisionLevels),
  Achievement(
      id: 'collector',
      title: 'Collector',
      description: 'Collect 500 pieces.',
      target: 500,
      reward: 200,
      measure: (c) => c.stats.pieces),
  Achievement(
      id: 'fusion',
      title: 'Fusion Expert',
      description: 'Fuse pieces 50 times.',
      target: 50,
      reward: 200,
      measure: (c) => c.stats.combines),
  Achievement(
      id: 'risk_taker',
      title: 'Risk Taker',
      description: 'Take the risky route 10 times.',
      target: 10,
      reward: 200,
      measure: (c) => c.stats.riskRoutes),
  Achievement(
      id: 'relic_keeper',
      title: 'Relic Keeper',
      description: 'Save 5 relics in one piece.',
      target: 5,
      reward: 250,
      measure: (c) => c.stats.relicsSaved),
  Achievement(
      id: 'endless_runner',
      title: 'Endless Runner',
      description: 'Run 3,000 m in Endless.',
      target: 3000,
      reward: 300,
      measure: (c) => c.endlessBestDistance ~/ 10),
  Achievement(
      id: 'daily_7',
      title: 'Dedicated',
      description: 'Reach a 7-day daily streak.',
      target: 7,
      reward: 300,
      measure: (c) => c.dailyStreak),
  Achievement(
      id: 'stars_60',
      title: 'Star Collector',
      description: 'Earn 60 stars.',
      target: 60,
      reward: 250,
      measure: (c) => c.totalStars),
  Achievement(
      id: 'level_100',
      title: 'Master Cutter',
      description: 'Complete level 100.',
      target: 100,
      reward: 1000,
      measure: (c) => c.highestLevelCompleted),
];
