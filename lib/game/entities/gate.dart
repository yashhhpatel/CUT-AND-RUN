import '../model/materials.dart';
import '../model/powerups.dart';

enum GateType {
  /// +N shards.
  add,

  /// xN shards.
  multiply,

  /// -N shards (the trap option).
  subtract,

  /// Requires N shards; rewards coins and score when met.
  quantity,

  /// Pay N shards for a power-up.
  sacrifice,

  /// Doubles shards if you carry an intact relic.
  preserve,

  /// Bonus for carrying pieces of a specific material.
  color,

  /// Fuses every pair of matching pieces in the carry stack.
  fusion,

  /// High multiplier, leads into a harder lane.
  risk,

  /// Flat coin reward.
  reward,

  /// Grants a power-up.
  powerUp,
}

class GateOption {
  GateOption({
    required this.x0,
    required this.x1,
    required this.type,
    this.value = 0,
    this.material,
    this.powerUp,
  });

  final double x0;
  final double x1;
  final GateType type;
  final int value;
  final MaterialKind? material;
  final PowerUpType? powerUp;

  double get center => (x0 + x1) / 2;

  /// Short label drawn on the gate. Always includes a symbol or number so
  /// meaning never depends on colour alone.
  String get label {
    switch (type) {
      case GateType.add:
        return '+$value';
      case GateType.multiply:
        return '×$value';
      case GateType.subtract:
        return '−$value';
      case GateType.quantity:
        return 'NEED $value';
      case GateType.sacrifice:
        return 'PAY $value';
      case GateType.preserve:
        return 'RELIC ×2';
      case GateType.color:
        return materialStyles[material]!.name.toUpperCase();
      case GateType.fusion:
        return 'FUSE';
      case GateType.risk:
        return 'RISK ×$value';
      case GateType.reward:
        return '+$value ◎';
      case GateType.powerUp:
        return powerUpInfo[powerUp]!.name.toUpperCase();
    }
  }

  String? get subLabel {
    switch (type) {
      case GateType.quantity:
        return 'bonus';
      case GateType.sacrifice:
        return '→ ${powerUpInfo[powerUp]!.name}';
      case GateType.color:
        return 'bonus ×3';
      case GateType.fusion:
        return 'combine';
      case GateType.risk:
        return 'hard lane';
      default:
        return null;
    }
  }

  /// Whether the option is generally good (green) or bad (red).
  bool get isPositive => type != GateType.subtract;
}

class GateRow {
  GateRow({required this.y, required this.options});

  final double y;
  final List<GateOption> options;
  bool resolved = false;
  int chosen = -1;
  double flash = 0;
  bool failed = false;
}
