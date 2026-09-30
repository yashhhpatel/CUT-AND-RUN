import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../levels/generators/mode_generators.dart';
import '../levels/models/level_config.dart';
import '../services/storage/storage_service.dart';
import 'progress_store.dart';

enum MissionType { cuts, perfectCuts, pieces, levels, combo, coins, gates, bonus, fusions, chains, endless }

class Mission {
  const Mission(this.type, this.target, this.reward);

  final MissionType type;
  final int target;
  final int reward;

  String get text {
    switch (type) {
      case MissionType.cuts:
        return 'Make $target cuts';
      case MissionType.perfectCuts:
        return 'Land $target Perfect Cuts';
      case MissionType.pieces:
        return 'Collect $target pieces';
      case MissionType.levels:
        return 'Complete $target levels';
      case MissionType.combo:
        return 'Reach a x$target combo in one run';
      case MissionType.coins:
        return 'Grab $target coins on the track';
      case MissionType.gates:
        return 'Pass through $target gates';
      case MissionType.bonus:
        return 'Reach finish bonus ×$target';
      case MissionType.fusions:
        return 'Fuse pieces $target times';
      case MissionType.chains:
        return 'Trigger $target Cut Chain${target == 1 ? '' : 's'}';
      case MissionType.endless:
        return 'Run $target m in one Endless run';
    }
  }

  /// "Best in one run" missions track a maximum instead of a running total.
  bool get isBest => type == MissionType.combo || type == MissionType.bonus || type == MissionType.endless;

  Map<String, dynamic> toJson() => {'t': type.name, 'n': target, 'r': reward};

  static Mission? fromJson(Map<String, dynamic> j) {
    final type = MissionType.values.where((t) => t.name == j['t']);
    final n = j['n'], r = j['r'];
    if (type.isEmpty || n is! num || r is! num) return null;
    return Mission(type.first, n.toInt(), r.toInt());
  }
}

/// Three fresh missions every day, chosen from the date and the player's
/// progress. Missions only use mechanics the player has already unlocked.
class MissionStore extends ChangeNotifier {
  MissionStore(this._storage, this._progress) {
    _load();
    ensureToday();
  }

  static const count = 3;
  static const _kDate = 'missions.date';
  static const _kList = 'missions.list';

  final StorageService _storage;
  final ProgressStore _progress;

  String _date = '';
  final List<Mission> missions = [];
  final List<int> progress = [];
  final List<bool> claimed = [];

  String get dateKey => _date;

  bool isComplete(int i) => progress[i] >= missions[i].target;

  int get claimable => [for (var i = 0; i < missions.length; i++) isComplete(i) && !claimed[i]].where((b) => b).length;

  void _load() {
    _date = _storage.getString(_kDate);
    final data = _storage.getJson(_kList);
    final list = data['m'];
    if (list is! List) return;
    for (final e in list) {
      if (e is! Map<String, dynamic>) continue;
      final m = Mission.fromJson(e);
      if (m == null) continue;
      missions.add(m);
      progress.add((e['p'] as num?)?.toInt() ?? 0);
      claimed.add(e['c'] == true);
    }
    if (missions.length != count) {
      missions.clear();
      progress.clear();
      claimed.clear();
      _date = '';
    }
  }

  Future<void> _save() => Future.wait([
        _storage.setString(_kDate, _date),
        _storage.setJson(_kList, {
          'm': [
            for (var i = 0; i < missions.length; i++) {...missions[i].toJson(), 'p': progress[i], 'c': claimed[i]},
          ],
        }),
      ]);

  /// Rolls over to today's missions if the day changed.
  void ensureToday([DateTime? now]) {
    final today = now ?? DateTime.now();
    final key = DailyGenerator.keyFor(today);
    if (key == _date && missions.length == count) return;
    _date = key;
    missions
      ..clear()
      ..addAll(generate(today, _progress.unlockedLevel));
    progress
      ..clear()
      ..addAll(List.filled(count, 0));
    claimed
      ..clear()
      ..addAll(List.filled(count, false));
    _save();
    notifyListeners();
  }

  /// Deterministic missions for [date], scaled to the player's level.
  static List<Mission> generate(DateTime date, int unlockedLevel) {
    final rng = math.Random(DailyGenerator.seedFor(date) * 31 + 7);
    final tier = unlockedLevel < 15 ? 0 : (unlockedLevel < 60 ? 1 : 2);
    int pick(List<int> byTier) => byTier[tier];
    final pool = <Mission>[
      Mission(MissionType.cuts, pick([25, 40, 60]), 60),
      Mission(MissionType.perfectCuts, pick([5, 8, 12]), 80),
      Mission(MissionType.pieces, pick([30, 50, 80]), 60),
      Mission(MissionType.levels, pick([2, 3, 5]), 100),
      Mission(MissionType.combo, pick([3, 4, 5]), 80),
      Mission(MissionType.coins, pick([20, 40, 60]), 60),
      Mission(MissionType.gates, pick([4, 8, 12]), 60),
      Mission(MissionType.bonus, pick([3, 4, 5]), 100),
      if (unlockedLevel >= 18) Mission(MissionType.fusions, pick([3, 5, 8]), 80),
      if (unlockedLevel >= 34) Mission(MissionType.chains, pick([1, 2, 3]), 100),
      if (unlockedLevel >= 5) Mission(MissionType.endless, pick([300, 500, 800]), 100),
    ];
    pool.shuffle(rng);
    return pool.take(count).toList();
  }

  /// Adds a finished run's stats. Returns the missions it just completed.
  List<Mission> recordRun(RunResult r, [DateTime? now]) {
    ensureToday(now);
    final s = r.stats;
    final done = <Mission>[];
    for (var i = 0; i < missions.length; i++) {
      final m = missions[i];
      final wasComplete = isComplete(i);
      final value = switch (m.type) {
        MissionType.cuts => s.cuts,
        MissionType.perfectCuts => s.perfectCuts,
        MissionType.pieces => s.piecesCollected,
        MissionType.levels => r.completed && r.config.mode != GameMode.endless ? 1 : 0,
        MissionType.combo => r.bestMultiplier,
        MissionType.coins => s.coinsCollected,
        MissionType.gates => s.gatesPassed,
        MissionType.bonus => r.completed ? s.bonusMultiplier : 0,
        MissionType.fusions => s.combines,
        MissionType.chains => s.chainCuts,
        MissionType.endless => r.config.mode == GameMode.endless ? (s.distance / 10).floor() : 0,
      };
      progress[i] = m.isBest ? math.max(progress[i], value) : progress[i] + value;
      if (!wasComplete && isComplete(i)) done.add(m);
    }
    _save();
    notifyListeners();
    return done;
  }

  bool claim(int i) {
    if (i < 0 || i >= missions.length || claimed[i] || !isComplete(i)) return false;
    claimed[i] = true;
    _progress.addCoins(missions[i].reward);
    _save();
    notifyListeners();
    return true;
  }
}
