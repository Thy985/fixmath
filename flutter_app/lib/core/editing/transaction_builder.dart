/// TransactionBuilder：收集 [EditOperation] 并构造 [Transaction]。
///
/// 落地 ADR-0008 §3（TransactionBuilder commit/rollback 原子性）+ §5（与 IME 交互）。
///
/// v1.2 关键约束：
/// - [TransactionId] 在 Builder **创建时**生成（非 commit 时），便于 debug 追踪
/// - onChange 回调：顶层 commit 时触发 1 次（嵌套 commit 不触发，合并到 parent）
/// - rollback：丢弃已收集的 ops，不应用任何变更
/// - 嵌套合并：子 builder commit 时把 ops 合并到 parent（explicit parent-child merge，
///   no ambient transaction context）
///
/// **apply 责任**：本类只负责 **收集** op + 构造 [Transaction]。
/// 实际 apply 到 [DocumentEditor] 的责任在 [EditorHistory] 或调用方。
///
/// 详见 Phase 2.6 Task Contract §3.5。
library;

import 'edit_operation.dart';
import 'transaction.dart';

/// 顶层 commit 时触发的回调类型（1 commit = 1 notification）。
///
/// 调用方（如 EditorHistory）在此回调中：
/// 1. 对 [DocumentEditor] 应用 [Transaction.ops]
/// 2. 把 [Transaction] 推入 undo 栈
/// 3. 触发 UI rebuild（通过 ChangeNotifier）
typedef TransactionChangeListener = void Function(Transaction transaction);

/// [Transaction] 的构造器（收集 [EditOperation] 并 commit）。
///
/// 用法：
/// ```dart
/// final builder = TransactionBuilder(
///   origin: TransactionOrigin.keyboard,
///   onChange: (tx) => history.apply(tx),
/// );
/// builder.add(TextOperation(...));
/// builder.add(TextOperation(...));
/// builder.commit(label: '输入 hello');
/// ```
///
/// **嵌套用法**（子 builder 的 ops 合并到 parent）：
/// ```dart
/// final parent = TransactionBuilder(origin: TransactionOrigin.programmatic);
/// parent.add(op1);
///
/// final child = TransactionBuilder(
///   origin: TransactionOrigin.programmatic,
///   parent: parent,
/// );
/// child.add(op2);
/// child.commit();  // 不触发 onChange，op2 合并到 parent
///
/// parent.commit();  // 触发 onChange，包含 op1 + op2
/// ```
class TransactionBuilder {
  /// 此 builder 的 id（创建时生成，commit 时复用）。
  final TransactionId id;

  /// 操作来源。
  final TransactionOrigin origin;

  /// 父 builder（嵌套时非 null）。
  final TransactionBuilder? parent;

  /// 顶层 commit 时触发的回调（嵌套 builder 的 commit 不触发）。
  final TransactionChangeListener? onChange;

  /// 默认标签（commit 时若未指定 label 则用此值）。
  final String? _defaultLabel;

  final List<EditOperation> _ops = [];

  bool _committed = false;
  bool _rolledBack = false;

  TransactionBuilder({
    required this.origin,
    this.parent,
    this.onChange,
    String? label,
  })  : id = TransactionId.next(),
        _defaultLabel = label;

  /// 是否嵌套（有 parent）。
  bool get isNested => parent != null;

  /// 是否已完成（commit 或 rollback）。
  bool get isCompleted => _committed || _rolledBack;

  /// 已收集的 ops（不可变视图）。
  List<EditOperation> get ops => List.unmodifiable(_ops);

  /// 已收集的 op 数量。
  int get opCount => _ops.length;

  /// 添加 op 到当前事务。
  ///
  /// 若已完成（commit 或 rollback）抛 [StateError]。
  void add(EditOperation op) {
    if (isCompleted) {
      throw StateError(
          'TransactionBuilder already completed (committed=$_committed, rolledBack=$_rolledBack)');
    }
    _ops.add(op);
  }

  /// 提交事务，返回构造的 [Transaction]。
  ///
  /// - 顶层 builder（[isNested] == false）：触发 [onChange] 回调 1 次
  /// - 嵌套 builder（[isNested] == true）：把 ops 合并到 [parent]，不触发 [onChange]
  ///
  /// 若已完成抛 [StateError]。
  ///
  /// 可选 [label]：覆盖默认 label；不传则用构造时的 [_defaultLabel]。
  Transaction commit({String? label}) {
    if (isCompleted) {
      throw StateError(
          'TransactionBuilder already completed (committed=$_committed, rolledBack=$_rolledBack)');
    }
    _committed = true;

    final transaction = Transaction(
      id: id,
      ops: List.unmodifiable(_ops),
      metadata: TransactionMetadata(
        timestamp: DateTime.now(),
        label: label ?? _defaultLabel,
      ),
      origin: origin,
    );

    if (isNested) {
      // 嵌套 commit：把 ops 合并到 parent（不触发 onChange）
      for (final op in _ops) {
        parent!.add(op);
      }
    } else {
      // 顶层 commit：触发 onChange 1 次
      onChange?.call(transaction);
    }

    return transaction;
  }

  /// 回滚事务：丢弃已收集的 ops，不应用任何变更。
  ///
  /// - 顶层 builder：直接清空 ops
  /// - 嵌套 builder：仅清空子 builder 的 ops（不影响 parent 已收集的 ops）
  ///
  /// 若已完成抛 [StateError]。
  void rollback() {
    if (isCompleted) {
      throw StateError(
          'TransactionBuilder already completed (committed=$_committed, rolledBack=$_rolledBack)');
    }
    _rolledBack = true;
    _ops.clear();
  }

  @override
  String toString() =>
      'TransactionBuilder(id=$id, origin=$origin, opCount=$opCount, '
      'isNested=$isNested, isCompleted=$isCompleted)';
}
