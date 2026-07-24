/// 自动配对规则单元测试：Phase 3.3 PR #3。
///
/// 落地 Task Contract v1.1 §5.1。
///
/// **覆盖范围**：
/// - 4 种配对符触发检测（`(` / `[` / `{` / `` ` ``）
/// - 非配对符不触发（`*` / `$` / `#` / 普通字符）
/// - 有选区时不触发（wrapSelection 留 Phase 3.4+）
/// - 删除 / 粘贴多字符不触发
/// - insertOffset + cursorOffset 正确性
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:formula_fix/core/editing/block_types.dart';
import 'package:formula_fix/presentation/blocks/input/auto_pair_rules.dart';
import 'package:formula_fix/presentation/commands/commands.dart';

void main() {
  const blockId = BlockId(1);

  /// 构造 oldValue（光标在末尾的空文本或指定文本）。
  TextEditingValue oldValueWith(String text, {int? cursor}) =>
      TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: cursor ?? text.length),
      );

  /// 模拟用户在光标位置输入 1 个字符。
  TextEditingValue typeChar(String text, String ch, {int? cursor}) {
    final pos = cursor ?? text.length;
    final newText = text.substring(0, pos) + ch + text.substring(pos);
    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: pos + 1),
    );
  }

  group('AutoPairRules.detect — 4 种配对符', () {
    test('输入 ( → 返回 PairInsertCommand(suffix=)), cursorOffset=-1)', () {
      final oldVal = oldValueWith('hello');
      final newVal = typeChar('hello', '(');
      final cmd = AutoPairRules.detect(
          newValue: newVal, oldValue: oldVal, blockId: blockId);

      expect(cmd, isNotNull);
      expect(cmd!.suffixChar, ')');
      expect(cmd.insertOffset, 6); // 光标在 '(' 之后
      expect(cmd.cursorOffset, -1); // 光标前移 1（在 '()' 中间）
      expect(cmd.mode, PairInsertMode.appendAfterCursor);
      expect(cmd.blockId, blockId);
    });

    test('输入 [ → 返回 PairInsertCommand(suffix=])', () {
      final oldVal = oldValueWith('');
      final newVal = typeChar('', '[');
      final cmd = AutoPairRules.detect(
          newValue: newVal, oldValue: oldVal, blockId: blockId);

      expect(cmd, isNotNull);
      expect(cmd!.suffixChar, ']');
      expect(cmd.insertOffset, 1);
      expect(cmd.cursorOffset, -1);
    });

    test('输入 { → 返回 PairInsertCommand(suffix=})', () {
      final oldVal = oldValueWith('abc');
      final newVal = typeChar('abc', '{');
      final cmd = AutoPairRules.detect(
          newValue: newVal, oldValue: oldVal, blockId: blockId);

      expect(cmd, isNotNull);
      expect(cmd!.suffixChar, '}');
      expect(cmd.insertOffset, 4);
      expect(cmd.cursorOffset, -1);
    });

    test('输入 ` → 返回 PairInsertCommand(suffix=`)', () {
      final oldVal = oldValueWith('code');
      final newVal = typeChar('code', '`');
      final cmd = AutoPairRules.detect(
          newValue: newVal, oldValue: oldVal, blockId: blockId);

      expect(cmd, isNotNull);
      expect(cmd!.suffixChar, '`');
      expect(cmd.insertOffset, 5);
      expect(cmd.cursorOffset, -1);
    });
  });

  group('AutoPairRules.detect — 不触发场景', () {
    test('有选区时 → 返回 null（wrapSelection 留 Phase 3.4+）', () {
      final oldVal = TextEditingValue(
        text: 'hello',
        selection: const TextSelection(baseOffset: 0, extentOffset: 5),
      );
      final newVal = TextEditingValue(
        text: '(',
        selection: const TextSelection.collapsed(offset: 1),
      );
      final cmd = AutoPairRules.detect(
          newValue: newVal, oldValue: oldVal, blockId: blockId);

      expect(cmd, isNull);
    });

    test('输入 * → 返回 null（v1.3 禁止语义字符配对）', () {
      final oldVal = oldValueWith('');
      final newVal = typeChar('', '*');
      final cmd = AutoPairRules.detect(
          newValue: newVal, oldValue: oldVal, blockId: blockId);

      expect(cmd, isNull);
    });

    test(r'输入 $ → 返回 null', () {
      final oldVal = oldValueWith('');
      final newVal = typeChar('', r'$');
      final cmd = AutoPairRules.detect(
          newValue: newVal, oldValue: oldVal, blockId: blockId);

      expect(cmd, isNull);
    });

    test('输入 # → 返回 null', () {
      final oldVal = oldValueWith('');
      final newVal = typeChar('', '#');
      final cmd = AutoPairRules.detect(
          newValue: newVal, oldValue: oldVal, blockId: blockId);

      expect(cmd, isNull);
    });

    test('输入普通字符 a → 返回 null', () {
      final oldVal = oldValueWith('');
      final newVal = typeChar('', 'a');
      final cmd = AutoPairRules.detect(
          newValue: newVal, oldValue: oldVal, blockId: blockId);

      expect(cmd, isNull);
    });

    test('删除字符（text 变短）→ 返回 null', () {
      final oldVal = oldValueWith('hello');
      final newVal = TextEditingValue(
        text: 'hell',
        selection: const TextSelection.collapsed(offset: 4),
      );
      final cmd = AutoPairRules.detect(
          newValue: newVal, oldValue: oldVal, blockId: blockId);

      expect(cmd, isNull);
    });

    test('粘贴多字符（text 增加超过 1）→ 返回 null', () {
      final oldVal = oldValueWith('');
      final newVal = TextEditingValue(
        text: '((',
        selection: const TextSelection.collapsed(offset: 2),
      );
      final cmd = AutoPairRules.detect(
          newValue: newVal, oldValue: oldVal, blockId: blockId);

      expect(cmd, isNull);
    });
  });

  group('AutoPairRules.detect — insertOffset + cursorOffset 正确性', () {
    test('在文本中间输入 ( → insertOffset = 光标位置', () {
      final oldVal = oldValueWith('hello', cursor: 2); // he|llo
      final newVal = typeChar('hello', '(', cursor: 2); // he(|llo
      final cmd = AutoPairRules.detect(
          newValue: newVal, oldValue: oldVal, blockId: blockId);

      expect(cmd, isNotNull);
      expect(cmd!.insertOffset, 3); // 光标在 '(' 之后 = position 3
      expect(cmd.cursorOffset, -1);
    });

    test('在文本开头输入 [ → insertOffset = 1', () {
      final oldVal = oldValueWith('world', cursor: 0);
      final newVal = typeChar('world', '[', cursor: 0);
      final cmd = AutoPairRules.detect(
          newValue: newVal, oldValue: oldVal, blockId: blockId);

      expect(cmd, isNotNull);
      expect(cmd!.insertOffset, 1);
    });

    test('cursorOffset = -suffix.length（光标在配对符中间）', () {
      final oldVal = oldValueWith('');
      final newVal = typeChar('', '(');
      final cmd = AutoPairRules.detect(
          newValue: newVal, oldValue: oldVal, blockId: blockId);

      expect(cmd, isNotNull);
      // 光标位置 = insertOffset + suffixChar.length + cursorOffset
      // = 1 + 1 + (-1) = 1（在 '(' 和 ')' 之间）
      final cursorPos =
          cmd!.insertOffset + cmd.suffixChar.length + cmd.cursorOffset;
      expect(cursorPos, 1);
    });
  });
}
