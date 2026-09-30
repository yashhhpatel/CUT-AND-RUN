import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/geometry.dart';
import '../../game/model/materials.dart';

class _Shard {
  _Shard(this.poly, this.vel, this.spin, this.color, this.cut);
  List<Offset> poly;
  Offset vel;
  double spin;
  final Color color;
  final bool cut;
  double age = 0;
}

/// Menu background: blocks drift by and get sliced — a living preview of the
/// core mechanic. Cheap vector drawing, capped object count.
class AnimatedBackdrop extends StatefulWidget {
  const AnimatedBackdrop({super.key, this.top = AppColors.bg, this.bottom = AppColors.bgDeep});
  final Color top;
  final Color bottom;

  @override
  State<AnimatedBackdrop> createState() => _AnimatedBackdropState();
}

class _AnimatedBackdropState extends State<AnimatedBackdrop> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _shards = <_Shard>[];
  final _slashes = <(Offset, Offset, double)>[];
  final _rng = math.Random(5);
  final _repaint = ValueNotifier<int>(0);
  Duration _last = Duration.zero;
  double _spawnT = 0;
  double _cutT = 1.2;
  Size _size = Size.zero;

  static const _mats = [
    MaterialKind.wood,
    MaterialKind.crystal,
    MaterialKind.fruit,
    MaterialKind.energy,
    MaterialKind.jelly,
    MaterialKind.prism,
  ];

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
  }

  void _tick(Duration now) {
    final dt = ((now - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = now;
    if (_size == Size.zero) return;
    _spawnT -= dt;
    _cutT -= dt;
    if (_spawnT <= 0 && _shards.length < 12) {
      _spawnT = 1.1 + _rng.nextDouble();
      final w = 50 + _rng.nextDouble() * 50;
      final c = Offset(_rng.nextDouble() * _size.width, _size.height + 60);
      final sides = [4, 4, 6, 3, 8][_rng.nextInt(5)];
      final poly = sides == 4 ? Geo.rectPoly(c, w * 1.3, w) : Geo.regularPoly(c, w * 0.6, sides, _rng.nextDouble());
      final style = materialStyles[_mats[_rng.nextInt(_mats.length)]]!;
      _shards.add(_Shard(poly, Offset((_rng.nextDouble() - 0.5) * 20, -40 - _rng.nextDouble() * 30),
          (_rng.nextDouble() - 0.5) * 0.4, style.base, false));
    }
    if (_cutT <= 0) {
      _cutT = 1.4 + _rng.nextDouble() * 0.8;
      final candidates = _shards.where((s) => !s.cut && Geo.centroid(s.poly).dy < _size.height * 0.85).toList();
      if (candidates.isNotEmpty) {
        final s = candidates[_rng.nextInt(candidates.length)];
        final c = Geo.centroid(s.poly);
        final ang = _rng.nextDouble() * math.pi;
        final d = Offset(math.cos(ang), math.sin(ang));
        final res = Geo.splitConvex(s.poly, c - d, c + d);
        if (res != null) {
          _shards.remove(s);
          final n = Geo.perp(d);
          _shards.add(_Shard(res.$1, s.vel + n * 40, 0.6, s.color, true));
          _shards.add(_Shard(res.$2, s.vel - n * 40, -0.6, s.color, true));
          _slashes.add((c - d * 90, c + d * 90, 0.3));
        }
      }
    }
    for (final s in _shards) {
      s.age += dt;
      final c = Geo.centroid(s.poly);
      s.poly = Geo.rotateAround([for (final p in s.poly) p + s.vel * dt], c + s.vel * dt, s.spin * dt);
      if (s.cut) s.vel = Offset(s.vel.dx * math.exp(-1.5 * dt), s.vel.dy);
    }
    _shards.removeWhere((s) => Geo.bounds(s.poly).bottom < -80);
    for (var i = _slashes.length - 1; i >= 0; i--) {
      final (a, b, l) = _slashes[i];
      if (l - dt <= 0) {
        _slashes.removeAt(i);
      } else {
        _slashes[i] = (a, b, l - dt);
      }
    }
    _repaint.value++;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _repaint.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      _size = c.biggest;
      return RepaintBoundary(
        child: CustomPaint(
          size: c.biggest,
          painter: _BackdropPainter(this, widget.top, widget.bottom),
        ),
      );
    });
  }
}

class _BackdropPainter extends CustomPainter {
  _BackdropPainter(this.s, this.top, this.bottom) : super(repaint: s._repaint);
  final _AnimatedBackdropState s;
  final Color top;
  final Color bottom;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [top, bottom])
            .createShader(rect),
    );
    final grid = Paint()
      ..color = Colors.white.withOpacity(0.025)
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 44) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = 0.0; y < size.height; y += 44) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final fill = Paint();
    for (final sh in s._shards) {
      final path = Path()..addPolygon(sh.poly, true);
      fill.color = sh.color.withOpacity(0.22);
      canvas.drawPath(path, fill);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = sh.color.withOpacity(0.4),
      );
    }
    for (final (a, b, l) in s._slashes) {
      final k = l / 0.3;
      canvas.drawLine(
          a,
          b,
          Paint()
            ..color = AppColors.accent.withOpacity(0.35 * k)
            ..strokeWidth = 8 * k
            ..strokeCap = StrokeCap.round);
      canvas.drawLine(
          a,
          b,
          Paint()
            ..color = Colors.white.withOpacity(0.7 * k)
            ..strokeWidth = 2
            ..strokeCap = StrokeCap.round);
    }
  }

  @override
  bool shouldRepaint(covariant _BackdropPainter old) => false;
}
