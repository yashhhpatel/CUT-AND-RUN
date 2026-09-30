import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../app/app_services.dart';
import '../../game/engine/game_events.dart';
import '../../game/engine/game_world.dart';
import '../../game/render/game_painter.dart';
import '../../game/render/viewport.dart';
import '../../levels/generators/level_generator.dart';
import '../../levels/generators/mode_generators.dart';
import '../../levels/models/level_config.dart';
import '../../levels/worlds.dart';
import '../../progression/progress_store.dart';
import '../../services/audio/audio_service.dart';
import '../../services/haptics/haptics_service.dart';
import '../../widgets/common/screen_scaffold.dart';
import 'hud.dart';
import 'overlays.dart';

enum _Overlay { none, pause, result, failure }

/// Hosts one run. Flutter widgets handle HUD and menus; the [GameWorld]
/// simulation and [GamePainter] handle everything inside the level.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.config, this.endless});

  final LevelConfig config;
  final EndlessGenerator? endless;

  factory GameScreen.campaign(int level) => GameScreen(config: LevelGenerator.campaign(level));

  factory GameScreen.daily([DateTime? date]) => GameScreen(config: DailyGenerator.forDate(date ?? DateTime.now()));

  factory GameScreen.endless() {
    final gen = EndlessGenerator();
    return GameScreen(config: gen.initialConfig(), endless: gen);
  }

  static int _active = 0;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final GameWorld world = GameWorld(widget.config, endless: widget.endless);
  final viewport = GameViewport();
  final _frame = ValueNotifier<int>(0);
  final _hudTick = ValueNotifier<int>(0);
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  _Overlay _overlay = _Overlay.none;
  RunResult? _result;
  bool _recorded = false;
  bool _introVisible = true;
  bool _movedOnce = false;
  int _endlessWorldId = 1;
  final _shardsKey = GlobalKey();
  late final double _endlessBestBefore;
  late final AppServices _s;

  int? _movePointer;
  int? _cutPointer;
  Offset _cutLast = Offset.zero;
  Duration _cutLastTime = Duration.zero;

  @override
  void initState() {
    super.initState();
    GameScreen._active++;
    WidgetsBinding.instance.addObserver(this);
    _ticker = createTicker(_tick)..start();
    Future.delayed(const Duration(milliseconds: 3600), () {
      if (mounted) setState(() => _introVisible = false);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInitServices) {
      _didInitServices = true;
      _s = AppScope.of(context);
      _endlessBestBefore = _s.progress.endless.distance;
      _s.audio.playMusic(Music.game);
    }
  }

  bool _didInitServices = false;

  @override
  void dispose() {
    GameScreen._active--;
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _frame.dispose();
    _hudTick.dispose();
    if (GameScreen._active == 0) _s.audio.playMusic(Music.menu);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive || state == AppLifecycleState.hidden) {
      if (_overlay == _Overlay.none && world.status == RunStatus.running) _pause();
      _s.audio.pauseMusic();
    } else if (state == AppLifecycleState.resumed) {
      _s.audio.resumeMusic();
    }
  }

  // ------------------------------------------------------------------- loop

  void _tick(Duration now) {
    final dt = _last == Duration.zero ? 0.0 : (now - _last).inMicroseconds / 1e6;
    _last = now;
    if (_overlay == _Overlay.pause) return;
    world.update(dt);
    _handleEvents();
    _frame.value++;
    if (_frame.value % 3 == 0) _hudTick.value++;
    if (_frame.value % 30 == 1) _locateShardsCounter();
    // Endless runs travel through the worlds; refresh the visual theme.
    if (widget.config.isEndless && _frame.value % 60 == 0) {
      final id = worldForLevel(EndlessGenerator.levelEquivalent(world.player.y)).id;
      if (id != _endlessWorldId) setState(() => _endlessWorldId = id);
    }

    if (world.status == RunStatus.failed && _overlay == _Overlay.none && world.statusTime > 0.9) {
      _s.audio.play(Sfx.fail);
      setState(() => _overlay = _Overlay.failure);
    }
    if (world.status == RunStatus.completed && _overlay == _Overlay.none && world.statusTime > 1.5) {
      _record(completed: true);
      setState(() => _overlay = _Overlay.result);
    }
  }

  void _handleEvents() {
    if (world.events.isEmpty) return;
    final audio = _s.audio;
    final h = _s.haptics;
    for (final e in world.events) {
      switch (e.type) {
        case GameEventType.cut:
          audio.play(Sfx.cut);
          audio.play(Sfx.split, volume: 0.7);
          h.fire(Haptic.light);
        case GameEventType.crack:
          audio.play(Sfx.clang, volume: 0.6);
          h.fire(Haptic.light);
        case GameEventType.deflect:
          audio.play(Sfx.clang);
          h.fire(Haptic.selection);
        case GameEventType.tooSlow:
          audio.play(Sfx.clang, volume: 0.4);
        case GameEventType.perfectCut:
          audio.play(Sfx.cut);
          audio.play(Sfx.perfect);
          h.fire(Haptic.medium);
        case GameEventType.chain:
          audio.play(Sfx.chain);
          h.fire(Haptic.medium);
        case GameEventType.collect:
          audio.play(Sfx.collect, volume: 0.55);
        case GameEventType.coin:
          audio.play(Sfx.coin, volume: 0.45);
        case GameEventType.combine:
          audio.play(Sfx.combine);
          h.fire(Haptic.medium);
        case GameEventType.perfectCollect:
        case GameEventType.perfectDodge:
        case GameEventType.perfectGate:
          audio.play(Sfx.perfect, volume: 0.8);
          h.fire(Haptic.light);
        case GameEventType.gatePass:
          audio.play(Sfx.gate);
          h.fire(Haptic.light);
        case GameEventType.gateFail:
          audio.play(Sfx.gateFail);
          h.fire(Haptic.medium);
        case GameEventType.powerUp:
          audio.play(Sfx.powerUp);
          h.fire(Haptic.medium);
        case GameEventType.shieldBreak:
          audio.play(Sfx.shield);
          h.fire(Haptic.heavy);
        case GameEventType.relicSaved:
          audio.play(Sfx.reward);
          h.fire(Haptic.medium);
        case GameEventType.relicBroken:
          audio.play(Sfx.gateFail, volume: 0.7);
        case GameEventType.comboUp:
          audio.play(Sfx.reward, volume: 0.5);
        case GameEventType.land:
          audio.play(Sfx.hit, volume: 0.45);
          h.fire(Haptic.light);
        case GameEventType.crash:
          audio.play(Sfx.hit);
          h.fire(Haptic.heavy);
        case GameEventType.complete:
          h.fire(Haptic.medium);
        case GameEventType.finishLine:
          audio.play(Sfx.complete);
          h.fire(Haptic.heavy);
        case GameEventType.bonusStep:
          audio.play(Sfx.coin);
          audio.play(Sfx.split, volume: 0.6);
          h.fire(Haptic.medium);
      }
    }
    world.events.clear();
  }

  void _locateShardsCounter() {
    final box = _shardsKey.currentContext?.findRenderObject();
    if (box is RenderBox && box.hasSize) {
      viewport.hudShardsTarget = box.localToGlobal(box.size.center(Offset.zero));
    }
  }

  // ------------------------------------------------------------------ input

  bool _inMoveZone(Offset p) => p.dy > viewport.playerScreenY - 30;

  void _onDown(PointerDownEvent e) {
    if (_overlay != _Overlay.none || world.status != RunStatus.running) return;
    if (_introVisible) setState(() => _introVisible = false);
    if (_inMoveZone(e.localPosition)) {
      _movePointer ??= e.pointer;
    } else if (_cutPointer == null) {
      _cutPointer = e.pointer;
      _cutLast = e.localPosition;
      _cutLastTime = e.timeStamp;
      world.cutter.begin(viewport.toWorld(e.localPosition));
    }
  }

  void _onMove(PointerMoveEvent e) {
    if (world.status != RunStatus.running) return;
    if (e.pointer == _movePointer) {
      world.moveBy(e.delta.dx / viewport.scale * 1.2);
      if (!_movedOnce && e.delta.dx.abs() > 0) setState(() => _movedOnce = true);
    } else if (e.pointer == _cutPointer) {
      final dtMs = (e.timeStamp - _cutLastTime).inMicroseconds / 1000;
      final dist = (e.localPosition - _cutLast).distance;
      final speed = dtMs > 0 ? dist / dtMs * 1000 : 0.0;
      _cutLast = e.localPosition;
      _cutLastTime = e.timeStamp;
      world.cutter.move(viewport.toWorld(e.localPosition), speed);
    }
  }

  void _onUp(PointerEvent e) {
    if (e.pointer == _movePointer) _movePointer = null;
    if (e.pointer == _cutPointer) {
      _cutPointer = null;
      world.cutter.end();
    }
  }

  // ---------------------------------------------------------------- actions

  void _pause() {
    if (world.status != RunStatus.running) return;
    world.cutter.end();
    _movePointer = null;
    _cutPointer = null;
    setState(() => _overlay = _Overlay.pause);
  }

  void _resume() {
    _last = Duration.zero;
    setState(() => _overlay = _Overlay.none);
  }

  void _record({required bool completed}) {
    if (_recorded) return;
    _recorded = true;
    if (widget.config.isEndless) world.finalizeEndless();
    _result = _s.progress.recordRun(
      config: widget.config,
      run: world.stats,
      completed: completed,
      bestMultiplier: world.bestMultiplier,
      failReason: world.failReason,
    );
    final done = _s.missions.recordRun(_result!);
    _result!.missionsCompleted.addAll(done.map((m) => m.text));
  }

  Future<void> _continueWithAd() async {
    final earned = await _s.ads.showRewarded();
    if (!mounted) return;
    if (earned) {
      world.revive();
      _last = Duration.zero;
      setState(() => _overlay = _Overlay.none);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No ad available right now. Check your connection and try again.')),
      );
    }
  }

  Future<void> _afterCompletionBreak() async {
    if (_result?.completed == true && widget.config.mode == GameMode.campaign) {
      await _s.ads.maybeShowInterstitial(levelJustCompleted: widget.config.levelId);
    }
  }

  Future<void> _retry() async {
    if (world.status != RunStatus.completed) _record(completed: false);
    await _afterCompletionBreak();
    if (!mounted) return;
    final next = widget.config.isEndless
        ? GameScreen.endless()
        : GameScreen(
            config: widget.config.mode == GameMode.campaign
                ? LevelGenerator.campaign(widget.config.levelId)
                : widget.config);
    Navigator.of(context).pushReplacement(FadeRoute(next));
  }

  Future<void> _home() async {
    if (world.status != RunStatus.completed) _record(completed: false);
    await _afterCompletionBreak();
    if (!mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  Future<void> _next() async {
    await _afterCompletionBreak();
    if (!mounted) return;
    final next = widget.config.levelId + 1;
    if (widget.config.mode != GameMode.campaign || next > kMaxLevel) {
      Navigator.of(context).popUntil((r) => r.isFirst);
      return;
    }
    Navigator.of(context).pushReplacement(FadeRoute(GameScreen.campaign(next)));
  }

  void _onBack() {
    switch (_overlay) {
      case _Overlay.none:
        _pause();
      case _Overlay.pause:
        _resume();
      case _Overlay.result:
      case _Overlay.failure:
        _home();
    }
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final theme = widget.config.isEndless
        ? worldForLevel(EndlessGenerator.levelEquivalent(world.player.y))
        : worldForLevel(widget.config.levelId);
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) _onBack();
      },
      child: Scaffold(
        backgroundColor: theme.bgBottom,
        body: LayoutBuilder(builder: (context, c) {
          viewport.resize(c.biggest);
          return Stack(
            children: [
              Positioned.fill(
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: _onDown,
                  onPointerMove: _onMove,
                  onPointerUp: _onUp,
                  onPointerCancel: _onUp,
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: GamePainter(
                        world: world,
                        viewport: viewport,
                        theme: theme,
                        loadout: _s.progress.loadout,
                        repaint: _frame,
                      ),
                    ),
                  ),
                ),
              ),
              MoveZoneHint(top: viewport.playerScreenY + 40, visible: !_movedOnce && _overlay == _Overlay.none),
              SafeArea(
                child: Column(
                  children: [
                    GameHud(world: world, tick: _hudTick, onPause: _pause, shardsKey: _shardsKey),
                    const SizedBox(height: 16),
                    IntroBanner(world: world, visible: _introVisible && _overlay == _Overlay.none),
                  ],
                ),
              ),
              if (widget.config.isTutorial)
                HintOverlay(world: world, tick: _hudTick, viewportPlayerY: viewport.playerScreenY),
              if (_overlay == _Overlay.pause) PauseOverlay(onResume: _resume, onRestart: _retry, onHome: _home),
              if (_overlay == _Overlay.failure)
                FailureOverlay(
                  world: world,
                  canContinue: !world.usedContinue && _s.ads.enabled,
                  onContinue: _continueWithAd,
                  onRetry: _retry,
                  onHome: _home,
                  previousBestDistance: _endlessBestBefore,
                ),
              if (_overlay == _Overlay.result && _result != null)
                ResultOverlay(
                  result: _result!,
                  onNext: widget.config.mode == GameMode.campaign && widget.config.levelId < kMaxLevel ? _next : null,
                  onRetry: _retry,
                  onHome: _home,
                ),
            ],
          );
        }),
      ),
    );
  }
}
