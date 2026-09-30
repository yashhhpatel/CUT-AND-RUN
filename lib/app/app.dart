import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../screens/home/splash_screen.dart';
import 'app_services.dart';

class CutAndRunApp extends StatelessWidget {
  const CutAndRunApp({super.key, required this.services, this.home});

  final AppServices services;

  /// Overridable start screen (tests).
  final Widget? home;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      services: services,
      child: MaterialApp(
        title: 'Cut & Run',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        builder: (context, child) {
          // Keep layouts stable: cap system font scaling at a readable maximum.
          final mq = MediaQuery.of(context);
          return MediaQuery(
            data: mq.copyWith(textScaler: mq.textScaler.clamp(minScaleFactor: 0.9, maxScaleFactor: 1.2)),
            child: child!,
          );
        },
        home: home ?? const SplashScreen(),
      ),
    );
  }
}
