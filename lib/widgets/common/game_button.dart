import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../services/audio/audio_service.dart';
import '../../services/haptics/haptics_service.dart';

enum GameButtonStyle { primary, secondary, reward, accent, ghost }

/// Chunky, tactile button with a pressed "lip" — the core interactive element
/// of every menu.
class GameButton extends StatefulWidget {
  const GameButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.style = GameButtonStyle.primary,
    this.height = 58,
    this.expand = true,
    this.subtitle,
    this.fontSize,
  });

  final String label;
  final String? subtitle;
  final IconData? icon;
  final VoidCallback? onTap;
  final GameButtonStyle style;
  final double height;
  final bool expand;
  final double? fontSize;

  @override
  State<GameButton> createState() => _GameButtonState();
}

class _GameButtonState extends State<GameButton> {
  bool _down = false;

  (Color, Color, Color) get _colors {
    switch (widget.style) {
      case GameButtonStyle.primary:
        return (AppColors.primary, AppColors.primaryDark, Colors.white);
      case GameButtonStyle.secondary:
        return (AppColors.surfaceHigh, const Color(0xFF161A36), AppColors.text);
      case GameButtonStyle.reward:
        return (AppColors.reward, AppColors.rewardDark, const Color(0xFF3A2A00));
      case GameButtonStyle.accent:
        return (AppColors.accent, AppColors.accentDark, const Color(0xFF042B36));
      case GameButtonStyle.ghost:
        return (Colors.transparent, Colors.transparent, AppColors.textMuted);
    }
  }

  void _tap() {
    if (widget.onTap == null) return;
    try {
      final s = AppScope.of(context);
      s.audio.play(Sfx.tap);
      s.haptics.fire(Haptic.selection);
    } catch (_) {}
    widget.onTap!();
  }

  @override
  Widget build(BuildContext context) {
    final (face, lip, fg) = _colors;
    final enabled = widget.onTap != null;
    const lipH = 5.0;
    final ghost = widget.style == GameButtonStyle.ghost;
    final content = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon, color: fg, size: (widget.fontSize ?? 17) + 5),
          const SizedBox(width: 10),
        ],
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.button.copyWith(color: fg, fontSize: widget.fontSize),
              ),
              if (widget.subtitle != null)
                Text(
                  widget.subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.label.copyWith(color: fg.withOpacity(0.8), fontSize: 11, letterSpacing: 0.4),
                ),
            ],
          ),
        ),
      ],
    );
    return Semantics(
      button: true,
      label: widget.label,
      enabled: enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapCancel: () => setState(() => _down = false),
        onTapUp: enabled
            ? (_) {
                setState(() => _down = false);
                _tap();
              }
            : null,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: enabled ? 1 : 0.45,
          child: SizedBox(
            height: widget.height + lipH,
            child: Stack(
              children: [
                if (!ghost)
                  Positioned.fill(
                    top: lipH,
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: lip, borderRadius: BorderRadius.circular(18)),
                    ),
                  ),
                // Non-positioned so the button also sizes itself when it
                // doesn't expand (e.g. inside a Row).
                AnimatedPadding(
                  duration: const Duration(milliseconds: 70),
                  padding: EdgeInsets.only(top: _down ? lipH : 0, bottom: _down ? 0 : lipH),
                  child: Container(
                    height: widget.height,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    decoration: BoxDecoration(
                      color: face,
                      borderRadius: BorderRadius.circular(18),
                      border: ghost ? Border.all(color: AppColors.stroke, width: 1.5) : null,
                      gradient: ghost
                          ? null
                          : LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color.lerp(face, Colors.white, 0.12)!, face],
                            ),
                    ),
                    child: Center(widthFactor: 1, child: content),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Round icon button for top bars (pause, back, settings).
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({super.key, required this.icon, required this.onTap, this.size = 46, this.tooltip, this.badge});

  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final String? tooltip;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          try {
            final s = AppScope.of(context);
            s.audio.play(Sfx.tap);
            s.haptics.fire(Haptic.selection);
          } catch (_) {}
          onTap();
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: AppColors.surface.withOpacity(0.92),
                borderRadius: BorderRadius.circular(size * 0.34),
                border: Border.all(color: AppColors.stroke, width: 1.5),
              ),
              child: Icon(icon, color: AppColors.text, size: size * 0.5),
            ),
            if (badge != null && badge! > 0)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(10)),
                  child: Text('$badge', style: AppText.label.copyWith(color: Colors.white, fontSize: 11)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
