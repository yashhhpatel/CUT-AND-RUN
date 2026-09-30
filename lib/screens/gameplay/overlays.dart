import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../game/engine/game_world.dart';
import '../../levels/models/level_config.dart';
import '../../progression/progress_store.dart';
import '../../services/audio/audio_service.dart';
import '../../services/haptics/haptics_service.dart';
import '../../widgets/common/badges.dart';
import '../../widgets/common/game_button.dart';

class _Dim extends StatelessWidget {
  const _Dim({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      builder: (_, v, c) => ColoredBox(
        color: Colors.black.withOpacity(0.62 * v),
        child: Opacity(
          opacity: v,
          child: Transform.scale(scale: 0.94 + 0.06 * v, child: c),
        ),
      ),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: child),
          ),
        ),
      ),
    );
  }
}

class PauseOverlay extends StatelessWidget {
  const PauseOverlay({super.key, required this.onResume, required this.onRestart, required this.onHome});
  final VoidCallback onResume;
  final VoidCallback onRestart;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final settings = AppScope.of(context).settings;
    return _Dim(
      child: Panel(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('PAUSED', style: AppText.title, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            GameButton(label: 'RESUME', icon: Icons.play_arrow_rounded, onTap: onResume),
            const SizedBox(height: 12),
            GameButton(
                label: 'RESTART', icon: Icons.replay_rounded, style: GameButtonStyle.secondary, onTap: onRestart),
            const SizedBox(height: 12),
            GameButton(label: 'HOME', icon: Icons.home_rounded, style: GameButtonStyle.secondary, onTap: onHome),
            const SizedBox(height: 18),
            ListenableBuilder(
              listenable: settings,
              builder: (_, __) => Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                      child: _Toggle(
                          icon: Icons.music_note_rounded,
                          label: 'Music',
                          on: settings.music,
                          onTap: () => settings.music = !settings.music)),
                  Expanded(
                      child: _Toggle(
                          icon: Icons.volume_up_rounded,
                          label: 'Sound',
                          on: settings.sfx,
                          onTap: () => settings.sfx = !settings.sfx)),
                  Expanded(
                      child: _Toggle(
                          icon: Icons.vibration_rounded,
                          label: 'Vibration',
                          on: settings.vibration,
                          onTap: () => settings.vibration = !settings.vibration)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({required this.icon, required this.label, required this.on, required this.onTap});
  final IconData icon;
  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: on,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: on ? AppColors.success.withOpacity(0.18) : AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: on ? AppColors.success : AppColors.stroke, width: 2),
              ),
              child: Icon(on ? icon : Icons.block_rounded, color: on ? AppColors.success : AppColors.textFaint),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('$label ${on ? 'ON' : 'OFF'}', style: AppText.label.copyWith(fontSize: 11), maxLines: 1),
            ),
          ],
        ),
      ),
    );
  }
}

class ResultOverlay extends StatefulWidget {
  const ResultOverlay({
    super.key,
    required this.result,
    required this.onNext,
    required this.onRetry,
    required this.onHome,
  });

  final RunResult result;
  final VoidCallback? onNext;
  final VoidCallback onRetry;
  final VoidCallback onHome;

  @override
  State<ResultOverlay> createState() => _ResultOverlayState();
}

