import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../game/engine/game_world.dart';
import '../../game/model/powerups.dart';
import '../../levels/models/level_config.dart';
import '../../levels/models/mechanics.dart';
import '../../levels/models/spawn.dart';
import '../../widgets/common/badges.dart';
import '../../widgets/common/game_button.dart';

/// Compact top HUD: pause, level + progress, score, shards, coins, combo and
/// active power-ups. Reads the world directly; rebuilt ~20 times a second.
class GameHud extends StatelessWidget {
  const GameHud({super.key, required this.world, required this.tick, required this.onPause});

  final GameWorld world;
  final Listenable tick;
  final VoidCallback onPause;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: tick,
      builder: (context, _) {
        final cfg = world.config;
        final endless = cfg.isEndless;
        final title = endless
            ? '${(world.player.y / 10).floor()} m'
            : (cfg.mode == GameMode.daily ? 'DAILY' : 'LEVEL ${cfg.levelId}');
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  RoundIconButton(icon: Icons.pause_rounded, onTap: onPause, size: 42, tooltip: 'Pause'),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: AppText.label.copyWith(color: AppColors.text, fontSize: 13)),
                        const SizedBox(height: 5),
                        if (!endless)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: SizedBox(
                              height: 7,
                              child: LinearProgressIndicator(
                                value: world.progress,
                                backgroundColor: Colors.black.withOpacity(0.35),
                                valueColor: const AlwaysStoppedAnimation(AppColors.success),
                              ),
                            ),
                          )
                        else
                          Text('SCORE ${formatNumber(world.stats.score)}', style: AppText.label.copyWith(fontSize: 11)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  _Chip(
                    icon: const ShardIcon(size: 18),
                    text: '${world.carry.shards}',
                    semantic: 'Shards',
                  ),
                  const SizedBox(width: 6),
                  _Chip(
                    icon: const CoinIcon(size: 18),
                    text: '${world.stats.coinsCollected}',
                    semantic: 'Coins',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (!endless) Text(formatNumber(world.stats.score), style: AppText.hud.copyWith(fontSize: 20)),
                  const Spacer(),
                  _ComboBadge(world: world),
                ],
              ),
              const SizedBox(height: 6),
              _PowerUps(world: world),
            ],
          ),
        );
      },
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.text, required this.semantic});
  final Widget icon;
  final String text;
  final String semantic;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$semantic $text',
      child: Container(
        height: 34,
        padding: const EdgeInsets.only(left: 7, right: 11),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.35),
          borderRadius: BorderRadius.circular(17),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [icon, const SizedBox(width: 6), Text(text, style: AppText.hud.copyWith(fontSize: 15))],
        ),
      ),
    );
  }
}

class _ComboBadge extends StatelessWidget {
  const _ComboBadge({required this.world});
  final GameWorld world;

  @override
  Widget build(BuildContext context) {
    final combo = world.combo;
    final show = combo.count > 0;
    final m = combo.multiplier;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: show ? 1 : 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 4, 10, 6),
        decoration: BoxDecoration(
          color: (m > 1 ? AppColors.reward : AppColors.surfaceHigh).withOpacity(0.92),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'COMBO x$m',
              style: AppText.label.copyWith(
                color: m > 1 ? const Color(0xFF3A2A00) : AppColors.text,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 3),
            SizedBox(
              width: 74,
              height: 4,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: (combo.timer / 3.2).clamp(0.0, 1.0),
                  backgroundColor: Colors.black.withOpacity(0.25),
                  valueColor: AlwaysStoppedAnimation(m > 1 ? const Color(0xFF3A2A00) : AppColors.accent),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PowerUps extends StatelessWidget {
  const _PowerUps({required this.world});
  final GameWorld world;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    for (final e in world.powerUps.entries) {
      final info = powerUpInfo[e.key]!;
      items.add(
          _PowerChip(label: info.name, color: info.color, fraction: info.duration == 0 ? 1 : e.value / info.duration));
    }
    if (world.megaCharges > 0) {
      final info = powerUpInfo[PowerUpType.megaCut]!;
      items.add(_PowerChip(label: 'Mega Cut ×${world.megaCharges}', color: info.color, fraction: 1));
    }
    if (world.player.shields > 0) {
      final info = powerUpInfo[PowerUpType.shield]!;
      items.add(_PowerChip(label: 'Shield${world.player.shields > 1 ? ' ×2' : ''}', color: info.color, fraction: 1));
    }
    if (items.isEmpty) return const SizedBox(height: 0);
    return Wrap(spacing: 6, runSpacing: 6, children: items);
  }
}

class _PowerChip extends StatelessWidget {
  const _PowerChip({required this.label, required this.color, required this.fraction});
  final String label;
  final Color color;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              value: fraction.clamp(0.0, 1.0),
              strokeWidth: 2.5,
              color: color,
              backgroundColor: Colors.white12,
            ),
          ),
          const SizedBox(width: 6),
          Text(label, style: AppText.label.copyWith(color: AppColors.text, fontSize: 11)),
        ],
      ),
    );
  }
}

