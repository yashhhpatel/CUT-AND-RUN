import 'dart:math' as math;
import 'dart:ui';

enum ParticleKind { spark, debris, dot, ring, confetti }

class Particle {
  double x = 0, y = 0, vx = 0, vy = 0;
  double life = 0, maxLife = 1;
  double size = 3;
  double rot = 0, vr = 0;
  Color color = const Color(0xFFFFFFFF);
  ParticleKind kind = ParticleKind.dot;
  bool alive = false;
  double drag = 2;

  double get t => 1 - life / maxLife;
}

/// Fixed-size particle pool. Never allocates during gameplay after warm-up.
class ParticleSystem {
  ParticleSystem([this.capacity = 520]) {
    for (var i = 0; i < capacity; i++) {
      _pool.add(Particle());
    }
  }

  final int capacity;
  final List<Particle> _pool = [];
  final math.Random _rng = math.Random(11);
  int _cursor = 0;

  Iterable<Particle> get alive => _pool.where((p) => p.alive);

  Particle _next() {
    for (var i = 0; i < capacity; i++) {
      final p = _pool[(_cursor + i) % capacity];
      if (!p.alive) {
        _cursor = (_cursor + i + 1) % capacity;
        return p;
      }
    }
    // Pool full: recycle the oldest slot.
    final p = _pool[_cursor];
    _cursor = (_cursor + 1) % capacity;
    return p;
  }

  void emit({
    required Offset at,
    required Color color,
    ParticleKind kind = ParticleKind.dot,
    int count = 8,
    double speed = 160,
    double spread = math.pi * 2,
    double direction = 0,
    double life = 0.5,
    double size = 3,
    double drag = 3,
  }) {
    for (var i = 0; i < count; i++) {
      final p = _next();
      final a = direction + (_rng.nextDouble() - 0.5) * spread;
      final s = speed * (0.4 + _rng.nextDouble() * 0.8);
      p
        ..alive = true
        ..x = at.dx
        ..y = at.dy
        ..vx = math.cos(a) * s
        ..vy = math.sin(a) * s
        ..maxLife = life * (0.7 + _rng.nextDouble() * 0.6)
        ..life = p.maxLife
        ..size = size * (0.6 + _rng.nextDouble() * 0.8)
        ..rot = _rng.nextDouble() * math.pi
        ..vr = (_rng.nextDouble() - 0.5) * 14
        ..color = color
        ..kind = kind
        ..drag = drag;
    }
  }

  void ring(Offset at, Color color, {double size = 60, double life = 0.4}) {
    final p = _next();
    p
      ..alive = true
      ..x = at.dx
      ..y = at.dy
      ..vx = 0
      ..vy = 0
      ..maxLife = life
      ..life = life
      ..size = size
      ..color = color
      ..kind = ParticleKind.ring;
  }

  /// Sparks spread along a cut line.
  void alongLine(Offset a, Offset b, Color color, {int count = 14}) {
    final d = b - a;
    final n = Offset(-d.dy, d.dx) / (d.distance == 0 ? 1 : d.distance);
    for (var i = 0; i < count; i++) {
      final at = a + d * _rng.nextDouble();
      final side = _rng.nextBool() ? 1.0 : -1.0;
      emit(
        at: at,
        color: color,
        kind: ParticleKind.spark,
        count: 1,
        speed: 220,
        spread: 0.9,
        direction: math.atan2(n.dy * side, n.dx * side),
        life: 0.35,
        size: 2.2,
      );
    }
  }

  void update(double dt) {
    for (final p in _pool) {
      if (!p.alive) continue;
      p.life -= dt;
      if (p.life <= 0) {
        p.alive = false;
        continue;
      }
      final k = math.exp(-p.drag * dt);
      p.vx *= k;
      p.vy *= k;
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.rot += p.vr * dt;
    }
  }

  void clear() {
    for (final p in _pool) {
      p.alive = false;
    }
  }
}

class FloatingText {
  FloatingText(this.text, this.pos, this.color, {this.big = false, this.life = 0.9});
  final String text;
  Offset pos;
  final Color color;
  final bool big;
  double life;
  final double maxLifeValue = 0.9;
  double age = 0;
}

/// A value label that flies from the world into the HUD shards counter
/// (gate results, finish-ladder payments).
class HudFly {
  HudFly(this.text, this.from, this.color);
  final String text;
  final Offset from;
  final Color color;
  double t = 0;
}

/// Short-lived collected-piece ghost that flies into the player.
class FlyIn {
  FlyIn(this.poly, this.color);
  final List<Offset> poly;
  final Color color;
  double t = 0;
}

/// Subtle camera: impact shake, zoom punch, never uncomfortable.
class CameraRig {
  double shake = 0;
  double zoom = 0;
  final math.Random _rng = math.Random(3);
  Offset offset = Offset.zero;

  void addShake(double amount) => shake = math.min(10, shake + amount);
  void punch(double amount) => zoom = math.min(0.06, zoom + amount);

  void update(double dt) {
    shake = math.max(0, shake - dt * 30);
    zoom = math.max(0, zoom - dt * 0.12);
    offset = shake > 0 ? Offset((_rng.nextDouble() - 0.5) * shake, (_rng.nextDouble() - 0.5) * shake) : Offset.zero;
  }
}
