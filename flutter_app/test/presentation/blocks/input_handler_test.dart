/// InputHandler 单元测试：Phase 3.3 PR #3 Commit 5。
///
/// 落地 Task Contract v1.1 §2.6（BaseBlockState input handler 边界）。
///
/// **覆盖范围**（单 Command 策略 v1.1）：
/// - 自动配对触发：输入 '(' → coordinator 派发 UpdateBlockSourceCommand(source='()')
/// - 自动续列表触发：输入 "- item\n" → coordinator 派发 UpdateBlockSourceCommand(source='- item\n- ')
/// - 互斥性：一次 onChanged 只触发一个 Command
/// - 不触发场景：普通字符 / 普通文本 + 回车
/// - oldValue 正确性：首次输入 vs 后续输入
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:formula_fix/core/editing/block_types.dart';
import 'package:formula_fix/core/editing/editor_history.dart';
import 'package:formula_fix/presentation/blocks/input/input_handler.dart';
import 'package:formula_fix/presentation/editor/editor_coordinator.dart';
import 'package:formula_fix/presentation/editor/in_memory_document_editor.dart';

void main() {
  late InMemoryDocumentEditor editor;
  late EditorHistory history;
  late EditorCoordinator coordinator;
  late InputHandler handler;
  late BlockId blockId;

  setUp(() {
    editor = InMemoryDocumentEditor();
    history = EditorHistory();
    coordinator = EditorCoordinator(editor: editor, history: history);
    handler = InputHandler();
    blockId = editor.addParagraph('');
    coordinator.setFocus(blockId);
  });

  group('InputHandler.handle — 自动配对触发', () {
    test('输入 ( → coordinator 派发 PairInsertCommand, source 变为 "()"', () {
      // oldValue: 空文本,光标在 0
      const oldValue = TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
      // newValue: 输入 '(' 后,光标在 1
      const newValue = TextEditingValue(
        text: '(',
        selection: TextSelection.collapsed(offset: 1),
      );

      handler.handle(
        newValue: newValue,
        oldValue: oldValue,
        blockId: blockId,
        coordinator: coordinator,
      );

      // 验证 source 已变为 '()'（PairInsertCommand 在 insertOffset=1 追加 ')'）
      expect(coordinator.sourceOf(blockId), '()');
      // 验证 selection 同步：光标在 '(' 和 ')' 之间（offset 1）
      final sel = coordinator.viewStateOf(blockId)?.selection;
      expect(sel, isNotNull);
      expect(sel!.baseOffset, 1);
    });

    test('输入 [ → source 变为 "[]"', () {
      const oldValue = TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
      const newValue = TextEditingValue(
        text: '[',
        selection: TextSelection.collapsed(offset: 1),
      );

      handler.handle(
        newValue: newValue,
        oldValue: oldValue,
        blockId: blockId,
        coordinator: coordinator,
      );

      expect(coordinator.sourceOf(blockId), '[]');
    });
  });

  group('InputHandler.handle — 自动续列表触发', () {
    test('输入 "- item\\n" → source 变为 "- item\\n- "', () {
      // 模拟用户在 '- item' 末尾按回车
      const oldValue = TextEditingValue(
        text: '- item',
        selection: TextSelection.collapsed(offset: 6),
      );
      const newValue = TextEditingValue(
        text: '- item\n',
        selection: TextSelection.collapsed(offset: 7),
      );

      handler.handle(
        newValue: newValue,
        oldValue: oldValue,
        blockId: blockId,
        coordinator: coordinator,
      );

      // 验证 source 已追加续行前缀 '- '
      expect(coordinator.sourceOf(blockId), '- item\n- ');
      // 验证 selection 在新行末尾（offset = 9）
      final sel = coordinator.viewStateOf(blockId)?.selection;
      expect(sel, isNotNull);
      expect(sel!.baseOffset, 9);
    });

    test('输入 "1. item\\n" → source 变为 "1. item\\n2. "（编号递增）', () {
      const oldValue = TextEditingValue(
        text: '1. item',
        selection: TextSelection.collapsed(offset: 7),
      );
      const newValue = TextEditingValue(
        text: '1. item\n',
        selection: TextSelection.collapsed(offset: 8),
      );

      handler.handle(
        newValue: newValue,
        oldValue: oldValue,
        blockId: blockId,
        coordinator: coordinator,
      );

      expect(coordinator.sourceOf(blockId), '1. item\n2. ');
    });

    test('输入 "- \\n" → 退出续行（清除前缀）', () {
      // 模拟用户在空列表项 '- ' 后按回车 → 退出
      const oldValue = TextEditingValue(
        text: '- ',
        selection: TextSelection.collapsed(offset: 2),
      );
      const newValue = TextEditingValue(
        text: '- \n',
        selection: TextSelection.collapsed(offset: 3),
      );

      handler.handle(
        newValue: newValue,
        oldValue: oldValue,
        blockId: blockId,
        coordinator: coordinator,
      );

      // 退出时清除最后一行的前缀 → source 变为空字符串
      expect(coordinator.sourceOf(blockId), '');
    });
  });

  group('InputHandler.handle — 互斥性 + 不触发', () {
    test('输入普通字符 a → 不触发任何 Command', () {
      const oldValue = TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
      const newValue = TextEditingValue(
        text: 'a',
        selection: TextSelection.collapsed(offset: 1),
      );

      handler.handle(
        newValue: newValue,
        oldValue: oldValue,
        blockId: blockId,
        coordinator: coordinator,
      );

      // source 应保持为 ''（InputHandler 未派发任何 Command）
      // 注意：'a' 不是配对符,也不以 '\n' 结尾,所以不触发
      expect(coordinator.sourceOf(blockId), '');
      expect(coordinator.canUndo, isFalse);
    });

    test('输入普通文本 + 回车 "hello\\n" → 不触发续行', () {
      const oldValue = TextEditingValue(
        text: 'hello',
        selection: TextSelection.collapsed(offset: 5),
      );
      const newValue = TextEditingValue(
        text: 'hello\n',
        selection: TextSelection.collapsed(offset: 6),
      );

      handler.handle(
        newValue: newValue,
        oldValue: oldValue,
        blockId: blockId,
        coordinator: coordinator,
      );

      // 普通文本不匹配任何列表前缀 → 不触发
      expect(coordinator.sourceOf(blockId), '');
      expect(coordinator.canUndo, isFalse);
    });

    test('自动配对与续列表互斥（输入 ( 不触发续列表）', () {
      // 输入 '(' 应只触发 PairInsertCommand,不会误触发续列表
      const oldValue = TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
      const newValue = TextEditingValue(
        text: '(',
        selection: TextSelection.collapsed(offset: 1),
      );

      handler.handle(
        newValue: newValue,
        oldValue: oldValue,
        blockId: blockId,
        coordinator: coordinator,
      );

      // 单 Command 策略（§2.2 v1.1）：产生 1 个 undo 步骤
      // （UpdateBlockSourceCommand 携带最终 source '()'）
      expect(coordinator.canUndo, isTrue);
      expect(coordinator.canRedo, isFalse);
    });
  });

  group('InputHandler.handle — oldValue 边界', () {
    test('oldValue == newValue（无变化）→ 不触发配对', () {
      // 场景：首次调用时 _previousTextValue 为 null,oldValue = newValue
      // text 长度差为 0,AutoPairRules.detect 返回 null
      const value = TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );

      handler.handle(
        newValue: value,
        oldValue: value,
        blockId: blockId,
        coordinator: coordinator,
      );

      expect(coordinator.sourceOf(blockId), '');
      expect(coordinator.canUndo, isFalse);
    });

    test('有选区的 oldValue → 不触发配对（wrapSelection 留 Phase 3.4+）', () {
      const oldValue = TextEditingValue(
        text: 'hello',
        selection: TextSelection(baseOffset: 0, extentOffset: 5),
      );
      const newValue = TextEditingValue(
        text: '(',
        selection: TextSelection.collapsed(offset: 1),
      );

      handler.handle(
        newValue: newValue,
        oldValue: oldValue,
        blockId: blockId,
        coordinator: coordinator,
      );

      // oldValue 有选区 → AutoPairRules.detect 返回 null
      expect(coordinator.canUndo, isFalse);
    });
  });
}
