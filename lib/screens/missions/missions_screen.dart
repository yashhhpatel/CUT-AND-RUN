import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../progression/missions.dart';
import '../../services/audio/audio_service.dart';
import '../../widgets/common/badges.dart';
import '../../widgets/common/game_button.dart';
import '../../widgets/common/screen_scaffold.dart';

class MissionsScreen extends StatefulWidget {
  const MissionsScreen({super.key});

  @override
  State<MissionsScreen> createState() => _MissionsScreenState();
}

class _MissionsScreenState extends State<MissionsScreen> {
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    // Refresh the "new missions in" countdown each minute.
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        AppScope.of(context).missions.ensureToday();
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  static IconData _icon(MissionType t) => switch (t) {
        MissionType.cuts => Icons.content_cut_rounded,
        MissionType.perfectCuts => Icons.auto_awesome_rounded,
        MissionType.pieces => Icons.category_rounded,
        MissionType.levels => Icons.flag_rounded,
        MissionType.combo => Icons.bolt_rounded,
        MissionType.coins => Icons.monetization_on_rounded,
        MissionType.gates => Icons.door_sliding_rounded,
        MissionType.bonus => Icons.stairs_rounded,
        MissionType.fusions => Icons.merge_type_rounded,
        MissionType.chains => Icons.link_rounded,
        MissionType.endless => Icons.all_inclusive_rounded,
      };

  String _resetIn() {
    final now = DateTime.now();
    final left = DateTime(now.year, now.month, now.day + 1).difference(now);
    return '${left.inHours}h ${left.inMinutes % 60}m';
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final store = s.missions..ensureToday();
    return ScreenScaffold(
      title: 'Daily Missions',
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Row(
              children: [
                const Icon(Icons.schedule_rounded, color: AppColors.textMuted, size: 18),
                const SizedBox(width: 6),
                Text('New missions in ${_resetIn()}', style: AppText.muted),
              ],
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < store.missions.length; i++) ...[
              _MissionCard(
                mission: store.missions[i],
                icon: _icon(store.missions[i].type),
                progress: store.progress[i],
                complete: store.isComplete(i),
                claimed: store.claimed[i],
                onClaim: () {
                  if (store.claim(i)) s.audio.play(Sfx.reward);
                },
              ),
              const SizedBox(height: 12),
            ],
            Text('Missions count progress from every mode: levels, Daily Challenge and Endless.',
                style: AppText.muted.copyWith(fontSize: 12.5)),
          ],
        ),
      ),
    );
  }
}

class _MissionCard extends StatelessWidget {
  const _MissionCard({
    required this.mission,
    required this.icon,
    required this.progress,
    required this.complete,
    required this.claimed,
    required this.onClaim,
  });

  final Mission mission;
  final IconData icon;
  final int progress;
  final bool complete;
  final bool claimed;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    final shown = progress.clamp(0, mission.target);
    return Panel(
      padding: const EdgeInsets.all(14),
      borderColor: complete && !claimed ? AppColors.reward : null,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: (complete ? AppColors.success : AppColors.accent).withOpacity(0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(complete ? Icons.check_rounded : icon, color: complete ? AppColors.success : AppColors.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(mission.text, style: AppText.body.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: shown / mission.target,
                    minHeight: 7,
                    backgroundColor: AppColors.surfaceHigh,
                    valueColor: AlwaysStoppedAnimation(complete ? AppColors.success : AppColors.accent),
                  ),
                ),
                const SizedBox(height: 3),
                Text('$shown / ${mission.target}', style: AppText.label.copyWith(fontSize: 10)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (claimed)
            const Icon(Icons.check_circle_rounded, color: AppColors.success)
          else if (complete)
            GameButton(
              label: '+${mission.reward}',
              style: GameButtonStyle.reward,
              height: 40,
              expand: false,
              fontSize: 14,
              onTap: onClaim,
            )
          else
            Row(mainAxisSize: MainAxisSize.min, children: [
              const CoinIcon(size: 16),
              const SizedBox(width: 4),
              Text('${mission.reward}', style: AppText.label),
            ]),
        ],
      ),
    );
  }
}
