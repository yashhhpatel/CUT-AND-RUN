import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/common/logo.dart';
import '../../widgets/common/screen_scaffold.dart';
import '../gameplay/game_screen.dart';
import 'home_screen.dart';

/// Brief brand moment, then straight into play: first-time players go
/// directly into the interactive tutorial (level 1).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1700), _go);
  }

  void _go() {
    if (!mounted) return;
    final progress = AppScope.of(context).progress;
    final nav = Navigator.of(context);
    nav.pushReplacement(FadeRoute(const HomeScreen()));
    if (!progress.tutorialDone) {
      nav.push(FadeRoute(GameScreen.campaign(1)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const LogoTitle(size: 72),
            const SizedBox(height: 22),
            Text('SLICE  ·  SPLIT  ·  ESCAPE', style: AppText.label.copyWith(letterSpacing: 3)),
          ],
        ),
      ),
    );
  }
}
