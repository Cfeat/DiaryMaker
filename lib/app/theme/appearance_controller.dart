import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme.dart';
import 'font_option.dart';

/// UI 外观偏好（非密钥，可用 SharedPreferences）。
class AppearanceState {
  const AppearanceState({
    this.font = AppFontOption.system,
    this.mood = AppColorMood.inkSea,
  });

  final AppFontOption font;
  final AppColorMood mood;

  AppearanceState copyWith({AppFontOption? font, AppColorMood? mood}) =>
      AppearanceState(
        font: font ?? this.font,
        mood: mood ?? this.mood,
      );

  ThemeData get theme => AppTheme.build(font: font, mood: mood);
}

class AppearanceController extends StateNotifier<AppearanceState> {
  AppearanceController(this._prefs)
      : super(
          AppearanceState(
            font: AppFontOption.fromId(_prefs.getString(_fontKey)),
            mood: AppColorMood.fromId(_prefs.getString(_moodKey)),
          ),
        );

  static const _fontKey = 'ui_font_option_v1';
  static const _moodKey = 'ui_color_mood_v1';

  final SharedPreferences _prefs;

  Future<void> setFont(AppFontOption font) async {
    state = state.copyWith(font: font);
    await _prefs.setString(_fontKey, font.id);
  }

  Future<void> setMood(AppColorMood mood) async {
    state = state.copyWith(mood: mood);
    await _prefs.setString(_moodKey, mood.id);
  }
}

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden');
});

final appearanceControllerProvider =
    StateNotifierProvider<AppearanceController, AppearanceState>((ref) {
  return AppearanceController(ref.watch(sharedPreferencesProvider));
});
