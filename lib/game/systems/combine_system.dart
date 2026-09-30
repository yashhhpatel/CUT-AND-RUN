import '../model/materials.dart';
import '../model/object_defs.dart';

/// One collected piece riding in the player's carry stack.
class CarryItem {
  CarryItem(this.group, this.material, this.tier);
  final String group;
  final MaterialKind material;
  int tier;

  /// 1 → 0 pop animation after collect/fuse.
  double pop = 1;
}

class CombineResult {
  const CombineResult(this.group, this.material, this.tier, this.bonus);
  final String group;
  final MaterialKind material;

  /// Tier of the newly created item (1 or 2).
  final int tier;

  /// Extra shards granted by the fusion.
  final int bonus;
}

/// CUT → SPLIT → COMBINE. Three matching pieces of the same tier fuse into one
/// stronger piece worth bonus shards. Tiers: 0 = shard, 1 = ingot, 2 = core.
class CarryStack {
  static const maxTier = 2;
  static const fuseCount = 3;
  static const maxItems = 36;

  final List<CarryItem> items = [];
  int shards = 0;
  int relics = 0;

  static int bonusFor(int newTier) => newTier == 1 ? 2 : 6;

  /// Adds a collected piece and resolves any fusions it triggers.
  List<CombineResult> add(ObjectDef def, int shardValue) {
    shards += shardValue;
    items.add(CarryItem(def.mergeGroup, def.material, 0));
    final results = <CombineResult>[];
    var changed = true;
    while (changed) {
      changed = false;
      for (var tier = 0; tier < maxTier; tier++) {
        final matches = items.where((i) => i.group == def.mergeGroup && i.tier == tier).toList();
        if (matches.length >= fuseCount) {
          results.add(_fuse(matches.take(fuseCount).toList(), tier + 1));
          changed = true;
          break;
        }
      }
    }
    _cap();
    return results;
  }

  CombineResult _fuse(List<CarryItem> parts, int newTier) {
    final keep = parts.first;
    for (final p in parts.skip(1)) {
      items.remove(p);
    }
    keep.tier = newTier;
    keep.pop = 1;
    final bonus = bonusFor(newTier);
    shards += bonus;
    return CombineResult(keep.group, keep.material, newTier, bonus);
  }

  /// Fusion gate: every pair of matching items fuses (a gentler rule than the
  /// automatic triple fusion).
  List<CombineResult> fuseAllPairs() {
    final results = <CombineResult>[];
    var changed = true;
    while (changed) {
      changed = false;
      for (var i = 0; i < items.length && !changed; i++) {
        final a = items[i];
        if (a.tier >= maxTier) continue;
        for (var j = i + 1; j < items.length; j++) {
          final b = items[j];
          if (b.group == a.group && b.tier == a.tier) {
            results.add(_fuse([a, b], a.tier + 1));
            changed = true;
            break;
          }
        }
      }
    }
    return results;
  }

  int countMaterial(MaterialKind m) => items.where((i) => i.material == m).length;

  /// Removes shards (clamped at zero) and trims visual items to match.
  int remove(int n) {
    final removed = n.clamp(0, shards);
    shards -= removed;
    var toDrop = removed;
    while (toDrop > 0 && items.isNotEmpty) {
      // Drop lowest tier first.
      items.sort((a, b) => a.tier.compareTo(b.tier));
      items.removeAt(0);
      toDrop -= 1;
    }
    if (shards == 0) items.clear();
    return removed;
  }

  void multiply(int factor) {
    shards *= factor;
  }

  void _cap() {
    while (items.length > maxItems) {
      final idx = items.indexWhere((i) => i.tier == 0);
      items.removeAt(idx >= 0 ? idx : 0);
    }
  }
}
