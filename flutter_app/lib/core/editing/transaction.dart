/// 编辑事务 + TransactionId + Metadata + Origin。
///
/// 落地 ADR-0008 §1（Transaction 容器）+ §8（TransactionId 内存顺序标识）。
///
/// v1.2 修订：
/// - TransactionId 在 TransactionBuilder **创建时**生成（非 commit 时），便于 debug 追踪
/// - TransactionOrigin 从 v1.0 的 4 值扩展为 6 值（keyboard/ime/paste/programmatic/undo/redo）
///
/// 详见 Phase 2.6 Task Contract §3.4。
library;

import 'package:flutter/foundation.dart';

import 'edit_operation.dart';

/// 编辑事务。一个 [Transaction] = 一组原子可逆的 [EditOperation]。
///
/// ADR-0008 §1：1 Transaction = 1 Undo 单元（Ctrl+Z 一次撤销整个 Transaction）。
///
/// v1.2 TransactionId 生命周期：在 [TransactionBuilder] 构造时生成，
/// 通过参数传入 [Transaction]，commit 时复用同一 id（便于 debug 关联）。
@immutable
class Transaction {
  /// 顺序自增标识（Builder 创建时生成）。
  final TransactionId id;

  /// 顺序敏感的操作列表（apply 时按序执行，revert 时逆序执行）。
  final List<EditOperation> ops;

  /// 时间戳与可读标签（用于 Undo/Redo 菜单展示）。
  final TransactionMetadata metadata;

  /// 操作来源（决定是否入栈 / 是否触发 listener / 是否可被 coalesce）。
  final TransactionOrigin origin;

  const Transaction({
    required this.id,
    required this.ops,
    required this.metadata,
    required this.origin,
  });
}

/// Transaction 顺序自增标识（ADR-0008 §8）。
///
/// **v1.2 评审反馈补强 2**：生命周期——在 [TransactionBuilder] **创建时**生成，
/// 非 commit 时。
///
/// 内存态，进程重启后从 0 开始。仅用于调试与日志。
///
/// 生命周期理由：
///
/// 若在 commit 时生成：
/// ```
/// Builder created  → T-001
/// (添加 op...)
/// commit           → T-002（与 builder 不一致）
/// ```
///
/// Debug log 追踪困难，无法把 "Builder 创建" 与 "Transaction 应用" 关联。
///
/// v1.2 在 Builder 创建时生成：
/// ```
/// Builder created  → T-001
/// (添加 op...)
/// commit           → T-001（一致）
/// ```
///
/// 便于日志追踪与性能分析（测量 Builder 创建到 commit 的耗时）。
class TransactionId {
  static int _counter = 0;
  final int value;

  TransactionId._(this.value);

  /// 在 [TransactionBuilder] 构造时调用（非 commit 时）。
  factory TransactionId.next() => TransactionId._(_counter++);

  @override
  String toString() => 'TransactionId($value)';
}

/// Transaction 元数据。
@immutable
class TransactionMetadata {
  /// 创建时间（commit 时填充）。
  final DateTime timestamp;

  /// 用户可读标签，如 "输入 'hello'" / "拆分块"。
  ///
  /// 用于 Undo/Redo 菜单展示（Phase 3 UI 接入）。
  final String? label;

  const TransactionMetadata({
    required this.timestamp,
    this.label,
  });
}

/// Transaction 来源。决定是否入栈 / 是否触发 listener / 是否可被 coalesce。
///
/// **v1.2 评审反馈补强 3**：从 v1.0/v1.1 的 4 值扩展为 6 值。
///
/// 扩展理由：
///
/// ADR-0008 §4 coalescing 6 触发条件之一是 `last.origin == user`，
/// 但 "user" 过于笼统：键盘连续输入与 IME commit / paste 在 Undo 行为上应该有差异
/// （paste 应该独立成单元，不应与前面键盘输入合并）。
///
/// v1.2 细化 user 为 keyboard / ime / paste 三类，coalesce 默认只合并 keyboard
/// （详见 [EditorHistory._defaultCanCoalesce]）。
enum TransactionOrigin {
  /// 键盘逐字符输入（可参与 coalescing）。
  ///
  /// 例：输入 "hello" 的 5 个 TextOperation 应合并为 1 个 Undo 单元。
  keyboard,

  /// IME commit（Phase 2.5 已预留，本 Phase 接入）。
  ///
  /// 例：输入 "你好" 的最终 commit。
  /// 不参与 coalescing（IME commit 必须独立成单元，避免与前面 keyboard 输入混淆）。
  /// 详见 ADR-0008 §5 铁律 2。
  ime,

  /// 粘贴（剪贴板批量插入）。
  ///
  /// 不参与 coalescing（paste 应独立成单元，符合用户直觉）。
  paste,

  /// 程序修改（如格式化 / 自动修复 / lint 修复）。
  ///
  /// 不参与 coalescing（程序修改应独立成单元，便于追溯）。
  programmatic,

  /// undo 自身（不入栈，避免无限递归）。
  undo,

  /// redo 自身（不入栈，避免无限递归）。
  redo,
}
