import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../levels/generators/level_generator.dart';
import '../../levels/models/mechanics.dart';
import '../../levels/worlds.dart';
import '../../progression/progress_store.dart';
import '../../widgets/common/badges.dart';
import '../../widgets/common/game_button.dart';
import '../../widgets/common/screen_scaffold.dart';
import '../gameplay/game_screen.dart';

/// Scrollable map of all 1000 levels, grouped by world. Built lazily.
class LevelMapScreen extends StatefulWidget {
  const LevelMapScreen({super.key});

  @override
  State<LevelMapScreen> createState() => _LevelMapScreenState();
}

sealed class _Item {}

class _Header extends _Item {
  _Header(this.world);
  final WorldDef world;
}

class _Node extends _Item {
  _Node(this.level);
  final int level;
}

class _LevelMapScreenState extends State<LevelMapScreen> {
  static const nodeH = 104.0;
  static const headerH = 132.0;
  late final List<_Item> _items;
  late final ScrollController _scroll;

  @override
  void initState() {
    super.initState();
    _items = [];
    for (final w in worlds) {
      _items.add(_Header(w));
      for (var l = w.firstLevel; l <= w.lastLevel; l++) {
        _items.add(_Node(l));
      }
    }
    _scroll = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToCurrent());
  }

  void _jumpToCurrent() {
    if (!mounted || !_scroll.hasClients) return;
    final current = AppScope.of(context).progress.unlockedLevel;
    var offset = 0.0;
    for (final it in _items) {
      if (it is _Node && it.level == current) break;
      offset += it is _Header ? headerH : nodeH;
    }
    final view = _scroll.position.viewportDimension;
    _scroll.jumpTo((offset - view / 2 + nodeH).clamp(0.0, _scroll.position.maxScrollExtent));
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _openLevel(int level) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _LevelSheet(level: level),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = AppScope.of(context).progress;
    return ScreenScaffold(
      title: 'Levels',
      body: ListenableBuilder(
        listenable: progress,
        builder: (context, _) => ListView.builder(
          controller: _scroll,
          reverse: true,
          padding: const EdgeInsets.only(top: 20, bottom: 30),
          itemCount: _items.length,
          itemBuilder: (context, i) {
            final it = _items[i];
            if (it is _Header) return _WorldHeader(world: it.world, stars: progress.starsInWorld(it.world));
            final level = (it as _Node).level;
            return _LevelRow(
              level: level,
              stars: progress.starsFor(level),
              unlocked: level <= progress.unlockedLevel,
              current: level == progress.unlockedLevel,
              onTap: () => _openLevel(level),
            );
          },
        ),
      ),
    );
  }
}

double _nodeX(int level) => math.sin(level * 0.85) * 0.28;

class _WorldHeader extends StatelessWidget {
  const _WorldHeader({required this.world, required this.stars});
  final WorldDef world;
  final int stars;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _LevelMapScreenState.headerH,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [world.bgTop, Color.lerp(world.bgTop, world.accent, 0.35)!]),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: world.rail.withOpacity(0.6), width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration:
                    BoxDecoration(color: Colors.black.withOpacity(0.25), borderRadius: BorderRadius.circular(14)),
                child: Center(child: Text('${world.id}', style: AppText.title.copyWith(color: world.rail))),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('WORLD ${world.id}', style: AppText.label.copyWith(color: Colors.white70)),
                    Text(world.name, style: AppText.section.copyWith(fontSize: 20)),
                    Text('Levels ${world.firstLevel}–${world.lastLevel}', style: AppText.label.copyWith(fontSize: 11)),
                  ],
                ),
              ),
              const StarIcon(filled: true, size: 20),
              const SizedBox(width: 4),
              Text('$stars/${world.levelCount * 3}', style: AppText.hud.copyWith(fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }
}

class _LevelRow extends StatelessWidget {
  const _LevelRow({
    required this.level,
    required this.stars,
    required this.unlocked,
    required this.current,
    required this.onTap,
  });

  final int level;
  final int stars;
  final bool unlocked;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final world = worldForLevel(level);
    return SizedBox(
      height: _LevelMapScreenState.nodeH,
      child: LayoutBuilder(builder: (context, c) {
        final w = c.maxWidth;
        final x = w / 2 + _nodeX(level) * w;
        final nextX = w / 2 + _nodeX(level + 1) * w;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _PathPainter(
                  from: Offset(x, _LevelMapScreenState.nodeH / 2),
                  to: Offset(nextX, -_LevelMapScreenState.nodeH / 2),
                  color: unlocked && !current ? world.rail.withOpacity(0.55) : AppColors.stroke,
                  drawTo: level != world.lastLevel,
                ),
              ),
            ),
            Positioned(
              left: x - 36,
              top: (_LevelMapScreenState.nodeH - 72) / 2 - 8,
              child: _LevelNode(
                  level: level, stars: stars, unlocked: unlocked, current: current, color: world.accent, onTap: onTap),
            ),
          ],
        );
      }),
    );
  }
}

