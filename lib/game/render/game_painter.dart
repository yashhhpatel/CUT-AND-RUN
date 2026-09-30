import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/geometry.dart';
import '../../levels/models/spawn.dart';
import '../../levels/worlds.dart';
import '../../progression/cosmetics.dart';
import '../effects/effects.dart';
import '../engine/game_world.dart';
import '../entities/body.dart';
import '../entities/gate.dart';
import '../entities/hazard.dart';
import '../entities/pickup.dart';
import '../entities/player.dart';
import '../model/materials.dart';
import '../model/object_defs.dart';
import '../model/powerups.dart';
import 'viewport.dart';

/// Renders the whole gameplay layer with lightweight vector drawing — no
/// bitmap assets, so it stays crisp on every screen density.
class GamePainter extends CustomPainter {
  GamePainter({
    required this.world,
    required this.viewport,
    required this.theme,
    required this.loadout,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final GameWorld world;
  final GameViewport viewport;
  final WorldDef theme;
  final Loadout loadout;

  final Paint _fill = Paint()..isAntiAlias = true;
  final Paint _stroke = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  static final Map<String, TextPainter> _textCache = {};

  double get t => world.time;

  @override
  void paint(Canvas canvas, Size size) {
    if (viewport.size != size) viewport.resize(size);
    viewport.cameraY = world.player.y;
    world.viewAhead = viewport.unitsAhead;
    world.viewBehind = viewport.unitsBehind + 40;

    _background(canvas, size);

    canvas.save();
    final cam = world.camera;
    final anchor = Offset(size.width / 2, viewport.playerScreenY);
    canvas.translate(cam.offset.dx, cam.offset.dy);
    if (cam.zoom > 0) {
      canvas.translate(anchor.dx, anchor.dy);
      canvas.scale(1 + cam.zoom);
      canvas.translate(-anchor.dx, -anchor.dy);
    }

    // ---- world layer (y up)
    canvas.save();
    canvas.translate(viewport.trackLeft, viewport.playerScreenY + viewport.cameraY * viewport.scale);
    canvas.scale(viewport.scale, -viewport.scale);
    _track(canvas);
    _floorHazards(canvas);
    _gatesBase(canvas);
    _shadows(canvas);
    _bodies(canvas);
    _pickups(canvas);
    _hazards(canvas);
    _playerTrail(canvas);
    _player(canvas);
    _flyIns(canvas);
    _particles(canvas);
    _beams(canvas);
    _cutTrail(canvas);
    canvas.restore();

    // ---- screen-space labels
    _gateLabels(canvas);
    _bodyGlyphs(canvas);
    _decals(canvas);
    _floatingTexts(canvas);
    canvas.restore();

    _ambient(canvas, size);
    if (world.hasPower(PowerUpType.slowMotion) || world.tutorialSlow) _vignette(canvas, size, const Color(0x552D6BFF));
    if (world.player.hitFlash > 0) _vignette(canvas, size, AppColors.danger.withOpacity(0.35 * world.player.hitFlash));
  }

  // ------------------------------------------------------------- background

  void _background(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    _fill.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [theme.bgTop, theme.bgBottom],
    ).createShader(rect);
    canvas.drawRect(rect, _fill);
    _fill.shader = null;
  }

  void _ambient(Canvas canvas, Size size) {
    _fill.color = theme.particle;
    final h = size.height;
    for (var i = 0; i < 22; i++) {
      final sx = ((i * 97 + 13) % 100) / 100 * size.width;
      final base = ((i * 53 + 7) % 100) / 100 * h;
      final sy = (base + (world.player.y * 0.35 + t * 12) * (1 + i % 3) * viewport.scale * 0.3) % h;
      canvas.drawCircle(Offset(sx, sy), 1.2 + (i % 3) * 0.8, _fill);
    }
  }

  void _vignette(Canvas canvas, Size size, Color c) {
    final rect = Offset.zero & size;
    _fill.shader = RadialGradient(
      colors: [Colors.transparent, c],
      stops: const [0.6, 1],
      radius: 0.9,
    ).createShader(rect);
    canvas.drawRect(rect, _fill);
    _fill.shader = null;
  }

  // ------------------------------------------------------------------ track

  double get _yMin => viewport.cameraY - viewport.unitsBehind - 20;
  double get _yMax => viewport.cameraY + viewport.unitsAhead + 20;

  void _track(Canvas canvas) {
    final y0 = _yMin, y1 = _yMax;
    // Floor tiles.
    const tile = 100.0;
    var ty = (y0 / tile).floor() * tile;
    var row = (y0 / tile).floor();
    while (ty < y1) {
      _fill.color = row.isEven ? theme.floorA : theme.floorB;
      canvas.drawRect(Rect.fromLTWH(0, ty, kTrackWidth, tile), _fill);
      ty += tile;
      row++;
    }
    // Lane guides.
    _stroke
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 3;
    const dash = 34.0, gap = 46.0;
    var dy = ((y0 / (dash + gap)).floor()) * (dash + gap);
    while (dy < y1) {
      for (final lx in [133.3, 266.6]) {
        canvas.drawLine(Offset(lx, dy), Offset(lx, dy + dash), _stroke);
      }
      dy += dash + gap;
    }
    // Side decor in the margins.
    _decor(canvas, y0, y1);
    // Edge rails.
    _stroke
      ..color = theme.rail.withOpacity(0.22)
      ..strokeWidth = 9;
    canvas.drawLine(Offset(0, y0), Offset(0, y1), _stroke);
    canvas.drawLine(Offset(kTrackWidth, y0), Offset(kTrackWidth, y1), _stroke);
    _stroke
      ..color = theme.rail
      ..strokeWidth = 3;
    canvas.drawLine(Offset(0, y0), Offset(0, y1), _stroke);
    canvas.drawLine(Offset(kTrackWidth, y0), Offset(kTrackWidth, y1), _stroke);

    // Finish line.
    if (!world.config.isEndless) {
      final fy = world.config.pathLength;
      if (fy > y0 - 60 && fy < y1 + 60) {
        const cell = 20.0;
        for (var i = 0; i < 20; i++) {
          for (var j = 0; j < 2; j++) {
            _fill.color = (i + j).isEven ? Colors.white : const Color(0xFF15182E);
            canvas.drawRect(Rect.fromLTWH(i * cell, fy + j * cell, cell, cell), _fill);
          }
        }
        _fill.color = theme.accent;
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(-16, fy - 10, 16, 60), const Radius.circular(4)), _fill);
        canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromLTWH(kTrackWidth, fy - 10, 16, 60), const Radius.circular(4)), _fill);
      }
    }
  }

  void _decor(Canvas canvas, double y0, double y1) {
    const step = 150.0;
    var y = (y0 / step).floor() * step;
    const leftX = -GameViewport.margin / 2 - 1, rightX = kTrackWidth + GameViewport.margin / 2 + 1;
    while (y < y1) {
      final k = (y / step).round();
      for (final x in [leftX, rightX]) {
        final c = Offset(x, y + (k.isEven ? 0 : 60));
        switch (theme.decor) {
          case DecorStyle.yard:
            _fill.color = const Color(0xFF3A4A72);
            canvas.drawRRect(
                RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: 10, height: 34), const Radius.circular(3)),
                _fill);
          case DecorStyle.factory:
            _fill.color = theme.rail.withOpacity(0.5);
            canvas.drawCircle(c, 5, _fill);
          case DecorStyle.crystal:
            _fill.color = theme.accent.withOpacity(0.55);
            canvas.drawPath(_polyPath(Geo.regularPoly(c, 9, 3, math.pi / 2)), _fill);
          case DecorStyle.jungle:
            _fill.color = const Color(0xFF3F8F4F);
            canvas.drawOval(Rect.fromCenter(center: c, width: 14, height: 30), _fill);
          case DecorStyle.city:
            _fill.color = const Color(0xFF4F4A58);
            canvas.drawRect(Rect.fromCenter(center: c, width: 14, height: 44), _fill);
          case DecorStyle.frost:
            _fill.color = Colors.white.withOpacity(0.6);
            canvas.drawCircle(c, 6, _fill);
          case DecorStyle.sky:
            _fill.color = Colors.white.withOpacity(0.5);
            canvas.drawCircle(c, 8, _fill);
            canvas.drawCircle(c + const Offset(0, 9), 6, _fill);
          case DecorStyle.space:
            _fill.color = Colors.white.withOpacity(0.8);
            canvas.drawCircle(c, 1.8, _fill);
          case DecorStyle.quantum:
            _fill.color = theme.rail.withOpacity(0.5);
            canvas.drawPath(_polyPath(Geo.regularPoly(c, 7, 4, t + k)), _fill);
          case DecorStyle.core:
            _fill.color = theme.rail.withOpacity(0.4 + 0.3 * math.sin(t * 3 + k));
            canvas.drawCircle(c, 4, _fill);
        }
      }
      y += step;
    }
  }

  // ---------------------------------------------------------------- hazards

  void _floorHazards(Canvas canvas) {
    for (final h in world.hazards) {
      if (!h.isFallHazard) continue;
      switch (h.kind) {
        case HazardKind.pit:
          _pit(canvas, Rect.fromCenter(center: Offset(h.x, h.y), width: h.w, height: h.h));
        case HazardKind.platformPit:
          _pit(canvas, Rect.fromLTWH(0, h.y - h.h / 2, kTrackWidth, h.h));
          final r = Rect.fromCenter(center: Offset(h.platformX, h.y), width: h.gap, height: h.h + 30);
          _fill.color = theme.floorA;
          canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(6)), _fill);
          _stroke
            ..color = theme.rail
            ..strokeWidth = 3;
          canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(6)), _stroke);
        case HazardKind.collapsingFloor:
          for (var r = 0; r < h.rowMasks.length; r++) {
            for (var c = 0; c < 5; c++) {
              final i = r * 5 + c;
              final rect = Rect.fromLTWH(c * 80.0, h.y + r * 80.0, 80, 80);
              final collapses = h.rowMasks[r] & (1 << c) != 0;
              final s = h.tileState.isEmpty ? 0.0 : h.tileState[i];
              if (collapses && s >= 1) {
                _pit(canvas, rect.deflate(2));
                continue;
              }
              _fill.color =
                  collapses ? Color.lerp(theme.floorB, const Color(0xFF6B4A3A), 0.35 + s * 0.4)! : theme.floorA;
              canvas.drawRect(rect.deflate(2), _fill);
              if (collapses) {
                _stroke
                  ..color = Colors.black.withOpacity(0.35 + s * 0.5)
                  ..strokeWidth = 2;
                final cx = rect.center;
                canvas.drawLine(cx + const Offset(-24, -18), cx + const Offset(4, 6), _stroke);
                canvas.drawLine(cx + const Offset(4, 6), cx + const Offset(22, -10), _stroke);
                if (s > 0.3) canvas.drawLine(cx + const Offset(4, 6), cx + const Offset(-6, 28), _stroke);
              }
            }
          }
        default:
          break;
      }
    }
  }

  void _pit(Canvas canvas, Rect r) {
    _fill.color = const Color(0xFF05060C);
    canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(8)), _fill);
    _stroke
      ..color = AppColors.danger.withOpacity(0.55)
      ..strokeWidth = 2.5;
    canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(8)), _stroke);
    _fill.color = Colors.white.withOpacity(0.05);
    canvas.drawRect(Rect.fromLTWH(r.left + 6, r.bottom - 12, r.width - 12, 6), _fill);
  }

  void _hazards(Canvas canvas) {
    for (final h in world.hazards) {
      switch (h.kind) {
        case HazardKind.spikes:
          _spikes(canvas, Rect.fromCenter(center: Offset(h.x, h.y), width: h.w, height: h.h));
        case HazardKind.wall:
        case HazardKind.movingWall:
          for (final s in h.shapes) {
            if (s is HRect) _wall(canvas, s.rect, moving: h.kind == HazardKind.movingWall);
          }
        case HazardKind.rotatingBar:
          for (final s in h.shapes) {
            if (s is HCapsule) {
              _stroke
                ..color = const Color(0xFF2A2F45)
                ..strokeWidth = 22;
              canvas.drawLine(s.a, s.b, _stroke);
              _stroke
                ..color = const Color(0xFFB9C2D9)
                ..strokeWidth = 14;
              canvas.drawLine(s.a, s.b, _stroke);
              _fill.color = AppColors.danger;
              canvas.drawCircle(s.a, 9, _fill);
              canvas.drawCircle(s.b, 9, _fill);
            } else if (s is HCircle) {
              _fill.color = const Color(0xFF2A2F45);
              canvas.drawCircle(s.center, s.radius + 3, _fill);
              _fill.color = AppColors.warning;
              canvas.drawCircle(s.center, s.radius - 3, _fill);
            }
          }
        case HazardKind.crusher:
        case HazardKind.timingDoor:
          final closing = h.openness < 0.35;
          for (final s in h.shapes) {
            if (s is HRect) {
              final r = Rect.fromLTRB(math.max(-GameViewport.margin, s.rect.left), s.rect.top,
                  math.min(kTrackWidth + GameViewport.margin, s.rect.right), s.rect.bottom);
              _wall(canvas, r, danger: closing);
            }
          }
          if (h.kind == HazardKind.timingDoor) {
            _fill.color = (h.openness > 0.5 ? AppColors.success : AppColors.danger).withOpacity(0.9);
            canvas.drawCircle(Offset(100, h.y + h.h / 2 + 10), 5, _fill);
            _fill.color = (h.openness <= 0.5 ? AppColors.success : AppColors.danger).withOpacity(0.9);
            canvas.drawCircle(Offset(300, h.y + h.h / 2 + 10), 5, _fill);
          }
        case HazardKind.laser:
          _laser(canvas, h);
        case HazardKind.pendulum:
          final anchor = Offset(h.x, h.y + h.amp);
          _stroke
            ..color = const Color(0xFF8A93AD)
            ..strokeWidth = 5;
          canvas.drawLine(anchor, h.bob, _stroke);
          _fill.color = const Color(0xFF2A2F45);
          canvas.drawCircle(anchor, 10, _fill);
          _blade(canvas, h.bob, 22, t * 6);
        case HazardKind.saw:
          if (h.amp > 0) {
            _stroke
              ..color = Colors.black.withOpacity(0.3)
              ..strokeWidth = 8;
            canvas.drawLine(Offset(h.x - h.amp, h.y), Offset(h.x + h.amp, h.y), _stroke);
          }
          _blade(canvas, h.sawCenter, h.w / 2, h.angle);
        case HazardKind.pushBlock:
          for (final s in h.shapes) {
            if (s is HRect) _wall(canvas, s.rect, danger: h.extension > 0.9);
          }
        default:
          break;
      }
    }
  }

  void _spikes(Canvas canvas, Rect r) {
    _fill.color = const Color(0xFF2A2F45);
    canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(4)), _fill);
    final n = math.max(2, (r.width / 22).floor());
    final w = r.width / n;
    final path = Path();
    for (var i = 0; i < n; i++) {
      final x = r.left + i * w;
      path
        ..moveTo(x + 2, r.top + 4)
        ..lineTo(x + w / 2, r.bottom + 4)
        ..lineTo(x + w - 2, r.top + 4)
        ..close();
    }
    _fill.color = const Color(0xFFDCE2F0);
    canvas.drawPath(path, _fill);
    _stroke
      ..color = AppColors.danger
      ..strokeWidth = 2;
    canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(4)), _stroke);
  }

  void _wall(Canvas canvas, Rect r, {bool moving = false, bool danger = false}) {
    _fill.color = const Color(0xFF1B1F33);
    canvas.drawRRect(RRect.fromRectAndRadius(r.shift(const Offset(3, -4)), const Radius.circular(5)), _fill);
    _fill.color = danger ? const Color(0xFF7A2A36) : const Color(0xFF4A5170);
    canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(5)), _fill);
    _fill.color = Colors.white.withOpacity(0.12);
    canvas.drawRect(Rect.fromLTWH(r.left + 3, r.bottom - 7, math.max(0, r.width - 6), 4), _fill);
    // Hazard stripes at the ends.
    _fill.color = AppColors.warning.withOpacity(0.85);
    for (final ex in [r.left + 4, r.right - 14]) {
      if (r.width < 30) break;
      canvas.drawRect(Rect.fromLTWH(ex, r.top + 3, 10, math.max(0, r.height - 6)), _fill);
    }
    if (moving) {
      _stroke
        ..color = Colors.white.withOpacity(0.5)
        ..strokeWidth = 2.5;
      final c = r.center;
      canvas.drawLine(c + const Offset(-14, 0), c + const Offset(14, 0), _stroke);
      canvas.drawLine(c + const Offset(-14, 0), c + const Offset(-8, 5), _stroke);
      canvas.drawLine(c + const Offset(14, 0), c + const Offset(8, 5), _stroke);
    }
  }

  void _laser(Canvas canvas, Hazard h) {
    const x0 = 0.0, mid = kTrackWidth / 2, x1 = kTrackWidth;
    _fill.color = const Color(0xFF2A2F45);
    for (final ex in [x0 - 4, mid, x1 + 4]) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset(ex, h.y), width: 16, height: 26), const Radius.circular(4)),
          _fill);
    }
    final blink = (t * 12).floor().isEven;
    for (final left in [true, false]) {
      final a = Offset(left ? x0 : mid + 8, h.y);
      final b = Offset(left ? mid - 8 : x1, h.y);
      final on = h.laserLeftOn == left;
      if (on) {
        _stroke
          ..color = AppColors.danger.withOpacity(0.35)
          ..strokeWidth = 18;
        canvas.drawLine(a, b, _stroke);
        _stroke
          ..color = const Color(0xFFFFD0D5)
          ..strokeWidth = 5;
        canvas.drawLine(a, b, _stroke);
      } else if (h.laserWarn) {
        // The dark beam is about to fire.
        _stroke
          ..color = AppColors.danger.withOpacity(blink ? 0.85 : 0.25)
          ..strokeWidth = 2.5;
        canvas.drawLine(a, b, _stroke);
      } else {
        _stroke
          ..color = AppColors.danger.withOpacity(0.18)
          ..strokeWidth = 1.5;
        for (var x = a.dx; x < b.dx; x += 16) {
          canvas.drawLine(Offset(x, h.y), Offset(math.min(b.dx, x + 7), h.y), _stroke);
        }
      }
    }
    _fill.color = AppColors.danger;
    canvas.drawCircle(Offset(h.laserLeftOn ? x0 - 4 : x1 + 4, h.y), 4, _fill);
  }

  void _blade(Canvas canvas, Offset c, double r, double angle) {
    final path = Path();
    const teeth = 12;
    for (var i = 0; i < teeth * 2; i++) {
      final a = angle + i * math.pi / teeth;
      final rr = i.isEven ? r : r * 0.78;
      final p = Offset(c.dx + math.cos(a) * rr, c.dy + math.sin(a) * rr);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    _fill.color = Colors.black.withOpacity(0.25);
    canvas.drawCircle(c + const Offset(3, -4), r, _fill);
    _fill.color = const Color(0xFFD5DBE8);
    canvas.drawPath(path, _fill);
    _fill.color = AppColors.danger;
    canvas.drawCircle(c, r * 0.36, _fill);
    _fill.color = const Color(0xFF2A2F45);
    canvas.drawCircle(c, r * 0.14, _fill);
  }

  // ------------------------------------------------------------------ gates

  Color _gateColor(GateOption o) {
    switch (o.type) {
      case GateType.subtract:
        return AppColors.danger;
      case GateType.risk:
        return AppColors.warning;
      case GateType.powerUp:
      case GateType.sacrifice:
        return AppColors.accent;
      case GateType.reward:
      case GateType.preserve:
      case GateType.fusion:
        return AppColors.reward;
      default:
        return AppColors.success;
    }
  }

  void _gatesBase(Canvas canvas) {
    for (final g in world.gates) {
      for (var i = 0; i < g.options.length; i++) {
        final o = g.options[i];
        final color = _gateColor(o);
        final dim = g.resolved && g.chosen != i;
        final r = Rect.fromLTRB(o.x0 + 4, g.y - 28, o.x1 - 4, g.y + 28);
        _fill.color = color.withOpacity(dim ? 0.08 : 0.22 + (g.chosen == i ? g.flash * 0.5 : 0));
        canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(10)), _fill);
        _stroke
          ..color = color.withOpacity(dim ? 0.25 : 0.9)
          ..strokeWidth = 3;
        canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(10)), _stroke);
      }
      // Posts between options.
      _fill.color = const Color(0xFFE8ECF7);
      for (var i = 0; i <= g.options.length; i++) {
        final x = i == g.options.length ? g.options.last.x1 : g.options[i].x0;
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(center: Offset(x.clamp(3, kTrackWidth - 3), g.y), width: 7, height: 66),
                const Radius.circular(3)),
            _fill);
      }
    }
  }

  void _gateLabels(Canvas canvas) {
    for (final g in world.gates) {
      for (var i = 0; i < g.options.length; i++) {
        final o = g.options[i];
        final dim = g.resolved && g.chosen != i;
        final p = viewport.toScreen(Offset(o.center, g.y));
        final color = dim ? AppColors.textFaint : Colors.white;
        _text(canvas, o.label, p + Offset(0, o.subLabel == null ? 0 : -7), color, 19 * viewport.scale / 2.4,
            weight: FontWeight.w900);
        if (o.subLabel != null) {
          _text(canvas, o.subLabel!, p + const Offset(0, 13), color.withOpacity(0.8), 11.5 * viewport.scale / 2.4,
              weight: FontWeight.w700);
        }
      }
    }
  }

  // ----------------------------------------------------------------- bodies

  Path _polyPath(List<Offset> poly) {
    final path = Path()..moveTo(poly.first.dx, poly.first.dy);
    for (var i = 1; i < poly.length; i++) {
      path.lineTo(poly[i].dx, poly[i].dy);
    }
    return path..close();
  }

  void _shadows(Canvas canvas) {
    _fill.color = Colors.black.withOpacity(0.28);
    for (final b in world.bodies) {
      if (b.removed || b.pendingDrop || b.fall >= 0) continue;
      if (b.airTime > 0) {
        final k = 1 - (b.airTime / 0.85).clamp(0.0, 1.0);
        _fill.color = Colors.black.withOpacity(0.15 + 0.3 * k);
        canvas.drawOval(
            Rect.fromCenter(
                center: b.center, width: b.bounds.width * (0.4 + 0.6 * k), height: b.bounds.height * (0.4 + 0.6 * k)),
            _fill);
        _fill.color = Colors.black.withOpacity(0.28);
        continue;
      }
      canvas.drawPath(_polyPath([for (final p in b.poly) p + const Offset(4, -5)]), _fill);
    }
  }

  bool _inView(Rect r) => r.top > _yMin - 40 && r.bottom < _yMax + 40;

  void _bodies(Canvas canvas) {
    final p = world.player;
    final precision = world.hasPower(PowerUpType.precisionCutter);
    for (final b in world.bodies) {
      if (b.removed || b.pendingDrop || !_inView(b.bounds)) continue;
      final style = materialStyles[b.def.material]!;
      canvas.save();
      if (b.airTime > 0) {
        final k = (b.airTime / 0.85).clamp(0.0, 1.0);
        canvas.translate(b.center.dx, b.center.dy + k * 120);
        canvas.scale(1 + k * 0.5);
        canvas.translate(-b.center.dx, -b.center.dy);
      } else if (b.fall >= 0) {
        final s = (1 - b.fall * 0.7).clamp(0.2, 1.0);
        canvas.translate(b.center.dx, b.center.dy);
        canvas.scale(s);
        canvas.translate(-b.center.dx, -b.center.dy);
      } else if (b.collectible) {
        final s = 1 + 0.06 * math.sin(t * 7 + b.id);
        canvas.translate(b.center.dx, b.center.dy);
        canvas.scale(s);
        canvas.translate(-b.center.dx, -b.center.dy);
      }
      final path = _polyPath(b.poly);
      final alpha = b.fall >= 0 ? (1 - b.fall).clamp(0.0, 1.0) : 1.0;

      if (b.isPiece) {
        if (b.collectible) {
          _stroke
            ..color = AppColors.reward.withOpacity((0.35 + 0.25 * math.sin(t * 8 + b.id)) * alpha)
            ..strokeWidth = 7;
          canvas.drawPath(path, _stroke);
        }
        _fill.color = style.interior.withOpacity(alpha);
        canvas.drawPath(path, _fill);
        _stroke
          ..color = style.base.withOpacity(alpha)
          ..strokeWidth = 4;
        canvas.drawPath(path, _stroke);
        if (!b.collectible && b.solid) {
          // Heavy piece: still an obstacle. Dark rim + hatch reads without colour.
          _stroke
            ..color = style.dark.withOpacity(0.9 * alpha)
            ..strokeWidth = 2;
          canvas.drawPath(path, _stroke);
          canvas.save();
          canvas.clipPath(path);
          _stroke
            ..color = style.dark.withOpacity(0.35)
            ..strokeWidth = 2;
          final bb = b.bounds;
          for (var x = bb.left - bb.height; x < bb.right; x += 12) {
            canvas.drawLine(Offset(x, bb.bottom), Offset(x + bb.height, bb.top), _stroke);
          }
          canvas.restore();
        }
      } else {
        _fill.color = style.base.withOpacity(alpha);
        canvas.drawPath(path, _fill);
        canvas.save();
        canvas.clipPath(path);
        _pattern(canvas, b, style);
        canvas.restore();
        _stroke
          ..color = style.dark.withOpacity(alpha)
          ..strokeWidth = 3;
        canvas.drawPath(path, _stroke);
      }

      for (final c in b.cracks) {
        _stroke
          ..color = Colors.white.withOpacity(0.85)
          ..strokeWidth = 2.5;
        final mid = Offset.lerp(c.$1, c.$2, 0.5)! + const Offset(4, 3);
        canvas.drawLine(c.$1, mid, _stroke);
        canvas.drawLine(mid, c.$2, _stroke);
      }
      if (b.def.cutResistance == CutResistance.hard && b.hitsLeft > 1) {
        _fill.color = Colors.white;
        for (var i = 0; i < b.hitsLeft; i++) {
          canvas.drawCircle(Offset(b.center.dx - 7 + i * 14, b.bounds.top - 9), 3.5, _fill);
        }
      }
      if (b.seamA != null && b.solid) {
        final chord = Geo.clipLine(b.poly, b.seamA!, b.seamB!);
        if (chord != null) _seam(canvas, chord.$1, chord.$2, reinforced: !b.seamIsTarget);
      } else if (precision && b.solid && b.def.cuttable && !b.isRelicWhole) {
        final chord = Geo.clipLine(b.poly, b.center - const Offset(0, 1), b.center + const Offset(0, 1));
        if (chord != null) _seam(canvas, chord.$1, chord.$2, reinforced: false);
      }
      if (b.flash > 0) {
        _fill.color = Colors.white.withOpacity(0.6 * b.flash);
        canvas.drawPath(path, _fill);
      }
      canvas.restore();

      // Target brackets on uncut blockers directly in the player's path.
      if (b.solid && !b.isPiece && b.def.cuttable && !b.isRelicWhole) {
        final ahead = b.center.dy - p.y;
        if (ahead > 60 && ahead < 520 && (b.center.dx - p.x).abs() < b.bounds.width / 2 + Player.radius) {
          _brackets(canvas, b.bounds.inflate(8), 0.35 + 0.25 * math.sin(t * 10));
        }
      }
      if (world.config.isTutorial && world.hint == TutorialStep.cut && b.solid && !b.isPiece) {
        final ahead = b.center.dy - p.y;
        if (ahead > 0 && ahead < 500) _swipeGuide(canvas, b);
      }
    }
  }

  void _pattern(Canvas canvas, Body b, MaterialStyle style) {
    final bb = b.bounds;
    final c = b.center;
    switch (style.pattern) {
      case SurfacePattern.grain:
        _stroke
          ..color = style.dark.withOpacity(0.35)
          ..strokeWidth = 2;
        final horizontal = bb.width >= bb.height;
        for (var i = 1; i <= 3; i++) {
          if (horizontal) {
            final y = bb.top + bb.height * i / 4;
            canvas.drawLine(Offset(bb.left, y), Offset(bb.right, y + 4 * math.sin(i.toDouble())), _stroke);
          } else {
            final x = bb.left + bb.width * i / 4;
            canvas.drawLine(Offset(x, bb.top), Offset(x + 4 * math.sin(i.toDouble()), bb.bottom), _stroke);
          }
        }
        _fill.color = style.light.withOpacity(0.5);
        canvas.drawRect(Rect.fromLTWH(bb.left, bb.bottom - 7, bb.width, 7), _fill);
      case SurfacePattern.rind:
        _stroke
          ..color = style.dark.withOpacity(0.6)
          ..strokeWidth = 4;
        for (var i = -2; i <= 2; i++) {
          canvas.drawLine(Offset(c.dx + i * 13, bb.top), Offset(c.dx + i * 9, bb.bottom), _stroke);
        }
        _fill.color = style.light.withOpacity(0.5);
        canvas.drawCircle(c + Offset(-bb.width * 0.2, bb.height * 0.2), bb.width * 0.12, _fill);
      case SurfacePattern.coil:
        _stroke
          ..color = style.dark.withOpacity(0.5)
          ..strokeWidth = 2.5;
        for (var r = 8.0; r < bb.width / 2; r += 9) {
          canvas.drawCircle(c, r, _stroke);
        }
      case SurfacePattern.wobble:
        final w = 1 + 0.03 * math.sin(t * 9 + b.id);
        _fill.color = style.light.withOpacity(0.55);
        canvas.drawOval(
            Rect.fromCenter(
                center: c + Offset(-bb.width * 0.18, bb.height * 0.2),
                width: bb.width * 0.32 * w,
                height: bb.height * 0.2 / w),
            _fill);
      case SurfacePattern.facets:
        _stroke
          ..color = style.light.withOpacity(0.7)
          ..strokeWidth = 2;
        for (final v in b.poly) {
          canvas.drawLine(c, v, _stroke);
        }
        _fill.color = style.light.withOpacity(0.35);
        canvas.drawPath(_polyPath([for (final v in b.poly) Offset.lerp(c, v, 0.45)!]), _fill);
      case SurfacePattern.stripes:
        _stroke
          ..color = style.light.withOpacity(0.45)
          ..strokeWidth = 5;
        for (var x = bb.left - bb.height; x < bb.right; x += 16) {
          canvas.drawLine(Offset(x, bb.top), Offset(x + bb.height, bb.bottom), _stroke);
        }
      case SurfacePattern.core:
        final pulse = 0.8 + 0.2 * math.sin(t * 6 + b.id);
        _fill.color = style.light.withOpacity(0.35);
        canvas.drawCircle(c, 24 * pulse, _fill);
        _fill.color = style.interior;
        canvas.drawCircle(c, 11 * pulse, _fill);
        _stroke
          ..color = style.dark
          ..strokeWidth = 3;
        canvas.drawLine(Offset(bb.left, bb.bottom - 10), Offset(bb.right, bb.bottom - 10), _stroke);
        canvas.drawLine(Offset(bb.left, bb.top + 10), Offset(bb.right, bb.top + 10), _stroke);
      case SurfacePattern.rivets:
        _stroke
          ..color = style.dark.withOpacity(0.6)
          ..strokeWidth = 4;
        canvas.drawLine(bb.topLeft, bb.bottomRight, _stroke);
        canvas.drawLine(bb.bottomLeft, bb.topRight, _stroke);
        _fill.color = style.light;
        for (final v in b.poly) {
          canvas.drawCircle(Offset.lerp(v, c, 0.18)!, 4, _fill);
        }
      case SurfacePattern.seam:
        _fill.color = style.light;
        for (final v in b.poly) {
          canvas.drawCircle(Offset.lerp(v, c, 0.14)!, 3.5, _fill);
        }
        _stroke
          ..color = style.dark
          ..strokeWidth = 3;
        canvas.drawPath(_polyPath([for (final v in b.poly) Offset.lerp(v, c, 0.28)!]), _stroke);
      case SurfacePattern.question:
        _stroke
          ..color = style.light
          ..strokeWidth = 3;
        canvas.drawRRect(RRect.fromRectAndRadius(bb.deflate(9), const Radius.circular(6)), _stroke);
      case SurfacePattern.shine:
        _fill.color = style.light;
        canvas.drawPath(_polyPath([for (final v in b.poly) Offset.lerp(c, v, 0.6)!]), _fill);
        _fill.color = Colors.white.withOpacity(0.7 + 0.3 * math.sin(t * 5));
        final s = c + Offset(-bb.width * 0.14, bb.height * 0.14);
        canvas.drawPath(
            _polyPath(
                [s + const Offset(0, 9), s + const Offset(2.5, 0), s + const Offset(0, -9), s + const Offset(-2.5, 0)]),
            _fill);
        canvas.drawPath(
            _polyPath(
                [s + const Offset(9, 0), s + const Offset(0, 2.5), s + const Offset(-9, 0), s + const Offset(0, -2.5)]),
            _fill);
      case SurfacePattern.pane:
        _stroke
          ..color = Colors.white.withOpacity(0.55)
          ..strokeWidth = 3;
        canvas.drawLine(Offset(bb.left + 12, bb.bottom), Offset(bb.left + 24, bb.top), _stroke);
        canvas.drawLine(Offset(bb.left + 30, bb.bottom), Offset(bb.left + 36, bb.top), _stroke);
      case SurfacePattern.hazard:
        _stroke
          ..color = AppColors.warning.withOpacity(0.8)
          ..strokeWidth = 7;
        for (var x = bb.left - bb.height; x < bb.right; x += 22) {
          canvas.drawLine(Offset(x, bb.bottom), Offset(x + bb.height, bb.top), _stroke);
        }
        _fill.color = style.base;
        canvas.drawRect(bb.deflate(10), _fill);
    }
    if (b.def.cutResistance == CutResistance.medium) {
      // Speed chevrons: "needs a fast swipe".
      _stroke
        ..color = Colors.white.withOpacity(0.8)
        ..strokeWidth = 2.5;
      final o = Offset(bb.right - 16, bb.top + 12);
      for (var i = 0; i < 2; i++) {
        final x = o.dx + i * 6;
        canvas.drawLine(Offset(x - 4, o.dy + 5), Offset(x, o.dy), _stroke);
        canvas.drawLine(Offset(x, o.dy), Offset(x - 4, o.dy - 5), _stroke);
      }
    }
  }

  void _seam(Canvas canvas, Offset a, Offset b, {required bool reinforced}) {
    final color = reinforced ? AppColors.warning : AppColors.accent;
    final pulse = 0.6 + 0.4 * math.sin(t * 8);
    _stroke
      ..color = color.withOpacity(0.3 * pulse)
      ..strokeWidth = 9;
    canvas.drawLine(a, b, _stroke);
    _stroke
      ..color = color
      ..strokeWidth = 2.5;
    final d = b - a;
    final len = d.distance;
    const dash = 9.0;
    for (var s = 0.0; s < len; s += dash * 2) {
      final e = math.min(len, s + dash);
      canvas.drawLine(a + d * (s / len), a + d * (e / len), _stroke);
    }
  }

  void _brackets(Canvas canvas, Rect r, double alpha) {
    _stroke
      ..color = Colors.white.withOpacity(alpha)
      ..strokeWidth = 2.5;
    const l = 12.0;
    for (final c in [r.topLeft, r.topRight, r.bottomLeft, r.bottomRight]) {
      final sx = c.dx < r.center.dx ? 1.0 : -1.0;
      final sy = c.dy < r.center.dy ? 1.0 : -1.0;
      canvas.drawLine(c, c + Offset(l * sx, 0), _stroke);
      canvas.drawLine(c, c + Offset(0, l * sy), _stroke);
    }
  }

  void _swipeGuide(Canvas canvas, Body b) {
    final k = (t * 1.2) % 1.0;
    final top = Offset(b.center.dx + 20, b.bounds.bottom + 60);
    final bottom = Offset(b.center.dx - 20, b.bounds.top - 60);
    _stroke
      ..color = Colors.white.withOpacity(0.25)
      ..strokeWidth = 4;
    canvas.drawLine(top, bottom, _stroke);
    _fill.color = Colors.white.withOpacity(0.9 * (1 - k));
    canvas.drawCircle(Offset.lerp(top, bottom, k)!, 9, _fill);
  }

  void _bodyGlyphs(Canvas canvas) {
    for (final b in world.bodies) {
      if (b.removed || b.pendingDrop || b.airTime > 0 || b.isPiece) continue;
      if (b.def.specialType == SpecialType.mystery) {
        _text(canvas, '?', viewport.toScreen(b.center), Colors.white, 30 * viewport.scale / 2.4,
            weight: FontWeight.w900);
      }
    }
  }

  // ---------------------------------------------------------------- pickups

  void _pickups(Canvas canvas) {
    for (final p in world.pickups) {
      if (p.collected || p.pos.dy < _yMin || p.pos.dy > _yMax) continue;
      if (p.kind == PickupKind.coin) {
        final sx = math.cos(p.age * 4 + p.pos.dx).abs() * 0.7 + 0.3;
        canvas.save();
        canvas.translate(p.pos.dx, p.pos.dy);
        canvas.scale(sx, 1);
        _fill.color = AppColors.rewardDark;
        canvas.drawCircle(const Offset(0, -2), 12, _fill);
        _fill.color = AppColors.reward;
        canvas.drawCircle(Offset.zero, 12, _fill);
        _stroke
          ..color = const Color(0xFFFFF0B8)
          ..strokeWidth = 2;
        canvas.drawCircle(Offset.zero, 7, _stroke);
        canvas.restore();
      } else {
        final info = powerUpInfo[p.powerUp]!;
        final bob = math.sin(p.age * 4) * 3;
        final c = p.pos + Offset(0, bob);
        _fill.color = info.color.withOpacity(0.25);
        canvas.drawCircle(c, 24 + 2 * math.sin(p.age * 6), _fill);
        _fill.color = const Color(0xFF151A33);
        canvas.drawCircle(c, 18, _fill);
        _stroke
          ..color = info.color
          ..strokeWidth = 3.5;
        canvas.drawCircle(c, 18, _stroke);
      }
    }
  }

  void _decals(Canvas canvas) {
    for (final d in world.decals) {
      _text(canvas, d.text, viewport.toScreen(d.pos), d.color.withOpacity(0.85), 16 * viewport.scale / 2.4,
          weight: FontWeight.w900);
    }
    for (final p in world.pickups) {
      if (p.kind != PickupKind.powerUp || p.collected) continue;
      final info = powerUpInfo[p.powerUp]!;
      _text(canvas, info.short, viewport.toScreen(p.pos + Offset(0, math.sin(p.age * 4) * 3)), Colors.white,
          13 * viewport.scale / 2.4,
          weight: FontWeight.w900);
    }
    if (!world.config.isEndless) {
      final fy = world.config.pathLength + 90;
      if (fy < _yMax && fy > _yMin) {
        _text(canvas, 'FINISH', viewport.toScreen(Offset(200, fy)), Colors.white, 26 * viewport.scale / 2.4,
            weight: FontWeight.w900);
      }
    }
  }

  // ----------------------------------------------------------------- player

  void _playerTrail(Canvas canvas) {
    final trail = loadout.trail;
    final pts = world.trailHistory;
    if (pts.length < 2 || !world.player.alive) return;
    switch (trail.trailStyle) {
      case TrailStyle.basic:
        for (var i = 0; i < pts.length; i += 3) {
          final k = i / pts.length;
          _fill.color = trail.primary.withOpacity(0.25 * k);
          canvas.drawCircle(pts[i], 3 + 4 * k, _fill);
        }
      case TrailStyle.glow:
        for (var i = 1; i < pts.length; i++) {
          final k = i / pts.length;
          _stroke
            ..color = Color.lerp(trail.secondary, trail.primary, k)!.withOpacity(0.6 * k)
            ..strokeWidth = 4 + 18 * k;
          canvas.drawLine(pts[i - 1], pts[i], _stroke);
        }
      case TrailStyle.particle:
        for (var i = 0; i < pts.length; i++) {
          final k = i / pts.length;
          final wob = math.sin(t * 20 + i) * 8 * (1 - k);
          _fill.color = (i.isEven ? trail.primary : trail.secondary).withOpacity(0.8 * k);
          canvas.drawCircle(pts[i] + Offset(wob, 0), 2 + 3 * k, _fill);
        }
      case TrailStyle.lightning:
        final path = Path()..moveTo(pts.first.dx, pts.first.dy);
        for (var i = 1; i < pts.length; i++) {
          final j = ((i * 7919 + (t * 30).floor()) % 13) - 6.0;
          path.lineTo(pts[i].dx + j, pts[i].dy);
        }
        _stroke
          ..color = trail.secondary.withOpacity(0.5)
          ..strokeWidth = 7;
        canvas.drawPath(path, _stroke);
        _stroke
          ..color = trail.primary
          ..strokeWidth = 2.5;
        canvas.drawPath(path, _stroke);
    }
  }

  void _player(Canvas canvas) {
    final p = world.player;
    if (!p.alive) return;
    if (p.invuln > 0 && (t * 16).floor().isEven && world.status == RunStatus.running) return;
    final skin = loadout.skin;
    final c = Offset(p.x, p.y);
    const r = Player.radius;
    final bob = math.sin(p.runPhase * 2);
    final lean = (p.vx * 0.0016).clamp(-0.35, 0.35);

    // Shadow.
    _fill.color = Colors.black.withOpacity(0.3);
    canvas.drawOval(Rect.fromCenter(center: c + const Offset(4, -8), width: r * 2.2, height: r * 1.6), _fill);

    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(-lean);
    // Feet alternate as the runner strides.
    _fill.color = Color.lerp(skin.primary, Colors.black, 0.35)!;
    final stride = math.sin(p.runPhase) * 9;
    canvas.drawOval(Rect.fromCenter(center: Offset(-8, stride), width: 9, height: 13), _fill);
    canvas.drawOval(Rect.fromCenter(center: Offset(8, -stride), width: 9, height: 13), _fill);
    // Squash & stretch with the stride.
    canvas.scale(1 - 0.05 * bob, 1 + 0.06 * bob);
    if (skin.glow != null) {
      _fill.color = skin.glow!.withOpacity(0.3);
      canvas.drawCircle(Offset.zero, r + 7, _fill);
    }
    _fill.color = skin.primary;
    canvas.drawCircle(Offset.zero, r, _fill);
    _fill.color = Colors.white.withOpacity(0.25);
    canvas.drawCircle(const Offset(-6, 6), r * 0.45, _fill);
    // Visor faces forward (up the track).
    _fill.color = skin.secondary;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: const Offset(0, 8), width: 24, height: 9), const Radius.circular(5)),
        _fill);
    _stroke
      ..color = Color.lerp(skin.primary, Colors.black, 0.4)!
      ..strokeWidth = 2.5;
    canvas.drawCircle(Offset.zero, r, _stroke);
    canvas.restore();

    if (p.shields > 0) {
      _stroke
        ..color = AppColors.success.withOpacity(0.7 + 0.2 * math.sin(t * 6))
        ..strokeWidth = 3;
      canvas.drawCircle(c, r + 9, _stroke);
      _fill.color = AppColors.success.withOpacity(0.12);
      canvas.drawCircle(c, r + 9, _fill);
    }
    if (world.hasPower(PowerUpType.magnet)) {
      _stroke
        ..color = powerUpInfo[PowerUpType.magnet]!.color.withOpacity(0.35)
        ..strokeWidth = 2;
      canvas.drawCircle(c, 60 + 10 * math.sin(t * 5), _stroke);
    }
    _carryStack(canvas, c);
  }

  void _carryStack(Canvas canvas, Offset c) {
    final items = world.carry.items;
    if (items.isEmpty) return;
    final n = math.min(9, items.length);
    for (var i = 0; i < n; i++) {
      final item = items[items.length - 1 - i];
      final size = 7.0 + item.tier * 3.5;
      final col = i % 3, row = i ~/ 3;
      final pos = c + Offset((col - 1) * 13.0, -26.0 - row * 12.0);
      final s = size * (1 + item.pop * 0.6);
      final style = materialStyles[item.material]!;
      _fill.color = style.base;
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(center: pos, width: s, height: s), Radius.circular(2 + item.tier.toDouble())),
          _fill);
      if (item.tier > 0) {
        _stroke
          ..color = AppColors.reward
          ..strokeWidth = 1.5;
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(center: pos, width: s, height: s), Radius.circular(2 + item.tier.toDouble())),
            _stroke);
      }
    }
  }

  void _flyIns(Canvas canvas) {
    final pc = Offset(world.player.x, world.player.y);
    for (final f in world.flyIns) {
      final k = Curves.easeIn.transform(f.t.clamp(0.0, 1.0));
      final pts = [for (final p in f.poly) Offset.lerp(p, pc, k)!];
      final c = Geo.centroid(pts);
      final scaled = [for (final p in pts) Offset.lerp(c, p, 1 - k * 0.8)!];
      _fill.color = f.color.withOpacity(1 - k * 0.7);
      canvas.drawPath(_polyPath(scaled), _fill);
    }
  }

  // ---------------------------------------------------------------- effects

  void _particles(Canvas canvas) {
    for (final p in world.particles.alive) {
      final a = (p.life / p.maxLife).clamp(0.0, 1.0);
      switch (p.kind) {
        case ParticleKind.spark:
          _stroke
            ..color = p.color.withOpacity(a)
            ..strokeWidth = p.size;
          canvas.drawLine(Offset(p.x, p.y), Offset(p.x - p.vx * 0.04, p.y - p.vy * 0.04), _stroke);
        case ParticleKind.debris:
        case ParticleKind.confetti:
          _fill.color = p.color.withOpacity(p.kind == ParticleKind.confetti ? math.min(1, a * 2) : a);
          final s = p.size;
          final cs = math.cos(p.rot) * s, sn = math.sin(p.rot) * s;
          final h = p.kind == ParticleKind.confetti ? 0.45 : 1.0;
          canvas.drawPath(
            _polyPath([
              Offset(p.x + cs, p.y + sn),
              Offset(p.x - sn * h, p.y + cs * h),
              Offset(p.x - cs, p.y - sn),
              Offset(p.x + sn * h, p.y - cs * h),
            ]),
            _fill,
          );
        case ParticleKind.dot:
          _fill.color = p.color.withOpacity(a);
          canvas.drawCircle(Offset(p.x, p.y), p.size * (0.5 + a * 0.5), _fill);
        case ParticleKind.ring:
          final k = 1 - a;
          _stroke
            ..color = p.color.withOpacity(a * 0.9)
            ..strokeWidth = 2 + 5 * a;
          canvas.drawCircle(Offset(p.x, p.y), p.size * Curves.easeOut.transform(k), _stroke);
      }
    }
  }

  void _beams(Canvas canvas) {
    final fx = loadout.cutEffect;
    for (final (a, b, life) in world.cutter.beams) {
      final k = (life / 0.25).clamp(0.0, 1.0);
      _stroke
        ..color = fx.secondary.withOpacity(0.4 * k)
        ..strokeWidth = 14 * k + 2;
      canvas.drawLine(a, b, _stroke);
      _stroke
        ..color = fx.primary.withOpacity(k)
        ..strokeWidth = 3;
      canvas.drawLine(a, b, _stroke);
    }
  }

  void _cutTrail(Canvas canvas) {
    final pts = world.cutter.trail;
    if (pts.length < 2) return;
    final fx = loadout.cutEffect;
    for (var pass = 0; pass < 2; pass++) {
      for (var i = 1; i < pts.length; i++) {
        final age = (world.time - pts[i].time) / 0.2;
        final k = (1 - age).clamp(0.0, 1.0);
        if (k <= 0) continue;
        if (pass == 0) {
          _stroke
            ..color = fx.secondary.withOpacity(0.35 * k)
            ..strokeWidth = 16 * k + 2;
        } else {
          _stroke
            ..color = fx.primary.withOpacity(k)
            ..strokeWidth = 6 * k + 1;
        }
        canvas.drawLine(pts[i - 1].pos, pts[i].pos, _stroke);
      }
    }
  }

  // ------------------------------------------------------------------- text

  void _floatingTexts(Canvas canvas) {
    for (final ft in world.texts) {
      final a = (ft.life / 0.3).clamp(0.0, 1.0);
      final pop = ft.age < 0.15 ? 0.6 + ft.age / 0.15 * 0.55 : (ft.age < 0.25 ? 1.15 - (ft.age - 0.15) : 1.05);
      final size = (ft.big ? 22.0 : 15.0) * viewport.scale / 2.4 * pop;
      _text(canvas, ft.text, viewport.toScreen(ft.pos), ft.color.withOpacity(a), size,
          weight: FontWeight.w900, outline: true);
    }
  }

  void _text(Canvas canvas, String text, Offset center, Color color, double size,
      {FontWeight weight = FontWeight.w800, bool outline = false}) {
    final px = (size * 2.4).roundToDouble() / 2.4;
    // Quantise opacity so fading text reuses cached layouts.
    color = color.withOpacity(((color.opacity * 10).round() / 10).clamp(0.0, 1.0));
    final key = '$text|${color.value}|$px|${weight.index}|$outline';
    var tp = _textCache[key];
    if (tp == null) {
      if (_textCache.length > 160) _textCache.clear();
      tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: color,
            fontSize: px * 2.4,
            fontWeight: weight,
            letterSpacing: 0.5,
            shadows: outline
                ? const [Shadow(color: Color(0xCC000000), blurRadius: 4, offset: Offset(0, 2))]
                : const [Shadow(color: Color(0x88000000), blurRadius: 2, offset: Offset(0, 1))],
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout();
      _textCache[key] = tp;
    }
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant GamePainter oldDelegate) => oldDelegate.loadout != loadout || oldDelegate.theme != theme;
}
