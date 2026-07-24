/// 自动续列表规则单元测试：Phase 3.3 PR #3。
///
/// 落地 Task Contract v1.1 §5.2。
///
/// **覆盖范围**：
/// - 5 种前缀触发续行（`- ` / `* ` / `1. ` / `> ` / `- [ ] `）
/// - 5 种前缀触发退出（空内容 + 回车）
/// - v1.1 P1-5：checkbox 优先于 `- `（不被抢先匹配）
/// - 有序列表编号递增（`1.` → `2.` / `10.` → `11.`）
/// - 不触发场景（普通文本 / 空 / 不以 `\n` 结尾 / 标题）
/// - 多行场景（倒数第二行前缀检测）
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:formula_fix/core/editing/block_types.dart';
import 'package:formula_fix/presentation/blocks/input/auto_continue_rules.dart';
import 'package:formula_fix/presentation/commands/commands.dart';

void main() {
  const blockId = BlockId(1);

  /// 模拟用户在 [source] 末尾按回车（IME 已提交 '\n'）。
  TextEditingValue pressEnter(String source) => TextEditingValue(
        text: '$source\n',
        selection: TextSelection.collapsed(offset: source.length + 1),
      );

  group('AutoContinueRules.detect — 5 种前缀触发续行', () {
    test('- item + 回车 → 续行 "- "', () {
      final cmd = AutoContinueRules.detect(
        newValue: pressEnter('- item'),
        blockId: blockId,
      );

      expect(cmd, isNotNull);
      expect(cmd!.prefix, '- ');
      expect(cmd.isExit, isFalse);
      expect(cmd.blockId, blockId);
    });

    test('* item + 回车 → 续行 "* "', () {
      final cmd = AutoContinueRules.detect(
        newValue: pressEnter('* item'),
        blockId: blockId,
      );

      expect(cmd, isNotNull);
      expect(cmd!.prefix, '* ');
      expect(cmd.isExit, isFalse);
    });

    test('1. item + 回车 → 续行 "2. "（编号 +1）', () {
      final cmd = AutoContinueRules.detect(
        newValue: pressEnter('1. item'),
        blockId: blockId,
      );

      expect(cmd, isNotNull);
      expect(cmd!.prefix, '2. ');
      expect(cmd.isExit, isFalse);
    });

    test('> quote + 回车 → 续行 "> "', () {
      final cmd = AutoContinueRules.detect(
        newValue: pressEnter('> quote'),
        blockId: blockId,
      );

      expect(cmd, isNotNull);
      expect(cmd!.prefix, '> ');
      expect(cmd.isExit, isFalse);
    });

    test('- [ ] task + 回车 → 续行 "- [ ] "', () {
      final cmd = AutoContinueRules.detect(
        newValue: pressEnter('- [ ] task'),
        blockId: blockId,
      );

      expect(cmd, isNotNull);
      expect(cmd!.prefix, '- [ ] ');
      expect(cmd.isExit, isFalse);
    });
  });

  group('AutoContinueRules.detect — 5 种前缀触发退出（空内容）', () {
    test('- + 回车 → 退出（isExit=true, prefix="- ")', () {
      final cmd = AutoContinueRules.detect(
        newValue: pressEnter('- '),
        blockId: blockId,
      );

      expect(cmd, isNotNull);
      expect(cmd!.isExit, isTrue);
      expect(cmd.prefix, '- ');
    });

    test('* + 回车 → 退出', () {
      final cmd = AutoContinueRules.detect(
        newValue: pressEnter('* '),
        blockId: blockId,
      );

      expect(cmd, isNotNull);
      expect(cmd!.isExit, isTrue);
      expect(cmd.prefix, '* ');
    });

    test('1. + 回车 → 退出（prefix="1. "）', () {
      final cmd = AutoContinueRules.detect(
        newValue: pressEnter('1. '),
        blockId: blockId,
      );

      expect(cmd, isNotNull);
      expect(cmd!.isExit, isTrue);
      expect(cmd.prefix, '1. ');
    });

    test('> + 回车 → 退出', () {
      final cmd = AutoContinueRules.detect(
        newValue: pressEnter('> '),
        blockId: blockId,
      );

      expect(cmd, isNotNull);
      expect(cmd!.isExit, isTrue);
      expect(cmd.prefix, '> ');
    });

    test('- [ ] + 回车 → 退出（prefix="- [ ] "）', () {
      final cmd = AutoContinueRules.detect(
        newValue: pressEnter('- [ ] '),
        blockId: blockId,
      );

      expect(cmd, isNotNull);
      expect(cmd!.isExit, isTrue);
      expect(cmd.prefix, '- [ ] ');
    });
  });

  group('AutoContinueRules.detect — v1.1 P1-5 checkbox 优先级', () {
    test('- [ ] task 不被 - 抢先匹配（续行 "- [ ] " 而非 "- ")', () {
      final cmd = AutoContinueRules.detect(
        newValue: pressEnter('- [ ] task'),
        blockId: blockId,
      );

      expect(cmd, isNotNull);
      // 关键断言：必须是 checkbox 前缀，不能是普通的 "- "
      expect(cmd!.prefix, '- [ ] ');
      expect(cmd.prefix, isNot('- '));
    });

    test('- [ ] （空内容）退出时 prefix 为 "- [ ] " 而非 "- "', () {
      final cmd = AutoContinueRules.detect(
        newValue: pressEnter('- [ ] '),
        blockId: blockId,
      );

      expect(cmd, isNotNull);
      expect(cmd!.isExit, isTrue);
      expect(cmd.prefix, '- [ ] ');
      expect(cmd.prefix, isNot('- '));
    });

    test('- [x] task（已完成 checkbox）→ 匹配 "- " 而非 checkbox', () {
      // 已完成 checkbox 不在优先级 1 的 regex 中（仅匹配 "- [ ] "）
      // 应降级到优先级 4（"- "），续行 "- "
      final cmd = AutoContinueRules.detect(
        newValue: pressEnter('- [x] task'),
        blockId: blockId,
      );

      expect(cmd, isNotNull);
      expect(cmd!.prefix, '- ');
      expect(cmd.isExit, isFalse);
    });
  });

  group('AutoContinueRules.detect — 有序列表编号递增', () {
    test('2. item + 回车 → 续行 "3. "', () {
      final cmd = AutoContinueRules.detect(
        newValue: pressEnter('2. item'),
        blockId: blockId,
      );

      expect(cmd, isNotNull);
      expect(cmd!.prefix, '3. ');
    });

    test('10. item + 回车 → 续行 "11. "（多位数字）', () {
      final cmd = AutoContinueRules.detect(
        newValue: pressEnter('10. item'),
        blockId: blockId,
      );

      expect(cmd, isNotNull);
      expect(cmd!.prefix, '11. ');
    });

    test('99. item + 回车 → 续行 "100. "（跨数量级）', () {
      final cmd = AutoContinueRules.detect(
        newValue: pressEnter('99. item'),
        blockId: blockId,
      );

      expect(cmd, isNotNull);
      expect(cmd!.prefix, '100. ');
    });
  });

  group('AutoContinueRules.detect — 不触发场景', () {
    test('普通文本 + 回车 → 返回 null', () {
      final cmd = AutoContinueRules.detect(
        newValue: pressEnter('hello world'),
        blockId: blockId,
      );

      expect(cmd, isNull);
    });

    test('空文本 + 回车 → 返回 null', () {
      final cmd = AutoContinueRules.detect(
        newValue: pressEnter(''),
        blockId: blockId,
      );

      expect(cmd, isNull);
    });

    test('不以 \\n 结尾 → 返回 null', () {
      final cmd = AutoContinueRules.detect(
        newValue: const TextEditingValue(
          text: '- item',
          selection: TextSelection.collapsed(offset: 6),
        ),
        blockId: blockId,
      );

      expect(cmd, isNull);
    });

    test('Markdown 标题 + 回车 → 返回 null（非列表前缀）', () {
      final cmd = AutoContinueRules.detect(
        newValue: pressEnter('# heading'),
        blockId: blockId,
      );

      expect(cmd, isNull);
    });

    test('二级标题 ## + 回车 → 返回 null', () {
      final cmd = AutoContinueRules.detect(
        newValue: pressEnter('## heading'),
        blockId: blockId,
      );

      expect(cmd, isNull);
    });
  });

  group('AutoContinueRules.detect — 多行场景', () {
    test('多行列表中回车 → 续行倒数第二行前缀', () {
      // 模拟：用户在 "- item2" 后按回车
      const text = '- item1\n- item2\n';
      final cmd = AutoContinueRules.detect(
        newValue: const TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        ),
        blockId: blockId,
      );

      expect(cmd, isNotNull);
      expect(cmd!.prefix, '- ');
      expect(cmd.isExit, isFalse);
    });

    test('多行中倒数第二行无前缀 → 返回 null', () {
      // 模拟：用户在 "普通行" 后按回车
      const text = '- item1\n普通行\n';
      final cmd = AutoContinueRules.detect(
        newValue: const TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        ),
        blockId: blockId,
      );

      expect(cmd, isNull);
    });

    test('多行有序列表回车 → 编号递增（倒数第二行编号 +1）', () {
      // 模拟：用户在 "1. first\n2. second" 后按回车
      const text = '1. first\n2. second\n';
      final cmd = AutoContinueRules.detect(
        newValue: const TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        ),
        blockId: blockId,
      );

      expect(cmd, isNotNull);
      expect(cmd!.prefix, '3. ');
      expect(cmd.isExit, isFalse);
    });

    test('多行 checkbox 回车 → 续行 checkbox 前缀', () {
      // 模拟：用户在 "- [ ] task1\n- [ ] task2" 后按回车
      const text = '- [ ] task1\n- [ ] task2\n';
      final cmd = AutoContinueRules.detect(
        newValue: const TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        ),
        blockId: blockId,
      );

      expect(cmd, isNotNull);
      expect(cmd!.prefix, '- [ ] ');
      expect(cmd.isExit, isFalse);
    });
  });

  group('AutoContinueRules.detect — Command 字段验证（v1.1 P0-3）', () {
    test('InsertNewLineWithPrefixCommand 无 currentSource 字段（编译时保证）', () {
      // 此测试仅验证 Command 字段可访问，currentSource 字段不存在由编译器保证
      final cmd = AutoContinueRules.detect(
        newValue: pressEnter('- item'),
        blockId: blockId,
      );

      expect(cmd, isNotNull);
      // 验证存在的字段：blockId / prefix / isExit / origin / displayName
      expect(cmd!.blockId, blockId);
      expect(cmd.prefix, '- ');
      expect(cmd.isExit, isFalse);
      expect(cmd.origin, CommandOrigin.ime);
      expect(cmd.displayName, '自动续列表');
      // currentSource 字段不存在：访问会编译错误，无需运行时测试
    });

    test('退出 Command 的 origin 也为 ime', () {
      final cmd = AutoContinueRules.detect(
        newValue: pressEnter('- '),
        blockId: blockId,
      );

      expect(cmd, isNotNull);
      expect(cmd!.origin, CommandOrigin.ime);
      expect(cmd.isExit, isTrue);
    });
  });
}
