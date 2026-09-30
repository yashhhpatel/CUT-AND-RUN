import 'dart:ui';

import '../../game/entities/gate.dart';
import '../../game/entities/hazard.dart';
import '../../game/entities/pickup.dart';
import '../../game/model/object_defs.dart';
import '../../game/model/powerups.dart';

/// Declarative level content. Generators output spawns; the world instantiates
/// them lazily as the player approaches, so a level is pure data.
sealed class Spawn {
  const Spawn(this.y);
  final double y;
}

enum SeamKind { none, vertical, horizontal, diagonal, antiDiagonal }

class BodySpawn extends Spawn {
  const BodySpawn({
    required double y,
    required this.def,
    required this.x,
    this.width,
    this.height,
    this.angle = 0,
    this.moveAmp = 0,
    this.moveFreq = 0,
    this.movePhase = 0,
    this.driftVy = 0,
    this.falling = false,
    this.seam = SeamKind.none,
    this.seamIsTarget = false,
    this.asPiece = false,
  }) : super(y);

  final ObjectDef def;
  final double x;

  /// Optional size override (cut-wall panels, membranes).
  final double? width;
  final double? height;
  final double angle;
  final double moveAmp;
  final double moveFreq;
  final double movePhase;
  final double driftVy;
  final bool falling;
  final SeamKind seam;
  final bool seamIsTarget;

  /// Spawns as an already-cut, collectible piece (tutorial / reward rows).
  final bool asPiece;
}

class HazardSpawn extends Spawn {
  const HazardSpawn({
    required double y,
    required this.kind,
    required this.x,
    this.w = 80,
    this.h = 40,
    this.amp = 0,
    this.freq = 1,
    this.phase = 0,
    this.gap = 110,
    this.rowMasks = const [],
  }) : super(y);

  final HazardKind kind;
  final double x;
  final double w;
  final double h;
  final double amp;
  final double freq;
  final double phase;
  final double gap;
  final List<int> rowMasks;

  Hazard build() => Hazard(
        kind: kind,
        x: x,
        y: y,
        w: w,
        h: h,
        amp: amp,
        freq: freq,
        phase: phase,
        gap: gap,
        rowMasks: rowMasks,
      );
}

class GateSpawn extends Spawn {
  const GateSpawn({required double y, required this.options}) : super(y);
  final List<GateOption> options;
}

class PickupSpawn extends Spawn {
  const PickupSpawn({required double y, required this.kind, required this.x, this.powerUp}) : super(y);
  final PickupKind kind;
  final double x;
  final PowerUpType? powerUp;
}

class DecalSpawn extends Spawn {
  const DecalSpawn({required double y, required this.text, required this.x, required this.color}) : super(y);
  final String text;
  final double x;
  final Color color;
}

enum TutorialStep { move, collect, cut, avoid, pieces, finish }

class HintSpawn extends Spawn {
  const HintSpawn({required double y, required this.step}) : super(y);
  final TutorialStep step;
}
