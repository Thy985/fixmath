/// EditorCoordinator 单元测试：Phase 3.3 PR #1 chrome 接线。
///
/// 落地 Phase 3.3 Task Contract §3.3.1 + §3.3.4 + §3.3.5 + ADR-0011 §4。
///
/// **覆盖范围**：
/// - title：默认值、构造注入、setter（透传 InMemoryDocumentEditor）
/// - wordCount：空文档、单块、多块（透传 allSources 求和）
/// - isDirty：初始 false、mutating 操作后 true、markSaved 后 false
/// - undo/redo：canUndo/canRedo 状态切换、undo 还原内容与 wordCount、redo 重放
///
/// **不在范围**：
/// - CommandHandler dispatch 路径细节（见 command_handler_dispatch_test.dart）
/// - InMemoryDocumentEditor CRUD（见 prototype/_shared/in_memory_document_editor_test.dart）
/// - UI Widget 渲染（见 test/architecture/ui_*_test.dart）
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:formula_fix/core/editing/block_types.dart';
import 'package:formula_fix/core/editing/editor_history.dart';
import 'package:formula_fix/data/models/document.dart';
import 'package:formula_fix/presentation/commands/commands.dart';
import 'package:formula_fix/presentation/commands/editor_command.dart';
import 'package:formula_fix/presentation/editor/editor_coordinator.dart';
import 'package:formula_fix/presentation/editor/in_memory_document_editor.dart';

