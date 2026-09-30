import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// "CUT & RUN" wordmark: the word CUT is literally sliced in two.
class LogoTitle extends StatefulWidget {
  const LogoTitle({super.key, this.size = 64, this.animate = true});
  final double size;
  final bool animate;

  @override
  State<LogoTitle> createState() => _LogoTitleState();
}

class _LogoTitleState extends State<LogoTitle> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted) _c.forward();
      });
    } else {
      _c.value = 1;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    final word = TextStyle(
      fontSize: s,
      fontWeight: FontWeight.w900,
      height: 1,
      letterSpacing: -s * 0.03,
      color: AppColors.text,
      shadows: const [Shadow(color: Color(0x66000000), blurRadius: 12, offset: Offset(0, 6))],
    );
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final slash = Curves.easeOutCubic.transform((_c.value / 0.45).clamp(0.0, 1.0));
        final sep = Curves.elasticOut.transform(((_c.value - 0.4) / 0.6).clamp(0.0, 1.0)) * s * 0.05;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Transform.translate(
                  offset: Offset(-sep, -sep * 0.6),
                  child: ClipPath(clipper: _HalfClipper(upper: true), child: Text('CUT', style: word)),
                ),
                Transform.translate(
                  offset: Offset(sep, sep * 0.6),
                  child: ClipPath(
                    clipper: _HalfClipper(upper: false),
                    child: Text('CUT', style: word.copyWith(color: AppColors.primary)),
                  ),
                ),
                Positioned.fill(child: CustomPaint(painter: _SlashPainter(slash))),
              ],
            ),
            SizedBox(height: s * 0.04),
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text('&', style: word.copyWith(fontSize: s * 0.62, color: AppColors.primary)),
                SizedBox(width: s * 0.12),
                Text('RUN', style: word),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _HalfClipper extends CustomClipper<Path> {
  _HalfClipper({required this.upper});
  final bool upper;

  @override
  Path getClip(Size size) {
    final a = Offset(0, size.height * 0.92);
    final b = Offset(size.width, size.height * 0.2);
    final p = Path();
    if (upper) {
      p
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(b.dx, b.dy)
        ..lineTo(a.dx, a.dy);
    } else {
      p
        ..moveTo(a.dx, a.dy)
        ..lineTo(b.dx, b.dy)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height);
    }
    return p..close();
  }

  @override
  bool shouldReclip(covariant _HalfClipper old) => old.upper != upper;
}

class _SlashPainter extends CustomPainter {
  _SlashPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0) return;
    final a = Offset(-size.width * 0.08, size.height * 0.98);
    final b = Offset(size.width * 1.08, size.height * 0.14);
    final end = Offset.lerp(a, b, t)!;
    final fade = t >= 1 ? 0.0 : 1.0;
    if (fade == 0) return;
    canvas.drawLine(
      a,
      end,
      Paint()
        ..color = AppColors.accent.withOpacity(0.5)
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      a,
      end,
      Paint()
        ..color = Colors.white
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _SlashPainter old) => old.t != t;
}
