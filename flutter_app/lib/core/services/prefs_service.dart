import 'package:shared_preferences/shared_preferences.dart';

class PrefsService {
  static const _keyDarkMode = 'pref_dark_mode';
  static const _keyLastContent = 'pref_last_content';
  static const _keyLastOpenPath = 'pref_last_open_path';

  static late SharedPreferences _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static bool get darkMode => _prefs.getBool(_keyDarkMode) ?? false;

  static set darkMode(bool value) {
    _prefs.setBool(_keyDarkMode, value);
  }

  static String get lastContent => _prefs.getString(_keyLastContent) ?? '';

  static set lastContent(String value) {
    _prefs.setString(_keyLastContent, value);
  }

  static String? get lastOpenPath => _prefs.getString(_keyLastOpenPath);

  static set lastOpenPath(String? value) {
    if (value == null) {
      _prefs.remove(_keyLastOpenPath);
    } else {
      _prefs.setString(_keyLastOpenPath, value);
    }
  }
}