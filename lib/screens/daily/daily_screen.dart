import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../levels/generators/mode_generators.dart';
import '../../widgets/common/badges.dart';
import '../../widgets/common/game_button.dart';
import '../../widgets/common/screen_scaffold.dart';
import '../gameplay/game_screen.dart';

class DailyScreen extends StatelessWidget {
  const DailyScreen({super.key});

  static const _months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];

  @override
  Widget build(BuildContext context) {
    final progress = AppScope.of(context).progress;
    final today = DateTime.now();
    final cfg = DailyGenerator.forDate(today);
    return ScreenScaffold(
      title: 'Daily Challenge',
      body: ListenableBuilder(
        listenable: progress,
        builder: (context, _) {
          final done = progress.dailyDoneFor(today);
          final streak = progress.dailyStreak;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 64,
                          height: 70,
                          decoration: BoxDecoration(color: AppColors.reward, borderRadius: BorderRadius.circular(16)),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(_months[today.month - 1],
                                  style: AppText.label.copyWith(color: const Color(0xFF3A2A00))),
                              Text('${today.day}',
                                  style: AppText.title.copyWith(color: const Color(0xFF3A2A00), fontSize: 28)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("TODAY'S RUN", style: AppText.label),
                              Text(done ? 'Completed!' : 'A fresh challenge',
                                  style: AppText.section.copyWith(fontSize: 20)),
                              Text('Difficulty ${(cfg.difficulty * 10).ceil()}/10', style: AppText.muted),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Text('OBJECTIVES', style: AppText.label),
                    const SizedBox(height: 6),
                    for (final o in cfg.objectives)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.flag_rounded, color: AppColors.accent, size: 18),
                            const SizedBox(width: 10),
                            Expanded(child: Text(o.description, style: AppText.body)),
                          ],
                        ),
                      ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const CoinIcon(size: 22),
                        const SizedBox(width: 8),
                        Text('+${DailyGenerator.bonusCoins} bonus coins',
                            style: AppText.body.copyWith(color: AppColors.reward, fontWeight: FontWeight.w800)),
                        if (done) ...[
                          const Spacer(),
                          Text('CLAIMED', style: AppText.label.copyWith(color: AppColors.success)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.local_fire_department_rounded, color: AppColors.primary),
                        const SizedBox(width: 8),
                        const Text('STREAK', style: AppText.label),
                        const Spacer(),
                        Text('$streak day${streak == 1 ? '' : 's'}', style: AppText.section),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (var i = 1; i <= 7; i++)
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: i <= streak.clamp(0, 7) ? AppColors.primary : AppColors.surfaceHigh,
                              shape: BoxShape.circle,
                            ),
                            child: Center(child: Text('$i', style: AppText.label.copyWith(color: AppColors.text))),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text('Keep your streak for up to +70 extra coins a day.',
                        style: AppText.muted.copyWith(fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              GameButton(
                label: done ? 'PLAY AGAIN' : 'START CHALLENGE',
                icon: Icons.play_arrow_rounded,
                style: done ? GameButtonStyle.secondary : GameButtonStyle.primary,
                onTap: () => Navigator.of(context).push(FadeRoute(GameScreen(config: cfg))),
              ),
              if (done) ...[
                const SizedBox(height: 10),
                const Text('Come back tomorrow for a new challenge.',
                    style: AppText.muted, textAlign: TextAlign.center),
              ],
            ],
          );
        },
      ),
    );
  }
}
