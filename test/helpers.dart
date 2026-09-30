import 'package:cut_and_run/app/app_services.dart';
import 'package:cut_and_run/progression/missions.dart';
import 'package:cut_and_run/progression/progress_store.dart';
import 'package:cut_and_run/services/ads/ad_service.dart';
import 'package:cut_and_run/services/audio/audio_service.dart';
import 'package:cut_and_run/services/haptics/haptics_service.dart';
import 'package:cut_and_run/services/purchases/purchase_service.dart';
import 'package:cut_and_run/services/storage/settings_store.dart';
import 'package:cut_and_run/services/storage/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppServices> testServices([Map<String, Object> prefs = const {}]) async {
  SharedPreferences.setMockInitialValues(prefs);
  final storage = await StorageService.create();
  final settings = SettingsStore(storage);
  final purchases = PurchaseService.offline(storage);
  final progress = ProgressStore(storage);
  return AppServices(
    storage: storage,
    settings: settings,
    progress: progress,
    audio: AudioService.disabled(settings),
    haptics: HapticsService(settings),
    ads: AdService.disabled(storage, purchases),
    purchases: purchases,
    missions: MissionStore(storage, progress),
  );
}

Widget wrap(AppServices s, Widget child) => AppScope(
      services: s,
      child: MaterialApp(home: child),
    );
