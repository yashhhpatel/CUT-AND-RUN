import 'dart:math' as math;
import 'dart:ui';

import '../../core/theme/app_colors.dart';
import '../../core/utils/geometry.dart';
import '../../levels/generators/mode_generators.dart';
import '../../levels/models/level_config.dart';
import '../../levels/models/mechanics.dart';
import '../../levels/models/spawn.dart';
import '../effects/effects.dart';
import '../entities/body.dart';
import '../entities/gate.dart';
import '../entities/hazard.dart';
import '../entities/pickup.dart';
import '../entities/player.dart';
import '../model/materials.dart';
import '../model/object_defs.dart';
import '../model/powerups.dart';
import '../systems/combine_system.dart';
import '../systems/combo_system.dart';
import '../systems/cut_system.dart';
import '../systems/run_stats.dart';
import 'game_events.dart';

enum RunStatus { running, completed, failed }

class _Group {
  int alive = 0;
  int collected = 0;
  int lost = 0;
  bool cut = false;
  bool resolved = false;
}

/// The complete gameplay simulation. Pure Dart (no widgets): it is advanced by
/// [update], receives input through [cutter]/[player], and reports side
/// effects through [events]. Rendering reads its state.
class GameWorld {
  GameWorld(this.config, {this.endless, int? seed})
      : rng = math.Random(seed ?? config.seed),
        speed = config.speed {
    _pending = List.of(config.spawns);
    newMechanic = config.mode == GameMode.campaign ? mechanicIntroducedAt(config.levelId) : null;
  }

  final LevelConfig config;
  final EndlessGenerator? endless;
  final math.Random rng;

  final Player player = Player();
  final List<Body> bodies = [];
  final List<Hazard> hazards = [];
  final List<GateRow> gates = [];
  final List<Pickup> pickups = [];
  final List<Decal> decals = [];
  final ParticleSystem particles = ParticleSystem();
  final List<FloatingText> texts = [];
  final List<FlyIn> flyIns = [];
  final List<HudFly> hudFlies = [];
  final CameraRig camera = CameraRig();
  final CarryStack carry = CarryStack();
  final ComboSystem combo = ComboSystem();
  final RunStats stats = RunStats();
  final Map<PowerUpType, double> powerUps = {};
  final List<GameEvent> events = [];

  /// Recent player positions for the cosmetic trail.
  final List<Offset> trailHistory = [];
  late final CutSystem cutter = CutSystem(this);

  late List<Spawn> _pending;
  int _spawnIndex = 0;
  int _nextId = 1;
  final Map<int, _Group> _groups = {};

  double time = 0;
  double speed;
  int megaCharges = 0;
  RunStatus status = RunStatus.running;
  String? failReason;
  double statusTime = 0;
  bool usedContinue = false;

  // Finish ladder: after the finish line, barriers ×2…×5 each cost shards.
  static const double bonusStepLength = 150;
  static const int bonusMaxMultiplier = 5;
  bool inBonus = false;
  int bonusMultiplier = 1;
  double _celebration = 0;
  double _finishSpeed = 0;

  /// World y of the barrier that unlocks multiplier [k] (2..5).
  double bonusStepY(int k) => config.pathLength + 130 + (k - 2) * bonusStepLength;
  double hitStop = 0;
  int bestMultiplier = 1;
  Mechanic? newMechanic;

  /// World units visible ahead of / behind the player (set by the view).
  double viewAhead = 900;
  double viewBehind = 320;

  // Tutorial.
  TutorialStep? hint;
  double hintTime = 0;
  bool tutorialSlow = false;
  final Set<TutorialStep> _hintsDone = {};
  double _hintBaseX = 0;
  int _hintBase = 0;

  double get progress => config.isEndless ? 0 : (player.y / config.pathLength).clamp(0.0, 1.0);

  int nextId() => _nextId++;

  bool hasPower(PowerUpType t) => (powerUps[t] ?? 0) > 0;

  void emit(GameEventType t, [int v = 0]) => events.add(GameEvent(t, v));

  void floatText(String text, Offset at, Color color, {bool big = false}) {
    if (texts.length > 14) texts.removeAt(0);
    texts.add(FloatingText(text, at, color, big: big));
  }

  void addScore(int base) => stats.score += base * combo.multiplier;

  // ------------------------------------------------------------------ input

  void moveBy(double dx) {
    if (status != RunStatus.running) return;
    player.moveBy(dx);
  }

  // ------------------------------------------------------------- lifecycle

