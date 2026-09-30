import 'dart:ui';

enum DecorStyle { yard, factory, crystal, jungle, city, frost, sky, space, quantum, core }

/// Visual identity of a world. Gameplay stays consistent; only the look evolves.
class WorldDef {
  const WorldDef({
    required this.id,
    required this.name,
    required this.firstLevel,
    required this.lastLevel,
    required this.bgTop,
    required this.bgBottom,
    required this.floorA,
    required this.floorB,
    required this.rail,
    required this.accent,
    required this.decor,
    required this.particle,
  });

  final int id;
  final String name;
  final int firstLevel;
  final int lastLevel;
  final Color bgTop;
  final Color bgBottom;
  final Color floorA;
  final Color floorB;
  final Color rail;
  final Color accent;
  final DecorStyle decor;

  /// Ambient particle colour.
  final Color particle;

  int get levelCount => lastLevel - firstLevel + 1;
}

const kMaxLevel = 1000;

const worlds = <WorldDef>[
  WorldDef(
    id: 1,
    name: 'Training Yard',
    firstLevel: 1,
    lastLevel: 20,
    bgTop: Color(0xFF1E2A4A),
    bgBottom: Color(0xFF121A30),
    floorA: Color(0xFF2B3A5E),
    floorB: Color(0xFF283657),
    rail: Color(0xFFFFB03D),
    accent: Color(0xFFFF8A3D),
    decor: DecorStyle.yard,
    particle: Color(0x55FFD28A),
  ),
  WorldDef(
    id: 2,
    name: 'Neon Factory',
    firstLevel: 21,
    lastLevel: 50,
    bgTop: Color(0xFF231A45),
    bgBottom: Color(0xFF120E28),
    floorA: Color(0xFF2E2656),
    floorB: Color(0xFF2A2250),
    rail: Color(0xFFFF4DA6),
    accent: Color(0xFF3DD6F5),
    decor: DecorStyle.factory,
    particle: Color(0x55FF7DC4),
  ),
  WorldDef(
    id: 3,
    name: 'Crystal Valley',
    firstLevel: 51,
    lastLevel: 100,
    bgTop: Color(0xFF15304A),
    bgBottom: Color(0xFF0C1C30),
    floorA: Color(0xFF1F4263),
    floorB: Color(0xFF1C3D5C),
    rail: Color(0xFF7FE3FF),
    accent: Color(0xFFA6DDFF),
    decor: DecorStyle.crystal,
    particle: Color(0x559CE7FF),
  ),
  WorldDef(
    id: 4,
    name: 'Jungle Run',
    firstLevel: 101,
    lastLevel: 175,
    bgTop: Color(0xFF14362A),
    bgBottom: Color(0xFF0B2019),
    floorA: Color(0xFF274A33),
    floorB: Color(0xFF23452F),
    rail: Color(0xFFB5E655),
    accent: Color(0xFFFFD23D),
    decor: DecorStyle.jungle,
    particle: Color(0x55C8FF8A),
  ),
  WorldDef(
    id: 5,
    name: 'Mechanical City',
    firstLevel: 176,
    lastLevel: 275,
    bgTop: Color(0xFF2E2A33),
    bgBottom: Color(0xFF18161C),
    floorA: Color(0xFF3B3842),
    floorB: Color(0xFF36333D),
    rail: Color(0xFFFFA63D),
    accent: Color(0xFFFFC940),
    decor: DecorStyle.city,
    particle: Color(0x55FFB86B),
  ),
  WorldDef(
    id: 6,
    name: 'Frozen Lab',
    firstLevel: 276,
    lastLevel: 400,
    bgTop: Color(0xFF203C55),
    bgBottom: Color(0xFF122436),
    floorA: Color(0xFF3A5A78),
    floorB: Color(0xFF365572),
    rail: Color(0xFFDDF4FF),
    accent: Color(0xFF7FD3FF),
    decor: DecorStyle.frost,
    particle: Color(0x77FFFFFF),
  ),
  WorldDef(
    id: 7,
    name: 'Sky Factory',
    firstLevel: 401,
    lastLevel: 550,
    bgTop: Color(0xFF2F4F8F),
    bgBottom: Color(0xFF1A2D5C),
    floorA: Color(0xFF3F5E9A),
    floorB: Color(0xFF3A5893),
    rail: Color(0xFFFFFFFF),
    accent: Color(0xFFFFC940),
    decor: DecorStyle.sky,
    particle: Color(0x66FFFFFF),
  ),
  WorldDef(
    id: 8,
    name: 'Space Station',
    firstLevel: 551,
    lastLevel: 700,
    bgTop: Color(0xFF0E0F24),
    bgBottom: Color(0xFF05060F),
    floorA: Color(0xFF22254A),
    floorB: Color(0xFF1F2244),
    rail: Color(0xFF8A7DFF),
    accent: Color(0xFF3DD6F5),
    decor: DecorStyle.space,
    particle: Color(0x88FFFFFF),
  ),
  WorldDef(
    id: 9,
    name: 'Quantum Zone',
    firstLevel: 701,
    lastLevel: 850,
    bgTop: Color(0xFF2A0F3D),
    bgBottom: Color(0xFF140620),
    floorA: Color(0xFF3A1D52),
    floorB: Color(0xFF351A4B),
    rail: Color(0xFF3DF5C3),
    accent: Color(0xFFFF7BB0),
    decor: DecorStyle.quantum,
    particle: Color(0x663DF5C3),
  ),
  WorldDef(
    id: 10,
    name: 'Final Core',
    firstLevel: 851,
    lastLevel: 1000,
    bgTop: Color(0xFF3D130F),
    bgBottom: Color(0xFF1C0806),
    floorA: Color(0xFF4A2019),
    floorB: Color(0xFF441D17),
    rail: Color(0xFFFF6A3D),
    accent: Color(0xFFFFC940),
    decor: DecorStyle.core,
    particle: Color(0x77FF9A5C),
  ),
];

WorldDef worldForLevel(int level) {
  for (final w in worlds) {
    if (level <= w.lastLevel) return w;
  }
  return worlds.last;
}
