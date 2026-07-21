/// TC-ARCH-UI-5 ~ 7: Phase 3.0 依赖方向守门测试。
///
/// 落地 Phase 3.0 Task Contract §5.1（自动验证）+ §6（Exit Gate）+
/// ADR-0009 Hard Rule 8（依赖方向严格）。
///
/// 守门内容：
/// - **TC-ARCH-UI-5**：blocks/ 不 import editor/（除 editor_coordinator.dart）/ panels/ / chrome/
/// - **TC-ARCH-UI-6**：editor/ 不 import panels/
/// - **TC-ARCH-UI-7**：chrome/ 不 import blocks/ / panels/
///
/// 依赖方向图（守门测试保障）：
/// ```
/// editor/  ─────────────────────────────────┐
///    ↓                                     │
/// chrome/ ── (通过 EditorCoordinator) ──────┤
///    ↓                                     │
/// blocks/ ←── EditorCoordinator 注入 ──────┘
///    ↓
/// core/editing  (内核，UI 不直接访问 mutation)
/// ```
library;

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 依赖方向守门正则（TC-ARCH-UI-5 ~ 7）
  String patternFor(String dir) => "import\\s+['\"].*presentation/$dir/";

  final importFromEditor = RegExp(patternFor('editor'));
  final importFromBlocks = RegExp(patternFor('blocks'));
  final importFromPanels = RegExp(patternFor('panels'));
  final importFromChrome = RegExp(patternFor('chrome'));

  // 已知豁免：editor/editor_coordinator.dart 是 EditorCoordinator 的定义文件，
  // blocks/ 必须能 import 它（这是 Hard Rule 8 允许的依赖方向）。
  const editorCoordinatorFile = 'editor/editor_coordinator.dart';

  // ============ TC-ARCH-UI-5 依赖方向守门 ============

  group('TC-ARCH-UI-5 依赖方向守门：blocks/ 不 import editor/ / panels/ / chrome/', () {
    test('lib/presentation/blocks/ 不 import editor/（除 editor_coordinator.dart）', () {
      final hits = <String>[];
      final directory = Directory('lib/presentation/blocks');
      if (!directory.existsSync()) {
        fail('lib/presentation/blocks 不存在');
      }
      for (final entity in directory.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final path = entity.path.replaceAll('\\', '/');
        final lines = entity.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          final trimmed = line.trim();
          if (trimmed.startsWith('//') || trimmed.startsWith('*')) continue;
          if (importFromEditor.hasMatch(line)) {
            // 豁免：editor/editor_coordinator.dart 是 EditorCoordinator 定义文件，
            // blocks/ 可以 import 它（这是 ADR-0009 §3.5 允许的依赖方向）
            if (line.contains(editorCoordinatorFile)) continue;
            hits.add('$path:${i + 1}:${line.trim()}');
          }
        }
      }
      expect(
        hits,
        isEmpty,
        reason: 'ADR-0009 Hard Rule 8：blocks/ 只能 import editor/editor_coordinator.dart，'
            '禁止 import editor/ 下其他文件（editor_page / editor_shell / editor_scope 等）。\n'
            '命中：\n${hits.join('\n')}',
      );
    });

    test('lib/presentation/blocks/ 不 import panels/ / chrome/', () {
      final hits = <String>[];
      final directory = Directory('lib/presentation/blocks');
      if (!directory.existsSync()) {
        fail('lib/presentation/blocks 不存在');
      }
      for (final entity in directory.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final path = entity.path.replaceAll('\\', '/');
        final lines = entity.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          final trimmed = line.trim();
          if (trimmed.startsWith('//') || trimmed.startsWith('*')) continue;
          if (importFromPanels.hasMatch(line) || importFromChrome.hasMatch(line)) {
            hits.add('$path:${i + 1}:${line.trim()}');
          }
        }
      }
      expect(
        hits,
        isEmpty,
        reason: 'ADR-0009 Hard Rule 8：blocks/ 不允许 import panels/ / chrome/。\n'
            '命中：\n${hits.join('\n')}',
      );
    });
  });

  // ============ TC-ARCH-UI-6 依赖方向守门 ============

  group('TC-ARCH-UI-6 依赖方向守门：editor/ 不 import panels/', () {
    test('lib/presentation/editor/ 不 import panels/', () {
      final hits = <String>[];
      final directory = Directory('lib/presentation/editor');
      if (!directory.existsSync()) {
        fail('lib/presentation/editor 不存在');
      }
      for (final entity in directory.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final path = entity.path.replaceAll('\\', '/');
        final lines = entity.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          final trimmed = line.trim();
          if (trimmed.startsWith('//') || trimmed.startsWith('*')) continue;
          if (importFromPanels.hasMatch(line)) {
            hits.add('$path:${i + 1}:${line.trim()}');
          }
        }
      }
      expect(
        hits,
        isEmpty,
        reason: 'ADR-0009 Hard Rule 8：editor/ 不允许 import panels/。\n'
            '命中：\n${hits.join('\n')}',
      );
    });
  });

  // ============ TC-ARCH-UI-7 依赖方向守门 ============

  group('TC-ARCH-UI-7 依赖方向守门：chrome/ 不 import blocks/ / panels/', () {
    test('lib/presentation/chrome/ 不 import blocks/ / panels/', () {
      final hits = <String>[];
      final directory = Directory('lib/presentation/chrome');
      if (!directory.existsSync()) {
        fail('lib/presentation/chrome 不存在');
      }
      for (final entity in directory.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final path = entity.path.replaceAll('\\', '/');
        final lines = entity.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          final trimmed = line.trim();
          if (trimmed.startsWith('//') || trimmed.startsWith('*')) continue;
          if (importFromBlocks.hasMatch(line) || importFromPanels.hasMatch(line)) {
            hits.add('$path:${i + 1}:${line.trim()}');
          }
        }
      }
      expect(
        hits,
        isEmpty,
        reason: 'Phase 3.0 Task Contract v1.1：chrome/ 只通过 EditorCoordinator '
            '接收数据，不允许 import blocks/ / panels/。\n'
            '命中：\n${hits.join('\n')}',
      );
    });
  });
}
