/// TC-ARCH-UI-14：Phase 3.1-A PR #2 范式切换守门测试。
///
/// 守门内容（按 [phase3.1-task-contract.md v2.0 §5](../../../docs/contracts/phase3.1-task-contract.md)）：
///
/// 1. `kEnableNewEditor == true`（Phase 3.1-A PR #2 后默认启用新 UI）
/// 2. `/editor` 路由直接构造 `EditorPage`（不再按 feature flag 分流）
/// 3. `/editor-legacy` 路由存在并指向旧 `EditorScreen`（fallback 保留）
/// 4. `/editor3` 路由已移除（Phase 3.0 测试路由合并到 `/editor`）
/// 5. `previewModeProvider` 不在 `providers/providers.dart` 中重复定义（AGENTS.md §3.2）
/// 6. 旧 `editor_screen.dart` 文件仍存在（fallback，未删除）
/// 7. `EditorAppBar` 含"切换到旧版"入口（context.go('/editor-legacy')）
///
/// TC-ARCH-UI-15：R5 BlockId 迁移通知机制守门
///
/// 1. DocumentEditor 接口含 replaceBlockKeepId 方法
/// 2. DocumentEditor 接口含 replaceBlockWithMigration 方法
/// 3. replaceBlock 默认保持 BlockId（不再分配新 BlockId）
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:formula_fix/presentation/editor/feature_flag.dart';

