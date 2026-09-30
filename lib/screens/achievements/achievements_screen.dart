import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../progression/achievements.dart';
import '../../services/audio/audio_service.dart';
import '../../widgets/common/badges.dart';
import '../../widgets/common/game_button.dart';
import '../../widgets/common/screen_scaffold.dart';

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.progress;
    return ScreenScaffold(
      title: 'Achievements',
      body: ListenableBuilder(
        listenable: p,
        builder: (context, _) {
          final ctx = p.achievementContext;
          final sorted = [...achievements]..sort((a, b) {
              int rank(Achievement x) => x.isComplete(ctx) ? (p.isClaimed(x) ? 2 : 0) : 1;
              return rank(a).compareTo(rank(b));
            });
          final done = achievements.where((a) => a.isComplete(ctx)).length;
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            itemCount: sorted.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              if (i == 0) {
                return Text('$done of ${achievements.length} unlocked', style: AppText.muted);
              }
              final a = sorted[i - 1];
              final complete = a.isComplete(ctx);
              final claimed = p.isClaimed(a);
              final prog = a.progress(ctx);
              return Panel(
                padding: const EdgeInsets.all(14),
                borderColor: complete && !claimed ? AppColors.reward : null,
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: (complete ? AppColors.reward : AppColors.surfaceHigh).withOpacity(complete ? 0.2 : 1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        complete ? Icons.emoji_events_rounded : Icons.lock_outline_rounded,
                        color: complete ? AppColors.reward : AppColors.textFaint,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a.title, style: AppText.body.copyWith(fontWeight: FontWeight.w800)),
                          Text(a.description, style: AppText.muted.copyWith(fontSize: 13)),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: prog / a.target,
                              minHeight: 6,
                              backgroundColor: AppColors.surfaceHigh,
                              valueColor: AlwaysStoppedAnimation(complete ? AppColors.success : AppColors.accent),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text('${formatNumber(prog)} / ${formatNumber(a.target)}',
                              style: AppText.label.copyWith(fontSize: 10)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (complete && !claimed)
                      GameButton(
                        label: '+${a.reward}',
                        style: GameButtonStyle.reward,
                        height: 40,
                        expand: false,
                        fontSize: 14,
                        onTap: () {
                          if (p.claim(a)) s.audio.play(Sfx.reward);
                        },
                      )
                    else if (claimed)
                      const Icon(Icons.check_circle_rounded, color: AppColors.success)
                    else
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        const CoinIcon(size: 16),
                        const SizedBox(width: 4),
                        Text('${a.reward}', style: AppText.label),
                      ]),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
