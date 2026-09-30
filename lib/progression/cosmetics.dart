import 'dart:ui';

enum CosmeticKind { skin, cutEffect, trail }

enum TrailStyle { basic, glow, particle, lightning }

/// Purely visual unlock. Cosmetics never change gameplay.
class Cosmetic {
  const Cosmetic({
    required this.id,
    required this.kind,
    required this.name,
    required this.price,
    required this.primary,
    required this.secondary,
    this.glow,
    this.trailStyle = TrailStyle.basic,
  });

  final String id;
  final CosmeticKind kind;
  final String name;

  /// Coin price. 0 = owned by default.
  final int price;
  final Color primary;
  final Color secondary;
  final Color? glow;
  final TrailStyle trailStyle;
}

abstract final class Cosmetics {
  static const skins = <Cosmetic>[
    Cosmetic(
        id: 'skin_classic',
        kind: CosmeticKind.skin,
        name: 'Classic',
        price: 0,
        primary: Color(0xFFFF6A3D),
        secondary: Color(0xFFFFFFFF)),
    Cosmetic(
        id: 'skin_neon',
        kind: CosmeticKind.skin,
        name: 'Neon',
        price: 400,
        primary: Color(0xFFFF4DA6),
        secondary: Color(0xFF3DD6F5),
        glow: Color(0xFFFF4DA6)),
    Cosmetic(
        id: 'skin_crystal',
        kind: CosmeticKind.skin,
        name: 'Crystal',
        price: 700,
        primary: Color(0xFF7FD3FF),
        secondary: Color(0xFFE5F7FF),
        glow: Color(0xFFA6E6FF)),
    Cosmetic(
        id: 'skin_shadow',
        kind: CosmeticKind.skin,
        name: 'Shadow',
        price: 900,
        primary: Color(0xFF3A2F5C),
        secondary: Color(0xFFFF4D5E)),
    Cosmetic(
        id: 'skin_gold',
        kind: CosmeticKind.skin,
        name: 'Gold',
        price: 1500,
        primary: Color(0xFFFFC940),
        secondary: Color(0xFFFFF3C4),
        glow: Color(0xFFFFD86B)),
    Cosmetic(
        id: 'skin_cyber',
        kind: CosmeticKind.skin,
        name: 'Cyber',
        price: 1200,
        primary: Color(0xFF1E2A2A),
        secondary: Color(0xFF3DF58E),
        glow: Color(0xFF3DF58E)),
    Cosmetic(
        id: 'skin_space',
        kind: CosmeticKind.skin,
        name: 'Space',
        price: 2000,
        primary: Color(0xFFF1F4FF),
        secondary: Color(0xFF4F6BFF),
        glow: Color(0xFF8A9CFF)),
  ];

  static const cutEffects = <Cosmetic>[
    Cosmetic(
        id: 'cut_slash',
        kind: CosmeticKind.cutEffect,
        name: 'Slash',
        price: 0,
        primary: Color(0xFFFFFFFF),
        secondary: Color(0xFFBFD8FF)),
    Cosmetic(
        id: 'cut_energy',
        kind: CosmeticKind.cutEffect,
        name: 'Energy',
        price: 300,
        primary: Color(0xFFB8F6FF),
        secondary: Color(0xFF3DD6F5)),
    Cosmetic(
        id: 'cut_spark',
        kind: CosmeticKind.cutEffect,
        name: 'Spark',
        price: 500,
        primary: Color(0xFFFFF1B0),
        secondary: Color(0xFFFFA63D)),
    Cosmetic(
        id: 'cut_plasma',
        kind: CosmeticKind.cutEffect,
        name: 'Plasma',
        price: 800,
        primary: Color(0xFFFFC2E8),
        secondary: Color(0xFFFF4DA6)),
    Cosmetic(
        id: 'cut_crystal',
        kind: CosmeticKind.cutEffect,
        name: 'Crystal',
        price: 1100,
        primary: Color(0xFFE5FBFF),
        secondary: Color(0xFF7FA7FF)),
  ];

  static const trails = <Cosmetic>[
    Cosmetic(
        id: 'trail_basic',
        kind: CosmeticKind.trail,
        name: 'Basic',
        price: 0,
        primary: Color(0x55FFFFFF),
        secondary: Color(0x22FFFFFF),
        trailStyle: TrailStyle.basic),
    Cosmetic(
        id: 'trail_glow',
        kind: CosmeticKind.trail,
        name: 'Glow',
        price: 350,
        primary: Color(0xAAFF6A3D),
        secondary: Color(0x33FFC940),
        trailStyle: TrailStyle.glow),
    Cosmetic(
        id: 'trail_particle',
        kind: CosmeticKind.trail,
        name: 'Particle',
        price: 650,
        primary: Color(0xFF3DD6F5),
        secondary: Color(0xFFB678F0),
        trailStyle: TrailStyle.particle),
    Cosmetic(
        id: 'trail_lightning',
        kind: CosmeticKind.trail,
        name: 'Lightning',
        price: 1000,
        primary: Color(0xFFFFF1B0),
        secondary: Color(0xFF7FA7FF),
        trailStyle: TrailStyle.lightning),
  ];

  static List<Cosmetic> ofKind(CosmeticKind k) => switch (k) {
        CosmeticKind.skin => skins,
        CosmeticKind.cutEffect => cutEffects,
        CosmeticKind.trail => trails,
      };

  static Cosmetic byId(String id) =>
      [...skins, ...cutEffects, ...trails].firstWhere((c) => c.id == id, orElse: () => skins.first);

  static const defaultIds = {'skin_classic', 'cut_slash', 'trail_basic'};
}

/// The selected look passed into the renderer.
class Loadout {
  const Loadout({required this.skin, required this.cutEffect, required this.trail});

  final Cosmetic skin;
  final Cosmetic cutEffect;
  final Cosmetic trail;

  static final standard = Loadout(
    skin: Cosmetics.skins.first,
    cutEffect: Cosmetics.cutEffects.first,
    trail: Cosmetics.trails.first,
  );
}