  void update(double realDt) {
    final rdt = realDt.clamp(0.0, 1 / 20);
    if (status != RunStatus.running) {
      statusTime += rdt;
      if (status == RunStatus.completed) {
        _finishSpeed *= math.exp(-3.5 * rdt);
        player.update(rdt, _finishSpeed);
        _recordTrail();
        if (rng.nextDouble() < 0.5) {
          particles.emit(
            at: Offset(rng.nextDouble() * kTrackWidth, player.y + 300 + rng.nextDouble() * 200),
            color: [AppColors.primary, AppColors.accent, AppColors.reward, AppColors.success][rng.nextInt(4)],
            kind: ParticleKind.confetti,
            count: 2,
            speed: 120,
            life: 1.4,
            size: 6,
            drag: 1,
          );
        }
      }
      _updateEffects(rdt);
      return;
    }

    var scale = 1.0;
    if (hitStop > 0) {
      hitStop -= rdt;
      scale = 0.07;
    } else if (_celebration > 0) {
      // Finish-line slow motion.
      _celebration -= rdt;
      scale = 0.32;
    } else {
      if (hasPower(PowerUpType.slowMotion)) scale = 0.55;
      if (tutorialSlow) scale = math.min(scale, 0.28);
    }
    final dt = rdt * scale;
    time += dt;

    if (endless != null) {
      speed = EndlessGenerator.speedAt(player.y);
      if (player.y + 3500 > endless!.generatedUntil) {
        _pending.addAll(endless!.extend(player.y + 6000));
      }
    }

    player.update(dt, speed);
    _recordTrail();
    stats.time += dt;
    stats.distance = player.y;

    _spawn();
    _updateBodies(dt);
    for (final h in hazards) {
      h.update(time, player.y);
    }
    for (final p in pickups) {
      p.age += dt;
      if (p.vel != Offset.zero) {
        p.pos += p.vel * dt;
        p.vel *= math.exp(-3 * dt);
      }
    }
    cutter.update(dt);
    _magnet(dt);
    _collisions();
    if (status != RunStatus.running) {
      _updateEffects(rdt);
      return;
    }
    _gates();
    _dodges();
    _tickPowerUps(dt);
    combo.boost = hasPower(PowerUpType.comboBoost);
    combo.update(dt);
    stats.bestCombo = math.max(stats.bestCombo, combo.count);
    bestMultiplier = math.max(bestMultiplier, combo.multiplier);
    _tutorial(rdt);
    _cleanup();
    _updateEffects(rdt);

    if (!config.isEndless && !inBonus && player.y >= config.pathLength) _enterBonus();
    if (inBonus && status == RunStatus.running) _bonusTick();
  }

  void _recordTrail() {
    trailHistory.add(Offset(player.x, player.y - 12));
    if (trailHistory.length > 16) trailHistory.removeAt(0);
  }

  void _updateEffects(double dt) {
    particles.update(dt);
    camera.update(dt);
    for (var i = texts.length - 1; i >= 0; i--) {
      final t = texts[i];
      t.age += dt;
      t.life -= dt;
      t.pos += Offset(0, 50 * dt);
      if (t.life <= 0) texts.removeAt(i);
    }
    for (var i = flyIns.length - 1; i >= 0; i--) {
      flyIns[i].t += dt * 5;
      if (flyIns[i].t >= 1) flyIns.removeAt(i);
    }
    for (final item in carry.items) {
      if (item.pop > 0) item.pop = math.max(0, item.pop - dt * 3);
    }
    for (final g in gates) {
      if (g.flash > 0) g.flash = math.max(0, g.flash - dt * 2);
    }
    for (var i = hudFlies.length - 1; i >= 0; i--) {
      hudFlies[i].t += dt * 1.5;
      if (hudFlies[i].t >= 1) hudFlies.removeAt(i);
    }
  }

  // ---------------------------------------------------------------- spawning

  void _spawn() {
    final limit = player.y + viewAhead + 260;
    while (_spawnIndex < _pending.length && _pending[_spawnIndex].y < limit) {
      _instantiate(_pending[_spawnIndex]);
      _spawnIndex++;
    }
    if (endless != null && _spawnIndex > 400) {
      _pending = _pending.sublist(_spawnIndex);
      _spawnIndex = 0;
    }
  }

