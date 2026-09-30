import 'dart:ui';

import '../model/powerups.dart';

enum PickupKind { coin, powerUp }

class Pickup {
  Pickup({required this.kind, required this.pos, this.powerUp});

  final PickupKind kind;
  Offset pos;
  final PowerUpType? powerUp;
  Offset vel = Offset.zero;
  bool collected = false;
  double age = 0;

  double get radius => kind == PickupKind.coin ? 12 : 20;
}

/// World-space text sign (e.g. "RISK ROUTE"), purely visual.
class Decal {
  Decal({required this.text, required this.pos, required this.color});
  final String text;
  final Offset pos;
  final Color color;
}