class _PathPainter extends CustomPainter {
  _PathPainter({required this.from, required this.to, required this.color, required this.drawTo});
  final Offset from;
  final Offset to;
  final Color color;
  final bool drawTo;

  @override
  void paint(Canvas canvas, Size size) {
    if (!drawTo) return;
    final p = Paint()
      ..color = color
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    const n = 7;
    for (var i = 1; i < n; i++) {
      final t = i / n;
      final pt = Offset.lerp(from, to, t)! + Offset(math.sin(t * math.pi) * 18, 0);
      canvas.drawCircle(pt, 3.2, p);
    }
  }

  @override
  bool shouldRepaint(covariant _PathPainter old) => old.color != color || old.from != from || old.to != to;
}

class _LevelNode extends StatefulWidget {
  const _LevelNode({
    required this.level,
    required this.stars,
    required this.unlocked,
    required this.current,
    required this.color,
    required this.onTap,
  });

  final int level;
  final int stars;
  final bool unlocked;
  final bool current;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_LevelNode> createState() => _LevelNodeState();
}

class _LevelNodeState extends State<_LevelNode> with SingleTickerProviderStateMixin {
  AnimationController? _c;

  @override
  void initState() {
    super.initState();
    if (widget.current) {
      _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _LevelNode old) {
    super.didUpdateWidget(old);
    if (widget.current && _c == null) {
      _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
    } else if (!widget.current && _c != null) {
      _c!.dispose();
      _c = null;
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final done = widget.stars > 0;
    final face = !widget.unlocked
        ? AppColors.surface
        : widget.current
            ? AppColors.primary
            : AppColors.surfaceHigh;
    final node = Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: face,
        shape: BoxShape.circle,
        border: Border.all(
          color: widget.current ? Colors.white : (done ? widget.color : AppColors.stroke),
          width: widget.current ? 3.5 : 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: widget.unlocked ? Color.lerp(face, Colors.black, 0.45)! : Colors.black26,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Center(
        child: widget.unlocked
            ? Text('${widget.level}', style: AppText.title.copyWith(fontSize: widget.level >= 100 ? 21 : 25))
            : const Icon(Icons.lock_rounded, color: AppColors.textFaint, size: 24),
      ),
    );
    return Semantics(
      button: true,
      label: widget.unlocked ? 'Level ${widget.level}, ${widget.stars} stars' : 'Level ${widget.level}, locked',
      child: GestureDetector(
        onTap: widget.unlocked ? widget.onTap : null,
        child: SizedBox(
          width: 72,
          height: 96,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              if (_c != null)
                AnimatedBuilder(
                  animation: _c!,
                  builder: (_, __) => Transform.scale(
                    scale: 1 + 0.36 * _c!.value,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primary.withOpacity(1 - _c!.value), width: 3),
                      ),
                    ),
                  ),
                ),
              node,
              if (done) Positioned(top: 74, child: StarRow(stars: widget.stars, size: 15, spacing: 1)),
            ],
          ),
        ),
      ),
    );
  }
}

class _LevelSheet extends StatelessWidget {
  const _LevelSheet({required this.level});
  final int level;

  @override
  Widget build(BuildContext context) {
    final cfg = LevelGenerator.campaign(level);
    final world = worldForLevel(level);
    final progress = AppScope.of(context).progress;
    final intro = mechanicIntroducedAt(level);
    final best = progress.bestScore(level);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Panel(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(color: AppColors.stroke, borderRadius: BorderRadius.circular(3))),
              ),
              const SizedBox(height: 14),
              Text(world.name.toUpperCase(), style: AppText.label.copyWith(color: world.accent)),
              Row(
                children: [
                  Text(level == 1 ? 'Tutorial' : 'Level $level', style: AppText.title),
                  const Spacer(),
                  StarRow(stars: progress.starsFor(level), size: 22),
                ],
              ),
              if (best > 0) Text('Best score ${formatNumber(best)}', style: AppText.muted),
              if (intro != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.14), borderRadius: BorderRadius.circular(14)),
                  child: Row(
                    children: [
                      const Icon(Icons.fiber_new_rounded, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text('${mechanicInfo[intro]!.title}: ${mechanicInfo[intro]!.tip}',
                              style: AppText.body.copyWith(fontSize: 13.5))),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              const Text('OBJECTIVES', style: AppText.label),
              const SizedBox(height: 6),
              for (var i = 0; i < cfg.objectives.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      StarIcon(filled: progress.starsFor(level) > i, size: 18),
                      const SizedBox(width: 10),
                      Expanded(child: Text(cfg.objectives[i].description, style: AppText.body)),
                    ],
                  ),
                ),
              const SizedBox(height: 18),
              GameButton(
                label: 'PLAY',
                icon: Icons.play_arrow_rounded,
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(FadeRoute(GameScreen(config: cfg)));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Exposed for tests.
int starsForWorld(ProgressStore p, WorldDef w) => p.starsInWorld(w);
