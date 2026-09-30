import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../progression/cosmetics.dart';
import '../../services/audio/audio_service.dart';
import '../../widgets/common/badges.dart';
import '../../widgets/common/game_button.dart';
import '../../widgets/common/screen_scaffold.dart';

class SkinsScreen extends StatefulWidget {
  const SkinsScreen({super.key});

  @override
  State<SkinsScreen> createState() => _SkinsScreenState();
}

class _SkinsScreenState extends State<SkinsScreen> {
  CosmeticKind _tab = CosmeticKind.skin;

  Future<void> _onTap(Cosmetic c) async {
    final s = AppScope.of(context);
    final p = s.progress;
    if (p.owns(c.id)) {
      p.select(c);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _BuyDialog(item: c, canAfford: p.coins >= c.price),
    );
    if (ok != true || !mounted) return;
    if (p.buy(c)) {
      p.select(c);
      s.audio.play(Sfx.reward);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context).progress;
    return ScreenScaffold(
      title: 'Skins',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  for (final (k, label) in [
                    (CosmeticKind.skin, 'Runner'),
                    (CosmeticKind.cutEffect, 'Cut FX'),
                    (CosmeticKind.trail, 'Trails'),
                  ])
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _tab = k),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          height: 42,
                          decoration: BoxDecoration(
                            color: _tab == k ? AppColors.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(label,
                                style: AppText.button
                                    .copyWith(fontSize: 14, color: _tab == k ? Colors.white : AppColors.textMuted)),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: p,
              builder: (context, _) {
                final items = Cosmetics.ofKind(_tab);
                final selected = p.selectedId(_tab);
                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 200,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.82,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final c = items[i];
                    return _CosmeticCard(
                      item: c,
                      owned: p.owns(c.id),
                      equipped: c.id == selected,
                      onTap: () => _onTap(c),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CosmeticCard extends StatelessWidget {
  const _CosmeticCard({required this.item, required this.owned, required this.equipped, required this.onTap});
  final Cosmetic item;
  final bool owned;
  final bool equipped;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${item.name}, ${equipped ? 'equipped' : owned ? 'owned' : '${item.price} coins'}',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: equipped ? AppColors.success : AppColors.stroke, width: equipped ? 2.5 : 1.5),
          ),
          child: Column(
            children: [
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.bgDeep, borderRadius: BorderRadius.circular(14)),
                  child: CustomPaint(painter: CosmeticPreviewPainter(item), size: Size.infinite),
                ),
              ),
              Text(item.name, style: AppText.body.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: equipped
                    ? Text('EQUIPPED', style: AppText.label.copyWith(color: AppColors.success))
                    : owned
                        ? const Text('TAP TO EQUIP', style: AppText.label)
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CoinIcon(size: 16),
                              const SizedBox(width: 5),
                              Text(formatNumber(item.price),
                                  style: AppText.label.copyWith(color: AppColors.reward, fontSize: 13)),
                            ],
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small vector preview of a cosmetic (runner, blade line or trail).
class CosmeticPreviewPainter extends CustomPainter {
  CosmeticPreviewPainter(this.item);
  final Cosmetic item;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    switch (item.kind) {
      case CosmeticKind.skin:
        final r = size.shortestSide * 0.24;
        if (item.glow != null) canvas.drawCircle(c, r + 8, Paint()..color = item.glow!.withOpacity(0.3));
        canvas.drawCircle(c, r, Paint()..color = item.primary);
        canvas.drawCircle(c + Offset(-r * 0.3, r * 0.3), r * 0.45, Paint()..color = Colors.white.withOpacity(0.25));
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromCenter(center: c - Offset(0, r * 0.4), width: r * 1.3, height: r * 0.5),
              Radius.circular(r * 0.25)),
          Paint()..color = item.secondary,
        );
        canvas.drawCircle(
          c,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = Color.lerp(item.primary, Colors.black, 0.4)!,
        );
      case CosmeticKind.cutEffect:
        final a = Offset(size.width * 0.15, size.height * 0.8);
        final b = Offset(size.width * 0.85, size.height * 0.2);
        canvas.drawLine(
            a,
            b,
            Paint()
              ..color = item.secondary.withOpacity(0.45)
              ..strokeWidth = 14
              ..strokeCap = StrokeCap.round);
        canvas.drawLine(
            a,
            b,
            Paint()
              ..color = item.primary
              ..strokeWidth = 4
              ..strokeCap = StrokeCap.round);
      case CosmeticKind.trail:
        for (var i = 0; i < 10; i++) {
          final k = i / 10;
          final p = Offset(size.width * 0.5 + math.sin(i * 0.8) * 10, size.height * (0.9 - k * 0.6));
          final col = i.isEven ? item.primary : item.secondary;
          canvas.drawCircle(p, 3 + 6 * k, Paint()..color = col.withOpacity(0.25 + 0.6 * k));
        }
        canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.24), 12, Paint()..color = AppColors.primary);
    }
  }

  @override
  bool shouldRepaint(covariant CosmeticPreviewPainter oldDelegate) => oldDelegate.item != item;
}

class _BuyDialog extends StatelessWidget {
  const _BuyDialog({required this.item, required this.canAfford});
  final Cosmetic item;
  final bool canAfford;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Panel(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 110, child: CustomPaint(painter: CosmeticPreviewPainter(item))),
            const SizedBox(height: 8),
            Text(item.name, style: AppText.title, textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(
              canAfford
                  ? 'Unlock for ${formatNumber(item.price)} coins?'
                  : 'You need ${formatNumber(item.price)} coins. Play levels and complete achievements to earn more.',
              style: AppText.muted,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            if (canAfford) ...[
              GameButton(
                  label: 'UNLOCK',
                  icon: Icons.lock_open_rounded,
                  style: GameButtonStyle.reward,
                  onTap: () => Navigator.pop(context, true)),
              const SizedBox(height: 10),
            ],
            GameButton(
                label: canAfford ? 'CANCEL' : 'OK',
                style: GameButtonStyle.secondary,
                onTap: () => Navigator.pop(context, false)),
          ],
        ),
      ),
    );
  }
}
