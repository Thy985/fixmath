/// R4 自省测试：验证所有 [EditorCommand] 子类都有对应的 `_handle*` 分支。
///
/// 落地 PR 评审 R4（Phase 2.9 PR review）+ ADR-0009 §3.2。
///
/// **背景**：`CommandHandler._dispatch` 使用 if-else 链分派（因 [EditorCommand]
/// 非 sealed，编译器不强制穷举）。若新增 [EditorCommand] 子类时忘记在
/// `_dispatch` 添加分支，会静默返回 false（无编译错误、无运行时异常）。
///
/// **守门策略**：本测试为每个 [EditorCommand] 子类构造一个**应成功**的场景，
/// 调用 `handler.handle(command)` 并验证：
/// 1. 返回 true（dispatch 命中对应分支）
/// 2. Editor 状态发生预期变化（实际执行了 op，而非 dispatch 静默失败）
///
/// **Phase 3.0 升级路径**（详见 command_handler.dart doc comment）：
/// 将 [EditorCommand] 转为 sealed class，改用 switch 表达式强制穷举，
/// 本测试可简化为编译期保证（仅需检查 switch 是否 exhaustive）。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:formula_fix/core/editing/editor_history.dart';
import 'package:formula_fix/data/models/document.dart';
import 'package:formula_fix/presentation/commands/command_handler.dart';
import 'package:formula_fix/presentation/commands/commands.dart';
import 'package:formula_fix/presentation/commands/editor_command.dart';
import 'package:formula_fix/presentation/prototype/_shared/in_memory_document_editor.dart';

