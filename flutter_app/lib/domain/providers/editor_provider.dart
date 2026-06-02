import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/history_manager.dart';

enum EditorMode { edit, preview, split }

final editorModeProvider = StateProvider<EditorMode>((ref) => EditorMode.edit);

final isDarkModeProvider = StateProvider<bool>((ref) => false);

final isExportingProvider = StateProvider<bool>((ref) => false);

final contentProvider = StateNotifierProvider<ContentNotifier, String>((ref) {
  return ContentNotifier();
});

class ContentNotifier extends StateNotifier<String> {
  final HistoryManager<String> _historyManager = HistoryManager(maxHistorySize: 100);
  Timer? _debounceTimer;

  ContentNotifier() : super('');

  bool get canUndo => _historyManager.canUndo;
  bool get canRedo => _historyManager.canRedo;

  void setContent(String content) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 1000), () {
      if (content != state) {
        _historyManager.push(state);
      }
    });
    state = content;
  }

  void setContentImmediately(String content) {
    _debounceTimer?.cancel();
    if (content != state) {
      _historyManager.push(state);
    }
    state = content;
  }

  void undo() {
    final previous = _historyManager.undo(state);
    if (previous != null) {
      state = previous;
    }
  }

  void redo() {
    final next = _historyManager.redo(state);
    if (next != null) {
      state = next;
    }
  }

  void clear() {
    _debounceTimer?.cancel();
    _historyManager.clear();
    state = '';
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}

final hasUnsavedChangesProvider = Provider<bool>((ref) {
  final content = ref.watch(contentProvider);
  return content.isNotEmpty;
});
