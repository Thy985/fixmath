import 'package:flutter_riverpod/flutter_riverpod.dart';

final editorContentProvider = StateProvider<String>((ref) => '');

final previewModeProvider = StateProvider<bool>((ref) => false);

final darkModeProvider = StateNotifierProvider<DarkModeNotifier, bool>((ref) {
  return DarkModeNotifier();
});

class DarkModeNotifier extends StateNotifier<bool> {
  DarkModeNotifier() : super(false);

  void toggle() => state = !state;
}

final isExportingProvider = StateProvider<bool>((ref) => false);

final clipboardContentProvider = FutureProvider<String?>((ref) async {
  return null;
});