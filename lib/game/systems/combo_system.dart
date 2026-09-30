import 'dart:math' as math;

/// Rewards consecutive skilled actions. The combo decays if the player goes
/// [window] seconds without a skilled action.
class ComboSystem {
  static const double window = 3.2;
  static const int maxMultiplier = 5;

  int count = 0;
  int best = 0;
  double timer = 0;
  bool boost = false;

  int get multiplier => math.min(maxMultiplier, 1 + count ~/ 4) + (boost ? 1 : 0);

  /// Registers [n] skilled actions. Returns true when the multiplier went up.
  bool add([int n = 1]) {
    final before = multiplier;
    count += n;
    best = math.max(best, count);
    timer = window;
    return multiplier > before;
  }

  /// Keeps the combo alive without increasing it (e.g. collecting).
  void refresh() {
    if (count > 0) timer = math.max(timer, window * 0.6);
  }

  void update(double dt) {
    if (count == 0) return;
    timer -= dt;
    if (timer <= 0) reset();
  }

  void reset() {
    count = 0;
    timer = 0;
  }
}