  void _instantiate(Spawn s) {
    switch (s) {
      case BodySpawn():
        addBody(buildBody(s));
      case HazardSpawn():
        final h = s.build()..update(time, player.y);
        hazards.add(h);
      case GateSpawn():
        gates.add(GateRow(y: s.y, options: s.options));
      case PickupSpawn():
        pickups.add(Pickup(kind: s.kind, pos: Offset(s.x, s.y), powerUp: s.powerUp));
      case DecalSpawn():
        decals.add(Decal(text: s.text, pos: Offset(s.x, s.y), color: s.color));
      case HintSpawn():
        _showHint(s.step);
    }
  }

  Body buildBody(BodySpawn s) {
    final def = s.def;
    final w = s.width ?? def.size.width;
    final h = s.height ?? def.size.height;
    final c = Offset(s.x, s.y);
    List<Offset> poly;
    switch (def.shape) {
      case ObjectShape.rect:
        poly = Geo.rectPoly(c, w, h);
      case ObjectShape.circle:
        poly = Geo.regularPoly(c, w / 2, 14);
      case ObjectShape.hexagon:
        poly = Geo.regularPoly(c, w / 2, 6, math.pi / 6);
      case ObjectShape.triangle:
        poly = Geo.regularPoly(c, w / 2, 3, math.pi / 2);
      case ObjectShape.octagon:
        poly = Geo.regularPoly(c, w / 2, 8, math.pi / 8);
    }
    if (s.angle != 0) poly = Geo.rotateAround(poly, c, s.angle);
    final id = nextId();
    final body = Body(id: id, def: def, poly: poly, groupId: id, isPiece: s.asPiece);
    if (s.seam != SeamKind.none) {
      final dir = switch (s.seam) {
        SeamKind.vertical => const Offset(0, 1),
        SeamKind.horizontal => const Offset(1, 0),
        SeamKind.diagonal => const Offset(0.7071, 0.7071),
        SeamKind.antiDiagonal => const Offset(0.7071, -0.7071),
        SeamKind.none => Offset.zero,
      };
      body.seamA = c - dir * 200;
      body.seamB = c + dir * 200;
      body.seamIsTarget = s.seamIsTarget;
    }
    if (s.moveAmp > 0) body.startMoving(s.moveAmp, s.moveFreq, s.movePhase, time);
    body.driftVy = s.driftVy;
    if (s.falling) {
      body.pendingDrop = true;
      body.airTime = 1e9;
    }
    return body;
  }

  void addBody(Body b) {
    bodies.add(b);
    _groups.putIfAbsent(b.groupId, _Group.new).alive++;
  }

  void removeBody(Body b, RemoveReason reason) {
    if (b.removed) return;
    b.removed = true;
    b.removeReason = reason;
    final g = _groups[b.groupId];
    if (g == null) return;
    g.alive--;
    if (reason == RemoveReason.collected) g.collected++;
    if (reason == RemoveReason.lost && b.isPiece) g.lost++;
    if (reason == RemoveReason.split) g.cut = true;
    if (g.alive <= 0 && !g.resolved) {
      g.resolved = true;
      if (g.cut && g.lost == 0 && g.collected >= 2) {
        stats.perfectCollects++;
        _perfect('PERFECT COLLECT', b.center, GameEventType.perfectCollect);
      }
    }
  }

  // ------------------------------------------------------------------ bodies

  void _updateBodies(double dt) {
    for (final b in bodies) {
      if (b.removed) continue;
      if (b.pendingDrop && b.center.dy - player.y < 600) {
        b.pendingDrop = false;
        b.airTime = 0.85;
      }
      final wasAir = b.airTime > 0 && !b.pendingDrop;
      b.update(dt, time);
      if (wasAir && b.airTime <= 0) {
        camera.addShake(3);
        particles.emit(at: b.center, color: const Color(0xAAFFFFFF), count: 12, speed: 140, life: 0.4, size: 4);
        emit(GameEventType.land);
      }
      if (b.isPiece && b.fall < 0 && (b.center.dx < -6 || b.center.dx > kTrackWidth + 6)) {
        b.fall = 0;
        b.stopMoving();
      }
      if (b.fall >= 1) removeBody(b, RemoveReason.lost);
    }
  }

  void _magnet(double dt) {
    final pc = Offset(player.x, player.y);
    if (!hasPower(PowerUpType.magnet)) {
      // Gentle attraction: pieces right beside the runner snap in.
      for (final b in bodies) {
        if (!b.collectible) continue;
        final d = pc - b.center;
        if (d.dy.abs() < 70 && d.distance < 62) b.translate(Geo.normalize(d) * math.min(d.distance, 260 * dt));
      }
      return;
    }
    for (final b in bodies) {
      if (!b.collectible) continue;
      final d = pc - b.center;
      if (d.distance < 190) b.translate(Geo.normalize(d) * math.min(d.distance, 520 * dt));
    }
    for (final p in pickups) {
      if (p.collected) continue;
      final d = pc - p.pos;
      if (d.distance < 190) p.pos += Geo.normalize(d) * math.min(d.distance, 560 * dt);
    }
  }

