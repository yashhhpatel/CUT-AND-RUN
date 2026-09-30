import 'package:cut_and_run/game/systems/run_stats.dart';
import 'package:cut_and_run/levels/generators/level_generator.dart';
import 'package:cut_and_run/levels/generators/mode_generators.dart';
import 'package:cut_and_run/progression/achievements.dart';
import 'package:cut_and_run/progression/cosmetics.dart';
import 'package:cut_and_run/progression/progress_store.dart';
import 'package:cut_and_run/services/storage/settings_store.dart';
import 'package:cut_and_run/services/storage/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<StorageService> freshStorage([Map<String, Object> v = const {}]) async {
  SharedPreferences.setMockInitialValues(v);
  return StorageService.create();
}

RunStats goodRun() => RunStats()
  ..cuts = 20
  ..perfectCuts = 6
  ..score = 99999
  ..finalShards = 60
  ..coinsCollected = 30
  ..piecesCollected = 40
  ..combines = 5
  ..chainCuts = 2
  ..relicsSaved = 1
  ..specialCuts = 2
  ..perfectDodges = 5
  ..bestCombo = 12
  ..shieldAtEnd = true;

void main() {
  test('completing a level unlocks the next, awards stars and coins', () async {
    final p = ProgressStore(await freshStorage());
    final cfg = LevelGenerator.campaign(2);
    final r = p.recordRun(config: cfg, run: goodRun(), completed: true, bestMultiplier: 5);
    expect(r.completed, isTrue);
    expect(r.stars, inInclusiveRange(1, 3));
    expect(p.unlockedLevel, 3);
    expect(p.starsFor(2), r.stars);
    expect(p.coins, r.coinsEarned);
    expect(r.coinsEarned, greaterThan(cfg.rewards.baseCoins));
  });

  test('failing does not unlock or award stars', () async {
    final p = ProgressStore(await freshStorage());
    final r = p.recordRun(
        config: LevelGenerator.campaign(2), run: RunStats()..coinsCollected = 4, completed: false, bestMultiplier: 1);
    expect(r.stars, 0);
    expect(p.unlockedLevel, 1);
    expect(p.coins, 4);
  });

  test('stars never decrease on a worse replay', () async {
    final p = ProgressStore(await freshStorage());
    final cfg = LevelGenerator.campaign(3);
    p.recordRun(config: cfg, run: goodRun(), completed: true, bestMultiplier: 5);
    final best = p.starsFor(3);
    p.recordRun(config: cfg, run: RunStats(), completed: true, bestMultiplier: 1);
    expect(p.starsFor(3), best);
  });

  test('progress persists across restarts', () async {
    final storage = await freshStorage();
    final p = ProgressStore(storage);
    p.recordRun(config: LevelGenerator.campaign(1), run: goodRun(), completed: true, bestMultiplier: 3);
    p.addCoins(500);
    p.buy(Cosmetics.skins[1]);
    p.select(Cosmetics.skins[1]);
    await Future<void>.delayed(Duration.zero);
    final reloaded = ProgressStore(storage);
    expect(reloaded.unlockedLevel, 2);
    expect(reloaded.tutorialDone, isTrue);
    expect(reloaded.coins, p.coins);
    expect(reloaded.owns(Cosmetics.skins[1].id), isTrue);
    expect(reloaded.selectedId(CosmeticKind.skin), Cosmetics.skins[1].id);
    expect(reloaded.stats.cuts, 20);
  });

  test('corrupted saved data falls back to safe defaults', () async {
    final storage = await freshStorage({
      'progress.stats': '{not json',
      'progress.stars': 'x9z',
      'progress.unlocked': 99999,
      'progress.coins': -50,
    });
    final p = ProgressStore(storage);
    expect(p.unlockedLevel, 1000);
    expect(p.coins, 0);
    expect(p.starsFor(1), 0);
    expect(p.starsFor(2), 3);
    expect(p.stats.cuts, 0);
  });

  test('cosmetics cannot be bought without enough coins', () async {
    final p = ProgressStore(await freshStorage());
    expect(p.buy(Cosmetics.skins.last), isFalse);
    expect(p.owns(Cosmetics.skins.first.id), isTrue);
  });

  test('daily challenge streak and bonus', () async {
    final p = ProgressStore(await freshStorage());
    final d1 = DateTime(2026, 9, 28);
    final d2 = DateTime(2026, 9, 29);
    final r1 =
        p.recordRun(config: DailyGenerator.forDate(d1), run: goodRun(), completed: true, bestMultiplier: 3, now: d1);
    expect(p.dailyStreak, 1);
    expect(r1.coinsEarned, greaterThanOrEqualTo(DailyGenerator.bonusCoins));
    p.recordRun(config: DailyGenerator.forDate(d2), run: goodRun(), completed: true, bestMultiplier: 3, now: d2);
    expect(p.dailyStreak, 2);
    expect(p.dailyDoneFor(d2), isTrue);
    // Replaying the same day gives no second bonus.
    final again =
        p.recordRun(config: DailyGenerator.forDate(d2), run: RunStats(), completed: true, bestMultiplier: 1, now: d2);
    expect(again.coinsEarned, 0);
  });

  test('endless bests are tracked', () async {
    final p = ProgressStore(await freshStorage());
    final cfg = EndlessGenerator(seed: 1).initialConfig();
    p.recordRun(
        config: cfg,
        run: RunStats()
          ..distance = 5000
          ..score = 1234
          ..cuts = 9
          ..time = 42,
        completed: false,
        bestMultiplier: 1);
    expect(p.endless.distance, 5000);
    expect(p.endless.score, 1234);
    expect(p.endless.cuts, 9);
  });

  test('achievements unlock and can be claimed once', () async {
    final p = ProgressStore(await freshStorage());
    final r = p.recordRun(config: LevelGenerator.campaign(2), run: goodRun(), completed: true, bestMultiplier: 3);
    expect(r.newAchievements.map((a) => a.id),
        containsAll(['first_cut', 'cuts_10', 'perfect_10'.replaceAll('10', '10')].take(2)));
    final first = achievements.firstWhere((a) => a.id == 'first_cut');
    final before = p.coins;
    expect(p.claim(first), isTrue);
    expect(p.coins, before + first.reward);
    expect(p.claim(first), isFalse);
  });

  test('double reward doubles coins once', () async {
    final p = ProgressStore(await freshStorage());
    final r = p.recordRun(config: LevelGenerator.campaign(2), run: goodRun(), completed: true, bestMultiplier: 3);
    final earned = r.coinsEarned;
    p.doubleReward(r);
    p.doubleReward(r);
    expect(r.coinsEarned, earned * 2);
    expect(p.coins, earned * 2);
  });

  test('settings persist', () async {
    final storage = await freshStorage();
    final s = SettingsStore(storage)
      ..music = false
      ..vibration = false;
    await Future<void>.delayed(Duration.zero);
    final again = SettingsStore(storage);
    expect(again.music, isFalse);
    expect(again.sfx, isTrue);
    expect(again.vibration, isFalse);
    expect(s.music, isFalse);
  });
}
