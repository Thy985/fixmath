import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final clipboardServiceProvider = Provider<ClipboardService>((ref) {
  return ClipboardService();
});

class ClipboardService {
  Future<String?> getClipboardContent() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      return data?.text;
    } catch (e) {
      return null;
    }
  }

  Future<bool> hasText() async {
    final content = await getClipboardContent();
    return content != null && content.trim().isNotEmpty;
  }

  Future<void> copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }
}

class ClipboardListener {
  String? _lastClipboardContent;

  Future<String?> checkForNewContent() async {
    try {
      final current = await Clipboard.getData(Clipboard.kTextPlain);
      final content = current?.text?.trim();

      if (content != null &&
          content.isNotEmpty &&
          content != _lastClipboardContent) {
        _lastClipboardContent = content;
        return content;
      }
    } catch (e) {
      // Ignore clipboard errors
    }
    return null;
  }

  void setLastKnownContent(String content) {
    _lastClipboardContent = content;
  }
}