  // --------------------------------------------------------------- collisions

  void _collisions() {
    final pc = Offset(player.x, player.y);
    const r = Player.radius;
    for (final b in List<Body>.of(bodies)) {
      if (b.removed || b.airTime > 0 || b.fall >= 0) continue;
      if (b.bounds.bottom < player.y - 60 || b.bounds.top > player.y + 60) continue;
      if (b.collectible) {
        if (Geo.circleIntersectsPolygon(pc, r + 12, b.poly)) _collect(b);
      } else if (Geo.circleIntersectsPolygon(pc, r * 0.8, b.poly)) {
        _crash(
            b.def.cuttable
                ? 'Crashed into ${materialStyles[b.def.material]!.name.toLowerCase()}'
                : 'Hit an obsidian pillar',
            body: b);
        if (status != RunStatus.running) return;
      }
    }
    for (final h in hazards) {
      if (h.y + h.extentFront < player.y - 60 || h.y - h.extentBack > player.y + 60) continue;
      for (final s in h.shapes) {
        if (s.hits(pc, r * 0.78)) {
          _crash('Hit ${h.label}');
          if (status != RunStatus.running) return;
          break;
        }
      }
      if (h.pits.isNotEmpty) {
        final inPit = h.pits.any((p) => p.deflate(10).contains(pc));
        final onSafe = h.safe.any((p) => p.contains(pc));
        if (inPit && !onSafe) {
          _crash('Fell into ${h.label}');
          if (status != RunStatus.running) return;
        }
      }
    }
    for (final p in pickups) {
      if (p.collected) continue;
      if ((p.pos - pc).distance < r + p.radius) _pickup(p);
    }
  }

  void _collect(Body b) {
    removeBody(b, RemoveReason.collected);
    final style = materialStyles[b.def.material]!;
    flyIns.add(FlyIn(List.of(b.poly), style.base));
    var value = b.def.value;
    if (hasPower(PowerUpType.doubleReward)) value *= 2;
    if (b.isRelicWhole) {
      stats.relicsSaved++;
      carry.relics++;
      value *= 2;
      _perfect('RELIC SAVED!', b.center, GameEventType.relicSaved);
    }
    final results = carry.add(b.def, value);
    stats.piecesCollected++;
    stats.shardsCollected += value;
    addScore(5 * value);
    combo.refresh();
    emit(GameEventType.collect, value);
    particles.emit(at: Offset(player.x, player.y), color: style.light, count: 5, speed: 90, life: 0.3, size: 3);
    for (final r in results) {
      stats.combines++;
      addScore(40 * (r.tier + 1));
      floatText('FUSE! +${r.bonus}', Offset(player.x, player.y + 50), AppColors.reward, big: true);
      particles.ring(Offset(player.x, player.y), materialStyles[r.material]!.light, size: 70, life: 0.4);
      particles.emit(
          at: Offset(player.x, player.y), color: AppColors.reward, count: 16, speed: 200, life: 0.5, size: 3);
      if (combo.add(1)) _comboUp();
      emit(GameEventType.combine, r.tier);
    }
  }

  void _pickup(Pickup p) {
    p.collected = true;
    if (p.kind == PickupKind.coin) {
      stats.coinsCollected++;
      addScore(10);
      particles.emit(at: p.pos, color: AppColors.reward, count: 6, speed: 110, life: 0.3, size: 2.5);
      emit(GameEventType.coin);
    } else {
      grantPowerUp(p.powerUp!, p.pos);
    }
  }

  void grantPowerUp(PowerUpType t, Offset at) {
    final info = powerUpInfo[t]!;
    switch (t) {
      case PowerUpType.shield:
        player.shields = math.min(2, player.shields + 1);
      case PowerUpType.megaCut:
        megaCharges++;
      default:
        powerUps[t] = info.duration;
    }
    stats.powerUpsUsed++;
    floatText(info.name.toUpperCase(), at + const Offset(0, 40), info.color, big: true);
    particles.ring(at, info.color, size: 60, life: 0.4);
    emit(GameEventType.powerUp);
  }

