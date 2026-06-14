import 'package:flutter/material.dart';

/// Lightweight map-based localization for Spanish (native), English and Russian.
///
/// Usage: `context.t('key')`. Missing keys fall back to Spanish, then the key.
/// Strings are migrated to keys incrementally; screens not yet migrated keep
/// their literal Spanish text.
class AppLocalizations {
  final Locale locale;
  const AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations) ??
      const AppLocalizations(Locale('es'));

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  String t(String key) {
    final lang = _values[locale.languageCode] ?? _values['es']!;
    return lang[key] ?? _values['es']![key] ?? key;
  }

  static const Map<String, Map<String, String>> _values = {
    'es': {
      // Settings
      'settings': 'Ajustes',
      'language': 'Idioma',
      'choose_language': 'Elige tu idioma',
      // Common
      'save': 'Guardar',
      'cancel': 'Cancelar',
      'done': 'Hecho',
      'retry': 'Reintentar',
      'search': 'Buscar',
      'see_all': 'Ver todo',
      // Activity / presence
      'members_active': 'Miembros activos',
      'online_now': 'En línea ahora',
      'no_one_online': 'Nadie conectado por ahora.',
      'owner': 'Dueño',
      'admins': 'Administradores',
      'mods': 'Mods',
      'members': 'Miembros',
      // Wiki / OC
      'wikis': 'Wikis',
      'characters': 'Personajes',
      'new_character': 'Nuevo Personaje',
      // Auth
      'login_subtitle': 'Inicia sesión para continuar',
      'continue_with_google': 'Continuar con Google',
    },
    'en': {
      'settings': 'Settings',
      'language': 'Language',
      'choose_language': 'Choose your language',
      'save': 'Save',
      'cancel': 'Cancel',
      'done': 'Done',
      'retry': 'Retry',
      'search': 'Search',
      'see_all': 'See all',
      'members_active': 'Active members',
      'online_now': 'Online now',
      'no_one_online': 'No one is online right now.',
      'owner': 'Owner',
      'admins': 'Admins',
      'mods': 'Mods',
      'members': 'Members',
      'wikis': 'Wikis',
      'characters': 'Characters',
      'new_character': 'New Character',
      'login_subtitle': 'Sign in to continue',
      'continue_with_google': 'Continue with Google',
    },
    'ru': {
      'settings': 'Настройки',
      'language': 'Язык',
      'choose_language': 'Выберите язык',
      'save': 'Сохранить',
      'cancel': 'Отмена',
      'done': 'Готово',
      'retry': 'Повторить',
      'search': 'Поиск',
      'see_all': 'Показать всё',
      'members_active': 'Активные участники',
      'online_now': 'Сейчас в сети',
      'no_one_online': 'Сейчас никого нет в сети.',
      'owner': 'Владелец',
      'admins': 'Администраторы',
      'mods': 'Модераторы',
      'members': 'Участники',
      'wikis': 'Вики',
      'characters': 'Персонажи',
      'new_character': 'Новый персонаж',
      'login_subtitle': 'Войдите, чтобы продолжить',
      'continue_with_google': 'Войти через Google',
    },
  };
}

extension AppLocalizationsX on BuildContext {
  /// Shorthand for `AppLocalizations.of(context).t(key)`.
  String t(String key) => AppLocalizations.of(this).t(key);
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      ['es', 'en', 'ru'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
