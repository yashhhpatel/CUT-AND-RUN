import 'dart:math' as math;

import 'hazard.dart';

/// The runner. Moves forward automatically; horizontal position follows the
/// player's drag with a fast, non-floaty exponential approach.
class Player {
  static const double radius = 18;

  double x = kTrackWidth / 2;
  double targetX = kTrackWidth / 2;
  double y = 0;
  double vx = 0;
  double runPhase = 0;
  double invuln = 0;
  int shields = 0;
  double hitFlash = 0;
  double landSquash = 0;
  bool alive = true;

  void moveBy(double dx) {
    targetX = (targetX + dx).clamp(radius + 4, kTrackWidth - radius - 4);
  }

  void update(double dt, double speed) {
    y += speed * dt;
    final prev = x;
    // Snappy approach: ~95% of the way in 0.12s.
    final k = 1 - math.exp(-24 * dt);
    x += (targetX - x) * k;
    vx = dt > 0 ? (x - prev) / dt : 0;
    runPhase += dt * speed / 26;
    if (invuln > 0) invuln = math.max(0, invuln - dt);
    if (hitFlash > 0) hitFlash = math.max(0, hitFlash - dt * 3);
    if (landSquash > 0) landSquash = math.max(0, landSquash - dt * 5);
  }
}
