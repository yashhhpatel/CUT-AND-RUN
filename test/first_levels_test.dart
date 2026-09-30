import 'package:cut_and_run/game/engine/game_world.dart';
import 'package:cut_and_run/levels/generators/level_generator.dart';
import 'package:cut_and_run/progression/progress_store.dart';
import 'package:flutter_test/flutter_test.dart';

import 'bot.dart';

/// Plays levels 1–20 end to end with the scripted bot and checks every one
/// can be completed with all 3 stars. Prints a per-level report.
void main() {
  test('levels 1-20 are completable', () {
    final lines = <String>[];
    final failed = <int>[];
    final notThreeStars = <int>[];
    for (var l = 1; l <= 20; l++) {
      final cfg = LevelGenerator.campaign(l);
      final w = GameWorld(cfg);
      final bot = Bot(w, greedy: true);
      const dt = 1 / 60;
      for (var t = 0.0; t < 240 && w.status == RunStatus.running; t += dt) {
        bot.step();
        w.update(dt);
        w.events.clear();
      }
      final done = w.status == RunStatus.completed;
      if (!done) failed.add(l);
      final met = [
        for (final o in cfg.objectives) o.isMet(w.stats, finished: done, comboMultiplierBest: w.bestMultiplier),
      ];
      final stars = ProgressStore.starsFrom(cfg, met, done);
      if (stars < 3) notThreeStars.add(l);
      lines.add('L${l.toString().padLeft(2)} ${done ? 'COMPLETE' : 'FAILED  '} '
          '${(w.progress * 100).round().toString().padLeft(3)}%  stars=$stars  '
          'time=${w.stats.time.toStringAsFixed(0)}s cuts=${w.stats.cuts} perfect=${w.stats.perfectCuts} '
          'pieces=${w.stats.piecesCollected} shards=${w.carry.shards} coins=${w.stats.coinsCollected} '
          'gates=${w.stats.gatesPassed} combo=x${w.bestMultiplier} hits=${w.stats.collisions}'
          '${w.failReason != null ? '  <- ${w.failReason}' : ''}');
    }
    // ignore: avoid_print
    print(lines.join('\n'));
    expect(failed, isEmpty, reason: 'levels failed: $failed');
    expect(notThreeStars, isEmpty, reason: 'every objective must be achievable: $notThreeStars');
  });
}
