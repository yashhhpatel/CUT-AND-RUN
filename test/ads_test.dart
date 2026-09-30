import 'package:cut_and_run/services/ads/ad_service.dart';
import 'package:cut_and_run/services/storage/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('interstitial is due after every 3 completed levels', () async {
    SharedPreferences.setMockInitialValues({});
    final pacer = InterstitialPacer(await StorageService.create());
    final due = <bool>[];
    for (var level = 1; level <= 9; level++) {
      final show = await pacer.registerCompletion();
      due.add(show);
      if (show) await pacer.reset();
    }
    expect(due, [false, false, true, false, false, true, false, false, true]);
  });

  test('if the ad was not ready it stays due for the next level', () async {
    SharedPreferences.setMockInitialValues({});
    final pacer = InterstitialPacer(await StorageService.create());
    await pacer.registerCompletion();
    await pacer.registerCompletion();
    expect(await pacer.registerCompletion(), isTrue); // not shown (no reset)
    expect(await pacer.registerCompletion(), isTrue);
    await pacer.reset();
    expect(await pacer.registerCompletion(), isFalse);
  });

  test('count survives app restarts', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = await StorageService.create();
    await InterstitialPacer(storage).registerCompletion();
    await InterstitialPacer(storage).registerCompletion();
    expect(await InterstitialPacer(storage).registerCompletion(), isTrue);
  });
}
