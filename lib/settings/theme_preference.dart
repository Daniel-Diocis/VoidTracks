import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemePreference extends ValueNotifier<ThemeMode> {
  ThemePreference(this._prefs)
    : super(switch (_prefs.getString(_key)) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      });

  static const _key = 'appearance.theme';
  final SharedPreferences _prefs;

  Future<void> select(ThemeMode mode) async {
    if (mode == value) return;
    final previous = value;
    value = mode;
    try {
      if (!await _prefs.setString(_key, mode.name)) {
        throw StateError('Salvataggio del tema non riuscito');
      }
    } catch (_) {
      if (value == mode) value = previous;
      rethrow;
    }
  }
}

ThemeData appTheme(Brightness brightness) {
  final colors = ColorScheme.fromSeed(
    seedColor: const Color(0xff527977),
    brightness: brightness,
    surface:
        brightness == Brightness.dark
            ? const Color(0xff14191b)
            : const Color(0xfffafbf9),
  );
  return ThemeData(
    colorScheme: colors,
    scaffoldBackgroundColor: colors.surface,
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: colors.surfaceContainerLow,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: colors.surface,
      foregroundColor: colors.onSurface,
    ),
  );
}
