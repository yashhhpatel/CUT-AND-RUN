import 'package:flutter/services.dart';

import '../storage/settings_store.dart';

enum Haptic { light, selection, medium, heavy }

/// Subtle, throttled haptics. Uses the platform haptic engine (no VIBRATE
/// permission needed) and respects the in-game Vibration toggle.
class HapticsService {
  HapticsService(this._settings);

  final SettingsStore _settings;
  DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);

  void fire(Haptic h) {
    if (!_settings.vibration) return;
    final now = DateTime.now();
    final minGap = h == Haptic.heavy ? 0 : 70;
    if (now.difference(_last).inMilliseconds < minGap) return;
    _last = now;
    try {
      switch (h) {
        case Haptic.light:
          HapticFeedback.lightImpact();
        case Haptic.selection:
          HapticFeedback.selectionClick();
        case Haptic.medium:
          HapticFeedback.mediumImpact();
        case Haptic.heavy:
          HapticFeedback.heavyImpact();
      }
    } catch (_) {
      // Haptics are optional.
    }
  }
}
