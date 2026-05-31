import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/prefs_service.dart';

final editorContentProvider = StateNotifierProvider<EditorContentNotifier, String>((ref) {
  return EditorContentNotifier();
});

class EditorContentNotifier extends StateNotifier<String> {
  EditorContentNotifier() : super(PrefsService.lastContent);

  @override
  set state(String value) {
    PrefsService.lastContent = value;
    super.state = value;
  }
}

final previewModeProvider = StateProvider<bool>((ref) => false);

final darkModeProvider = StateNotifierProvider<DarkModeNotifier, bool>((ref) {
  return DarkModeNotifier();
});

class DarkModeNotifier extends StateNotifier<bool> {
  DarkModeNotifier() : super(PrefsService.darkMode);

  void toggle() {
    state = !state;
    PrefsService.darkMode = state;
  }
}

final isExportingProvider = StateProvider<bool>((ref) => false);