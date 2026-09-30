import 'package:flutter/foundation.dart';

import 'storage_service.dart';

class SettingsStore extends ChangeNotifier {
  SettingsStore(this._storage)
      : _music = _storage.getBool(_kMusic, true),
        _sfx = _storage.getBool(_kSfx, true),
        _vibration = _storage.getBool(_kVibration, true);

  final StorageService _storage;

  static const _kMusic = 'settings.music';
  static const _kSfx = 'settings.sfx';
  static const _kVibration = 'settings.vibration';

  bool _music;
  bool _sfx;
  bool _vibration;

  bool get music => _music;
  bool get sfx => _sfx;
  bool get vibration => _vibration;

  set music(bool v) {
    _music = v;
    _storage.setBool(_kMusic, v);
    notifyListeners();
  }

  set sfx(bool v) {
    _sfx = v;
    _storage.setBool(_kSfx, v);
    notifyListeners();
  }

  set vibration(bool v) {
    _vibration = v;
    _storage.setBool(_kVibration, v);
    notifyListeners();
  }
}
