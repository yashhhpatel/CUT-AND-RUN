import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../levels/worlds.dart';
import '../../services/audio/audio_service.dart';
import '../../widgets/common/animated_backdrop.dart';
import '../../widgets/common/badges.dart';
import '../../widgets/common/game_button.dart';
import '../../widgets/common/logo.dart';
import '../../widgets/common/screen_scaffold.dart';
import '../achievements/achievements_screen.dart';
import '../daily/daily_screen.dart';
import '../endless/endless_screen.dart';
import '../gameplay/game_screen.dart';
import '../level_map/level_map_screen.dart';
import '../settings/settings_screen.dart';
import '../skins/skins_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
    ..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppScope.of(context).audio.playMusic(Music.menu);
    });
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _open(Widget page) => Navigator.of(context).push(FadeRoute(page));

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final progress = s.progress;
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: AnimatedBackdrop(top: Color(0xFF1B2250))),
          SafeArea(
            child: ListenableBuilder(
              listenable: progress,
              builder: (context, _) {
                final level = progress.unlockedLevel;
                final world = worldForLevel(level);
                final today = DateTime.now();
                return LayoutBuilder(builder: (context, c) {
                  final compact = c.maxHeight < 640;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            CoinBadge(coins: progress.coins),
                            const Spacer(),
                            RoundIconButton(
                              icon: Icons.settings_rounded,
                              tooltip: 'Settings',
                              onTap: () => _open(const SettingsScreen()),
                            ),
                          ],
                        ),
                        const Spacer(flex: 2),
                        LogoTitle(size: compact ? 58 : 72),
                        const SizedBox(height: 12),
                        Text('SLICE  ·  SPLIT  ·  ESCAPE', style: AppText.label.copyWith(letterSpacing: 3)),
                        const Spacer(flex: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(color: world.accent, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 8),
                              Text('LEVEL $level', style: AppText.label.copyWith(color: AppColors.text)),
                              Flexible(
                                child: Text('  ·  ${world.name.toUpperCase()}',
                                    style: AppText.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        ScaleTransition(
                          scale: Tween(begin: 1.0, end: 1.04)
                              .animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut)),
                          child: GameButton(
                            label: 'PLAY',
                            icon: Icons.play_arrow_rounded,
                            height: 72,
                            fontSize: 26,
                            onTap: () => _open(GameScreen.campaign(level)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _ModeTile(
                                icon: Icons.map_rounded,
                                title: 'Levels',
                                subtitle: '${progress.totalStars} ★',
                                color: AppColors.accent,
                                onTap: () => _open(const LevelMapScreen()),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _ModeTile(
                                icon: Icons.today_rounded,
                                title: 'Daily',
                                subtitle: progress.dailyDoneFor(today) ? 'Done ✓' : 'New!',
                                color: AppColors.reward,
                                highlight: !progress.dailyDoneFor(today),
                                onTap: () => _open(const DailyScreen()),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _ModeTile(
                                icon: Icons.all_inclusive_rounded,
                                title: 'Endless',
                                subtitle: '${(progress.endless.distance / 10).floor()} m',
                                color: AppColors.primary,
                                onTap: () => _open(const EndlessScreen()),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: GameButton(
                                label: 'SKINS',
                                icon: Icons.checkroom_rounded,
                                style: GameButtonStyle.secondary,
                                height: 52,
                                onTap: () => _open(const SkinsScreen()),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  GameButton(
                                    label: 'AWARDS',
                                    icon: Icons.emoji_events_rounded,
                                    style: GameButtonStyle.secondary,
                                    height: 52,
                                    onTap: () => _open(const AchievementsScreen()),
                                  ),
                                  if (progress.unclaimedAchievements > 0)
                                    Positioned(
                                      right: -2,
                                      top: -6,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                            color: AppColors.danger, borderRadius: BorderRadius.circular(10)),
                                        child: Text('${progress.unclaimedAchievements}',
                                            style: AppText.label.copyWith(color: Colors.white, fontSize: 11)),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: compact ? 12 : 24),
                      ],
                    ),
                  );
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.highlight = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title, $subtitle',
      child: GestureDetector(
        onTap: () {
          AppScope.of(context).audio.play(Sfx.tap);
          onTap();
        },
        child: Container(
          height: 100,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surface.withOpacity(0.94),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: highlight ? color : AppColors.stroke, width: highlight ? 2 : 1.5),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: color.withOpacity(0.18), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color, size: 21),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child:
                    Text(title, style: AppText.body.copyWith(fontWeight: FontWeight.w800, fontSize: 14, height: 1.2)),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(subtitle, style: AppText.label.copyWith(fontSize: 11), maxLines: 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
