/// InputHandler：自动配对 + 自动续列表的统一调度入口。
///
/// 落地 Phase 3.3 PR #3 Task Contract v1.1 §2.6（BaseBlockState input handler 边界）。
///
/// **职责**（§2.6 职责边界）：
/// - 协调 [AutoPairRules] + [AutoContinueRules] 检测
/// - 计算最终 source（用户输入 + 配对符 / 续行前缀）
/// - 调用 [EditorCoordinator.handle] 派发 [UpdateBlockSourceCommand]
/// - 同步光标位置到 [BlockViewState]
///
/// **不负责**：
/// - ❌ 不直接修改 TextEditingController（由 BaseBlockState 通过 didUpdateWidget 同步）
/// - ❌ 不实现配对 / 续行规则（规则在 AutoPairRules / AutoContinueRules）
/// - ❌ 不检查 composing region（由调用方 BaseBlockState 保证）
/// - ❌ 不持有 oldValue 状态（由调用方 BaseBlockState 提供,避免首次调用 oldValue=null 误判）
///
/// **v1.1 Hard Rule（§2.1.1）**：调用方（BaseBlockState._onTextChanged）已保证
/// `composing == TextRange.empty`，本类不再检查 composing。
///
/// **无状态设计**：本类不持有任何可变状态,每次 [handle] 调用都是纯函数式
/// （oldValue 由调用方提供）。这让 [BaseBlockState] 成为状态唯一管理者,
/// 避免状态分散在 InputHandler + BaseBlockState 两处。
///
/// **单 Command 策略**（v1.1 实施时修订）：
/// 原设计为两步（先 UpdateBlockSourceCommand 提交用户输入,再 PairInsertCommand /
/// InsertNewLineWithPrefixCommand 追加）。但 [BlockOperations.updateSource] 会触发
/// [BlockType] transform（如 `- item\n` → listItem）,而 [fromElement] 序列化
/// ListElement 时不保留尾部 `\n`,导致第二步读取的 source 丢失 `\n`。
/// 因此改为：在 InputHandler 中计算最终 source,提交单个 [UpdateBlockSourceCommand]，
/// 然后同步光标位置。这也带来更好的 Undo UX（1 步 undo 而非 2 步）。
library;

import 'package:flutter/widgets.dart';

import '../../../core/editing/block_types.dart';
import '../../commands/commands.dart';
import '../../editor/editor_coordinator.dart';
import '../../states/block_view_state.dart';
import 'auto_continue_rules.dart';
import 'auto_pair_rules.dart';

/// 自动输入行为调度器（自动配对 + 自动续列表）。
///
/// 无状态：不持有 oldValue,由调用方 [BaseBlockState] 提供。
class InputHandler {
  /// 处理 onChanged 的 TextEditingValue 变化。
  ///
  /// **调用方契约**（BaseBlockState._onTextChanged）：
  /// 1. 已检查 `isFocused == true`
  /// 2. 已检查 `value.composing == TextRange.empty`（§2.1.1 Hard Rule）
  /// 3. 已检查 `!isCodeBlock`（§2.5 CodeBlock 例外）
  /// 4. 已提供正确的 [oldValue]（前一次的 TextEditingValue）
  ///
  /// **调度顺序**：
  /// 1. 先检测自动配对（单字符新增场景）
  /// 2. 若未触发配对,再检测自动续列表（以 `\n` 结尾场景）
  /// 3. 两者互斥：一次 onChanged 只触发一个 Command
  ///
  /// **Undo 语义**（单 Command 策略）：触发配对 / 续行时,产生 1 个 undo 步骤
  /// （[UpdateBlockSourceCommand] 携带最终 source）。用户 undo 1 次即可完全撤销。
  void handle({
    required TextEditingValue newValue,
    required TextEditingValue oldValue,
    required BlockId blockId,
    required EditorCoordinator coordinator,
  }) {
    // 1. 自动配对检测（单字符新增）
    final pairCmd = AutoPairRules.detect(
      newValue: newValue,
      oldValue: oldValue,
      blockId: blockId,
    );
    if (pairCmd != null) {
      // 计算最终 source：在 insertOffset 处插入 suffixChar
      final finalSource = newValue.text.substring(0, pairCmd.insertOffset) +
          pairCmd.suffixChar +
          newValue.text.substring(pairCmd.insertOffset);
      coordinator.handle(UpdateBlockSourceCommand(
        blockId: blockId,
        newSource: finalSource,
        origin: CommandOrigin.ime,
      ));
      // 光标在配对符中间：insertOffset（'(' 之后,'）' 之前）
      _syncCursor(coordinator, blockId, pairCmd.insertOffset);
      return;
    }

    // 2. 自动续列表检测（以 '\n' 结尾）
    final continueCmd = AutoContinueRules.detect(
      newValue: newValue,
      blockId: blockId,
    );
    if (continueCmd != null) {
      final String finalSource;
      final int cursorOffset;
      if (continueCmd.isExit) {
        // 退出续行：移除空列表项行（前缀 + 刚输入的 '\n'）
        // 例如 "- \n" → ""，"item\n- \n" → "item\n"
        final text = newValue.text;
        final lastNewline = text.lastIndexOf('\n');
        if (lastNewline == -1) {
          finalSource = text;
        } else {
          final beforeLastNewline = text.substring(0, lastNewline);
          final prevNewline = beforeLastNewline.lastIndexOf('\n');
          final lastLineStart = prevNewline == -1 ? 0 : prevNewline + 1;
          final lastLine = beforeLastNewline.substring(lastLineStart);
          if (lastLine == continueCmd.prefix) {
            // 移除前缀行 + 刚输入的 '\n',保留之前的内容
            finalSource =
                beforeLastNewline.substring(0, lastLineStart) +
                    text.substring(lastNewline + 1);
          } else {
            // 兜底：仅移除最后的 '\n'
            finalSource = beforeLastNewline;
          }
        }
        cursorOffset = finalSource.length;
      } else {
        // 续行：在用户输入后追加前缀
        finalSource = newValue.text + continueCmd.prefix;
        cursorOffset = finalSource.length;
      }
      coordinator.handle(UpdateBlockSourceCommand(
        blockId: blockId,
        newSource: finalSource,
        origin: CommandOrigin.ime,
      ));
      _syncCursor(coordinator, blockId, cursorOffset);
    }
  }

  /// 同步光标位置到 [BlockViewState]（BaseBlockState.didUpdateWidget 会读取此值）。
  void _syncCursor(EditorCoordinator coordinator, BlockId blockId, int offset) {
    final state = coordinator.viewStateOf(blockId) ?? BlockViewState(id: blockId);
    coordinator.updateViewState(
      blockId,
      state.copyWith(selection: TextSelection.collapsed(offset: offset)),
    );
  }
}