/// Tutorial / onboarding hint card with a gesture demo.
class HintOverlay extends StatelessWidget {
  const HintOverlay({super.key, required this.world, required this.tick, required this.viewportPlayerY});

  final GameWorld world;
  final Listenable tick;
  final double viewportPlayerY;

  static (String, String, IconData) textFor(TutorialStep s) {
    switch (s) {
      case TutorialStep.move:
        return ('MOVE', 'Drag left and right at the bottom of the screen', Icons.swipe_rounded);
      case TutorialStep.collect:
        return ('COLLECT', 'Run through glowing pieces to collect shards', Icons.auto_awesome_rounded);
      case TutorialStep.cut:
        return ('CUT', 'Swipe across the block to slice it in two', Icons.content_cut_rounded);
      case TutorialStep.avoid:
        return ('AVOID', 'Spikes cannot be cut. Steer around them', Icons.warning_amber_rounded);
      case TutorialStep.pieces:
        return ('CHOOSE', 'Gates change your shards. Pick the best one', Icons.call_split_rounded);
      case TutorialStep.finish:
        return ('ESCAPE', 'Reach the finish line to cash in your shards', Icons.flag_rounded);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: tick,
      builder: (context, _) {
        final hint = world.hint;
        return IgnorePointer(
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                left: 20,
                right: 20,
                top: hint == null ? -140 : 150,
                child: hint == null ? const SizedBox() : _HintCard(step: hint),
              ),
              if (hint == TutorialStep.move) _HandDemo(y: viewportPlayerY + 70, horizontal: true, time: world.hintTime),
              if (hint == TutorialStep.cut && world.tutorialSlow)
                _HandDemo(y: viewportPlayerY * 0.42, horizontal: false, time: world.hintTime),
            ],
          ),
        );
      },
    );
  }
}

class _HintCard extends StatelessWidget {
  const _HintCard({required this.step});
  final TutorialStep step;

  @override
  Widget build(BuildContext context) {
    final (title, body, icon) = HintOverlay.textFor(step);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.95),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.accent.withOpacity(0.7), width: 1.5),
        boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 16, offset: Offset(0, 6))],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration:
                BoxDecoration(color: AppColors.accent.withOpacity(0.18), borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: AppColors.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: AppText.label.copyWith(color: AppColors.accent)),
                const SizedBox(height: 2),
                Text(body, style: AppText.body.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HandDemo extends StatelessWidget {
  const _HandDemo({required this.y, required this.horizontal, required this.time});
  final double y;
  final bool horizontal;
  final double time;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final k = (math.sin(time * 3) + 1) / 2;
    final x = horizontal ? w * (0.25 + 0.5 * k) : w * (0.62 - 0.25 * ((time * 0.9) % 1.0));
    final yy = horizontal ? y : y - 70 + 140 * ((time * 0.9) % 1.0);
    return Positioned(
      left: x - 22,
      top: yy - 10,
      child: const Opacity(
        opacity: 0.9,
        child: Icon(Icons.touch_app_rounded, size: 46, color: Colors.white, shadows: [
          Shadow(color: Color(0xAA000000), blurRadius: 8),
        ]),
      ),
    );
  }
}

/// Level intro banner: objectives + newly introduced mechanic.
class IntroBanner extends StatelessWidget {
  const IntroBanner({super.key, required this.world, required this.visible});
  final GameWorld world;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    final cfg = world.config;
    final mech = world.newMechanic;
    return IgnorePointer(
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: visible ? 1 : 0,
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          offset: visible ? Offset.zero : const Offset(0, -0.2),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (mech != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                          child: Text('NEW',
                              style: AppText.label.copyWith(color: AppColors.primaryDark, fontWeight: FontWeight.w900)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(mechanicInfo[mech]!.title, style: AppText.section),
                              Text(mechanicInfo[mech]!.tip, style: AppText.body.copyWith(fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                if (!cfg.isEndless && !cfg.isTutorial)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface.withOpacity(0.94),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.stroke),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(cfg.title?.toUpperCase() ?? 'LEVEL ${cfg.levelId}', style: AppText.label),
                        const SizedBox(height: 8),
                        for (var i = 0; i < cfg.objectives.length; i++)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              children: [
                                StarIcon(filled: true, size: 16 + (i == 0 ? 0 : 0)),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: Text(cfg.objectives[i].description,
                                        style: AppText.body.copyWith(fontSize: 14))),
                              ],
                            ),
                          ),
                      ],
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

/// Subtle marker for the movement zone below the runner.
class MoveZoneHint extends StatelessWidget {
  const MoveZoneHint({super.key, required this.top, required this.visible});
  final double top;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      top: top,
      bottom: 0,
      child: IgnorePointer(
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 500),
          opacity: visible ? 1 : 0,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.white.withOpacity(0.06)],
              ),
            ),
            child: Align(
              alignment: const Alignment(0, 0.55),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.chevron_left_rounded, color: Colors.white.withOpacity(0.5), size: 28),
                  Text('DRAG TO MOVE', style: AppText.label.copyWith(color: Colors.white.withOpacity(0.55))),
                  Icon(Icons.chevron_right_rounded, color: Colors.white.withOpacity(0.5), size: 28),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