  void _crash(String reason, {Body? body}) {
    if (player.invuln > 0) return;
    stats.collisions++;
    combo.reset();
    final pc = Offset(player.x, player.y);
    if (body != null) {
      // The obstacle shatters on impact either way.
      particles.emit(
          at: body.center,
          color: materialStyles[body.def.material]!.base,
          kind: ParticleKind.debris,
          count: 14,
          speed: 220,
          life: 0.6,
          size: 6);
      removeBody(body, RemoveReason.destroyed);
    }
    if (player.shields > 0 || config.isTutorial) {
      if (player.shields > 0) player.shields--;
      player.invuln = 1.3;
      player.hitFlash = 1;
      camera.addShake(6);
      particles.ring(pc, AppColors.success, size: 80, life: 0.45);
      floatText(config.isTutorial && body != null ? 'SWIPE TO CUT IT!' : 'SHIELD!', pc + const Offset(0, 60),
          AppColors.success,
          big: true);
      emit(GameEventType.shieldBreak);
      return;
    }
    status = RunStatus.failed;
    failReason = reason;
    player.alive = false;
    statusTime = 0;
    cutter.reset();
    camera.addShake(10);
    particles.emit(
        at: pc, color: AppColors.primary, kind: ParticleKind.debris, count: 22, speed: 260, life: 0.8, size: 6);
    particles.ring(pc, AppColors.danger, size: 90, life: 0.5);
    stats.finalShards = carry.shards;
    emit(GameEventType.crash);
  }

  /// Rewarded continue: revive with brief invulnerability.
  void revive() {
    if (status != RunStatus.failed) return;
    status = RunStatus.running;
    usedContinue = true;
    player.alive = true;
    player.invuln = 2.2;
    player.hitFlash = 1;
    failReason = null;
    // Clear what killed us nearby.
    for (final b in bodies) {
      if (!b.removed && b.solid && (b.center.dy - player.y).abs() < 160) removeBody(b, RemoveReason.destroyed);
    }
    particles.ring(Offset(player.x, player.y), AppColors.success, size: 120, life: 0.6);
  }

  // ------------------------------------------------------------------- gates

  void _gates() {
    for (final g in gates) {
      if (g.resolved || player.y < g.y) continue;
      g.resolved = true;
      var idx = g.options.indexWhere((o) => player.x >= o.x0 && player.x < o.x1);
      if (idx < 0) {
        var best = double.infinity;
        for (var i = 0; i < g.options.length; i++) {
          final d = (g.options[i].center - player.x).abs();
          if (d < best) {
            best = d;
            idx = i;
          }
        }
      }
      g.chosen = idx;
      g.flash = 1;
      final values = g.options.map(_gateValue).toList();
      final bestValue = values.reduce(math.max);
      final before = carry.shards;
      final ok = _applyGate(g.options[idx], Offset(g.options[idx].center, g.y));
      final delta = carry.shards - before;
      if (delta != 0) {
        hudFlies.add(HudFly(delta > 0 ? '+$delta' : '−${-delta}', Offset(g.options[idx].center, g.y),
            delta > 0 ? AppColors.success : AppColors.danger));
      }
      g.failed = !ok;
      stats.gatesPassed++;
      if (ok && values[idx] >= bestValue && values[idx] > 0 && g.options.length > 1) {
        stats.perfectGates++;
        _perfect('PERFECT GATE', Offset(player.x, g.y + 90), GameEventType.perfectGate);
      }
    }
  }

  double _gateValue(GateOption o) {
    final s = carry.shards;
    switch (o.type) {
      case GateType.add:
        return o.value.toDouble();
      case GateType.multiply:
      case GateType.risk:
        return s * (o.value - 1.0);
      case GateType.subtract:
        return -math.min(o.value, s).toDouble();
      case GateType.quantity:
        return s >= o.value ? o.value.toDouble() : -s * 0.25;
      case GateType.sacrifice:
        return s >= o.value ? 8.0 - o.value : -1;
      case GateType.preserve:
        return carry.relics > 0 ? s.toDouble() : 0;
      case GateType.color:
        return carry.countMaterial(o.material!) * 3.0;
      case GateType.fusion:
        final pairs = <String, int>{};
        for (final i in carry.items) {
          if (i.tier < CarryStack.maxTier) pairs.update('${i.group}${i.tier}', (v) => v + 1, ifAbsent: () => 1);
        }
        return pairs.values.fold<int>(0, (a, v) => a + v ~/ 2) * 2.0;
      case GateType.reward:
        return o.value / 2;
      case GateType.powerUp:
        return 5;
    }
  }

