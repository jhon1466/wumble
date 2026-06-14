import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global, persisted app locale. Spanish is the native/default language.
class LocaleController {
  static const String _prefsKey = 'app_locale';

  /// Languages the app supports.
  static const List<Locale> supported = [
    Locale('es'),
    Locale('en'),
    Locale('ru'),
  ];

  /// Listenable current locale; MaterialApp rebuilds when this changes.
  static final ValueNotifier<Locale> locale = ValueNotifier(const Locale('es'));

  /// Native display name for each supported language.
  static const Map<String, String> displayNames = {
    'es': 'Español',
    'en': 'English',
    'ru': 'Русский',
  };

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_prefsKey);
      if (code != null && supported.any((l) => l.languageCode == code)) {
        locale.value = Locale(code);
      }
    } catch (_) {}
  }

  static Future<void> setLocale(String code) async {
    if (!supported.any((l) => l.languageCode == code)) return;
    locale.value = Locale(code);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, code);
    } catch (_) {}
  }
}
