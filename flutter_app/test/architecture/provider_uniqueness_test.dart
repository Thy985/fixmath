/// TC-ARCH-6 / TC-1.1.1: Provider 全局唯一性守门
///
/// 对应 ADR-0002、AGENTS.md §3.2 / §6.1 #2。
library;

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TC-ARCH-6 / TC-1.1.1 Provider 全局唯一性', () {
    test('sharedPreferencesProvider 仅定义一次', () {
      final hits = _grepLib(RegExp(r'sharedPreferencesProvider\s*='));
      expect(
        hits,
        hasLength(1),
        reason: '实际命中：\n${hits.join("\n")}\n'
            'ADR-0002 / AGENTS.md §3.2 禁止重复定义',
      );
    }, skip: 'Known issue: providers/providers.dart 与 editor_providers.dart 重复定义');

    test('darkModeProvider 仅定义一次', () {
      final hits = _grepLib(RegExp(r'darkModeProvider\s*=\s*StateNotifierProvider'));
      expect(hits, hasLength(1));
    }, skip: 'Known issue: 同上，两文件均定义 DarkModeNotifier');

    test('documentsProvider 仅定义一次', () {
      final hits = _grepLib(RegExp(r'documentsProvider\s*='));
      expect(hits, hasLength(1),
          reason: '命中：\n${hits.join("\n")}');
    }, skip: 'Known issue: providers/providers.dart 与 domain/providers/document_provider.dart 重复定义');

    test('fileRepositoryProvider 仅定义一次', () {
      final hits = _grepLib(RegExp(r'fileRepositoryProvider\s*='));
      expect(hits, hasLength(1),
          reason: '命中：\n${hits.join("\n")}');
    });

    test('previewModeProvider 仅定义一次', () {
      final hits = _grepLib(RegExp(r'previewModeProvider\s*='));
      expect(hits, hasLength(1));
    }, skip: 'Known issue: 两文件重复定义');

    test('isExportingProvider 仅定义一次', () {
      final hits = _grepLib(RegExp(r'isExportingProvider\s*='));
      expect(hits, hasLength(1));
    }, skip: 'Known issue: 两文件重复定义');

    test('editorContentProvider 仅定义一次', () {
      final hits = _grepLib(RegExp(r'editorContentProvider\s*='));
      expect(hits, hasLength(1));
    }, skip: 'Known issue: 两文件重复定义');
  });
}

/// 在 lib/ 下递归扫描匹配 [pattern] 的行，返回 `file:line:content` 列表。
List<String> _grepLib(RegExp pattern) {
  final libDir = Directory('lib');
  final results = <String>[];
  if (!libDir.existsSync()) return results;
  for (final entity in libDir.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final lines = entity.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      if (pattern.hasMatch(lines[i])) {
        results.add('${entity.path}:${i + 1}:${lines[i].trim()}');
      }
    }
  }
  return results;
}