void main() {
  group('R4 自省：所有 EditorCommand 子类都有对应 _handle* 分支', () {
    late InMemoryDocumentEditor editor;
    late EditorHistory history;
    late CommandHandler handler;

    setUp(() {
      editor = InMemoryDocumentEditor();
      history = EditorHistory();
      handler = CommandHandler(editor: editor, history: history);
    });

    test('SplitBlockCommand 被 dispatch', () {
      final id = editor.addParagraph('hello world');
      final success = handler.handle(SplitBlockCommand(
        blockId: id,
        offset: 5,
        origin: CommandOrigin.keyboard,
      ));
      expect(success, isTrue,
          reason: 'SplitBlockCommand 应被 dispatch（否则 _dispatch 漏了分支）');
      expect(editor.blockCount, equals(2),
          reason: 'dispatch 成功后块数应从 1 变为 2');
    });

    test('MergeWithPreviousCommand 被 dispatch', () {
      editor.addParagraph('hello ');
      final id2 = editor.addParagraph('world');
      final success = handler.handle(MergeWithPreviousCommand(
        blockId: id2,
        origin: CommandOrigin.keyboard,
      ));
      expect(success, isTrue,
          reason: 'MergeWithPreviousCommand 应被 dispatch');
      expect(editor.blockCount, equals(1),
          reason: 'dispatch 成功后块数应从 2 变为 1（id2 合并到 id1）');
    });

    test('InsertBlockAfterCommand 被 dispatch', () {
      final id = editor.addParagraph('hello');
      final success = handler.handle(InsertBlockAfterCommand(
        blockId: id,
        element: ParagraphElement(children: [TextElement('')]),
        origin: CommandOrigin.keyboard,
      ));
      expect(success, isTrue,
          reason: 'InsertBlockAfterCommand 应被 dispatch');
      expect(editor.blockCount, equals(2),
          reason: 'dispatch 成功后块数应从 1 变为 2');
    });

    test('DeleteBlockCommand 被 dispatch', () {
      final id1 = editor.addParagraph('hello');
      editor.addParagraph('world');
      final success = handler.handle(DeleteBlockCommand(
        blockId: id1,
        origin: CommandOrigin.keyboard,
      ));
      expect(success, isTrue,
          reason: 'DeleteBlockCommand 应被 dispatch');
      expect(editor.blockCount, equals(1),
          reason: 'dispatch 成功后块数应从 2 变为 1');
    });

    test('MoveBlockUpCommand 被 dispatch', () {
      editor.addParagraph('hello');
      final id2 = editor.addParagraph('world');
      final success = handler.handle(MoveBlockUpCommand(
        blockId: id2,
        origin: CommandOrigin.keyboard,
      ));
      expect(success, isTrue,
          reason: 'MoveBlockUpCommand 应被 dispatch');
      // 块数不变，但顺序变了：world 应在前
      expect(editor.blockCount, equals(2));
      expect(editor.allSources.first, equals('world'),
          reason: 'id2 上移后应在第一位');
    });

    test('MoveBlockDownCommand 被 dispatch', () {
      final id1 = editor.addParagraph('hello');
      editor.addParagraph('world');
      final success = handler.handle(MoveBlockDownCommand(
        blockId: id1,
        origin: CommandOrigin.keyboard,
      ));
      expect(success, isTrue,
          reason: 'MoveBlockDownCommand 应被 dispatch');
      expect(editor.blockCount, equals(2));
      expect(editor.allSources.last, equals('hello'),
          reason: 'id1 下移后应在最后一位');
    });

    test('UpdateBlockSourceCommand 被 dispatch', () {
      final id = editor.addParagraph('hello');
      final success = handler.handle(UpdateBlockSourceCommand(
        blockId: id,
        newSource: 'updated',
        origin: CommandOrigin.keyboard,
      ));
      expect(success, isTrue,
          reason: 'UpdateBlockSourceCommand 应被 dispatch');
      expect(editor.sourceOf(id), equals('updated'),
          reason: 'dispatch 成功后 source 应被替换');
    });

    test('TransformBlockCommand 被 dispatch', () {
      final id = editor.addParagraph('# Title');
      final success = handler.handle(TransformBlockCommand(
        blockId: id,
        origin: CommandOrigin.keyboard,
      ));
      expect(success, isTrue,
          reason: 'TransformBlockCommand 应被 dispatch');
      expect(editor.getBlock(id), isA<HeadingElement>(),
          reason: 'dispatch 成功后 ParagraphElement 应被 transform 为 HeadingElement');
    });
  });

  // Phase 3.3 PR #2A 新增的 4 个测试组（InsertTextCommand / WrapSelectionCommand /
  // InsertTemplateCommand / Undo-Redo 集成）已拆分到
  // test/presentation/commands/command_handler_pr2a_test.dart（AGENTS.md §1.2）。

  group('R4 守卫测试：_handle* 方法的边界守卫', () {
    late InMemoryDocumentEditor editor;
    late EditorHistory history;
    late CommandHandler handler;

    setUp(() {
      editor = InMemoryDocumentEditor();
      history = EditorHistory();
      handler = CommandHandler(editor: editor, history: history);
    });

    test('MergeWithPreviousCommand 首块守卫：返回 false 且块数不变', () {
      final id1 = editor.addParagraph('only one');
      final success = handler.handle(MergeWithPreviousCommand(
        blockId: id1,
        origin: CommandOrigin.keyboard,
      ));
      expect(success, isFalse,
          reason: '首块无法 merge，应被 _handleMerge 守卫拦截');
      expect(editor.blockCount, equals(1),
          reason: '守卫触发时块数不变');
    });

    test('MoveBlockUpCommand 首块守卫：返回 false 且顺序不变', () {
      final id1 = editor.addParagraph('first');
      editor.addParagraph('second');
      final success = handler.handle(MoveBlockUpCommand(
        blockId: id1,
        origin: CommandOrigin.keyboard,
      ));
      expect(success, isFalse,
          reason: '首块无法上移，应被 _handleMoveUp 守卫拦截');
      expect(editor.allSources, equals(['first', 'second']),
          reason: '守卫触发时顺序不变');
    });

    test('MoveBlockDownCommand 末块守卫：返回 false 且顺序不变', () {
      editor.addParagraph('first');
      final id2 = editor.addParagraph('last');
      final success = handler.handle(MoveBlockDownCommand(
        blockId: id2,
        origin: CommandOrigin.keyboard,
      ));
      expect(success, isFalse,
          reason: '末块无法下移，应被 _handleMoveDown 守卫拦截');
      expect(editor.allSources, equals(['first', 'last']),
          reason: '守卫触发时顺序不变');
    });

    test('DeleteBlockCommand 单块守卫：返回 false 且块数不变', () {
      // BlockOperations.delete 的守卫：blockCount <= 1 时返回 false
      final id1 = editor.addParagraph('only');
      final success = handler.handle(DeleteBlockCommand(
        blockId: id1,
        origin: CommandOrigin.keyboard,
      ));
      expect(success, isFalse,
          reason: '单块无法删除，应被 BlockOperations.delete 守卫拦截');
      expect(editor.blockCount, equals(1),
          reason: '守卫触发时块数不变');
    });
  });
}