class _ResultOverlayState extends State<ResultOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1900))
    ..forward();
  int _starsShown = 0;
  bool _adBusy = false;

  @override
  void initState() {
    super.initState();
    _c.addListener(() {
      final n = ((_c.value - 0.2) / 0.16).floor().clamp(0, widget.result.stars);
      if (n > _starsShown) {
        setState(() => _starsShown = n);
        final s = AppScope.of(context);
        s.audio.play(Sfx.reward);
        s.haptics.fire(Haptic.medium);
      }
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _double() async {
    final s = AppScope.of(context);
    setState(() => _adBusy = true);
    final earned = await s.ads.showRewarded();
    if (!mounted) return;
    if (earned) {
      s.progress.doubleReward(widget.result);
      s.audio.play(Sfx.reward);
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('No reward available right now. Try again later.')));
    }
    setState(() => _adBusy = false);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    final s = r.stats;
    final services = AppScope.of(context);
    final cfg = r.config;
    final title =
        cfg.isTutorial ? 'TUTORIAL COMPLETE' : (cfg.mode == GameMode.daily ? 'DAILY COMPLETE' : 'LEVEL COMPLETE');
    return _Dim(
      child: Panel(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final countUp = Curves.easeOutCubic.transform((_c.value / 0.8).clamp(0.0, 1.0));
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: AppText.title.copyWith(color: AppColors.success), textAlign: TextAlign.center),
                if (cfg.mode == GameMode.campaign && !cfg.isTutorial)
                  Text('Level ${cfg.levelId}', style: AppText.muted, textAlign: TextAlign.center),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < 3; i++)
                      Padding(
                        padding: EdgeInsets.fromLTRB(6, i == 1 ? 0 : 14, 6, 0),
                        child: AnimatedScale(
                          scale: i < _starsShown ? 1 : 0.8,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.elasticOut,
                          child: StarIcon(filled: i < _starsShown, size: i == 1 ? 64 : 52),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(formatNumber((s.score * countUp).round()),
                    style: AppText.display.copyWith(fontSize: 40), textAlign: TextAlign.center),
                Text(r.newBest ? 'NEW BEST SCORE!' : 'SCORE',
                    style: AppText.label.copyWith(color: r.newBest ? AppColors.reward : null),
                    textAlign: TextAlign.center),
                const SizedBox(height: 14),
                _StatGrid(items: [
                  ('Cuts', '${s.cuts}'),
                  ('Perfect', '${s.perfectCuts}'),
                  ('Best combo', 'x${r.bestMultiplier}'),
                  ('Pieces', '${s.piecesCollected}'),
                  ('Shards', '${s.finalShards}'),
                  ('Fusions', '${s.combines}'),
                ]),
                const SizedBox(height: 12),
                _Objectives(result: r),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                  decoration: BoxDecoration(
                    color: AppColors.reward.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.reward.withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      const CoinIcon(size: 26),
                      const SizedBox(width: 10),
                      Text('+${formatNumber((r.coinsEarned * countUp).round())}',
                          style: AppText.section.copyWith(color: AppColors.reward)),
                      const SizedBox(width: 6),
                      Text(r.doubled ? 'DOUBLED' : 'coins', style: AppText.label),
                      const Spacer(),
                      if (!r.doubled && r.coinsEarned > 0 && services.ads.enabled)
                        GameButton(
                          label: 'x2',
                          icon: Icons.smart_display_rounded,
                          style: GameButtonStyle.reward,
                          height: 38,
                          expand: false,
                          fontSize: 15,
                          onTap: _adBusy ? null : _double,
                        ),
                    ],
                  ),
                ),
                if (r.newAchievements.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  for (final a in r.newAchievements)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        children: [
                          const Icon(Icons.emoji_events_rounded, color: AppColors.reward, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                              child:
                                  Text('Achievement unlocked: ${a.title}', style: AppText.body.copyWith(fontSize: 13))),
                        ],
                      ),
                    ),
                ],
                const SizedBox(height: 18),
                if (widget.onNext != null) ...[
                  GameButton(
                      label: cfg.mode == GameMode.campaign ? 'NEXT LEVEL' : 'CONTINUE',
                      icon: Icons.arrow_forward_rounded,
                      onTap: widget.onNext),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    Expanded(
                        child: GameButton(
                            label: 'RETRY',
                            icon: Icons.replay_rounded,
                            style: GameButtonStyle.secondary,
                            onTap: widget.onRetry)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: GameButton(
                            label: 'HOME',
                            icon: Icons.home_rounded,
                            style: GameButtonStyle.secondary,
                            onTap: widget.onHome)),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.items});
  final List<(String, String)> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        for (final (label, value) in items)
          Container(
            width: 104,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                Text(value, style: AppText.hud.copyWith(fontSize: 18)),
                Text(label.toUpperCase(), style: AppText.label.copyWith(fontSize: 10)),
              ],
            ),
          ),
      ],
    );
  }
}

