import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) async {
  return SharedPreferences.getInstance();
});

final darkModeProvider = StateNotifierProvider<DarkModeNotifier, bool>((ref) {
  final prefsAsync = ref.watch(sharedPreferencesProvider);
  return DarkModeNotifier(prefsAsync.valueOrNull);
});

class DarkModeNotifier extends StateNotifier<bool> {
  final SharedPreferences? _prefs;
  static const _key = 'pref_dark_mode';

  DarkModeNotifier(this._prefs) : super(_prefs?.getBool(_key) ?? false);

  void toggle() {
    state = !state;
    _prefs?.setBool(_key, state);
  }
}

final previewModeProvider = StateProvider<bool>((ref) => false);

final isExportingProvider = StateProvider<bool>((ref) => false);

final editorContentProvider = StateNotifierProvider<EditorContentNotifier, String>((ref) {
  final prefsAsync = ref.watch(sharedPreferencesProvider);
  return EditorContentNotifier(prefsAsync.valueOrNull);
});

class EditorContentNotifier extends StateNotifier<String> {
  final SharedPreferences? _prefs;
  static const _key = 'pref_last_content';
  DateTime? _lastSave;

  EditorContentNotifier(this._prefs) : super(_prefs?.getString(_key) ?? '');

  @override
  set state(String v) {
    super.state = v;
    _debouncedSave(v);
  }

  void _debouncedSave(String v) {
    final now = DateTime.now();
    if (_lastSave != null && now.difference(_lastSave!).inMilliseconds < 500) {
      return;
    }
    _lastSave = now;
    _prefs?.setString(_key, v);
  }

  Future<void> forceSave() async {
    _prefs?.setString(_key, state);
  }
}