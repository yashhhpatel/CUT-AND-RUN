import 'dart:ui';

import 'materials.dart';

enum CutResistance {
  /// One cut of any speed.
  soft,

  /// Needs a fast, decisive swipe.
  medium,

  /// Needs two hits before it splits (first hit cracks it).
  hard,

  /// Only splits along its weak seam (or with Mega Cut).
  reinforced,

  /// Blade bounces off. Must be avoided.
  uncuttable,
}

enum SplitBehavior {
  normal,

  /// Every piece is collectible no matter its size (glass membranes).
  shatter,

  /// Emits a shockwave that cuts nearby objects (energy cells).
  chain,

  /// Reveals a hidden pickup (mystery boxes).
  reveal,

  /// Worth far more collected whole; cutting it breaks the relic.
  relic,
}

enum ObjectShape { rect, circle, hexagon, triangle, octagon }

enum Rarity { common, uncommon, rare, epic }

enum SpecialType { none, rolling, falling, relic, chain, mystery, membrane, pillar }

/// Static definition of a cuttable object type.
class ObjectDef {
  const ObjectDef({
    required this.id,
    required this.shape,
    required this.size,
    required this.material,
    this.value = 1,
    this.durability = 1,
    this.cutResistance = CutResistance.soft,
    this.rarity = Rarity.common,
    this.scoreValue = 10,
    this.splitBehavior = SplitBehavior.normal,
    String? mergeGroup,
    this.specialType = SpecialType.none,
  }) : mergeGroup = mergeGroup ?? id;

  final String id;
  final ObjectShape shape;
  final Size size;
  final MaterialKind material;

  /// Shards granted per collected piece.
  final int value;

  /// Hits required before the object splits.
  final int durability;
  final CutResistance cutResistance;
  final Rarity rarity;
  final int scoreValue;
  final SplitBehavior splitBehavior;

  /// Pieces sharing a merge group fuse together in the carry stack.
  final String mergeGroup;
  final SpecialType specialType;

  bool get cuttable => cutResistance != CutResistance.uncuttable;
}

/// Pieces at or below this area (world units²) become collectible shards.
const double kCollectArea = 5200;

abstract final class ObjectDefs {
  static const woodBlock = ObjectDef(
    id: 'wood_block',
    shape: ObjectShape.rect,
    size: Size(120, 66),
    material: MaterialKind.wood,
    mergeGroup: 'wood',
  );
  static const woodPlank = ObjectDef(
    id: 'wood_plank',
    shape: ObjectShape.rect,
    size: Size(180, 48),
    material: MaterialKind.wood,
    mergeGroup: 'wood',
  );
  static const bigCrate = ObjectDef(
    id: 'big_crate',
    shape: ObjectShape.rect,
    size: Size(170, 110),
    material: MaterialKind.wood,
    value: 1,
    scoreValue: 20,
    rarity: Rarity.uncommon,
    mergeGroup: 'wood',
  );
  static const melon = ObjectDef(
    id: 'melon',
    shape: ObjectShape.circle,
    size: Size(76, 76),
    material: MaterialKind.fruit,
    value: 2,
    scoreValue: 12,
  );
  static const rope = ObjectDef(
    id: 'rope_bundle',
    shape: ObjectShape.octagon,
    size: Size(92, 92),
    material: MaterialKind.rope,
  );
  static const jelly = ObjectDef(
    id: 'jelly_cube',
    shape: ObjectShape.rect,
    size: Size(96, 96),
    material: MaterialKind.jelly,
    rarity: Rarity.uncommon,
  );
  static const crystal = ObjectDef(
    id: 'crystal',
    shape: ObjectShape.hexagon,
    size: Size(100, 100),
    material: MaterialKind.crystal,
    value: 2,
    cutResistance: CutResistance.medium,
    rarity: Rarity.uncommon,
    scoreValue: 15,
  );
  static const prism = ObjectDef(
    id: 'prism',
    shape: ObjectShape.triangle,
    size: Size(116, 116),
    material: MaterialKind.prism,
    value: 2,
    cutResistance: CutResistance.medium,
    rarity: Rarity.uncommon,
    scoreValue: 15,
  );
  static const energyCell = ObjectDef(
    id: 'energy_cell',
    shape: ObjectShape.rect,
    size: Size(70, 90),
    material: MaterialKind.energy,
    value: 3,
    rarity: Rarity.rare,
    scoreValue: 25,
    splitBehavior: SplitBehavior.chain,
    specialType: SpecialType.chain,
  );
  static const metalCrate = ObjectDef(
    id: 'metal_crate',
    shape: ObjectShape.rect,
    size: Size(104, 104),
    material: MaterialKind.metal,
    value: 2,
    durability: 2,
    cutResistance: CutResistance.hard,
    rarity: Rarity.uncommon,
    scoreValue: 20,
  );
  static const steelSafe = ObjectDef(
    id: 'steel_safe',
    shape: ObjectShape.rect,
    size: Size(120, 80),
    material: MaterialKind.steel,
    value: 4,
    cutResistance: CutResistance.reinforced,
    rarity: Rarity.rare,
    scoreValue: 30,
  );
  static const mysteryBox = ObjectDef(
    id: 'mystery_box',
    shape: ObjectShape.rect,
    size: Size(80, 80),
    material: MaterialKind.mystery,
    rarity: Rarity.rare,
    scoreValue: 20,
    splitBehavior: SplitBehavior.reveal,
    specialType: SpecialType.mystery,
  );
  static const relic = ObjectDef(
    id: 'relic',
    shape: ObjectShape.octagon,
    size: Size(62, 62),
    material: MaterialKind.gold,
    value: 12,
    rarity: Rarity.epic,
    scoreValue: 60,
    splitBehavior: SplitBehavior.relic,
    specialType: SpecialType.relic,
  );
  static const membrane = ObjectDef(
    id: 'glass_membrane',
    shape: ObjectShape.rect,
    size: Size(130, 22),
    material: MaterialKind.glass,
    splitBehavior: SplitBehavior.shatter,
    specialType: SpecialType.membrane,
  );
  static const pillar = ObjectDef(
    id: 'obsidian_pillar',
    shape: ObjectShape.rect,
    size: Size(70, 70),
    material: MaterialKind.obsidian,
    value: 0,
    cutResistance: CutResistance.uncuttable,
    specialType: SpecialType.pillar,
  );
  static const log = ObjectDef(
    id: 'rolling_log',
    shape: ObjectShape.rect,
    size: Size(168, 44),
    material: MaterialKind.wood,
    mergeGroup: 'wood',
    scoreValue: 15,
    specialType: SpecialType.rolling,
  );

  static const all = [
    woodBlock,
    woodPlank,
    bigCrate,
    melon,
    rope,
    jelly,
    crystal,
    prism,
    energyCell,
    metalCrate,
    steelSafe,
    mysteryBox,
    relic,
    membrane,
    pillar,
    log,
  ];

  static ObjectDef byId(String id) => all.firstWhere((d) => d.id == id, orElse: () => woodBlock);
}
