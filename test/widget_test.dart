import 'package:cut_and_run/app/app_services.dart';
import 'package:cut_and_run/game/engine/game_world.dart';
import 'package:cut_and_run/game/systems/run_stats.dart';
import 'package:cut_and_run/levels/generators/level_generator.dart';
import 'package:cut_and_run/screens/gameplay/game_screen.dart';
import 'package:cut_and_run/screens/gameplay/overlays.dart';
import 'package:cut_and_run/screens/home/home_screen.dart';
import 'package:cut_and_run/screens/level_map/level_map_screen.dart';
import 'package:cut_and_run/screens/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

Future<void> phone(WidgetTester t, [Size size = const Size(412, 915)]) async {
  t.view.physicalSize = size * 2.625;
  t.view.devicePixelRatio = 2.625;
  addTearDown(t.view.reset);
}

void main() {
  late AppServices s;
  setUp(() async => s = await testServices({'progress.tutorialDone': true}));

  testWidgets('home shows the brand, play button and modes', (t) async {
    await phone(t);
    await t.pumpWidget(wrap(s, const HomeScreen()));
    await t.pump(const Duration(milliseconds: 1200));
    expect(find.text('PLAY'), findsOneWidget);
    expect(find.text('Levels'), findsOneWidget);
    expect(find.text('Daily'), findsOneWidget);
    expect(find.text('Endless'), findsOneWidget);
    expect(find.text('SKINS'), findsOneWidget);
    expect(find.textContaining('LEVEL 1'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('home fits a small phone without overflow', (t) async {
    await phone(t, const Size(360, 640));
    await t.pumpWidget(wrap(s, const HomeScreen()));
    await t.pump(const Duration(milliseconds: 800));
    expect(t.takeException(), isNull);
  });

  testWidgets('level map shows unlocked and locked levels', (t) async {
    await phone(t);
    await t.pumpWidget(wrap(s, const LevelMapScreen()));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('Levels'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'Level 1, 0 stars')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'Level 2, locked')), findsOneWidget);
    // The level node's number label (the world badge also shows "1").
    await t.tap(find.text('1').last);
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));
    expect(find.text('OBJECTIVES'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('result screen shows rewards and waits for the player', (t) async {
    await phone(t);
    final cfg = LevelGenerator.campaign(3);
    final run = RunStats()
      ..cuts = 8
      ..score = 1500
      ..finalShards = 20;
    final r = s.progress.recordRun(config: cfg, run: run, completed: true, bestMultiplier: 2);
    var next = 0;
    await t.pumpWidget(wrap(
      s,
      Scaffold(body: ResultOverlay(result: r, onNext: () => next++, onRetry: () {}, onHome: () {})),
    ));
    await t.pump(const Duration(seconds: 3));
    expect(find.text('LEVEL COMPLETE'), findsOneWidget);
    expect(find.text('NEXT LEVEL'), findsOneWidget);
    expect(find.text('RETRY'), findsOneWidget);
    expect(find.text('HOME'), findsOneWidget);
    // No automatic redirect.
    await t.pump(const Duration(seconds: 5));
    expect(next, 0);
    await t.tap(find.text('NEXT LEVEL'));
    await t.pump(const Duration(milliseconds: 100));
    expect(next, 1);
  });

  testWidgets('failure screen shows progress and actions', (t) async {
    await phone(t);
    final w = GameWorld(LevelGenerator.campaign(4));
    w.failReason = 'Hit spikes';
    await t.pumpWidget(wrap(
      s,
      Scaffold(
        body: FailureOverlay(world: w, canContinue: true, onContinue: () async {}, onRetry: () {}, onHome: () {}),
      ),
    ));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('LEVEL FAILED'), findsOneWidget);
    expect(find.text('Hit spikes'), findsOneWidget);
    expect(find.text('WATCH AD & CONTINUE'), findsOneWidget);
    expect(find.text('RETRY'), findsOneWidget);
  });

  testWidgets('settings toggles persist', (t) async {
    await phone(t);
    await t.pumpWidget(wrap(s, const SettingsScreen()));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('Music'), findsOneWidget);
    expect(find.text('Remove Ads'), findsOneWidget);
    expect(find.text('Restore Purchases'), findsOneWidget);
    await t.tap(find.text('Music'));
    await t.pump();
    expect(s.settings.music, isFalse);
    expect(s.storage.getBool('settings.music', true), isFalse);
  });

  testWidgets('gameplay screen runs, responds to input and pauses on back', (t) async {
    await phone(t);
    await t.pumpWidget(wrap(s, GameScreen.campaign(2)));
    for (var i = 0; i < 90; i++) {
      await t.pump(const Duration(milliseconds: 16));
    }
    final state = t.state(find.byType(GameScreen));
    final world = (state as dynamic).world as GameWorld;
    expect(world.player.y, greaterThan(100));
    // Drag in the movement zone.
    final size = t.view.physicalSize / t.view.devicePixelRatio;
    final g = await t.startGesture(Offset(size.width / 2, size.height * 0.9));
    await g.moveBy(const Offset(80, 0));
    await g.up();
    for (var i = 0; i < 20; i++) {
      await t.pump(const Duration(milliseconds: 16));
    }
    expect(world.player.x, greaterThan(230));
    await t.tap(find.bySemanticsLabel('Pause'));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('PAUSED'), findsOneWidget);
    final y = world.player.y;
    await t.pump(const Duration(seconds: 1));
    expect(world.player.y, y, reason: 'paused world does not advance');
    await t.tap(find.text('RESUME'));
    await t.pump(const Duration(seconds: 4));
    expect(t.takeException(), isNull);
  });
}
