import 'package:cut_and_run/game/model/object_defs.dart';
import 'package:cut_and_run/game/systems/combine_system.dart';
import 'package:cut_and_run/game/systems/combo_system.dart';
import 'package:cut_and_run/game/systems/run_stats.dart';
import 'package:cut_and_run/levels/models/objective.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('combine (A + A + A = B)', () {
    test('three matching pieces fuse into a higher tier with bonus shards', () {
      final c = CarryStack();
      c.add(ObjectDefs.woodBlock, 1);
      c.add(ObjectDefs.woodBlock, 1);
      final r = c.add(ObjectDefs.woodBlock, 1);
      expect(r.length, 1);
      expect(r.first.tier, 1);
      expect(c.items.length, 1);
      expect(c.shards, 3 + CarryStack.bonusFor(1));
    });

    test('fusion cascades up to the max tier', () {
      final c = CarryStack();
      var fusions = 0;
      for (var i = 0; i < 9; i++) {
        fusions += c.add(ObjectDefs.melon, 2).length;
      }
      expect(fusions, 4); // 3 × tier1 + 1 × tier2
      expect(c.items.single.tier, 2);
    });

    test('different materials do not fuse', () {
      final c = CarryStack();
      c.add(ObjectDefs.woodBlock, 1);
      c.add(ObjectDefs.melon, 2);
      expect(c.add(ObjectDefs.crystal, 2), isEmpty);
    });

    test('fusion gate fuses pairs', () {
      final c = CarryStack();
      c.add(ObjectDefs.woodBlock, 1);
      c.add(ObjectDefs.woodBlock, 1);
      expect(c.fuseAllPairs().length, 1);
    });

    test('removing shards clamps at zero and trims items', () {
      final c = CarryStack();
      c.add(ObjectDefs.woodBlock, 1);
      c.add(ObjectDefs.melon, 2);
      expect(c.remove(10), 3);
      expect(c.shards, 0);
      expect(c.items, isEmpty);
    });
  });

  group('combo', () {
    test('multiplier rises every 4 actions and caps', () {
      final c = ComboSystem();
      expect(c.multiplier, 1);
      c.add(4);
      expect(c.multiplier, 2);
      c.add(100);
      expect(c.multiplier, ComboSystem.maxMultiplier);
      c.boost = true;
      expect(c.multiplier, ComboSystem.maxMultiplier + 1);
    });

    test('combo expires after the window', () {
      final c = ComboSystem()..add(5);
      c.update(ComboSystem.window + 0.1);
      expect(c.count, 0);
      expect(c.best, 5);
    });
  });

  group('objectives', () {
    test('secondary objectives require finishing', () {
      final s = RunStats()..cuts = 10;
      const o = Objective(ObjectiveType.makeCuts, 5);
      expect(o.isMet(s, finished: false, comboMultiplierBest: 1), isFalse);
      expect(o.isMet(s, finished: true, comboMultiplierBest: 1), isTrue);
    });

    test('combo objective uses best multiplier', () {
      const o = Objective(ObjectiveType.reachCombo, 3);
      expect(o.isMet(RunStats(), finished: true, comboMultiplierBest: 2), isFalse);
      expect(o.isMet(RunStats(), finished: true, comboMultiplierBest: 3), isTrue);
    });

    test('every objective has a readable description', () {
      for (final t in ObjectiveType.values) {
        expect(Objective(t, 2).description, isNotEmpty);
      }
    });
  });
}
