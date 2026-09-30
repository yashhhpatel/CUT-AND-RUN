import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../game/systems/run_stats.dart';
import '../levels/generators/mode_generators.dart';
import '../levels/models/level_config.dart';
import '../levels/worlds.dart';
import '../services/storage/storage_service.dart';
import 'achievements.dart';
import 'cosmetics.dart';

class EndlessBests {
  double distance = 0;
  int score = 0;
  int combo = 0;
  int cuts = 0;
  double survival = 0;
}

/// Everything shown on the result screen.
class RunResult {
  RunResult({
    required this.config,
    required this.stats,
    required this.completed,
    required this.stars,
    required this.objectivesMet,
    required this.coinsEarned,
    required this.bestMultiplier,
    required this.newAchievements,
    this.previousStars = 0,
    this.newBest = false,
    this.failReason,
  });

  final LevelConfig config;
  final RunStats stats;
  final bool completed;
  final int stars;
  final int previousStars;
  final List<bool> objectivesMet;
  int coinsEarned;
  final int bestMultiplier;
  final List<Achievement> newAchievements;
  final bool newBest;
  final String? failReason;
  bool doubled = false;

  /// Daily missions completed by this run (filled in by the screen).
  final List<String> missionsCompleted = [];
}

/// Player progression: levels, stars, coins, cosmetics, daily, endless,
/// achievements and lifetime stats. Persisted locally; works fully offline.
class ProgressStore extends ChangeNotifier {
  ProgressStore(this._storage) {
    _load();
  }

  final StorageService _storage;

  static const _kUnlocked = 'progress.unlocked';
  static const _kStars = 'progress.stars';
  static const _kCoins = 'progress.coins';
  static const _kStats = 'progress.stats';
  static const _kClaimed = 'progress.achievementsClaimed';
  static const _kOwned = 'progress.owned';
  static const _kSelected = 'progress.selected';
  static const _kDailyLast = 'daily.lastCompleted';
  static const _kDailyStreak = 'daily.streak';
  static const _kEndless = 'endless.bests';
  static const _kTutorial = 'progress.tutorialDone';
  static const _kBestScores = 'progress.bestScores';

  int _unlocked = 1;
  final List<int> _stars = List.filled(kMaxLevel, 0);
  int _coins = 0;
  LifetimeStats stats = LifetimeStats();
  Set<String> _claimed = {};
  Set<String> _owned = {};
  Map<String, String> _selected = {};
  String _dailyLast = '';
  int _dailyStreak = 0;
  final EndlessBests endless = EndlessBests();
  bool _tutorialDone = false;
  Map<String, dynamic> _bestScores = {};

  int get unlockedLevel => _unlocked;
  int get coins => _coins;
  bool get tutorialDone => _tutorialDone;
  int get dailyStreak => _dailyStreak;
  int starsFor(int level) => (level >= 1 && level <= kMaxLevel) ? _stars[level - 1] : 0;
  int get totalStars => _stars.fold(0, (a, b) => a + b);
  int get highestCompleted => _unlocked - 1 + (starsFor(kMaxLevel) > 0 ? 1 : 0);
  int bestScore(int level) => (_bestScores['$level'] as num?)?.toInt() ?? 0;

  int starsInWorld(WorldDef w) {
    var s = 0;
    for (var l = w.firstLevel; l <= w.lastLevel; l++) {
      s += starsFor(l);
    }
    return s;
  }

