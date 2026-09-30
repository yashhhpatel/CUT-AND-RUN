/// Every gameplay mechanic the generator can use, with the level where it is
/// first introduced. Progression = more mechanics combined, not just speed.
enum Mechanic {
  softCut,
  melon,
  gatesBasic,
  softVariety,
  subtractGate,
  shieldMagnet,
  pits,
  sawStatic,
  cutWall,
  rewardZone,
  precisionSeam,
  crystal,
  quantityGate,
  combine,
  prism,
  slowPrecision,
  sawMoving,
  movingWall,
  pendulum,
  movingObjects,
  energyChain,
  riskReward,
  rotatingBar,
  mystery,
  laser,
  relic,
  autoDouble,
  colorGate,
  hardMetal,
  multiCut,
  sacrificeGate,
  crusher,
  fallingBlocks,
  megaCombo,
  multiLayerWall,
  timingDoor,
  reinforced,
  diagonalSeam,
  rollingLogs,
  pushBlock,
  beamSaver,
  collapsingFloor,
  platformPit,
}

class MechanicInfo {
  const MechanicInfo(this.level, this.title, this.tip);
  final int level;
  final String title;
  final String tip;
}

const mechanicInfo = <Mechanic, MechanicInfo>{
  Mechanic.softCut: MechanicInfo(1, 'Cut & Collect', 'Swipe through blocks, then run through the pieces.'),
  Mechanic.melon: MechanicInfo(2, 'Melons', 'Juicy and worth double shards.'),
  Mechanic.gatesBasic: MechanicInfo(3, 'Gates', 'Steer into the gate that grows your shards.'),
  Mechanic.softVariety: MechanicInfo(4, 'Soft Materials', 'Rope and jelly slice with one swipe.'),
  Mechanic.subtractGate: MechanicInfo(5, 'Trap Gates', 'Red gates take shards away. Avoid them.'),
  Mechanic.shieldMagnet: MechanicInfo(6, 'Power-Ups', 'Grab bubbles for shields and magnets.'),
  Mechanic.pits: MechanicInfo(7, 'Pits', 'Steer around gaps in the floor.'),
  Mechanic.sawStatic: MechanicInfo(8, 'Saw Blades', 'Spinning saws cannot be cut. Dodge them.'),
  Mechanic.cutWall: MechanicInfo(9, 'Cut Walls', 'Slice the panel in your path to break through.'),
  Mechanic.rewardZone: MechanicInfo(10, 'Reward Zones', 'Coin-rich stretches. Grab them all!'),
  Mechanic.precisionSeam: MechanicInfo(12, 'Precision Cuts', 'Cut along the dashed line for a Perfect Cut.'),
  Mechanic.crystal: MechanicInfo(14, 'Crystal', 'Crystal needs a fast, decisive swipe.'),
  Mechanic.quantityGate: MechanicInfo(16, 'Quantity Gates', 'Carry enough shards to unlock the bonus.'),
  Mechanic.combine: MechanicInfo(18, 'Fusion', 'Collect 3 matching pieces to fuse them into a stronger one.'),
  Mechanic.prism: MechanicInfo(20, 'Prisms', 'Triangular and tough: swipe fast.'),
  Mechanic.slowPrecision: MechanicInfo(22, 'New Power-Ups', 'Slow-Mo and Precision help with tricky cuts.'),
  Mechanic.sawMoving: MechanicInfo(25, 'Moving Saws', 'Watch the rhythm, then slip past.'),
  Mechanic.movingWall: MechanicInfo(27, 'Moving Walls', 'Time your pass through the opening.'),
  Mechanic.pendulum: MechanicInfo(30, 'Swinging Blades', 'Blades swing in a steady arc.'),
  Mechanic.movingObjects: MechanicInfo(32, 'Moving Targets', 'Some blocks slide. Time your cut.'),
  Mechanic.energyChain: MechanicInfo(34, 'Energy Cells', 'Cut one to trigger a Cut Chain on nearby objects.'),
  Mechanic.riskReward: MechanicInfo(36, 'Risk Routes', 'Pick the safe lane or gamble for more.'),
  Mechanic.rotatingBar: MechanicInfo(38, 'Rotating Bars', 'Pass behind the sweep.'),
  Mechanic.mystery: MechanicInfo(40, 'Mystery Boxes', 'Cut them open to reveal a surprise.'),
  Mechanic.laser: MechanicInfo(42, 'Lasers', 'Lasers blink before they fire.'),
  Mechanic.relic: MechanicInfo(44, 'Relics', 'Collect relics whole. Cutting breaks them!'),
  Mechanic.autoDouble: MechanicInfo(46, 'Auto Cutter', 'Auto Cutter and Double Reward power-ups.'),
  Mechanic.colorGate: MechanicInfo(48, 'Material Gates', 'Carry the right material for a bonus.'),
  Mechanic.hardMetal: MechanicInfo(52, 'Metal Crates', 'Metal needs two hits to split.'),
  Mechanic.multiCut: MechanicInfo(55, 'Multi-Cut', 'Big crates need several cuts to become collectible.'),
  Mechanic.sacrificeGate: MechanicInfo(58, 'Sacrifice Gates', 'Pay shards to gain a power-up.'),
  Mechanic.crusher: MechanicInfo(60, 'Crushers', 'Wait for the jaws to open.'),
  Mechanic.fallingBlocks: MechanicInfo(64, 'Falling Blocks', 'Watch the shadows. Blocks drop from above.'),
  Mechanic.megaCombo: MechanicInfo(68, 'Mega Cut', 'One mighty swipe slices everything in line.'),
  Mechanic.multiLayerWall: MechanicInfo(72, 'Layered Walls', 'Two walls in a row. Keep slicing.'),
  Mechanic.timingDoor: MechanicInfo(80, 'Timing Doors', 'Doors open and close in rhythm.'),
  Mechanic.reinforced: MechanicInfo(101, 'Reinforced Steel', 'Only the glowing seam can be cut.'),
  Mechanic.diagonalSeam: MechanicInfo(110, 'Diagonal Seams', 'Match the angle of the seam.'),
  Mechanic.rollingLogs: MechanicInfo(120, 'Rolling Logs', 'Logs roll towards you. Slice them fast.'),
  Mechanic.pushBlock: MechanicInfo(130, 'Pistons', 'Pistons punch in from the side.'),
  Mechanic.beamSaver: MechanicInfo(140, 'Cutter Beam', 'Cutter Beam and Piece Saver power-ups.'),
  Mechanic.collapsingFloor: MechanicInfo(201, 'Collapsing Floors', 'Tiles crumble. Follow the solid path.'),
  Mechanic.platformPit: MechanicInfo(240, 'Moving Platforms', 'Ride the platform across the gap.'),
};

Set<Mechanic> mechanicsForLevel(int level) => {
      for (final e in mechanicInfo.entries)
        if (e.value.level <= level) e.key
    };

/// Mechanic introduced exactly at [level], if any (shown as a "NEW" tip).
Mechanic? mechanicIntroducedAt(int level) {
  for (final e in mechanicInfo.entries) {
    if (e.value.level == level) return e.key;
  }
  return null;
}
