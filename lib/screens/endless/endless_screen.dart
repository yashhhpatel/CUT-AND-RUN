import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/common/badges.dart';
import '../../widgets/common/game_button.dart';
import '../../widgets/common/screen_scaffold.dart';
import '../gameplay/game_screen.dart';

class EndlessScreen extends StatelessWidget {
  const EndlessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final progress = AppScope.of(context).progress;
    return ScreenScaffold(
      title: 'Endless',
      body: ListenableBuilder(
        listenable: progress,
        builder: (context, _) {
          final e = progress.endless;
          final secs = e.survival.floor();
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              Panel(
                child: Column(
                  children: [
                    const Icon(Icons.all_inclusive_rounded, color: AppColors.primary, size: 44),
                    const SizedBox(height: 8),
                    Text('${(e.distance / 10).floor()} m', style: AppText.display),
                    const Text('PERSONAL BEST DISTANCE', style: AppText.label),
                    const SizedBox(height: 14),
                    const Text(
                      'One life. The track never ends and keeps getting tougher. How far can you cut your way?',
                      style: AppText.muted,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.9,
                children: [
                  _Best(
                      label: 'Best score',
                      value: formatNumber(e.score),
                      icon: Icons.star_rounded,
                      color: AppColors.reward),
                  _Best(label: 'Best combo', value: '${e.combo}', icon: Icons.bolt_rounded, color: AppColors.accent),
                  _Best(
                      label: 'Most cuts',
                      value: '${e.cuts}',
                      icon: Icons.content_cut_rounded,
                      color: AppColors.primary),
                  _Best(
                      label: 'Survival',
                      value: '${secs ~/ 60}:${(secs % 60).toString().padLeft(2, '0')}',
                      icon: Icons.timer_rounded,
                      color: AppColors.success),
                ],
              ),
              const SizedBox(height: 22),
              GameButton(
                label: 'START RUN',
                icon: Icons.play_arrow_rounded,
                onTap: () => Navigator.of(context).push(FadeRoute(GameScreen.endless())),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Best extends StatelessWidget {
  const _Best({required this.label, required this.value, required this.icon, required this.color});
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: AppText.hud.copyWith(fontSize: 20))),
                Text(label.toUpperCase(),
                    style: AppText.label.copyWith(fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