  void _load() {
    _unlocked = _storage.getInt(_kUnlocked, 1).clamp(1, kMaxLevel);
    final starStr = _storage.getString(_kStars);
    for (var i = 0; i < math.min(starStr.length, kMaxLevel); i++) {
      final v = int.tryParse(starStr[i]) ?? 0;
      _stars[i] = v.clamp(0, 3);
    }
    _coins = math.max(0, _storage.getInt(_kCoins));
    stats = LifetimeStats.fromJson(_storage.getJson(_kStats));
    _claimed = _storage.getStringSet(_kClaimed);
    _owned = {...Cosmetics.defaultIds, ..._storage.getStringSet(_kOwned)};
    _selected = _storage.getJson(_kSelected).map((k, v) => MapEntry(k, '$v'));
    _dailyLast = _storage.getString(_kDailyLast);
    _dailyStreak = _storage.getInt(_kDailyStreak);
    final e = _storage.getJson(_kEndless);
    endless
      ..distance = (e['distance'] as num?)?.toDouble() ?? 0
      ..score = (e['score'] as num?)?.toInt() ?? 0
      ..combo = (e['combo'] as num?)?.toInt() ?? 0
      ..cuts = (e['cuts'] as num?)?.toInt() ?? 0
      ..survival = (e['survival'] as num?)?.toDouble() ?? 0;
    _tutorialDone = _storage.getBool(_kTutorial);
    _bestScores = _storage.getJson(_kBestScores);
  }

  Future<void> _save() async {
    await Future.wait([
      _storage.setInt(_kUnlocked, _unlocked),
      _storage.setString(_kStars, _stars.join()),
      _storage.setInt(_kCoins, _coins),
      _storage.setJson(_kStats, stats.toJson()),
      _storage.setStringSet(_kClaimed, _claimed),
      _storage.setStringSet(_kOwned, _owned),
      _storage.setJson(_kSelected, _selected),
      _storage.setString(_kDailyLast, _dailyLast),
      _storage.setInt(_kDailyStreak, _dailyStreak),
      _storage.setJson(_kEndless, {
        'distance': endless.distance,
        'score': endless.score,
        'combo': endless.combo,
        'cuts': endless.cuts,
        'survival': endless.survival,
      }),
      _storage.setBool(_kTutorial, _tutorialDone),
      _storage.setJson(_kBestScores, _bestScores),
    ]);
  }

  // ------------------------------------------------------------------- coins

  void addCoins(int n) {
    if (n <= 0) return;
    _coins += n;
    _save();
    notifyListeners();
  }

  bool spendCoins(int n) {
    if (n < 0 || _coins < n) return false;
    _coins -= n;
    _save();
    notifyListeners();
    return true;
  }

  // --------------------------------------------------------------- cosmetics

  bool owns(String id) => _owned.contains(id);

  String selectedId(CosmeticKind k) => _selected[k.name] ?? Cosmetics.ofKind(k).first.id;

  Loadout get loadout => Loadout(
        skin: Cosmetics.byId(selectedId(CosmeticKind.skin)),
        cutEffect: Cosmetics.byId(selectedId(CosmeticKind.cutEffect)),
        trail: Cosmetics.byId(selectedId(CosmeticKind.trail)),
      );

  bool buy(Cosmetic c) {
    if (owns(c.id)) return true;
    if (!spendCoins(c.price)) return false;
    _owned.add(c.id);
    _save();
    notifyListeners();
    return true;
  }

  void select(Cosmetic c) {
    if (!owns(c.id)) return;
    _selected[c.kind.name] = c.id;
    _save();
    notifyListeners();
  }

  // ------------------------------------------------------------ achievements

  AchievementContext get achievementContext => AchievementContext(
        stats: stats,
        highestLevelCompleted: highestCompleted,
        totalStars: totalStars,
        endlessBestDistance: endless.distance,
        dailyStreak: _dailyStreak,
      );

  bool isClaimed(Achievement a) => _claimed.contains(a.id);

  int get unclaimedAchievements => achievements.where((a) => a.isComplete(achievementContext) && !isClaimed(a)).length;

  bool claim(Achievement a) {
    if (isClaimed(a) || !a.isComplete(achievementContext)) return false;
    _claimed.add(a.id);
    _coins += a.reward;
    _save();
    notifyListeners();
    return true;
  }

  // ------------------------------------------------------------------ daily

  bool dailyDoneFor(DateTime d) => _dailyLast == DailyGenerator.keyFor(d);

  // --------------------------------------------------------------- tutorial

  void markTutorialDone() {
    if (_tutorialDone) return;
    _tutorialDone = true;
    _save();
    notifyListeners();
  }

