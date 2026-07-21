/// R3 _shared 层单元测试：CommandHandler 在 BlockEditorFacade 上下文中的行为。
///
/// 落地 PR 评审 R3（Phase 2.9 PR review）+ Phase 2.9 Task Contract §5.1。
///
/// **覆盖范围**（补充 [command_handler_dispatch_test.dart] 的 R4 自省测试）：
/// - [CommandOrigin] → [TransactionOrigin] 映射正确性
/// - `handle()` 成功后 Transaction 被 commit 并 push 到 [EditorHistory]
/// - [BlockEditorFacade] 聚合层的 undo / redo 行为（已知 Prototype 限制，见 R2）
///
/// **不在范围**：
/// - _dispatch 是否覆盖所有 EditorCommand 子类 → 见 [command_handler_dispatch_test.dart]
/// - _handle* 守卫逻辑 → 见 [command_handler_dispatch_test.dart]
/// - InMemoryDocumentEditor CRUD → 见 [in_memory_document_editor_test.dart]
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:formula_fix/core/editing/transaction.dart';
import 'package:formula_fix/presentation/commands/commands.dart';
import 'package:formula_fix/presentation/commands/editor_command.dart';
import 'package:formula_fix/presentation/prototype/_shared/block_editor_facade.dart';

void main() {
  group('R3 CommandHandler Transaction 生命周期', () {
    test('handle 成功后 Transaction 入 history 栈', () {
      final facade = BlockEditorFacade.empty();
      final id = facade.editor.addParagraph('hello');

      final ok = facade.handler.handle(UpdateBlockSourceCommand(
        blockId: id,
        newSource: 'updated',
        origin: CommandOrigin.keyboard,
      ));

      expect(ok, isTrue);
      expect(facade.canUndo, isTrue,
          reason: 'handle 成功后 Transaction 应 push 到 history');
      expect(facade.history.undoCount, equals(1));
    });

    test('handle 失败（守卫触发）不 push Transaction 到 history', () {
      final facade = BlockEditorFacade.empty();
      // 只有一块，merge 应被守卫拦截
      final id = facade.editor.allIds.first;

      final ok = facade.handler.handle(MergeWithPreviousCommand(
        blockId: id,
        origin: CommandOrigin.keyboard,
      ));

      expect(ok, isFalse);
      expect(facade.canUndo, isFalse,
          reason: '守卫失败时不应 push Transaction 到 history');
      expect(facade.history.undoCount, equals(0));
    });

    test('handle 成功后 Undo 可恢复 editor 状态', () {
      final facade = BlockEditorFacade.empty();
      final id = facade.editor.allIds.first;
      // 初始 source 是空字符串 ''
      expect(facade.sourceOf(id), equals(''));

      // 更新 source
      final ok = facade.handler.handle(UpdateBlockSourceCommand(
        blockId: id,
        newSource: 'hello',
        origin: CommandOrigin.keyboard,
      ));
      expect(ok, isTrue);
      expect(facade.sourceOf(id), equals('hello'));

      // Undo 应恢复到空 source
      final undoneTx = facade.undo();
      expect(undoneTx, isNotNull);
      expect(facade.sourceOf(id), equals(''),
          reason: 'Undo 后 source 应恢复为初始空字符串');
    });
  });

  group('R3 CommandOrigin → TransactionOrigin 映射', () {
    /// 验证映射规则的辅助函数：执行 command 后检查栈顶 Transaction.origin。
    ///
    /// 使用 [UpdateBlockSourceCommand]（始终成功，便于隔离 origin 验证）。
    TransactionOrigin originAfterHandle(
        BlockEditorFacade facade, CommandOrigin origin, String newSource) {
      final id = facade.editor.allIds.first;
      final ok = facade.handler.handle(UpdateBlockSourceCommand(
        blockId: id,
        newSource: newSource,
        origin: origin,
      ));
      expect(ok, isTrue, reason: 'UpdateBlockSourceCommand 应成功');
      final lastTx = facade.history.lastOrNull;
      expect(lastTx, isNotNull, reason: 'Transaction 应已 push');
      return lastTx!.origin;
    }

    test('keyboard → TransactionOrigin.keyboard', () {
      final facade = BlockEditorFacade.empty();
      // 先添加一个非空 source（避免空 source 与 'a' 类型相同时被判定无变化）
      final id = facade.editor.allIds.first;
      facade.handler.handle(UpdateBlockSourceCommand(
        blockId: id,
        newSource: 'init',
        origin: CommandOrigin.menu,
      ));
      // 第二次：keyboard origin（source 变化，会生成新 Transaction）
      final origin = originAfterHandle(facade, CommandOrigin.keyboard, 'a');
      expect(origin, equals(TransactionOrigin.keyboard));
    });

    test('ime → TransactionOrigin.ime', () {
      final facade = BlockEditorFacade.empty();
      final id = facade.editor.allIds.first;
      facade.handler.handle(UpdateBlockSourceCommand(
        blockId: id,
        newSource: 'init',
        origin: CommandOrigin.menu,
      ));
      final origin = originAfterHandle(facade, CommandOrigin.ime, '你好');
      expect(origin, equals(TransactionOrigin.ime));
    });

    test('ai → TransactionOrigin.programmatic', () {
      final facade = BlockEditorFacade.empty();
      final id = facade.editor.allIds.first;
      facade.handler.handle(UpdateBlockSourceCommand(
        blockId: id,
        newSource: 'init',
        origin: CommandOrigin.menu,
      ));
      final origin = originAfterHandle(facade, CommandOrigin.ai, 'ai-gen');
      expect(origin, equals(TransactionOrigin.programmatic));
    });

    test('voice → TransactionOrigin.programmatic', () {
      final facade = BlockEditorFacade.empty();
      final id = facade.editor.allIds.first;
      facade.handler.handle(UpdateBlockSourceCommand(
        blockId: id,
        newSource: 'init',
        origin: CommandOrigin.menu,
      ));
      final origin = originAfterHandle(facade, CommandOrigin.voice, 'voice');
      expect(origin, equals(TransactionOrigin.programmatic));
    });

    test('menu → TransactionOrigin.programmatic', () {
      final facade = BlockEditorFacade.empty();
      // 第一次 menu origin（source 变化触发 push）
      final origin = originAfterHandle(facade, CommandOrigin.menu, 'menu');
      expect(origin, equals(TransactionOrigin.programmatic));
    });

    test('gesture → TransactionOrigin.programmatic', () {
      final facade = BlockEditorFacade.empty();
      final id = facade.editor.allIds.first;
      facade.handler.handle(UpdateBlockSourceCommand(
        blockId: id,
        newSource: 'init',
        origin: CommandOrigin.menu,
      ));
      final origin = originAfterHandle(facade, CommandOrigin.gesture, 'gesture');
      expect(origin, equals(TransactionOrigin.programmatic));
    });
  });

  group('R3 BlockEditorFacade undo/redo Prototype 限制（R2 已标注）', () {
    test('undo 后 canRedo 应为 true', () {
      final facade = BlockEditorFacade.empty();
      final id = facade.editor.allIds.first;
      facade.handler.handle(UpdateBlockSourceCommand(
        blockId: id,
        newSource: 'changed',
        origin: CommandOrigin.keyboard,
      ));
      expect(facade.canUndo, isTrue);

      final undoneTx = facade.undo();
      expect(undoneTx, isNotNull);
      expect(facade.canRedo, isTrue,
          reason: 'Undo 后应可 Redo（redo 栈非空）');
      expect(facade.canUndo, isFalse);
    });

    test('undo 实际恢复 editor 状态', () {
      final facade = BlockEditorFacade.empty();
      final id = facade.editor.allIds.first;
      facade.handler.handle(UpdateBlockSourceCommand(
        blockId: id,
        newSource: 'changed',
        origin: CommandOrigin.keyboard,
      ));
      expect(facade.sourceOf(id), equals('changed'));

      facade.undo();

      expect(facade.sourceOf(id), equals(''),
          reason: 'Undo 应恢复 editor 状态到 source=""');
    });

    test('R2 Prototype 限制：redo 不实际恢复 editor 状态（已知 tech debt）', () {
      // 这个测试验证 R2 文档化的限制：
      // `BlockEditorFacade.undo/redo` 的 currentState 使用空 Transaction，
      // 导致 redo 栈中保存的是空 Transaction，redo 时无法恢复 editor 状态。
      //
      // 详细分析：
      // 1. Initial: source=''
      // 2. handle(UpdateSource('changed')) → source='changed', undoStack=[T1]
      // 3. undo(): currentState=空Tx, history.undo 推空Tx 入 redo 栈,
      //            pop T1, revert T1.ops → source=''
      // 4. redo(): currentState=空Tx, history.redo pop 空Tx (不是 T1！),
      //            apply 空Tx.ops (无 op) → source 保持 ''
      //
      // 即 redo → undo 链在第 2 步会丢失状态记录。
      // Phase 3.0 需实现完整 state snapshot 机制（capture + restore）。
      final facade = BlockEditorFacade.empty();
      final id = facade.editor.allIds.first;
      facade.handler.handle(UpdateBlockSourceCommand(
        blockId: id,
        newSource: 'changed',
        origin: CommandOrigin.keyboard,
      ));
      facade.undo();
      expect(facade.sourceOf(id), equals(''));
      expect(facade.canRedo, isTrue);

      final redoneTx = facade.redo();
      // Redo 返回非 null（栈非空），但实际是空 Transaction
      expect(redoneTx, isNotNull);
      expect(redoneTx!.ops, isEmpty,
          reason: 'R2 限制：redo 栈中是空 Transaction（currentState 被推入）');
      // 关键验证：redo 没有实际恢复 editor 状态（source 仍是空）
      expect(facade.sourceOf(id), equals(''),
          reason: 'R2 限制：redo 未恢复 source（已知 tech debt，Phase 3.0 修复）');
      // 但 canUndo/canRedo 标志本身正确（栈管理无误）
      expect(facade.canUndo, isTrue,
          reason: '空 Tx 已被推入 undo 栈（栈管理正确）');
      expect(facade.canRedo, isFalse);
    });
  });
}
