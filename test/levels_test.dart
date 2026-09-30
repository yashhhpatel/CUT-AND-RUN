import 'package:cut_and_run/game/entities/hazard.dart';
import 'package:cut_and_run/levels/generators/level_generator.dart';
import 'package:cut_and_run/levels/generators/mode_generators.dart';
import 'package:cut_and_run/levels/models/level_config.dart';
import 'package:cut_and_run/levels/models/mechanics.dart';
import 'package:cut_and_run/levels/models/spawn.dart';
import 'package:cut_and_run/levels/worlds.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all 1000 campaign levels generate valid configs', () {
    for (var l = 1; l <= kMaxLevel; l++) {
      final c = LevelGenerator.campaign(l);
      expect(c.levelId, l);
      expect(c.pathLength, greaterThan(3000), reason: 'level $l');
      expect(c.objectives.length, 3, reason: 'level $l objectives');
      expect(c.spawns, isNotEmpty);
      for (var i = 1; i < c.spawns.length; i++) {
        expect(c.spawns[i].y, greaterThanOrEqualTo(c.spawns[i - 1].y), reason: 'level $l sorted');
      }
      for (final s in c.spawns) {
        if (s is BodySpawn && s.moveAmp == 0) {
          final w = s.width ?? s.def.size.width;
          expect(s.x - w / 2, greaterThanOrEqualTo(-1), reason: 'level $l body in track');
          expect(s.x + w / 2, lessThanOrEqualTo(kTrackWidth + 1), reason: 'level $l body in track');
        }
      }
    }
  });

  test('generation is deterministic', () {
    final a = LevelGenerator.campaign(137);
    final b = LevelGenerator.campaign(137);
    expect(a.spawns.length, b.spawns.length);
    expect(a.pathLength, b.pathLength);
    expect(a.objectives.map((o) => o.description), b.objectives.map((o) => o.description));
  });

  test('difficulty and speed increase gradually', () {
    expect(LevelGenerator.difficultyFor(500), greaterThan(LevelGenerator.difficultyFor(50)));
    expect(LevelGenerator.speedFor(1000), greaterThan(LevelGenerator.speedFor(1)));
    expect(LevelGenerator.speedFor(1000), lessThan(420));
    expect(mechanicsForLevel(1000).length, greaterThan(mechanicsForLevel(10).length));
  });

  test('early levels only use early mechanics', () {
    final c = LevelGenerator.campaign(5);
    expect(c.patterns.hazards.contains(HazardKind.laser), isFalse);
    expect(c.spawns.whereType<HazardSpawn>().any((h) => h.kind == HazardKind.crusher), isFalse);
  });

  test('tutorial covers every onboarding step', () {
    final t = LevelGenerator.campaign(1);
    expect(t.isTutorial, isTrue);
    final steps = t.spawns.whereType<HintSpawn>().map((h) => h.step).toSet();
    expect(steps, TutorialStep.values.toSet());
  });

  test('worlds cover all 1000 levels contiguously', () {
    expect(worlds.first.firstLevel, 1);
    expect(worlds.last.lastLevel, kMaxLevel);
    for (var i = 1; i < worlds.length; i++) {
      expect(worlds[i].firstLevel, worlds[i - 1].lastLevel + 1);
    }
    expect(worldForLevel(1).name, 'Training Yard');
    expect(worldForLevel(1000).name, 'Final Core');
  });

  test('daily challenge is stable per date and differs by day', () {
    final d1 = DailyGenerator.forDate(DateTime(2026, 9, 30));
    final d1b = DailyGenerator.forDate(DateTime(2026, 9, 30));
    final d2 = DailyGenerator.forDate(DateTime(2026, 10, 1));
    expect(d1.mode, GameMode.daily);
    expect(d1.spawns.length, d1b.spawns.length);
    expect(d1.seed == d2.seed, isFalse);
  });

  test('endless keeps generating content ahead', () {
    final g = EndlessGenerator(seed: 3);
    g.initialConfig();
    final more = g.extend(40000);
    expect(more, isNotEmpty);
    expect(g.generatedUntil, greaterThanOrEqualTo(40000));
  });
}
