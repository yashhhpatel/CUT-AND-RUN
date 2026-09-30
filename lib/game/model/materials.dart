import 'dart:ui';

/// Physical material of a cuttable object. Drives colour, surface pattern,
/// combine grouping and the sounds/particles of a cut.
enum MaterialKind {
  wood,
  fruit,
  rope,
  jelly,
  crystal,
  prism,
  energy,
  metal,
  steel,
  mystery,
  gold,
  glass,
  obsidian,
}

enum SurfacePattern { grain, rind, coil, wobble, facets, stripes, core, rivets, seam, question, shine, pane, hazard }

class MaterialStyle {
  const MaterialStyle({
    required this.name,
    required this.base,
    required this.light,
    required this.dark,
    required this.interior,
    required this.pattern,
  });

  final String name;
  final Color base;
  final Color light;
  final Color dark;

  /// Colour of the exposed face after a cut (fruit flesh, fresh wood, glowing core...).
  final Color interior;
  final SurfacePattern pattern;
}

const materialStyles = <MaterialKind, MaterialStyle>{
  MaterialKind.wood: MaterialStyle(
    name: 'Wood',
    base: Color(0xFFC98A4B),
    light: Color(0xFFE5AE72),
    dark: Color(0xFF8A5528),
    interior: Color(0xFFF2D19E),
    pattern: SurfacePattern.grain,
  ),
  MaterialKind.fruit: MaterialStyle(
    name: 'Melon',
    base: Color(0xFF4DBA6A),
    light: Color(0xFF7BDB8F),
    dark: Color(0xFF2B7D43),
    interior: Color(0xFFFF7A8A),
    pattern: SurfacePattern.rind,
  ),
  MaterialKind.rope: MaterialStyle(
    name: 'Rope',
    base: Color(0xFFD9B77E),
    light: Color(0xFFF0D7A6),
    dark: Color(0xFF9C7A45),
    interior: Color(0xFFF7E6C4),
    pattern: SurfacePattern.coil,
  ),
  MaterialKind.jelly: MaterialStyle(
    name: 'Jelly',
    base: Color(0xFFB678F0),
    light: Color(0xFFD5A8FF),
    dark: Color(0xFF7D48B3),
    interior: Color(0xFFE6CCFF),
    pattern: SurfacePattern.wobble,
  ),
  MaterialKind.crystal: MaterialStyle(
    name: 'Crystal',
    base: Color(0xFF4FB8FF),
    light: Color(0xFFA6DDFF),
    dark: Color(0xFF2377C4),
    interior: Color(0xFFD9F1FF),
    pattern: SurfacePattern.facets,
  ),
  MaterialKind.prism: MaterialStyle(
    name: 'Prism',
    base: Color(0xFFFF7BB0),
    light: Color(0xFFFFB0D0),
    dark: Color(0xFFC24479),
    interior: Color(0xFFFFE0EC),
    pattern: SurfacePattern.stripes,
  ),
  MaterialKind.energy: MaterialStyle(
    name: 'Energy Cell',
    base: Color(0xFF2FD4B0),
    light: Color(0xFF8BFFE6),
    dark: Color(0xFF148A72),
    interior: Color(0xFFE8FFF9),
    pattern: SurfacePattern.core,
  ),
  MaterialKind.metal: MaterialStyle(
    name: 'Metal Crate',
    base: Color(0xFF8D9AB5),
    light: Color(0xFFC2CBDD),
    dark: Color(0xFF5A6682),
    interior: Color(0xFFE6ECF7),
    pattern: SurfacePattern.rivets,
  ),
  MaterialKind.steel: MaterialStyle(
    name: 'Reinforced Steel',
    base: Color(0xFF5B6784),
    light: Color(0xFF8C97B3),
    dark: Color(0xFF363F57),
    interior: Color(0xFFB9C4DE),
    pattern: SurfacePattern.seam,
  ),
  MaterialKind.mystery: MaterialStyle(
    name: 'Mystery Box',
    base: Color(0xFF7A5CFF),
    light: Color(0xFFAA96FF),
    dark: Color(0xFF4B33B8),
    interior: Color(0xFFFFE27A),
    pattern: SurfacePattern.question,
  ),
  MaterialKind.gold: MaterialStyle(
    name: 'Golden Relic',
    base: Color(0xFFFFC940),
    light: Color(0xFFFFE699),
    dark: Color(0xFFC08A12),
    interior: Color(0xFFFFF3C4),
    pattern: SurfacePattern.shine,
  ),
  MaterialKind.glass: MaterialStyle(
    name: 'Glass',
    base: Color(0x993DD6F5),
    light: Color(0xCCB8F3FF),
    dark: Color(0xFF1C9DBF),
    interior: Color(0xFFE5FBFF),
    pattern: SurfacePattern.pane,
  ),
  MaterialKind.obsidian: MaterialStyle(
    name: 'Obsidian',
    base: Color(0xFF2A2440),
    light: Color(0xFF4A416B),
    dark: Color(0xFF15111F),
    interior: Color(0xFF4A416B),
    pattern: SurfacePattern.hazard,
  ),
};
