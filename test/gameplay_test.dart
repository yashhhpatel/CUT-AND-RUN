import 'package:cut_and_run/game/engine/game_world.dart';
import 'package:cut_and_run/game/entities/gate.dart';
import 'package:cut_and_run/game/entities/hazard.dart';
import 'package:cut_and_run/game/model/object_defs.dart';
import 'package:cut_and_run/game/model/powerups.dart';
import 'package:cut_and_run/levels/generators/level_generator.dart';
import 'package:cut_and_run/levels/models/level_config.dart';
import 'package:cut_and_run/levels/models/objective.dart';
import 'package:cut_and_run/levels/models/spawn.dart';
import 'package:flutter_test/flutter_test.dart';

import 'bot.dart';

LevelConfig level(List<Spawn> spawns, {double length = 3000, bool tutorial = false}) => LevelConfig(
      levelId: 40,
      worldId: 2,
      mode: GameMode.campaign,
      seed: 7,
      speed: 260,
      pathLength: length,
      difficulty: 0.2,
      segments: const [],
      objectives: const [Objective(ObjectiveType.reachFinish), Objective(ObjectiveType.makeCuts, 1)],
      rewards: const LevelRewards(baseCoins: 10, perStar: 5),
      patterns: const LevelPatterns(objects: [], hazards: [], gates: [], powerUps: []),
      specialMechanics: const {},
      spawns: spawns..sort((a, b) => a.y.compareTo(b.y)),
      isTutorial: tutorial,
    );

void run(GameWorld w, double seconds, {void Function()? each}) {
  const dt = 1 / 60;
  for (var t = 0.0; t < seconds; t += dt) {
    each?.call();
    w.update(dt);
    w.events.clear();
    if (w.status != RunStatus.running) break;
  }
}

