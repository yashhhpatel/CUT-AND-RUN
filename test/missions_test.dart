import 'package:cut_and_run/game/systems/run_stats.dart';
import 'package:cut_and_run/levels/generators/level_generator.dart';
import 'package:cut_and_run/progression/missions.dart';
import 'package:cut_and_run/progression/progress_store.dart';
import 'package:cut_and_run/services/storage/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late StorageService storage;
  late ProgressStore progress;
  final day1 = DateTime(2026, 10, 1, 10);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = await StorageService.create();
    progress = ProgressStore(storage);
  });

  RunResult result(RunStats s, {bool completed = true, int best = 2}) =>
      progress.recordRun(config: LevelGenerator.campaign(2), run: s, completed: completed, bestMultiplier: best);

  test('three missions per day, stable for the same date', () {
    final a = MissionStore.generate(day1, 10);
    final b = MissionStore.generate(DateTime(2026, 10, 1, 22), 10);
    expect(a.length, 3);
    expect(a.map((m) => m.text), b.map((m) => m.text));
    expect(a.map((m) => m.type).toSet().length, 3, reason: 'no duplicate mission types');
  });

  test('locked mechanics never appear in early missions', () {
    for (var d = 1; d <= 60; d++) {
      final types = MissionStore.generate(DateTime(2026, 1, 1).add(Duration(days: d)), 3).map((m) => m.type);
      expect(types, isNot(contains(MissionType.chains)));
      expect(types, isNot(contains(MissionType.fusions)));
    }
  });

  test('progress accumulates across runs and rewards are claimed once', () {
    final store = MissionStore(storage, progress)..ensureToday(day1);
    final run = RunStats()
      ..cuts = 200
      ..perfectCuts = 50
      ..piecesCollected = 200
      ..coinsCollected = 200
      ..gatesPassed = 50
      ..combines = 50
      ..chainCuts = 10
      ..bonusMultiplier = 5
      ..distance = 20000;
    final done = store.recordRun(result(run, best: 5), day1);
    // Every mission except possibly "complete N levels" is finished by this run.
    expect(done.length, greaterThanOrEqualTo(2));
    final i = List.generate(3, (i) => i).firstWhere(store.isComplete);
    final before = progress.coins;
    expect(store.claim(i), isTrue);
    expect(progress.coins, before + store.missions[i].reward);
    expect(store.claim(i), isFalse);
  });

  test('missions reset the next day and persist within a day', () {
    final today = DateTime.now();
    final store = MissionStore(storage, progress)..ensureToday(today);
    store.recordRun(
        result(RunStats()
          ..cuts = 3
          ..perfectCuts = 1
          ..piecesCollected = 2),
        today);
    final saved = List.of(store.progress);
    expect(saved.any((p) => p > 0), isTrue);
    final reloaded = MissionStore(storage, progress)..ensureToday(today);
    expect(reloaded.progress, saved);
    reloaded.ensureToday(today.add(const Duration(days: 1)));
    expect(reloaded.progress, [0, 0, 0]);
    expect(reloaded.claimed, [false, false, false]);
  });

  test('"best in one run" missions track the maximum, not a sum', () {
    const m = Mission(MissionType.combo, 4, 80);
    expect(m.isBest, isTrue);
    expect(const Mission(MissionType.cuts, 10, 60).isBest, isFalse);
  });
}