  // ---------------------------------------------------------------- results

  static int starsFrom(LevelConfig config, List<bool> met, bool completed) {
    if (!completed) return 0;
    return (1 + met.skip(1).where((m) => m).length).clamp(1, 3);
  }

  RunResult recordRun({
    required LevelConfig config,
    required RunStats run,
    required bool completed,
    required int bestMultiplier,
    String? failReason,
    DateTime? now,
  }) {
    final before = {for (final a in achievements) a.id: a.isComplete(achievementContext)};
    stats
      ..runs += 1
      ..cuts += run.cuts
      ..perfectCuts += run.perfectCuts
      ..chainCuts += run.chainCuts
      ..pieces += run.piecesCollected
      ..combines += run.combines
      ..riskRoutes += run.riskRoutes
      ..relicsSaved += run.relicsSaved
      ..bestComboCount = math.max(stats.bestComboCount, run.bestCombo);

    final met = [
      for (final o in config.objectives) o.isMet(run, finished: completed, comboMultiplierBest: bestMultiplier),
    ];
    final stars = starsFrom(config, met, completed);
    var coins = run.coinsCollected;
    var previousStars = 0;
    var newBest = false;

    switch (config.mode) {
      case GameMode.campaign:
        previousStars = starsFor(config.levelId);
        if (completed) {
          final firstClear = previousStars == 0;
          stats.levelsCompleted++;
          if (run.collisions == 0) stats.noCollisionLevels++;
          coins += firstClear ? config.rewards.baseCoins : config.rewards.baseCoins ~/ 3;
          coins += math.max(0, stars - previousStars) * config.rewards.perStar;
          coins += (run.finalShards ~/ 4) * math.max(1, run.bonusMultiplier);
          if (stars > previousStars) _stars[config.levelId - 1] = stars;
          if (config.levelId >= _unlocked && config.levelId < kMaxLevel) _unlocked = config.levelId + 1;
          if (config.isTutorial) _tutorialDone = true;
          if (run.score > bestScore(config.levelId)) {
            newBest = bestScore(config.levelId) > 0;
            _bestScores['${config.levelId}'] = run.score;
          }
        }
      case GameMode.daily:
        final today = now ?? DateTime.now();
        if (completed) {
          coins += (run.finalShards ~/ 4) * math.max(1, run.bonusMultiplier);
          if (!dailyDoneFor(today)) {
            final yesterday = DailyGenerator.keyFor(today.subtract(const Duration(days: 1)));
            _dailyStreak = _dailyLast == yesterday ? _dailyStreak + 1 : 1;
            _dailyLast = DailyGenerator.keyFor(today);
            coins += config.rewards.bonus + math.min(7, _dailyStreak) * 10;
          }
        }
      case GameMode.endless:
        coins += run.finalShards ~/ 5;
        if (run.distance > endless.distance) {
          newBest = endless.distance > 0;
          endless.distance = run.distance;
        }
        endless.score = math.max(endless.score, run.score);
        endless.combo = math.max(endless.combo, run.bestCombo);
        endless.cuts = math.max(endless.cuts, run.cuts);
        endless.survival = math.max(endless.survival, run.time);
    }

    _coins += coins;
    final ctx = achievementContext;
    final unlockedNow = achievements.where((a) => !before[a.id]! && a.isComplete(ctx)).toList();
    _save();
    notifyListeners();
    return RunResult(
      config: config,
      stats: run,
      completed: completed,
      stars: stars,
      previousStars: previousStars,
      objectivesMet: met,
      coinsEarned: coins,
      bestMultiplier: bestMultiplier,
      newAchievements: unlockedNow,
      newBest: newBest,
      failReason: failReason,
    );
  }

  /// Rewarded "double coins" on the result screen.
  void doubleReward(RunResult r) {
    if (r.doubled) return;
    r.doubled = true;
    _coins += r.coinsEarned;
    r.coinsEarned *= 2;
    _save();
    notifyListeners();
  }
}
