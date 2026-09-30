import 'package:flutter/widgets.dart';

import '../progression/progress_store.dart';
import '../services/ads/ad_service.dart';
import '../services/audio/audio_service.dart';
import '../services/haptics/haptics_service.dart';
import '../services/purchases/purchase_service.dart';
import '../services/storage/settings_store.dart';
import '../services/storage/storage_service.dart';

/// Service container. Gameplay never reaches in here directly; screens pass
/// what the game needs, keeping the simulation decoupled from app services.
class AppServices {
  AppServices({
    required this.storage,
    required this.settings,
    required this.progress,
    required this.audio,
    required this.haptics,
    required this.ads,
    required this.purchases,
  });

  final StorageService storage;
  final SettingsStore settings;
  final ProgressStore progress;
  final AudioService audio;
  final HapticsService haptics;
  final AdService ads;
  final PurchaseService purchases;
}

class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.services, required super.child});

  final AppServices services;

  static AppServices of(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope missing');
    return scope!.services;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) => services != oldWidget.services;
}