class _Objectives extends StatelessWidget {
  const _Objectives({required this.result});
  final RunResult result;

  @override
  Widget build(BuildContext context) {
    final objectives = result.config.objectives;
    return Column(
      children: [
        for (var i = 0; i < objectives.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Icon(
                  result.objectivesMet[i] ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  color: result.objectivesMet[i] ? AppColors.success : AppColors.textFaint,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    objectives[i].description,
                    style: AppText.body.copyWith(
                      fontSize: 13.5,
                      color: result.objectivesMet[i] ? AppColors.text : AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class FailureOverlay extends StatefulWidget {
  const FailureOverlay({
    super.key,
    required this.world,
    required this.canContinue,
    required this.onContinue,
    required this.onRetry,
    required this.onHome,
    this.previousBestDistance = 0,
  });

  final GameWorld world;
  final bool canContinue;
  final Future<void> Function() onContinue;
  final VoidCallback onRetry;
  final VoidCallback onHome;
  final double previousBestDistance;

  @override
  State<FailureOverlay> createState() => _FailureOverlayState();
}

class _FailureOverlayState extends State<FailureOverlay> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final w = widget.world;
    final endless = w.config.isEndless;
    final meters = (w.player.y / 10).floor();
    final best = endless && w.player.y > widget.previousBestDistance && widget.previousBestDistance > 0;
    return _Dim(
      child: Panel(
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(endless ? 'RUN OVER' : 'LEVEL FAILED',
                style: AppText.title.copyWith(color: endless ? AppColors.primary : AppColors.danger),
                textAlign: TextAlign.center),
            if (w.failReason != null) ...[
              const SizedBox(height: 4),
              Text(w.failReason!, style: AppText.muted, textAlign: TextAlign.center),
            ],
            const SizedBox(height: 18),
            if (endless) ...[
              Text('$meters m', style: AppText.display, textAlign: TextAlign.center),
              Text(best ? 'NEW BEST DISTANCE!' : 'Best ${(widget.previousBestDistance / 10).floor()} m',
                  style: AppText.label.copyWith(color: best ? AppColors.reward : null), textAlign: TextAlign.center),
            ] else ...[
              Text('${(w.progress * 100).floor()}%', style: AppText.display, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: w.progress,
                  minHeight: 10,
                  backgroundColor: AppColors.surfaceHigh,
                  valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                ),
              ),
              const SizedBox(height: 4),
              const Text('PROGRESS', style: AppText.label, textAlign: TextAlign.center),
            ],
            const SizedBox(height: 14),
            _StatGrid(items: [
              ('Score', formatNumber(w.stats.score)),
              ('Cuts', '${w.stats.cuts}'),
              ('Shards', '${w.carry.shards}'),
            ]),
            const SizedBox(height: 18),
            if (widget.canContinue) ...[
              GameButton(
                label: 'WATCH AD & CONTINUE',
                icon: Icons.smart_display_rounded,
                style: GameButtonStyle.reward,
                onTap: _busy
                    ? null
                    : () async {
                        setState(() => _busy = true);
                        await widget.onContinue();
                        if (mounted) setState(() => _busy = false);
                      },
              ),
              const SizedBox(height: 12),
            ],
            GameButton(label: 'RETRY', icon: Icons.replay_rounded, onTap: widget.onRetry),
            const SizedBox(height: 12),
            GameButton(label: 'HOME', icon: Icons.home_rounded, style: GameButtonStyle.secondary, onTap: widget.onHome),
          ],
        ),
      ),
    );
  }
}
