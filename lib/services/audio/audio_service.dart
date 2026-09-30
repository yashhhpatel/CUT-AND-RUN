import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../storage/settings_store.dart';

enum Sfx {
  cut,
  split,
  collect,
  coin,
  combine,
  hit,
  shield,
  perfect,
  chain,
  gate,
  gateFail,
  powerUp,
  tap,
  reward,
  complete,
  fail,
  clang
}

enum Music { menu, game }

/// All audio is synthesised by tool/gen_audio.py (original, shippable).
/// Every call is fail-safe: missing assets or audio errors never crash the game.
class AudioService {
  AudioService(this._settings) : _enabled = true {
    _settings.addListener(_onSettings);
  }

  /// A silent instance for tests.
  AudioService.disabled(this._settings) : _enabled = false;

  final SettingsStore _settings;
  final bool _enabled;
  final Map<Sfx, AudioPool> _pools = {};
  final Map<Sfx, DateTime> _lastPlayed = {};
  AudioPlayer? _music;
  Music? _currentMusic;
  bool _ready = false;

  static const _files = {
    Sfx.cut: 'cut',
    Sfx.split: 'split',
    Sfx.collect: 'collect',
    Sfx.coin: 'coin',
    Sfx.combine: 'combine',
    Sfx.hit: 'hit',
    Sfx.shield: 'shield',
    Sfx.perfect: 'perfect',
    Sfx.chain: 'chain',
    Sfx.gate: 'gate',
    Sfx.gateFail: 'gate_fail',
    Sfx.powerUp: 'powerup',
    Sfx.tap: 'tap',
    Sfx.reward: 'reward',
    Sfx.complete: 'complete',
    Sfx.fail: 'fail',
    Sfx.clang: 'clang',
  };

  Future<void> init() async {
    if (!_enabled) return;
    try {
      await AudioPlayer.global.setAudioContext(AudioContext(
        android: const AudioContextAndroid(
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.game,
          audioFocus: AndroidAudioFocus.none,
        ),
      ));
      await Future.wait(_files.entries.map((e) async {
        try {
          _pools[e.key] = await AudioPool.create(
            source: AssetSource('audio/${e.value}.ogg'),
            maxPlayers: e.key == Sfx.collect || e.key == Sfx.coin || e.key == Sfx.cut ? 4 : 2,
          );
        } catch (err) {
          debugPrint('audio: failed to load ${e.value}: $err');
        }
      }));
      _music = AudioPlayer(playerId: 'music');
      await _music!.setReleaseMode(ReleaseMode.loop);
      await _music!.setVolume(0.45);
      _ready = true;
    } catch (e) {
      debugPrint('audio: init failed, continuing silently: $e');
    }
  }

  void play(Sfx s, {double volume = 1}) {
    if (!_enabled || !_ready || !_settings.sfx) return;
    final now = DateTime.now();
    final last = _lastPlayed[s];
    if (last != null && now.difference(last).inMilliseconds < 45) return;
    _lastPlayed[s] = now;
    final pool = _pools[s];
    if (pool == null) return;
    unawaited(pool.start(volume: volume).then((_) {}, onError: (Object e) => debugPrint('audio: $e')));
  }

  Future<void> playMusic(Music m) async {
    _currentMusic = m;
    if (!_enabled || !_ready || !_settings.music) return;
    try {
      await _music!.stop();
      await _music!.play(AssetSource(m == Music.menu ? 'audio/music_menu.ogg' : 'audio/music_game.ogg'));
    } catch (e) {
      debugPrint('audio: music failed: $e');
    }
  }

  Future<void> pauseMusic() async {
    if (!_ready) return;
    try {
      await _music?.pause();
    } catch (_) {}
  }

  Future<void> resumeMusic() async {
    if (!_ready || !_settings.music) return;
    try {
      if (_music?.state == PlayerState.paused) {
        await _music?.resume();
      } else if (_currentMusic != null) {
        await playMusic(_currentMusic!);
      }
    } catch (_) {}
  }

  void _onSettings() {
    if (!_ready) return;
    if (_settings.music) {
      if (_music?.state != PlayerState.playing && _currentMusic != null) playMusic(_currentMusic!);
    } else {
      _music?.stop();
    }
  }

  void dispose() {
    _settings.removeListener(_onSettings);
    _music?.dispose();
    for (final p in _pools.values) {
      p.dispose();
    }
  }
}
