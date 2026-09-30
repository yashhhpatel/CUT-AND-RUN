import 'dart:math' as math;

import '../../game/systems/run_stats.dart';

enum ObjectiveType {
  reachFinish,
  makeCuts,
  perfectCuts,
  collectShards,
  chainCut,
  reachScore,
  reachCombo,
  noCollision,
  preserveRelic,
  cutSpecial,
  combine,
  collectCoins,
  finishWithShield,
  perfectRoute,
  perfectDodges,
}

class Objective {
  const Objective(this.type, [this.target = 1]);

  final ObjectiveType type;
  final int target;

  String get description {
    switch (type) {
      case ObjectiveType.reachFinish:
        return 'Reach the finish';
      case ObjectiveType.makeCuts:
        return 'Make $target cuts';
      case ObjectiveType.perfectCuts:
        return target == 1 ? 'Land a Perfect Cut' : 'Land $target Perfect Cuts';
      case ObjectiveType.collectShards:
        return 'Finish with $target shards';
      case ObjectiveType.chainCut:
        return 'Trigger a Cut Chain';
      case ObjectiveType.reachScore:
        return 'Score $target points';
      case ObjectiveType.reachCombo:
        return 'Reach a x$target combo';
      case ObjectiveType.noCollision:
        return 'Finish without a collision';
      case ObjectiveType.preserveRelic:
        return 'Collect a relic in one piece';
      case ObjectiveType.cutSpecial:
        return 'Open $target mystery box${target == 1 ? '' : 'es'}';
      case ObjectiveType.combine:
        return 'Fuse pieces $target time${target == 1 ? '' : 's'}';
      case ObjectiveType.collectCoins:
        return 'Grab $target coins';
      case ObjectiveType.finishWithShield:
        return 'Finish with a shield';
      case ObjectiveType.perfectRoute:
        return 'Flawless: no collisions or failed gates';
      case ObjectiveType.perfectDodges:
        return 'Make $target Perfect Dodges';
    }
  }

  /// Current progress towards [target] (for HUD / result display).
  int progress(RunStats s, int comboMultiplierBest) {
    switch (type) {
      case ObjectiveType.reachFinish:
        return 0;
      case ObjectiveType.makeCuts:
        return s.cuts;
      case ObjectiveType.perfectCuts:
        return s.perfectCuts;
      case ObjectiveType.collectShards:
        return s.finalShards;
      case ObjectiveType.chainCut:
        return s.chainCuts;
      case ObjectiveType.reachScore:
        return s.score;
      case ObjectiveType.reachCombo:
        return comboMultiplierBest;
      case ObjectiveType.noCollision:
        return s.collisions == 0 ? 1 : 0;
      case ObjectiveType.preserveRelic:
        return s.relicsSaved;
      case ObjectiveType.cutSpecial:
        return s.specialCuts;
      case ObjectiveType.combine:
        return s.combines;
      case ObjectiveType.collectCoins:
        return s.coinsCollected;
      case ObjectiveType.finishWithShield:
        return s.shieldAtEnd ? 1 : 0;
      case ObjectiveType.perfectRoute:
        return (s.collisions == 0 && s.gateFails == 0) ? 1 : 0;
      case ObjectiveType.perfectDodges:
        return s.perfectDodges;
    }
  }

  bool isMet(RunStats s, {required bool finished, required int comboMultiplierBest}) {
    if (!finished) return false;
    if (type == ObjectiveType.reachFinish) return true;
    return progress(s, comboMultiplierBest) >= math.max(1, target);
  }
}