void main() {
  late InMemoryDocumentEditor editor;
  late EditorHistory history;
  late EditorCoordinator coordinator;

  setUp(() {
    editor = InMemoryDocumentEditor();
    history = EditorHistory();
    coordinator = EditorCoordinator(editor: editor, history: history);
  });

  group('Phase 3.3 §3.3.1 title', () {
    test('默认值为 "未命名"', () {
      expect(coordinator.title, equals('未命名'));
    });

    test('构造时注入 custom title 并透传', () {
      final customEditor = InMemoryDocumentEditor(title: '我的笔记');
      final customCoordinator = EditorCoordinator(
        editor: customEditor,
        history: EditorHistory(),
      );
      expect(customCoordinator.title, equals('我的笔记'));
    });

    test('editor.title setter 修改后 coordinator.title 同步反映', () {
      editor.title = '新标题';
      expect(coordinator.title, equals('新标题'));
    });
  });

  group('Phase 3.3 §3.3.4 wordCount', () {
    test('空文档 wordCount == 0', () {
      expect(coordinator.wordCount, equals(0));
    });

    test('单块 paragraph wordCount 等于 source 长度', () {
      editor.addParagraph('hello');
      // 'hello' 长度 5
      expect(coordinator.wordCount, equals(5));
    });

    test('多块拼接 wordCount 等于各块 source 长度之和', () {
      editor.addParagraph('hello'); // 5
      editor.addBlock('# 标题', BlockType.heading); // '# 标题' = 4
      editor.addParagraph('世界'); // 2
      expect(coordinator.wordCount, equals(5 + 4 + 2));
    });

    test('删除块后 wordCount 同步递减', () {
      final id = editor.addParagraph('hello'); // 5
      expect(coordinator.wordCount, equals(5));
      editor.removeBlock(id);
      expect(coordinator.wordCount, equals(0));
    });
  });

  group('Phase 3.3 §3.3.1 + ADR-0011 §4 isDirty', () {
    test('初始构造 isDirty == false', () {
      expect(coordinator.isDirty, isFalse,
          reason: '空 editor 不应标记 dirty');
    });

    test('markSaved 后 isDirty == false', () {
      editor.addParagraph('hello');
      expect(coordinator.isDirty, isTrue);
      coordinator.markSaved();
      expect(coordinator.isDirty, isFalse);
    });

    test('insertBlock 后 isDirty == true', () {
      editor.insertBlock(0, const ParagraphElement(children: [TextElement('x')]));
      expect(coordinator.isDirty, isTrue);
    });

    test('removeBlock 后 isDirty == true', () {
      final id = editor.addParagraph('hello');
      coordinator.markSaved();
      expect(coordinator.isDirty, isFalse);
      editor.removeBlock(id);
      expect(coordinator.isDirty, isTrue);
    });

    test('replaceBlock 后 isDirty == true', () {
      final id = editor.addParagraph('old');
      coordinator.markSaved();
      expect(coordinator.isDirty, isFalse);
      editor.replaceBlock(
          id, const ParagraphElement(children: [TextElement('new')]));
      expect(coordinator.isDirty, isTrue);
    });

    test('updateBlockContent 后 isDirty == true', () {
      final id = editor.addParagraph('old');
      coordinator.markSaved();
      expect(coordinator.isDirty, isFalse);
      editor.updateBlockContent(
          id, const ParagraphElement(children: [TextElement('new')]));
      expect(coordinator.isDirty, isTrue);
    });

    test('SeedDocuments 初始化后 isDirty == false（markSaved 已调用）', () {
      // 模拟 SeedDocuments.createDemo1 流程
      final demoEditor = InMemoryDocumentEditor(title: 'FormulaFix Demo');
      demoEditor.addBlock('# FormulaFix Demo', BlockType.heading);
      demoEditor.addParagraph('Hello, Block Editor!');
      demoEditor.markSaved();
      final demoCoordinator = EditorCoordinator(
        editor: demoEditor,
        history: EditorHistory(),
      );
      expect(demoCoordinator.isDirty, isFalse,
          reason: '种子文档应视为已保存的初始状态');
    });
  });

  group('Phase 3.3 §3.3.5 undo/redo', () {
    test('初始 canUndo == false 且 canRedo == false', () {
      expect(coordinator.canUndo, isFalse);
      expect(coordinator.canRedo, isFalse);
    });

    test('handle 成功后 canUndo == true 且 canRedo == false', () {
      final id = editor.addParagraph('hello');
      // 注意：addParagraph 直接走 editor，未入栈 history
      expect(coordinator.canUndo, isFalse,
          reason: '直接 editor.addParagraph 不入 history 栈');

      final ok = coordinator.handle(InsertBlockAfterCommand(
        blockId: id,
        element: const ParagraphElement(children: [TextElement('new')]),
        origin: CommandOrigin.keyboard,
      ));
      expect(ok, isTrue);
      expect(coordinator.canUndo, isTrue,
          reason: 'handle 成功后应可撤销');
      expect(coordinator.canRedo, isFalse);
    });

    test('undo 还原内容并减少 wordCount', () {
      final id = editor.addParagraph('hello'); // wordCount=5
      coordinator.markSaved();
      expect(coordinator.wordCount, equals(5));

      // 通过 handle 插入新块（入栈 history）
      coordinator.handle(InsertBlockAfterCommand(
        blockId: id,
        element: const ParagraphElement(children: [TextElement(' world')]),
        origin: CommandOrigin.keyboard,
      ));
      expect(coordinator.blockCount, equals(2));
      expect(coordinator.wordCount, equals(5 + 6)); // 'hello' + ' world'

      final tx = coordinator.undo();
      expect(tx, isNotNull, reason: 'undo 应返回被撤销的 Transaction');
      expect(coordinator.blockCount, equals(1),
          reason: 'undo 后插入的块应被移除');
      expect(coordinator.wordCount, equals(5),
          reason: 'undo 后 wordCount 应回到 undo 前的值');
    });

    test('undo 后 canRedo == true（栈管理正确）', () {
      final id = editor.addParagraph('hello');
      coordinator.handle(InsertBlockAfterCommand(
        blockId: id,
        element: const ParagraphElement(children: [TextElement('x')]),
        origin: CommandOrigin.keyboard,
      ));
      expect(coordinator.blockCount, equals(2));

      coordinator.undo();
      expect(coordinator.canRedo, isTrue, reason: 'undo 后应可重做');
      expect(coordinator.blockCount, equals(1));
    });

    // R2 Prototype 限制（见 editor_coordinator.dart:153-156 doc + 
    // command_handler_test.dart:201-239 同类测试）：
    // `currentState` 使用空 Transaction，redo 栈中保存的是空 Transaction，
    // redo() 返回非 null 但 ops 为空，不会实际恢复 editor 状态。
    // Phase 3.0+ 需 state snapshot 机制修复。
    test('R2 Prototype 限制：redo 不实际恢复 editor 状态（已知 tech debt）', () {
      final id = editor.addParagraph('hello');
      coordinator.handle(InsertBlockAfterCommand(
        blockId: id,
        element: const ParagraphElement(children: [TextElement('x')]),
        origin: CommandOrigin.keyboard,
      ));
      final countBeforeUndo = coordinator.blockCount; // 2
      coordinator.undo();
      expect(coordinator.blockCount, equals(countBeforeUndo - 1),
          reason: 'undo 应移除插入的块');
      expect(coordinator.canRedo, isTrue);

      final redoneTx = coordinator.redo();
      // redo 返回非 null（栈非空），但实际是空 Transaction
      expect(redoneTx, isNotNull,
          reason: 'redo 栈非空应返回 Transaction');
      expect(redoneTx!.ops, isEmpty,
          reason: 'R2 限制：redo 栈中是空 Transaction（currentState 被推入）');
      // 关键验证：redo 没有实际恢复 editor 状态（blockCount 仍是 undo 后的值）
      expect(coordinator.blockCount, equals(countBeforeUndo - 1),
          reason: 'R2 限制：redo 未恢复块数（已知 tech debt，Phase 3.0+ 修复）');
      // 但 canUndo/canRedo 标志本身正确（栈管理无误）
      expect(coordinator.canUndo, isTrue,
          reason: '空 Tx 已被推入 undo 栈（栈管理正确）');
      expect(coordinator.canRedo, isFalse);
    });

    test('UpdateBlockSourceCommand 走 handle 后可 undo 还原 source', () {
      final id = editor.addParagraph('hello');
      coordinator.markSaved();
      final originalWordCount = coordinator.wordCount;

      coordinator.handle(UpdateBlockSourceCommand(
        blockId: id,
        newSource: 'hello world',
        origin: CommandOrigin.keyboard,
      ));
      expect(coordinator.wordCount, equals(11),
          reason: '更新后 wordCount 应反映新 source');
      expect(coordinator.isDirty, isTrue);

      coordinator.undo();
      expect(coordinator.wordCount, equals(originalWordCount),
          reason: 'undo 后 wordCount 应回到原值');
    });

    test('handle 返回 false 时不入栈（canUndo 不变）', () {
      final id = editor.addParagraph('hello');
      // MergeWithPreviousCommand 在第一块时返回 false（currentIndex <= 0）
      final ok = coordinator.handle(MergeWithPreviousCommand(
        blockId: id,
        origin: CommandOrigin.keyboard,
      ));
      expect(ok, isFalse, reason: '第一块无法与前一块合并');
      expect(coordinator.canUndo, isFalse,
          reason: 'handle 失败不应入 history 栈');
    });
  });
}