  bool _loseShards(int n, Offset at) {
    if (hasPower(PowerUpType.pieceSaver)) {
      powerUps.remove(PowerUpType.pieceSaver);
      floatText('PIECES SAVED!', at, AppColors.success, big: true);
      return false;
    }
    final lost = carry.remove(n);
    floatText('−$lost', at, AppColors.danger, big: true);
    return true;
  }

  bool _applyGate(GateOption o, Offset at) {
    final label = at + const Offset(0, 70);
    switch (o.type) {
      case GateType.add:
        carry.shards += o.value;
        floatText('+${o.value}', label, AppColors.success, big: true);
      case GateType.multiply:
        carry.multiply(o.value);
        floatText('×${o.value}!', label, AppColors.success, big: true);
      case GateType.risk:
        carry.multiply(o.value);
        stats.riskRoutes++;
        floatText('RISK ×${o.value}!', label, AppColors.warning, big: true);
      case GateType.subtract:
        _loseShards(o.value, label);
        stats.gateFails++;
        emit(GameEventType.gateFail);
        combo.reset();
        return false;
      case GateType.quantity:
        if (carry.shards >= o.value) {
          stats.coinsCollected += o.value ~/ 2;
          addScore(o.value * 20);
          floatText('UNLOCKED! +${o.value ~/ 2}◎', label, AppColors.reward, big: true);
        } else {
          _loseShards((carry.shards * 0.25).ceil(), label);
          floatText('NEED ${o.value}', label + const Offset(0, 40), AppColors.danger);
          stats.gateFails++;
          emit(GameEventType.gateFail);
          combo.reset();
          return false;
        }
      case GateType.sacrifice:
        if (carry.shards >= o.value) {
          carry.remove(o.value);
          grantPowerUp(o.powerUp!, at);
        } else {
          floatText('NOT ENOUGH', label, AppColors.textMuted);
          emit(GameEventType.gateFail);
          return false;
        }
      case GateType.preserve:
        if (carry.relics > 0) {
          carry.multiply(2);
          floatText('RELIC ×2!', label, AppColors.reward, big: true);
        } else {
          floatText('NO RELIC', label, AppColors.textMuted);
          return false;
        }
      case GateType.color:
        final n = carry.countMaterial(o.material!);
        if (n > 0) {
          carry.shards += n * 3;
          floatText('+${n * 3}', label, AppColors.success, big: true);
        } else {
          floatText('NO ${materialStyles[o.material]!.name.toUpperCase()}', label, AppColors.textMuted);
          return false;
        }
      case GateType.fusion:
        final results = carry.fuseAllPairs();
        stats.combines += results.length;
        final bonus = results.fold<int>(0, (a, r) => a + r.bonus);
        floatText(results.isEmpty ? 'NOTHING TO FUSE' : 'FUSED ×${results.length} +$bonus', label,
            results.isEmpty ? AppColors.textMuted : AppColors.reward,
            big: results.isNotEmpty);
        if (results.isNotEmpty) {
          emit(GameEventType.combine, 1);
          particles.ring(Offset(player.x, player.y), AppColors.reward, size: 90, life: 0.5);
        }
      case GateType.reward:
        stats.coinsCollected += o.value;
        floatText('+${o.value} ◎', label, AppColors.reward, big: true);
      case GateType.powerUp:
        grantPowerUp(o.powerUp!, at);
    }
    emit(GameEventType.gatePass);
    particles.emit(at: at, color: AppColors.success, count: 14, speed: 180, life: 0.5, size: 3);
    return true;
  }

  // ----------------------------------------------------------------- dodges

  void _dodges() {
    final pc = Offset(player.x, player.y);
    for (final h in hazards) {
      if (h.resolved || h.isFallHazard) continue;
      if (h.kind == HazardKind.wall && h.h > 200) continue; // lane dividers
      if (player.y < h.y - h.extentBack - 40) continue;
      if (player.y > h.y + h.extentFront + 30) {
        h.resolved = true;
        if (h.minDist > 0 && h.minDist < 22 && player.invuln <= 0) {
          stats.perfectDodges++;
          _perfect('PERFECT DODGE', pc + const Offset(0, 60), GameEventType.perfectDodge);
        }
        continue;
      }
      final d = h.distanceTo(pc) - Player.radius;
      if (d < h.minDist) h.minDist = d;
    }
  }

  // ---------------------------------------------------------------- scoring