void main() {
  test('player runs forward automatically and steers responsively', () {
    final w = GameWorld(level([]));
    w.moveBy(100);
    run(w, 0.3);
    expect(w.player.y, greaterThan(60));
    expect(w.player.x, closeTo(300, 5));
    w.moveBy(-1000);
    run(w, 0.3);
    expect(w.player.x, closeTo(kPlayerMinX, 6));
  });

  test('collecting ready-cut pieces adds shards', () {
    final w = GameWorld(level([
      const BodySpawn(y: 200, def: ObjectDefs.woodBlock, x: 200, width: 40, height: 30, asPiece: true),
      const BodySpawn(y: 260, def: ObjectDefs.melon, x: 200, width: 40, height: 40, asPiece: true),
    ]));
    run(w, 1.5);
    expect(w.stats.piecesCollected, 2);
    expect(w.carry.shards, 3);
  });

  test('crashing into an uncut block fails the level', () {
    final w = GameWorld(level([const BodySpawn(y: 300, def: ObjectDefs.woodBlock, x: 200)]));
    run(w, 3);
    expect(w.status, RunStatus.failed);
    expect(w.failReason, contains('Crashed'));
    w.revive();
    expect(w.status, RunStatus.running);
    run(w, 1);
    expect(w.status, RunStatus.running);
  });

  test('cutting the block and running through its pieces succeeds', () {
    final w = GameWorld(level([const BodySpawn(y: 400, def: ObjectDefs.woodBlock, x: 200)], length: 900));
    var cut = false;
    run(w, 6, each: () {
      if (!cut && w.player.y > 100) {
        cut = true;
        w.cutter.begin(const Offset(200, 470));
        w.cutter.move(const Offset(203, 400), 3000);
        w.cutter.move(const Offset(206, 330), 3000);
        w.cutter.end();
      }
    });
    expect(w.status, RunStatus.completed);
    expect(w.stats.cuts, 1);
    expect(w.stats.piecesCollected, greaterThanOrEqualTo(1));
  });

  test('hazards kill, shields save', () {
    final spikes = [const HazardSpawn(y: 300, kind: HazardKind.spikes, x: 200, w: 200, h: 34)];
    final w = GameWorld(level(List.of(spikes)));
    run(w, 3);
    expect(w.status, RunStatus.failed);
    expect(w.failReason, contains('spikes'));

    final w2 = GameWorld(level(List.of(spikes)));
    w2.grantPowerUp(PowerUpType.shield, Offset.zero);
    run(w2, 3);
    expect(w2.status, RunStatus.running);
    expect(w2.player.shields, 0);
    expect(w2.stats.collisions, 1);
  });

  test('pits make the runner fall', () {
    final w = GameWorld(level([const HazardSpawn(y: 300, kind: HazardKind.pit, x: 200, w: 200, h: 120)]));
    run(w, 3);
    expect(w.status, RunStatus.failed);
    expect(w.failReason, contains('pit'));
  });

  test('gates apply their effect for the chosen side', () {
    final w = GameWorld(level([
      GateSpawn(y: 300, options: [
        GateOption(x0: 0, x1: 200, type: GateType.multiply, value: 2),
        GateOption(x0: 200, x1: 400, type: GateType.subtract, value: 3),
      ]),
    ]));
    w.carry.shards = 5;
    w.moveBy(-100);
    run(w, 2);
    expect(w.carry.shards, 10);
    expect(w.stats.perfectGates, 1);

    final w2 = GameWorld(level([
      GateSpawn(y: 300, options: [
        GateOption(x0: 0, x1: 200, type: GateType.multiply, value: 2),
        GateOption(x0: 200, x1: 400, type: GateType.subtract, value: 3),
      ]),
    ]));
    w2.carry.shards = 5;
    w2.moveBy(100);
    run(w2, 2);
    expect(w2.carry.shards, 2);
    expect(w2.stats.gateFails, 1);
  });

  test('quantity gate rewards only when requirement is met', () {
    final w = GameWorld(level([
      GateSpawn(y: 300, options: [GateOption(x0: 0, x1: 400, type: GateType.quantity, value: 10)]),
    ]));
    w.carry.shards = 4;
    run(w, 2);
    expect(w.stats.gateFails, 1);
    expect(w.carry.shards, 3);
  });

  test('reaching the finish completes the level and banks shards', () {
    final w = GameWorld(level([], length: 500));
    w.carry.shards = 7;
    run(w, 4);
    expect(w.status, RunStatus.completed);
    expect(w.stats.finalShards, 7);
    expect(w.stats.score, greaterThanOrEqualTo(70));
  });

  test('finish ladder: shards buy ×2…×5 and set the bonus multiplier', () {
    final w = GameWorld(level([], length: 500));
    w.carry.shards = 21;
    run(w, 12);
    expect(w.status, RunStatus.completed);
    expect(w.stats.finalShards, 21, reason: 'shards counted at the finish line');
    expect(w.bonusMultiplier, 5);
    expect(w.stats.bonusMultiplier, 5);
    expect(w.carry.shards, 1, reason: '4 barriers × 5 shards paid');
  });

  test('finish ladder stops at the first barrier the player cannot afford', () {
    final w = GameWorld(level([], length: 500));
    w.carry.shards = 7;
    run(w, 12);
    expect(w.status, RunStatus.completed);
    expect(w.stats.bonusMultiplier, 2);
    final stoppedAt = w.player.y;
    run(w, 2);
    expect(w.player.y, lessThan(w.bonusStepY(3) + 30), reason: 'runner halts at the ×3 barrier');
    expect(stoppedAt, lessThan(w.bonusStepY(3)));
  });

  test('gate results fly to the HUD', () {
    final w = GameWorld(level([
      GateSpawn(y: 300, options: [GateOption(x0: 0, x1: 400, type: GateType.add, value: 6)]),
    ]));
    run(w, 1.4);
    expect(w.carry.shards, 6);
    expect(w.hudFlies.map((f) => f.text), contains('+6'));
  });

  test('tutorial never hard-fails on a collision', () {
    final w = GameWorld(level([const BodySpawn(y: 300, def: ObjectDefs.woodBlock, x: 200)], tutorial: true));
    run(w, 3);
    expect(w.status, RunStatus.running);
  });

  test('magnet pulls collectibles in', () {
    final w = GameWorld(level([
      const BodySpawn(y: 300, def: ObjectDefs.woodBlock, x: 330, width: 40, height: 30, asPiece: true),
    ]));
    w.grantPowerUp(PowerUpType.magnet, Offset.zero);
    run(w, 2);
    expect(w.stats.piecesCollected, 1);
  });

  test('auto cutter slices blockers ahead', () {
    final w = GameWorld(level([const BodySpawn(y: 500, def: ObjectDefs.woodBlock, x: 200)], length: 1200));
    w.grantPowerUp(PowerUpType.autoCutter, Offset.zero);
    run(w, 6);
    expect(w.stats.cuts, greaterThanOrEqualTo(1));
    expect(w.status, RunStatus.completed);
  });

  test('bot can play generated levels end to end without errors', () {
    final results = <int, String>{};
    var completed = 0;
    for (final l in [1, 2, 5, 10, 20, 35, 60, 120, 250, 500, 800, 1000]) {
      final w = GameWorld(LevelGenerator.campaign(l));
      final bot = Bot(w);
      run(w, 200, each: bot.step);
      results[l] = '${w.status.name} ${(w.progress * 100).round()}% cuts=${w.stats.cuts} ${w.failReason ?? ''}';
      if (w.status == RunStatus.completed) completed++;
    }
    // ignore: avoid_print
    print(results.entries.map((e) => 'L${e.key}: ${e.value}').join('\n'));
    expect(results[1], startsWith('completed'), reason: 'tutorial must be completable');
    expect(completed, greaterThanOrEqualTo(6));
  });
}

const double kPlayerMinX = 22; // Player.radius + 4 clamp.
