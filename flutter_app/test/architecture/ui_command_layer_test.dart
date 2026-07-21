/// TC-ARCH-UI-1 ~ 3: Phase 3.0 Command Layer 守门测试。
///
/// 落地 Phase 3.0 Task Contract §5.1（自动验证）+ §6（Exit Gate）+
/// ADR-0009 Hard Rule 2（Command Layer 强制）。
///
/// 守门内容：
/// - **TC-ARCH-UI-1**：UI 不直接 import BlockOperations / DocumentEditor
/// - **TC-ARCH-UI-2**：UI 不直接 import TransactionBuilder / EditOperation
/// - **TC-ARCH-UI-3**：State 子类不缓存 AST 字段（AST 零污染）
///
/// 所有 UI 事件必须经 EditorCommand → CommandHandler → TransactionBuilder →
/// BlockOperation 路径，禁止 UI 层直接调用 BlockOperations 或修改 AST。
library;

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 匹配 import 语句中的内核 mutation 文件
  // 注意：用普通字符串（非 raw）以支持 \" 转义
  final blockOperationsImport =
      RegExp("import\\s+['\"].*core/editing/block_operations\\.dart");
  final documentEditorImport =
      RegExp("import\\s+['\"].*core/editing/document_editor\\.dart");
  final transactionBuilderImport =
      RegExp("import\\s+['\"].*core/editing/transaction_builder\\.dart");
  final editOperationImport =
      RegExp("import\\s+['\"].*core/editing/edit_operation\\.dart");

  // 已知豁免：editor/in_memory_document_editor.dart 是 DocumentEditor 接口的
  // production 实现，需要 import 接口定义本身（implements DocumentEditor）。
  // Widget / Coordinator 不直接 import DocumentEditor，只 import 此实现类。
  const inMemoryEditorImplFile = 'editor/in_memory_document_editor.dart';

  // ============ TC-ARCH-UI-1 Command Layer 守门 ============

  group('TC-ARCH-UI-1 Command Layer 守门：UI 不直接 import BlockOperations / DocumentEditor', () {
    test('lib/presentation/{editor,blocks,panels,chrome}/ 不 import block_operations.dart', () {
      final hits = <String>[];
      for (final dir in ['editor', 'blocks', 'panels', 'chrome']) {
        final directory = Directory('lib/presentation/$dir');
        if (!directory.existsSync()) continue;
        for (final entity in directory.listSync(recursive: true)) {
          if (entity is! File || !entity.path.endsWith('.dart')) continue;
          final path = entity.path.replaceAll('\\', '/');
          final lines = entity.readAsLinesSync();
          for (var i = 0; i < lines.length; i++) {
            final line = lines[i];
            final trimmed = line.trim();
            if (trimmed.startsWith('//') || trimmed.startsWith('*')) continue;
            if (blockOperationsImport.hasMatch(line)) {
              hits.add('$path:${i + 1}:${line.trim()}');
            }
          }
        }
      }
      expect(
        hits,
        isEmpty,
        reason: 'AGENTS.md + ADR-0009 Hard Rule 2：UI 必须经 CommandHandler 访问内核，'
            '禁止直接 import BlockOperations。\n'
            '命中：\n${hits.join('\n')}',
      );
    });

    test('lib/presentation/{editor,blocks,panels,chrome}/ 不 import document_editor.dart', () {
      final hits = <String>[];
      for (final dir in ['editor', 'blocks', 'panels', 'chrome']) {
        final directory = Directory('lib/presentation/$dir');
        if (!directory.existsSync()) continue;
        for (final entity in directory.listSync(recursive: true)) {
          if (entity is! File || !entity.path.endsWith('.dart')) continue;
          final path = entity.path.replaceAll('\\', '/');
          // 豁免：in_memory_document_editor.dart 是 DocumentEditor 的实现，
          // 需要 import 接口本身（implements DocumentEditor）。
          // Widget / Coordinator 不直接 import DocumentEditor。
          if (path.endsWith(inMemoryEditorImplFile)) continue;
          final lines = entity.readAsLinesSync();
          for (var i = 0; i < lines.length; i++) {
            final line = lines[i];
            final trimmed = line.trim();
            if (trimmed.startsWith('//') || trimmed.startsWith('*')) continue;
            if (documentEditorImport.hasMatch(line)) {
              hits.add('$path:${i + 1}:${line.trim()}');
            }
          }
        }
      }
      expect(
        hits,
        isEmpty,
        reason: 'ADR-0009 Hard Rule 2：UI 通过 EditorCoordinator 间接持有 '
            'InMemoryDocumentEditor，禁止直接 import core/editing/document_editor.dart。',
      );
    });
  });

  // ============ TC-ARCH-UI-2 Command Layer 守门 ============

  group('TC-ARCH-UI-2 Command Layer 守门：UI 不直接 import TransactionBuilder / EditOperation', () {
    test('lib/presentation/{editor,blocks,panels,chrome}/ 不 import transaction_builder.dart', () {
      final hits = <String>[];
      for (final dir in ['editor', 'blocks', 'panels', 'chrome']) {
        final directory = Directory('lib/presentation/$dir');
        if (!directory.existsSync()) continue;
        for (final entity in directory.listSync(recursive: true)) {
          if (entity is! File || !entity.path.endsWith('.dart')) continue;
          final path = entity.path.replaceAll('\\', '/');
          final lines = entity.readAsLinesSync();
          for (var i = 0; i < lines.length; i++) {
            final line = lines[i];
            final trimmed = line.trim();
            if (trimmed.startsWith('//') || trimmed.startsWith('*')) continue;
            if (transactionBuilderImport.hasMatch(line)) {
              hits.add('$path:${i + 1}:${line.trim()}');
            }
          }
        }
      }
      expect(
        hits,
        isEmpty,
        reason: 'ADR-0009 Hard Rule 2：Transaction 构造由 CommandHandler 负责，'
            'UI 不得直接 import TransactionBuilder。',
      );
    });

    test('lib/presentation/{editor,blocks,panels,chrome}/ 不 import edit_operation.dart', () {
      final hits = <String>[];
      for (final dir in ['editor', 'blocks', 'panels', 'chrome']) {
        final directory = Directory('lib/presentation/$dir');
        if (!directory.existsSync()) continue;
        for (final entity in directory.listSync(recursive: true)) {
          if (entity is! File || !entity.path.endsWith('.dart')) continue;
          final path = entity.path.replaceAll('\\', '/');
          final lines = entity.readAsLinesSync();
          for (var i = 0; i < lines.length; i++) {
            final line = lines[i];
            final trimmed = line.trim();
            if (trimmed.startsWith('//') || trimmed.startsWith('*')) continue;
            if (editOperationImport.hasMatch(line)) {
              hits.add('$path:${i + 1}:${line.trim()}');
            }
          }
        }
      }
      expect(
        hits,
        isEmpty,
        reason: 'ADR-0009 Hard Rule 2：EditOperation 由内核构造，'
            'UI 不得直接 import edit_operation.dart。',
      );
    });
  });

  // ============ TC-ARCH-UI-3 AST 零污染守门 ============

  group('TC-ARCH-UI-3 Command Layer 守门：State 子类不缓存 AST 字段', () {
    // 扫描所有 _State 子类（extends State<...>）的字段，
    // 禁止持有 DocumentElement / ParagraphElement / HeadingElement / CodeElement 等字段。
    // 允许：StatelessWidget 通过 final 构造参数接收 AST 数据（这是数据流方向，非状态持有）。
    test('lib/presentation/{editor,blocks,panels,chrome}/ 下 State 类不持有 AST 字段', () {
      final hits = <String>[];
      final astFieldPattern = RegExp(
        r'^\s*(?:late\s+|final\s+)?(?:DocumentElement|ParagraphElement|HeadingElement|CodeElement|ListElement|TaskListItemElement|TableElement|BlockquoteElement|MermaidElement|HorizontalRuleElement)\??\s+\w+',
      );
      for (final dir in ['editor', 'blocks', 'panels', 'chrome']) {
        final directory = Directory('lib/presentation/$dir');
        if (!directory.existsSync()) continue;
        for (final entity in directory.listSync(recursive: true)) {
          if (entity is! File || !entity.path.endsWith('.dart')) continue;
          final path = entity.path.replaceAll('\\', '/');
          final lines = entity.readAsLinesSync();
          // 检测是否在 State 类（extends State<...>）内部
          var inStateClass = false;
          var braceDepth = 0;
          for (var i = 0; i < lines.length; i++) {
            final line = lines[i];
            // 检测 class X extends State<Y>
            final stateMatch =
                RegExp(r'class\s+\w+\s+extends\s+State<').firstMatch(line);
            if (stateMatch != null) {
              inStateClass = true;
              braceDepth = 0;
            }
            if (inStateClass) {
              // 简化括号匹配（不处理字符串/注释内的括号，但对当前文件足够）
              braceDepth += '{'.allMatches(line).length;
              braceDepth -= '}'.allMatches(line).length;
              final trimmed = line.trim();
              if (trimmed.startsWith('//') || trimmed.startsWith('*')) continue;
              if (astFieldPattern.hasMatch(line) &&
                  !line.contains('widget.')) {
                hits.add('$path:${i + 1}:${line.trim()}');
              }
              if (braceDepth <= 0 && i > 0 && inStateClass) {
                inStateClass = false;
              }
            }
          }
        }
      }
      expect(
        hits,
        isEmpty,
        reason: 'ADR-0009 Hard Rule 1（AST 零污染）：State 类不应缓存 AST 字段，'
            '必须通过 coordinator.getBlock(id) 实时获取。\n'
            '允许：StatelessWidget 通过 final 构造参数接收（数据流方向）。\n'
            '命中：\n${hits.join('\n')}',
      );
    });
  });
}