  void _perfect(String text, Offset at, GameEventType type) {
    floatText(text, at, AppColors.accent, big: true);
    particles.ring(at, AppColors.accent, size: 70, life: 0.4);
    addScore(30);
    if (combo.add(1)) _comboUp();
    emit(type);
  }

  void _comboUp() {
    final m = combo.multiplier;
    floatText('COMBO x$m', Offset(player.x, player.y + 120), AppColors.reward, big: true);
    emit(GameEventType.comboUp, m);
  }

  /// Called by the cut system after every successful split.
  void onCut(Body body, {required bool perfect, required bool auto, required bool chain, required Offset at}) {
    stats.cuts++;
    _groups[body.groupId]?.cut = true;
    addScore(body.def.scoreValue);
    if (!chain && combo.add(1)) _comboUp();
    if (perfect) {
      stats.perfectCuts++;
      floatText('PERFECT CUT!', at + const Offset(0, 40), AppColors.accent, big: true);
      particles.ring(at, AppColors.accent, size: 60, life: 0.35);
      addScore(25);
      if (combo.add(1)) _comboUp();
      emit(GameEventType.perfectCut);
    } else {
      emit(GameEventType.cut);
    }
    if (config.isTutorial && hint == TutorialStep.cut) tutorialSlow = false;
  }

  void onChain(Offset at, int hits) {
    if (hits <= 0) return;
    stats.chainCuts++;
    stats.bestChain = math.max(stats.bestChain, hits);
    addScore(50 * hits);
    if (combo.add(2)) _comboUp();
    floatText(hits >= 3 ? 'PERFECT CHAIN ×$hits!' : 'CUT CHAIN ×$hits!', at + const Offset(0, 50), AppColors.accent,
        big: true);
    camera.addShake(4);
    camera.punch(0.02);
    emit(GameEventType.chain, hits);
  }

  void revealMystery(Offset at) {
    stats.specialCuts++;
    final pool = config.patterns.powerUps;
    if (pool.isNotEmpty && rng.nextDouble() < 0.55) {
      final t = pool[rng.nextInt(pool.length)];
      pickups.add(Pickup(kind: PickupKind.powerUp, pos: at, powerUp: t)..vel = const Offset(0, -60));
      floatText('SURPRISE!', at + const Offset(0, 50), AppColors.accent, big: true);
    } else {
      for (var i = 0; i < 6; i++) {
        final a = i / 6 * math.pi * 2;
        pickups.add(Pickup(kind: PickupKind.coin, pos: at)..vel = Offset(math.cos(a), math.sin(a)) * 160);
      }
      floatText('COIN BURST!', at + const Offset(0, 50), AppColors.reward, big: true);
    }
    particles.ring(at, AppColors.reward, size: 70, life: 0.4);
  }

  void onRelicBroken(Offset at) {
    stats.relicsBroken++;
    floatText('RELIC BROKEN', at + const Offset(0, 40), AppColors.danger, big: true);
    emit(GameEventType.relicBroken);
  }

  // ------------------------------------------------------------ power-ups

  void _tickPowerUps(double dt) {
    if (powerUps.isEmpty) return;
    final expired = <PowerUpType>[];
    powerUps.updateAll((k, v) {
      final nv = v - dt;
      if (nv <= 0) expired.add(k);
      return nv;
    });
    for (final k in expired) {
      powerUps.remove(k);
    }
  }

  // --------------------------------------------------------------- tutorial

  void _showHint(TutorialStep step) {
    hint = step;
    hintTime = 0;
    _hintBaseX = player.x;
    _hintBase = switch (step) {
      TutorialStep.collect => stats.piecesCollected,
      TutorialStep.cut => stats.cuts,
      TutorialStep.pieces => stats.gatesPassed,
      _ => 0,
    };
  }

  void _tutorial(double rdt) {
    final h = hint;
    if (h == null) return;
    hintTime += rdt;
    var done = false;
    switch (h) {
      case TutorialStep.move:
        done = (player.x - _hintBaseX).abs() > 70 && hintTime > 1.0;
      case TutorialStep.collect:
        done = stats.piecesCollected > _hintBase && hintTime > 0.8;
      case TutorialStep.cut:
        done = stats.cuts > _hintBase + 1;
        final target =
            bodies.any((b) => b.solid && !b.isPiece && b.center.dy > player.y && b.center.dy - player.y < 380);
        tutorialSlow = target && stats.cuts <= _hintBase;
        if (stats.cuts > _hintBase && !target) done = done || hintTime > 6;
      case TutorialStep.avoid:
        done = hintTime > 5.5;
      case TutorialStep.pieces:
        done = stats.gatesPassed > _hintBase;
      case TutorialStep.finish:
        done = hintTime > 3;
    }
    if (done) {
      _hintsDone.add(h);
      hint = null;
      tutorialSlow = false;
    }
  }

