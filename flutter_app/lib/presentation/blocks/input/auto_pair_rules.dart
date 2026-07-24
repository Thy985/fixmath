/// 自动配对规则表 + 触发条件检测。
///
/// 落地 Phase 3.3 PR #3 Task Contract v1.1 §4.2。
///
/// **职责**：检测 onChanged 是否触发了自动配对，返回 [PairInsertCommand]?
/// （null = 不触发）。不调用 Coordinator（由 [InputHandler] 负责调度）。
///
/// **v1.1 Hard Rule（§2.1.1）**：调用方（[InputHandler]）已保证
/// `composing == TextRange.empty`，本类不再检查 composing。
///
/// **支持 4 种配对符**（v1.3 硬规则：`*` / `$` / `#` / `-` / `>` 不支持）：
/// - `(` → `)`
/// - `[` → `]`
/// - `{` → `}`
/// - `` ` `` → `` ` ``
library;

import 'package:flutter/widgets.dart';

import '../../commands/commands.dart';
import '../../../core/editing/block_types.dart';

/// 自动配对规则检测器。
///
/// 纯函数设计：无状态、无副作用，接收 [TextEditingValue] 返回 [PairInsertCommand]?。
class AutoPairRules {
  /// 配对符映射（左半 → 右半）。
  static const Map<String, String> _pairs = {
    '(': ')',
    '[': ']',
    '{': '}',
    '`': '`',
  };

  /// 检测 onChanged 是否触发了自动配对。
  ///
  /// **触发条件**（全部满足）：
  /// 1. [oldValue].selection 为 collapsed（无选区）
  /// 2. [newValue].text 比 [oldValue].text 恰好多 1 个字符
  /// 3. 新增字符在 [_pairs] 中
  ///
  /// **不触发**：
  /// - 有选区时（wrapSelection 模式留 Phase 3.4+，IME 替换选区后无法简单恢复）
  /// - 删除字符时（text 变短）
  /// - 粘贴多字符时（text 增加超过 1）
  /// - 新增字符不在配对表中
  ///
  /// 返回 [PairInsertCommand]（mode = appendAfterCursor，光标在配对符中间）。
  static PairInsertCommand? detect({
    required TextEditingValue newValue,
    required TextEditingValue oldValue,
    required BlockId blockId,
  }) {
    // 有选区时不触发（wrapSelection 留 Phase 3.4+）
    if (!oldValue.selection.isCollapsed) return null;

    // 仅处理新增 1 个字符的情况
    if (newValue.text.length != oldValue.text.length + 1) return null;

    // 光标必须在有效位置
    final cursor = newValue.selection.baseOffset;
    if (cursor <= 0 || cursor > newValue.text.length) return null;

    // 新增字符 = 光标前一个字符
    final insertedChar = newValue.text.substring(cursor - 1, cursor);
    final suffix = _pairs[insertedChar];
    if (suffix == null) return null;

    // 构造 PairInsertCommand
    // insertOffset = 光标位置（'(' 之后，即 suffix 要插入的位置）
    // cursorOffset = -suffix.length（光标在 suffixChar 之前，即配对符中间）
    return PairInsertCommand(
      blockId: blockId,
      suffixChar: suffix,
      insertOffset: cursor,
      mode: PairInsertMode.appendAfterCursor,
      cursorOffset: -suffix.length,
    );
  }
}
