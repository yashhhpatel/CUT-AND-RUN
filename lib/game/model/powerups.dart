import 'dart:ui';

enum PowerUpType {
  autoCutter,
  precisionCutter,
  megaCut,
  magnet,
  shield,
  slowMotion,
  doubleReward,
  pieceSaver,
  comboBoost,
  cutterBeam,
}

class PowerUpInfo {
  const PowerUpInfo(this.name, this.short, this.duration, this.color, this.description);

  final String name;

  /// Two-letter code drawn on in-world pickups (readable without colour).
  final String short;

  /// Seconds active. 0 = instant/charge based.
  final double duration;
  final Color color;
  final String description;
}

const powerUpInfo = <PowerUpType, PowerUpInfo>{
  PowerUpType.autoCutter:
      PowerUpInfo('Auto Cutter', 'AC', 5, Color(0xFFFF6A3D), 'Automatically slices objects right in front of you.'),
  PowerUpType.precisionCutter:
      PowerUpInfo('Precision', 'PR', 8, Color(0xFF3DD6F5), 'Shows cut guides and widens the Perfect window.'),
  PowerUpType.megaCut:
      PowerUpInfo('Mega Cut', 'MC', 0, Color(0xFFFF4D8A), 'Your next swipe slices across the whole track, even steel.'),
  PowerUpType.magnet: PowerUpInfo('Magnet', 'MG', 8, Color(0xFFB678F0), 'Pulls nearby shards and coins towards you.'),
  PowerUpType.shield: PowerUpInfo('Shield', 'SH', 0, Color(0xFF3DDC84), 'Absorbs one collision.'),
  PowerUpType.slowMotion: PowerUpInfo('Slow-Mo', 'SM', 5, Color(0xFF7FA7FF), 'Slows the world down for precise cuts.'),
  PowerUpType.doubleReward: PowerUpInfo('Double', 'x2', 10, Color(0xFFFFC940), 'Shards collected count double.'),
  PowerUpType.pieceSaver: PowerUpInfo('Piece Saver', 'PS', 15, Color(0xFF2FD4B0), 'Blocks the next loss of shards.'),
  PowerUpType.comboBoost: PowerUpInfo('Combo Boost', 'CB', 10, Color(0xFFFFA63D), 'Adds +1 to your combo multiplier.'),
  PowerUpType.cutterBeam: PowerUpInfo('Cutter Beam', 'BM', 8, Color(0xFF9CF5FF), 'Your swipes reach much further.'),
};