  // ------------------------------------------------------------------ misc

  void _cleanup() {
    final behind = player.y - viewBehind;
    for (final b in bodies) {
      if (!b.removed && b.bounds.top < behind - 40 && b.bounds.bottom < behind) {
        removeBody(b, RemoveReason.lost);
      }
    }
    bodies.removeWhere((b) => b.removed);
    hazards.removeWhere((h) => h.y + h.extentFront < behind - 100);
    pickups.removeWhere((p) => p.collected || p.pos.dy < behind);
    gates.removeWhere((g) => g.y < behind - 100);
    decals.removeWhere((d) => d.pos.dy < behind - 100);
  }

  /// Crossing the finish line: short slow-motion celebration, then the
  /// runner spends shards to smash through the ×2…×5 bonus barriers.
  void _enterBonus() {
    inBonus = true;
    stats.shieldAtEnd = player.shields > 0;
    stats.finalShards = carry.shards;
    stats.score += carry.shards * 10;
    hint = null;
    tutorialSlow = false;
    cutter.reset();
    _celebration = 0.9;
    camera.punch(0.04);
    camera.addShake(3);
    final at = Offset(player.x, player.y + 40);
    floatText('FINISH!', at + const Offset(0, 60), AppColors.reward, big: true);
    for (var i = 0; i < 5; i++) {
      particles.ring(at, [AppColors.reward, AppColors.accent, AppColors.primary][i % 3],
          size: 60.0 + i * 30, life: 0.5 + i * 0.1);
    }
    for (var i = 0; i < 4; i++) {
      particles.emit(
        at: Offset(40.0 + i * 107, player.y + 60),
        color: [AppColors.primary, AppColors.accent, AppColors.reward, AppColors.success][i],
        kind: ParticleKind.confetti,
        count: 10,
        speed: 260,
        direction: 1.5708,
        spread: 1.6,
        life: 1.4,
        size: 6,
        drag: 1.5,
      );
    }
    emit(GameEventType.finishLine);
  }

  void _bonusTick() {
    final next = bonusMultiplier + 1;
    if (next > bonusMaxMultiplier) {
      _complete();
      return;
    }
    final barrier = bonusStepY(next);
    final cost = config.bonusStepCost;
    if (player.y < barrier - 26) return;
    if (carry.shards >= cost) {
      carry.remove(cost);
      bonusMultiplier = next;
      final at = Offset(player.x, barrier);
      hudFlies.add(HudFly('−$cost', at, AppColors.reward));
      floatText('×$next', at + const Offset(0, 70), AppColors.reward, big: true);
      particles.emit(
          at: at, color: AppColors.reward, kind: ParticleKind.debris, count: 16, speed: 240, life: 0.6, size: 5);
      particles.ring(at, AppColors.reward, size: 90, life: 0.4);
      camera.addShake(2.5);
      emit(GameEventType.bonusStep, next);
      if (next == bonusMaxMultiplier) _complete();
    } else {
      // Not enough shards: the runner stops at this barrier.
      player.y = barrier - 26;
      _complete();
    }
  }

  void _complete() {
    status = RunStatus.completed;
    statusTime = 0;
    _finishSpeed = inBonus ? speed * 0.25 : speed * 0.6;
    if (!inBonus) {
      stats.shieldAtEnd = player.shields > 0;
      stats.finalShards = carry.shards;
      stats.score += carry.shards * 10;
    }
    stats.bonusMultiplier = bonusMultiplier;
    stats.score += stats.finalShards * 10 * (bonusMultiplier - 1);
    hint = null;
    tutorialSlow = false;
    cutter.reset();
    camera.punch(0.03);
    floatText('BONUS ×$bonusMultiplier', Offset(player.x, player.y + 110), AppColors.reward, big: true);
    for (var i = 0; i < 3; i++) {
      particles.ring(Offset(player.x, player.y + 40), [AppColors.reward, AppColors.accent, AppColors.primary][i],
          size: 70.0 + i * 30, life: 0.5 + i * 0.1);
    }
    emit(GameEventType.complete);
  }

  /// Endless mode ends on the first crash; this finalises its stats.
  void finalizeEndless() {
    stats.finalShards = carry.shards;
  }
}
