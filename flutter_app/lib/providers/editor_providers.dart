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
  return EditorContentNotifier();
});

/// 编辑器文本缓冲区（纯内存，不含持久化）。
///
/// 草稿持久化已在 Phase 1 由 ADR-0003 废除：不再写入
/// `SharedPreferences['pref_last_content']`，改为编辑器对当前打开的
/// .md 文件做防抖自动保存（见 [EditorScreen]）。
class EditorContentNotifier extends StateNotifier<String> {
  EditorContentNotifier() : super('');

  void setContent(String content) => state = content;

  void clear() => state = '';
}