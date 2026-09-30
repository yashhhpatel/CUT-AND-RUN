import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/app.dart';
import 'app/app_services.dart';
import 'progression/progress_store.dart';
import 'services/ads/ad_service.dart';
import 'services/audio/audio_service.dart';
import 'services/haptics/haptics_service.dart';
import 'services/purchases/purchase_service.dart';
import 'services/storage/settings_store.dart';
import 'services/storage/storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Optional services must never take the game down.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('flutter error: ${details.exceptionAsString()}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('uncaught: $error\n$stack');
    return true;
  };

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF090B1A),
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  final storage = await StorageService.create();
  final settings = SettingsStore(storage);
  final progress = ProgressStore(storage);
  final purchases = PurchaseService(storage);
  final audio = AudioService(settings);
  final services = AppServices(
    storage: storage,
    settings: settings,
    progress: progress,
    audio: audio,
    haptics: HapticsService(settings),
    ads: AdService(storage, purchases),
    purchases: purchases,
  );

  runApp(CutAndRunApp(services: services));

  // Non-blocking start-up of optional services.
  unawaited(audio.init().then((_) => audio.playMusic(Music.menu)));
  unawaited(purchases.init());
  unawaited(services.ads.init());
}
