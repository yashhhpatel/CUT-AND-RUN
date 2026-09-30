import 'package:cut_and_run/game/engine/game_events.dart';
import 'package:cut_and_run/game/engine/game_world.dart';
import 'package:cut_and_run/game/entities/body.dart';
import 'package:cut_and_run/game/model/object_defs.dart';
import 'package:cut_and_run/game/model/powerups.dart';
import 'package:cut_and_run/game/systems/cut_system.dart';
import 'package:cut_and_run/levels/models/level_config.dart';
import 'package:cut_and_run/levels/models/objective.dart';
import 'package:cut_and_run/levels/models/spawn.dart';
import 'package:flutter_test/flutter_test.dart';

LevelConfig emptyLevel({List<Spawn> spawns = const [], double length = 5000}) => LevelConfig(
      levelId: 50,
      worldId: 1,
      mode: GameMode.campaign,
      seed: 1,
      speed: 250,
      pathLength: length,
      difficulty: 0.2,
      segments: const [],
      objectives: const [Objective(ObjectiveType.reachFinish)],
      rewards: const LevelRewards(baseCoins: 10, perStar: 5),
      patterns: const LevelPatterns(objects: [], hazards: [], gates: [], powerUps: [PowerUpType.magnet]),
      specialMechanics: const {},
      spawns: spawns,
    );

Body place(GameWorld w, ObjectDef def,
    {double x = 200, double y = 400, SeamKind seam = SeamKind.none, bool target = false}) {
  final b = w.buildBody(BodySpawn(y: y, def: def, x: x, seam: seam, seamIsTarget: target));
  w.addBody(b);
  return b;
}

void main() {
  late GameWorld w;
  setUp(() => w = GameWorld(emptyLevel()));

  test('soft block splits into two real pieces that are collectible', () {
    final b = place(w, ObjectDefs.woodBlock);
    final out = w.cutter.attemptCut(b, const Offset(200, 300), const Offset(200, 500));
    expect(out, CutOutcome.split);
    final pieces = w.bodies.where((p) => !p.removed).toList();
    expect(pieces.length, 2);
    expect(pieces.every((p) => p.isPiece && p.collectible), isTrue);
    final total = pieces.fold<double>(0, (s, p) => s + p.area);
    expect(total, closeTo(b.area, 1));
    expect(w.stats.cuts, 1);
    expect(w.events.any((e) => e.type == GameEventType.perfectCut), isTrue, reason: 'centre cut = equal halves');
  });

  test('pieces separate and spin after a cut', () {
    final b = place(w, ObjectDefs.woodBlock);
    w.cutter.attemptCut(b, const Offset(200, 300), const Offset(200, 500));
    final pieces = w.bodies.where((p) => !p.removed).toList();
    expect(pieces[0].vel.dx.sign, isNot(pieces[1].vel.dx.sign));
    expect(pieces.every((p) => p.spin != 0), isTrue);
  });

  test('off-centre cut on a big crate leaves a solid (dangerous) piece', () {
    final b = place(w, ObjectDefs.bigCrate);
    w.cutter.attemptCut(b, const Offset(150, 300), const Offset(150, 500));
    final pieces = w.bodies.where((p) => !p.removed).toList();
    expect(pieces.where((p) => p.solid).length, greaterThanOrEqualTo(1));
    expect(w.stats.perfectCuts, 0);
  });

  test('medium resistance needs a fast swipe', () {
    final b = place(w, ObjectDefs.crystal);
    expect(w.cutter.attemptCut(b, const Offset(200, 300), const Offset(200, 500), speed: 200), CutOutcome.tooSlow);
    expect(w.cutter.attemptCut(b, const Offset(200, 300), const Offset(200, 500), speed: 2500), CutOutcome.split);
  });

  test('hard resistance cracks first, then splits', () {
    final b = place(w, ObjectDefs.metalCrate);
    expect(w.cutter.attemptCut(b, const Offset(200, 300), const Offset(200, 500)), CutOutcome.cracked);
    expect(b.cracks.length, 1);
    b.cutCooldown = 0;
    expect(w.cutter.attemptCut(b, const Offset(200, 300), const Offset(200, 500)), CutOutcome.split);
  });

  test('reinforced steel only splits along its seam (perfect)', () {
    final b = place(w, ObjectDefs.steelSafe, seam: SeamKind.vertical);
    expect(w.cutter.attemptCut(b, const Offset(150, 300), const Offset(150, 500)), CutOutcome.missedSeam);
    expect(w.cutter.attemptCut(b, const Offset(200, 300), const Offset(200, 500)), CutOutcome.split);
    expect(w.stats.perfectCuts, 1);
  });

  test('mega cut ignores reinforcement', () {
    final b = place(w, ObjectDefs.steelSafe, seam: SeamKind.vertical);
    expect(w.cutter.attemptCut(b, const Offset(150, 300), const Offset(150, 500), mega: true), CutOutcome.split);
  });

  test('uncuttable deflects the blade', () {
    final b = place(w, ObjectDefs.pillar);
    expect(w.cutter.attemptCut(b, const Offset(200, 300), const Offset(200, 500)), CutOutcome.deflected);
    expect(b.removed, isFalse);
  });

  test('swipe gestures drive cuts through the stroke pipeline', () {
    place(w, ObjectDefs.woodBlock, y: 400);
    w.cutter.begin(const Offset(200, 480));
    w.cutter.move(const Offset(200, 400), 3000);
    w.cutter.move(const Offset(200, 320), 3000);
    w.cutter.end();
    expect(w.stats.cuts, 1);
  });

  test('energy cell triggers a chain cut on neighbours', () {
    final cell = place(w, ObjectDefs.energyCell, x: 200, y: 400);
    place(w, ObjectDefs.woodBlock, x: 90, y: 400);
    place(w, ObjectDefs.woodBlock, x: 310, y: 400);
    w.cutter.attemptCut(cell, const Offset(200, 300), const Offset(200, 500));
    for (var i = 0; i < 20; i++) {
      w.update(1 / 60);
    }
    expect(w.stats.chainCuts, 1);
    expect(w.stats.bestChain, 2);
    expect(w.stats.cuts, 3);
  });

  test('mystery box reveals a pickup', () {
    final b = place(w, ObjectDefs.mysteryBox);
    w.cutter.attemptCut(b, const Offset(200, 300), const Offset(200, 500));
    expect(w.pickups, isNotEmpty);
    expect(w.stats.specialCuts, 1);
  });

  test('cutting a relic breaks it', () {
    final b = place(w, ObjectDefs.relic);
    w.cutter.attemptCut(b, const Offset(200, 300), const Offset(200, 500));
    expect(w.stats.relicsBroken, 1);
  });
}