void main() {
  // 项目的根目录（test/ 上一层是 lib/，再上一层是 flutter_app/）
  // 这个测试运行时的 cwd 是 flutter_app/，所以 lib/ 是相对路径
  const libRoot = 'lib';

  group('TC-ARCH-UI-14: Phase 3.1-A PR #2 范式切换守门', () {
    test('1. kEnableNewEditor == true（Phase 3.1-A PR #2 后默认启用新 UI）', () {
      expect(kEnableNewEditor, isTrue,
          reason: 'Phase 3.1-A PR #2 起 kEnableNewEditor 应为 true');
    });

    test('2. app_router.dart 含 /editor 路由', () {
      final file = File('$libRoot/core/router/app_router.dart');
      expect(file.existsSync(), isTrue,
          reason: 'app_router.dart 必须存在');
      final content = file.readAsStringSync();
      expect(content.contains("path: '/editor'"), isTrue,
          reason: '/editor 路由必须存在');
    });

    test('3. app_router.dart 含 /editor-legacy 路由（fallback）', () {
      final file = File('$libRoot/core/router/app_router.dart');
      final content = file.readAsStringSync();
      expect(content.contains("path: '/editor-legacy'"), isTrue,
          reason: '/editor-legacy fallback 路由必须存在');
    });

    test('4. app_router.dart 不含 /editor3 路由（Phase 3.0 测试路由已移除）', () {
      final file = File('$libRoot/core/router/app_router.dart');
      final content = file.readAsStringSync();
      expect(content.contains("path: '/editor3'"), isFalse,
          reason: '/editor3 路由应已移除（合并到 /editor）');
    });

    test('5. previewModeProvider 不在 providers/providers.dart 中重复定义', () {
      // 守门：AGENTS.md §3.2 禁止在多个文件定义同名 Provider
      // Phase 3.1-A PR #2 移除了 providers/providers.dart 中的 previewModeProvider
      // 唯一权威定义位于 providers/editor_providers.dart（仅供 legacy fallback 用）
      final providersFile = File('$libRoot/providers/providers.dart');
      expect(providersFile.existsSync(), isTrue);
      final content = providersFile.readAsStringSync();
      // 允许出现在注释中，但不允许 "final previewModeProvider = " 这样的定义
      expect(
        RegExp(r'final\s+previewModeProvider\s*=').hasMatch(content) ||
            content.contains('final previewModeProvider ='),
        isFalse,
        reason: 'providers/providers.dart 不应再定义 previewModeProvider '
            '（违反 AGENTS.md §3.2，应只在 editor_providers.dart 中定义）',
      );
    });

    test('6. 旧 editor_screen.dart 文件仍存在（fallback 未删除）', () {
      // Phase 3.1-A PR #2：保留 legacy EditorScreen 一个 release 周期
      // Phase 3.17 完成后才删除
      final editorScreenFile =
          File('$libRoot/presentation/screens/editor_screen.dart');
      expect(editorScreenFile.existsSync(), isTrue,
          reason: '旧 editor_screen.dart 文件必须保留作为 fallback');
    });

    test('7. EditorAppBar 含"切换到旧版"入口', () {
      final appBarFile = File('$libRoot/presentation/chrome/editor_app_bar.dart');
      expect(appBarFile.existsSync(), isTrue);
      final content = appBarFile.readAsStringSync();
      expect(content.contains("/editor-legacy"), isTrue,
          reason: 'EditorAppBar 应含 context.go("/editor-legacy") 隐藏入口');
      expect(content.contains('切换到旧版'), isTrue,
          reason: 'EditorAppBar 菜单项应含"切换到旧版"文案');
    });
  });

  group('TC-ARCH-UI-15: R5 BlockId 迁移通知机制守门', () {
    test('1. DocumentEditor 接口含 replaceBlockKeepId 方法', () {
      final interfaceFile = File('$libRoot/core/editing/document_editor.dart');
      expect(interfaceFile.existsSync(), isTrue);
      final content = interfaceFile.readAsStringSync();
      expect(content.contains('replaceBlockKeepId'), isTrue,
          reason: 'DocumentEditor 接口应含 replaceBlockKeepId 方法');
    });

    test('2. DocumentEditor 接口含 replaceBlockWithMigration 方法', () {
      final interfaceFile = File('$libRoot/core/editing/document_editor.dart');
      final content = interfaceFile.readAsStringSync();
      expect(content.contains('replaceBlockWithMigration'), isTrue,
          reason: 'DocumentEditor 接口应含 replaceBlockWithMigration 方法');
    });

    test('3. InMemoryDocumentEditor.replaceBlock 不含 _nextIdValue++（保持 BlockId）', () {
      // 静态守门：replaceBlock 实现不应分配新 BlockId
      final implFile =
          File('$libRoot/presentation/editor/in_memory_document_editor.dart');
      expect(implFile.existsSync(), isTrue);
      final content = implFile.readAsStringSync();
      // 提取 replaceBlock 方法体
      // 匹配 "DocumentElement replaceBlock(BlockId id, DocumentElement element) { ... }"
      // 到下一个 @override 或 replaceBlockKeepId
      final match = RegExp(
        r'DocumentElement replaceBlock\(BlockId id, DocumentElement element\)\s*\{',
      ).firstMatch(content);
      expect(match, isNotNull,
          reason: '应找到 replaceBlock 方法实现');

      // 从 match 开始提取方法体（匹配 { ... }）
      final startIdx = match!.end - 1; // 指向 '{'
      var depth = 0;
      var endIdx = startIdx;
      for (var i = startIdx; i < content.length; i++) {
        final c = content[i];
        if (c == '{') depth++;
        if (c == '}') {
          depth--;
          if (depth == 0) {
            endIdx = i;
            break;
          }
        }
      }
      final body = content.substring(startIdx, endIdx + 1);
      // replaceBlock 方法体内不应调用 _nextIdValue++
      expect(body.contains('_nextIdValue++'), isFalse,
          reason: 'replaceBlock 方法体不应分配新 BlockId（R5 默认保持 BlockId）');
    });

    test('4. replaceBlockWithMigration 含 onMigrated 回调调用', () {
      final implFile =
          File('$libRoot/presentation/editor/in_memory_document_editor.dart');
      final content = implFile.readAsStringSync();
      // 守门：replaceBlockWithMigration 实现应调用 onMigrated?.call
      expect(content.contains('onMigrated?.call'), isTrue,
          reason: 'replaceBlockWithMigration 应调用 onMigrated 回调');
    });
  });
}
