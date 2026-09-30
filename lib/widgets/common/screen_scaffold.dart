import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import 'badges.dart';
import 'game_button.dart';

/// Standard menu screen: gradient background, back button, title and coins.
class ScreenScaffold extends StatelessWidget {
  const ScreenScaffold({
    super.key,
    required this.title,
    required this.body,
    this.showCoins = true,
    this.background,
    this.onBack,
  });

  final String title;
  final Widget body;
  final bool showCoins;
  final Widget? background;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final progress = AppScope.of(context).progress;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          Positioned.fill(
            child: background ??
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF1A2046), AppColors.bgDeep],
                    ),
                  ),
                ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                  child: Row(
                    children: [
                      RoundIconButton(
                        icon: Icons.arrow_back_rounded,
                        tooltip: 'Back',
                        onTap: onBack ?? () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(title, style: AppText.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      if (showCoins)
                        ListenableBuilder(
                          listenable: progress,
                          builder: (_, __) => CoinBadge(coins: progress.coins),
                        ),
                    ],
                  ),
                ),
                Expanded(child: body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Fade + slight rise route used for all menu navigation.
class FadeRoute<T> extends PageRouteBuilder<T> {
  FadeRoute(Widget page)
      : super(
          transitionDuration: const Duration(milliseconds: 280),
          reverseTransitionDuration: const Duration(milliseconds: 220),
          pageBuilder: (_, __, ___) => page,
          transitionsBuilder: (_, a, __, child) {
            final curved = CurvedAnimation(parent: a, curve: Curves.easeOutCubic);
            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween(begin: const Offset(0, 0.03), end: Offset.zero).animate(curved),
                child: child,
              ),
            );
          },
        );
}
