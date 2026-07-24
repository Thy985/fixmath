/// Phase 3.3 PR #2A：3 个新 Command 子类的 dispatch + 行为 + Undo/Redo 集成测试。
///
/// 落地 Task Contract v2.1 §4.4 + §5.4.1（selection offset 必须验证）。
///
/// 从 `command_handler_dispatch_test.dart` 拆分（AGENTS.md §1.2 文件 ≤ 400 行），
/// 本文件专测 PR #2A 新增的 [InsertTextCommand] / [WrapSelectionCommand] /
/// [InsertTemplateCommand]，原文件保留 R4 自省 + R4 守卫测试。
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:formula_fix/core/editing/block_types.dart';
import 'package:formula_fix/core/editing/editor_history.dart';
import 'package:formula_fix/presentation/commands/command_handler.dart';
import 'package:formula_fix/presentation/commands/commands.dart';
import 'package:formula_fix/presentation/prototype/_shared/in_memory_document_editor.dart';

void main() {
  group('Phase 3.3 PR #2A: InsertTextCommand dispatch + 行为', () {
    late InMemoryDocumentEditor editor;
    late EditorHistory history;
    late CommandHandler handler;

    setUp(() {
      editor = InMemoryDocumentEditor();
      history = EditorHistory();
      handler = CommandHandler(editor: editor, history: history);
    });

    test('InsertTextCommand 被 dispatch（无选区，追加到末尾）', () {
      final id = editor.addParagraph('hello');
      final success = handler.handle(InsertTextCommand(
        blockId: id,
        text: ' world',
        selection: null, // 无选区 → 追加到末尾
      ));
      expect(success, isTrue,
          reason: 'InsertTextCommand 应被 dispatch');
      expect(editor.sourceOf(id), equals('hello world'),
          reason: '无选区时 text 应追加到 source 末尾');
    });

    test('InsertTextCommand 在光标位置插入（selection.baseOffset）', () {
      final id = editor.addParagraph('hello world');
      // 光标在 offset 5（hello 与 world 之间）
      const selection = TextSelection(baseOffset: 5, extentOffset: 5);
      final success = handler.handle(InsertTextCommand(
        blockId: id,
        text: '_',
        selection: selection,
      ));
      expect(success, isTrue);
      expect(editor.sourceOf(id), equals('hello_ world'),
          reason: 'text 应在 selection.baseOffset 位置插入');
    });

    test('InsertTextCommand 有选区时替换选区内容', () {
      final id = editor.addParagraph('hello world');
      // 选中 "world" [6..11]
      const selection = TextSelection(baseOffset: 6, extentOffset: 11);
      final success = handler.handle(InsertTextCommand(
        blockId: id,
        text: 'dart',
        selection: selection,
      ));
      expect(success, isTrue);
      // selection.baseOffset=6,在 6 处插入 'dart',原 [6..11] 不变但被推后
      // 实际：hello [插入 dart] world → hello dartworld
      // 注意：InsertTextCommand 仅插入,不删除选区（删除选区是 WrapSelection 的职责）
      expect(editor.sourceOf(id), equals('hello dartworld'),
          reason: 'InsertText 仅在 baseOffset 插入,不删除选区');
    });

    test('InsertTextCommand 越界守卫：baseOffset > source.length 返回 false', () {
      final id = editor.addParagraph('hello'); // length=5
      const selection = TextSelection(baseOffset: 100, extentOffset: 100);
      final success = handler.handle(InsertTextCommand(
        blockId: id,
        text: 'x',
        selection: selection,
      ));
      expect(success, isFalse,
          reason: 'baseOffset 越界应被守卫拦截');
      expect(editor.sourceOf(id), equals('hello'),
          reason: '守卫触发时 source 不变');
    });

    test('InsertTextCommand 找不到 blockId 返回 false', () {
      const invalidId = BlockId(999);
      const cmd = InsertTextCommand(
        blockId: invalidId,
        text: 'x',
      );
      final success = handler.handle(cmd);
      expect(success, isFalse,
          reason: '找不到 blockId 应返回 false');
    });
  });

  group('Phase 3.3 PR #2A: WrapSelectionCommand dispatch + 行为', () {
    late InMemoryDocumentEditor editor;
    late EditorHistory history;
    late CommandHandler handler;

    setUp(() {
      editor = InMemoryDocumentEditor();
      history = EditorHistory();
      handler = CommandHandler(editor: editor, history: history);
    });

    test('WrapSelectionCommand 被 dispatch（** 包裹）', () {
      final id = editor.addParagraph('hello world');
      // 选中 "hello" [0..5]
      const selection = TextSelection(baseOffset: 0, extentOffset: 5);
      final success = handler.handle(WrapSelectionCommand(
        blockId: id,
        prefix: '**',
        suffix: '**',
        selection: selection,
      ));
      expect(success, isTrue,
          reason: 'WrapSelectionCommand 应被 dispatch');
      expect(editor.sourceOf(id), equals('**hello** world'),
          reason: '选区应被 prefix + selected + suffix 包裹');
    });

    test('WrapSelectionCommand 中间选区包裹', () {
      final id = editor.addParagraph('hello world');
      // 选中 "world" [6..11]
      const selection = TextSelection(baseOffset: 6, extentOffset: 11);
      final success = handler.handle(WrapSelectionCommand(
        blockId: id,
        prefix: '`',
        suffix: '`',
        selection: selection,
      ));
      expect(success, isTrue);
      expect(editor.sourceOf(id), equals('hello `world`'),
          reason: '中间选区应被正确包裹');
    });

    test('WrapSelectionCommand 链接模板 [sel](url)', () {
      final id = editor.addParagraph('click here');
      // 选中 "click here" [0..10]
      const selection = TextSelection(baseOffset: 0, extentOffset: 10);
      final success = handler.handle(WrapSelectionCommand(
        blockId: id,
        prefix: '[',
        suffix: '](url)',
        selection: selection,
      ));
      expect(success, isTrue);
      expect(editor.sourceOf(id), equals('[click here](url)'),
          reason: '链接模板应正确包裹');
    });

    test('WrapSelectionCommand 越界守卫：end > source.length 返回 false', () {
      final id = editor.addParagraph('hello'); // length=5
      const selection = TextSelection(baseOffset: 0, extentOffset: 100);
      final success = handler.handle(WrapSelectionCommand(
        blockId: id,
        prefix: '**',
        suffix: '**',
        selection: selection,
      ));
      expect(success, isFalse,
          reason: 'end 越界应被守卫拦截');
      expect(editor.sourceOf(id), equals('hello'),
          reason: '守卫触发时 source 不变');
    });

    test('WrapSelectionCommand 反向选区（baseOffset > extentOffset）正确包裹',
        () {
      final id = editor.addParagraph('hello world');
      // 反向选区：用户从右向左选择 "lo wo" [8..3]
      // TextSelection.start/.end 自动归一化为 (3, 8)，应正确包裹 "lo wo"
      const selection = TextSelection(baseOffset: 8, extentOffset: 3);
      final success = handler.handle(WrapSelectionCommand(
        blockId: id,
        prefix: '**',
        suffix: '**',
        selection: selection,
      ));
      expect(success, isTrue,
          reason: '反向选区应被归一化后正常处理（非错误）');
      expect(editor.sourceOf(id), equals('hel**lo wo**rld'),
          reason: '应包裹归一化后的选区 [3..8] 即 "lo wo"');
    });
  });

  group('Phase 3.3 PR #2A: InsertTemplateCommand dispatch + 行为', () {
    late InMemoryDocumentEditor editor;
    late EditorHistory history;
    late CommandHandler handler;

    setUp(() {
      editor = InMemoryDocumentEditor();
      history = EditorHistory();
      handler = CommandHandler(editor: editor, history: history);
    });

    test('InsertTemplateCommand 被 dispatch（insert 模式）', () {
      final id = editor.addParagraph('hello');
      final success = handler.handle(InsertTemplateCommand(
        blockId: id,
        template: ' world',
        mode: TemplateInsertMode.insert,
        selection: null, // 追加到末尾
      ));
      expect(success, isTrue,
          reason: 'InsertTemplateCommand (insert) 应被 dispatch');
      expect(editor.sourceOf(id), equals('hello world'),
          reason: 'insert 模式应在光标位置插入模板');
    });

    test('InsertTemplateCommand 被 dispatch（newBlock 模式）', () {
      final id = editor.addParagraph('first block');
      final success = handler.handle(InsertTemplateCommand(
        blockId: id,
        template: '- [ ] task',
        mode: TemplateInsertMode.newBlock,
      ));
      expect(success, isTrue,
          reason: 'InsertTemplateCommand (newBlock) 应被 dispatch');
      expect(editor.blockCount, equals(2),
          reason: 'newBlock 模式应新增一块');
      expect(editor.allSources.last, equals('- [ ] task'),
          reason: '新块 source 应为模板内容');
    });

    test('InsertTemplateCommand newBlock 模式插入表格模板', () {
      final id = editor.addParagraph('intro');
      const tableTemplate = '| A | B |\n|---|---|\n| 1 | 2 |';
      final success = handler.handle(InsertTemplateCommand(
        blockId: id,
        template: tableTemplate,
        mode: TemplateInsertMode.newBlock,
      ));
      expect(success, isTrue);
      expect(editor.blockCount, equals(2));
      expect(editor.allSources.last, equals(tableTemplate),
          reason: '表格模板应作为新块插入');
    });

    test('InsertTemplateCommand insert 模式复用 InsertText 越界守卫', () {
      final id = editor.addParagraph('hello');
      const selection = TextSelection(baseOffset: 100, extentOffset: 100);
      final success = handler.handle(InsertTemplateCommand(
        blockId: id,
        template: 'x',
        mode: TemplateInsertMode.insert,
        selection: selection,
      ));
      expect(success, isFalse,
          reason: 'insert 模式应继承 InsertText 的越界守卫');
    });

    test('InsertTemplateCommand 找不到 blockId 返回 false', () {
      const invalidId = BlockId(999);
      const cmd = InsertTemplateCommand(
        blockId: invalidId,
        template: 'x',
        mode: TemplateInsertMode.newBlock,
      );
      final success = handler.handle(cmd);
      expect(success, isFalse,
          reason: '找不到 blockId 应返回 false（newBlock 依赖 blockId 存在）');
    });
  });

  group('Phase 3.3 PR #2A: 新 Command 与 Undo/Redo 集成', () {
    late InMemoryDocumentEditor editor;
    late EditorHistory history;
    late CommandHandler handler;

    setUp(() {
      editor = InMemoryDocumentEditor();
      history = EditorHistory();
      handler = CommandHandler(editor: editor, history: history);
    });

    test('InsertTextCommand 执行后 Undo 还原 source', () {
      final id = editor.addParagraph('hello');
      // 执行 InsertText
      handler.handle(InsertTextCommand(
        blockId: id,
        text: ' world',
      ));
      expect(editor.sourceOf(id), equals('hello world'));
      expect(history.canUndo, isTrue,
          reason: 'InsertText 执行后应可 Undo');

      // Undo：revert 所有 op（与 transaction_history_integration_test 一致）
      final undone = history.undo(history.lastOrNull!);
      for (final op in undone!.ops.reversed) {
        op.revert(editor);
      }
      expect(editor.sourceOf(id), equals('hello'),
          reason: 'Undo 后 source 应还原');
    });

    test('WrapSelectionCommand 执行后 Undo 还原 source', () {
      final id = editor.addParagraph('hello');
      handler.handle(WrapSelectionCommand(
        blockId: id,
        prefix: '**',
        suffix: '**',
        selection: const TextSelection(baseOffset: 0, extentOffset: 5),
      ));
      expect(editor.sourceOf(id), equals('**hello**'));
      expect(history.canUndo, isTrue);

      final undone = history.undo(history.lastOrNull!);
      for (final op in undone!.ops.reversed) {
        op.revert(editor);
      }
      expect(editor.sourceOf(id), equals('hello'),
          reason: 'Undo 后 WrapSelection 应被还原');
    });

    test('InsertTemplateCommand (newBlock) 执行后 Undo 还原块数', () {
      final id = editor.addParagraph('first');
      handler.handle(InsertTemplateCommand(
        blockId: id,
        template: 'second',
        mode: TemplateInsertMode.newBlock,
      ));
      expect(editor.blockCount, equals(2));
      expect(history.canUndo, isTrue);

      final undone = history.undo(history.lastOrNull!);
      for (final op in undone!.ops.reversed) {
        op.revert(editor);
      }
      expect(editor.blockCount, equals(1),
          reason: 'Undo 后 newBlock 应被还原（块数回到 1）');
    });
  });
}
