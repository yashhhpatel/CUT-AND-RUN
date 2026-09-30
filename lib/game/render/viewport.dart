import 'dart:ui';

import '../entities/hazard.dart';

/// Maps world units to screen pixels. The track (400 units) plus a small
/// margin on each side always fills the screen width, so gameplay stays fair
/// across aspect ratios; taller screens simply see a little further ahead.
class GameViewport {
  static const double margin = 22;
  static const double viewWidth = kTrackWidth + margin * 2;

  /// Player sits at this fraction of the screen height.
  static const double playerAnchor = 0.74;

  Size size = Size.zero;
  double scale = 1;
  double trackLeft = 0;
  double playerScreenY = 0;
  double cameraY = 0;

  void resize(Size s) {
    size = s;
    scale = s.width / viewWidth;
    trackLeft = margin * scale;
    playerScreenY = s.height * playerAnchor;
  }

  double get unitsAhead => playerScreenY / scale;
  double get unitsBehind => (size.height - playerScreenY) / scale;

  Offset toScreen(Offset w) => Offset(trackLeft + w.dx * scale, playerScreenY - (w.dy - cameraY) * scale);

  Offset toWorld(Offset s) => Offset((s.dx - trackLeft) / scale, cameraY + (playerScreenY - s.dy) / scale);
}
