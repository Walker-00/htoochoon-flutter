import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App locale override. `null` = follow the device/system locale.
/// Supported: English (en), Burmese (my), Thai (th).
class LocaleProvider extends ChangeNotifier {
  static const _kKey = 'app_locale';
  static const supported = [Locale('en'), Locale('my'), Locale('th')];

  Locale? _locale;
  Locale? get locale => _locale;

  LocaleProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_kKey);
    if (code != null && code.isNotEmpty) {
      _locale = Locale(code);
      notifyListeners();
    }
  }

  Future<void> setLocale(Locale? locale) async {
    _locale = locale;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (locale == null) {
      await prefs.remove(_kKey);
    } else {
      await prefs.setString(_kKey, locale.languageCode);
    }
  }

  static String labelFor(String code) {
    switch (code) {
      case 'my':
        return 'မြန်မာ (Burmese)';
      case 'th':
        return 'ไทย (Thai)';
      case 'en':
        return 'English';
      default:
        return code;
    }
  }
}
