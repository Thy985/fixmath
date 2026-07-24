/// 自动续列表规则表 + 触发条件检测。
///
/// 落地 Phase 3.3 PR #3 Task Contract v1.1 §4.3。
///
/// **职责**：检测 onChanged 是否触发了自动续列表，返回
/// [InsertNewLineWithPrefixCommand]?（null = 不触发）。不调用 Coordinator
/// （由 [InputHandler] 负责调度）。
///
/// **v1.1 Hard Rule（§2.1.1）**：调用方（[InputHandler]）已保证
/// `composing == TextRange.empty`，本类不再检查 composing。
///
/// **支持 5 种前缀**（v1.1 P1-5：优先级排序，checkbox 优先）：
/// 1. `- [ ] `（checkbox，最具体，必须先匹配）
/// 2. `\d+\. `（有序列表，编号 +1）
/// 3. `> `（引用）
/// 4. `- `（无序列表）
/// 5. `* `（无序列表）
library;

import 'package:flutter/widgets.dart';

import '../../commands/commands.dart';
import '../../../core/editing/block_types.dart';

/// 自动续列表规则检测器。
///
/// 纯函数设计：无状态、无副作用，接收 [TextEditingValue] 返回
/// [InsertNewLineWithPrefixCommand]?。
class AutoContinueRules {
  /// v1.1 P1-5：按优先级排序，checkbox 最优先。
  ///
  /// 匹配顺序至关重要：checkbox（`- [ ] `）必须早于 `- `，否则会被
  /// `^- (.*)$` 抢先匹配，导致任务列表续行变成普通无序列表续行。
  static const List<_ContinuePattern> _patterns = [
    // 优先级 1：checkbox（最具体，必须先匹配，否则会被 '- ' 抢先）
    _ContinuePattern(
      regex: r'^- \[ \] (.*)$',
      nextPrefix: '- [ ] ',
    ),
    // 优先级 2：有序列表（编号 +1 动态计算，nextPrefix = null）
    _ContinuePattern(
      regex: r'^(\d+)\. (.*)$',
      nextPrefix: null,
    ),
    // 优先级 3：引用
    _ContinuePattern(
      regex: r'^> (.*)$',
      nextPrefix: '> ',
    ),
    // 优先级 4：无序列表（-）
    _ContinuePattern(
      regex: r'^- (.*)$',
      nextPrefix: '- ',
    ),
    // 优先级 5：无序列表（*）
    _ContinuePattern(
      regex: r'^\* (.*)$',
      nextPrefix: '* ',
    ),
  ];

  /// 检测 onChanged 是否触发了自动续列表。
  ///
  /// **触发条件**（全部满足）：
  /// 1. [newValue].text 以 `\n` 结尾（用户按回车，IME 已提交 `\n`）
  /// 2. 倒数第二行（`\n` 之前的最后一行）匹配某个列表 / 引用前缀
  /// 3. 若该行仅有前缀无内容 → 退出（清除前缀，`isExit = true`）
  /// 4. 否则 → 续行（追加前缀，`isExit = false`）
  ///
  /// **不触发**：
  /// - text 不以 `\n` 结尾
  /// - 倒数第二行无列表 / 引用前缀
  /// - 普通文本 + 回车
  ///
  /// 返回 [InsertNewLineWithPrefixCommand]（`isExit=true` 退出 / `isExit=false` 续行）。
  static InsertNewLineWithPrefixCommand? detect({
    required TextEditingValue newValue,
    required BlockId blockId,
  }) {
    final text = newValue.text;
    if (text.isEmpty || !text.endsWith('\n')) return null;

    // 提取倒数第二行（最后一个 '\n' 之前的那一行）
    final lastNewline = text.lastIndexOf('\n');
    final beforeLastNewline = text.substring(0, lastNewline);
    final prevNewline = beforeLastNewline.lastIndexOf('\n');
    final lastLineStart = prevNewline == -1 ? 0 : prevNewline + 1;
    final lastLine = text.substring(lastLineStart, lastNewline);

    // 按优先级匹配 _patterns（checkbox 优先）
    for (final pattern in _patterns) {
      final match = RegExp(pattern.regex).firstMatch(lastLine);
      if (match == null) continue;

      // content = 最后一个 capture group（所有 pattern 的最后一组都是内容）
      final content = match.group(match.groupCount) ?? '';
      // actualPrefix = 内容之前的全部字符（用于退出时清除）
      final actualPrefix =
          lastLine.substring(0, lastLine.length - content.length);

      if (content.isEmpty) {
        // 退出：清除最后一行的前缀
        return InsertNewLineWithPrefixCommand(
          blockId: blockId,
          prefix: actualPrefix,
          isExit: true,
        );
      }

      // 续行：构造下一行前缀（有序列表 nextPrefix=null → 动态计算）
      final nextPrefix =
          pattern.nextPrefix ?? pattern.computeNextPrefix(match);
      return InsertNewLineWithPrefixCommand(
        blockId: blockId,
        prefix: nextPrefix,
        isExit: false,
      );
    }

    return null;
  }
}

/// 续行模式定义（私有值类）。
@immutable
class _ContinuePattern {
  /// 匹配当前行的正则。
  ///
  /// **约束**：最后一个 capture group 必须是"内容"部分（可能为空字符串）。
  /// 有序列表的 group(1) 是数字，group(2) 是内容。
  final String regex;

  /// 下一行的前缀（`null` = 动态计算，如有序列表编号 +1）。
  final String? nextPrefix;

  const _ContinuePattern({
    required this.regex,
    required this.nextPrefix,
  });

  /// 计算下一行前缀（仅 [nextPrefix] == null 时调用，即有序列表编号 +1）。
  ///
  /// 有序列表 regex `^(\d+)\. (.*)$`：group(1) = 数字字符串。
  String computeNextPrefix(RegExpMatch match) {
    final number = int.tryParse(match.group(1) ?? '1') ?? 1;
    return '${number + 1}. ';
  }
}
