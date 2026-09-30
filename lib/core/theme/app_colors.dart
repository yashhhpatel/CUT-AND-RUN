import 'package:flutter/material.dart';

/// Central colour tokens. Gameplay colours carry meaning consistently:
/// green = safe/success, red = danger, yellow = reward, cyan = special/power.
abstract final class AppColors {
  static const bg = Color(0xFF0F1226);
  static const bgDeep = Color(0xFF090B1A);
  static const surface = Color(0xFF1A1F3D);
  static const surfaceHigh = Color(0xFF242A50);
  static const stroke = Color(0xFF333B6B);

  static const primary = Color(0xFFFF6A3D);
  static const primaryDark = Color(0xFFD4471E);
  static const primaryLight = Color(0xFFFF9670);
  static const accent = Color(0xFF3DD6F5);
  static const accentDark = Color(0xFF1C9DBF);

  static const reward = Color(0xFFFFC940);
  static const rewardDark = Color(0xFFCC9418);
  static const success = Color(0xFF3DDC84);
  static const warning = Color(0xFFFFA63D);
  static const danger = Color(0xFFFF4D5E);

  static const text = Color(0xFFF4F6FF);
  static const textMuted = Color(0xFF9AA3C7);
  static const textFaint = Color(0xFF5F6891);
}
