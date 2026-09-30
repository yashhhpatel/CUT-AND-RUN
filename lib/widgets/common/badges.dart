import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

class CoinIcon extends StatelessWidget {
  const CoinIcon({super.key, this.size = 20});
  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: _CoinPainter());
}

class _CoinPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    canvas.drawCircle(c + Offset(0, r * 0.12), r, Paint()..color = AppColors.rewardDark);
    canvas.drawCircle(c, r, Paint()..color = AppColors.reward);
    canvas.drawCircle(
      c,
      r * 0.58,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.16
        ..color = const Color(0xFFFFF0B8),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ShardIcon extends StatelessWidget {
  const ShardIcon({super.key, this.size = 20, this.color = AppColors.primary});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: _ShardPainter(color));
}

class _ShardPainter extends CustomPainter {
  _ShardPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size s) {
    final a = Path()
      ..moveTo(s.width * 0.1, s.height * 0.15)
      ..lineTo(s.width * 0.8, s.height * 0.15)
      ..lineTo(s.width * 0.1, s.height * 0.85)
      ..close();
    final b = Path()
      ..moveTo(s.width * 0.92, s.height * 0.28)
      ..lineTo(s.width * 0.92, s.height * 0.92)
      ..lineTo(s.width * 0.28, s.height * 0.92)
      ..close();
    canvas.drawPath(a, Paint()..color = color);
    canvas.drawPath(b, Paint()..color = Color.lerp(color, Colors.black, 0.2)!);
  }

  @override
  bool shouldRepaint(covariant _ShardPainter old) => old.color != color;
}

/// Five-point star used for level ratings.
class StarIcon extends StatelessWidget {
  const StarIcon({super.key, required this.filled, this.size = 22});
  final bool filled;
  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: _StarPainter(filled));
}

class _StarPainter extends CustomPainter {
  _StarPainter(this.filled);
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final a = -math.pi / 2 + i * math.pi / 5;
      final rr = i.isEven ? r : r * 0.48;
      final p = c + Offset(math.cos(a) * rr, math.sin(a) * rr);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    if (filled) {
      canvas.drawPath(path.shift(Offset(0, r * 0.1)), Paint()..color = AppColors.rewardDark);
      canvas.drawPath(path, Paint()..color = AppColors.reward);
    } else {
      canvas.drawPath(path, Paint()..color = Colors.black.withOpacity(0.35));
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.12
          ..strokeJoin = StrokeJoin.round
          ..color = AppColors.stroke,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StarPainter old) => old.filled != filled;
}

class StarRow extends StatelessWidget {
  const StarRow({super.key, required this.stars, this.size = 18, this.spacing = 2});
  final int stars;
  final double size;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: spacing),
            child: StarIcon(filled: i < stars, size: size),
          ),
      ],
    );
  }
}

/// Pill showing the player's coins; animates when the value changes.
class CoinBadge extends StatelessWidget {
  const CoinBadge({super.key, required this.coins});
  final int coins;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.only(left: 6, right: 14),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.stroke, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CoinIcon(size: 26),
          const SizedBox(width: 8),
          TweenAnimationBuilder<double>(
            tween: Tween(end: coins.toDouble()),
            duration: const Duration(milliseconds: 500),
            builder: (_, v, __) => Text(_fmt(v.round()), style: AppText.hud),
          ),
        ],
      ),
    );
  }

  static String _fmt(int v) {
    final s = v.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return b.toString();
  }
}

String formatNumber(int v) => CoinBadge._fmt(v);

/// Rounded surface panel used throughout menus.
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.color, this.borderColor});
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor ?? AppColors.stroke.withOpacity(0.8), width: 1.5),
        boxShadow: const [BoxShadow(color: Color(0x44000000), blurRadius: 18, offset: Offset(0, 8))],
      ),
      child: child,
    );
  }
}
