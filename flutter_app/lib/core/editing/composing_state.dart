/// IME 组合态状态机。
///
/// 4 态有限状态机，描述 composing region 的生命周期。
/// 详见 ADR-0007 §3.2 三铁律 + Phase 2.5 Task Contract §3.1。
///
/// 状态转换图：
///
/// ```
///         onComposingStart()                    onComposingCommit(text)
/// idle --------------------> composing --------------------------------> committing
///  ^                                                                     |
///  |                                                                     | commitComplete
///  |                                                                     v
///  +<------------------ idle <------------ cancelling <------------+
///                         |                | onComposingCancel()
///                         |                v
///                         +---> cancelling
///                              (rollback source)
/// ```
///
/// Self-transition（评审反馈 1）：
/// - `composing + onComposingUpdate → composing` 是合法 self-transition
/// - update 仅刷新 composing region（由 ComposingHost 管理），不算状态转换
/// - composing region 真相源在 ComposingHost，ComposingController 不保存
///
/// 三铁律对应：
/// - 铁律 1（不切块）：composing / committing / cancelling 态禁止 BlockOperation
/// - 铁律 2（commit 不丢字）：committing 态用新文本替换 composing region
/// - 铁律 3（cancel 回滚）：cancelling 态恢复 commit 前 source
library;

/// IME 组合态状态枚举。
enum ComposingState {
  /// 空闲态：无 composing region。
  idle,

  /// 组合中：IME 正在输入（中文/日文未 commit）。
  ///
  /// 允许 self-transition（onComposingUpdate）。
  composing,

  /// 提交中：IME 正在 commit（瞬间完成，为铁律 2 保留过渡态）。
  committing,

  /// 取消中：IME cancel 已触发，正在回滚 source（瞬间完成）。
  cancelling,
}

/// 状态转换触发事件。
///
/// 与 [ComposingState] 共同定义状态机。
enum ComposingEvent {
  /// IME composing 开始（idle → composing）。
  start,

  /// IME composing region 更新（composing → composing，self-transition）。
  update,

  /// IME commit（composing → committing）。
  commit,

  /// commit 完成（committing → idle）。
  commitComplete,

  /// IME cancel（composing → cancelling）。
  cancel,

  /// cancel 完成（cancelling → idle）。
  cancelComplete,
}

/// 状态机转换函数。
///
/// 纯函数，无副作用。给定当前状态与事件，返回新状态。
/// 非法转换抛 [StateError]。
///
/// 详见 ADR-0007 §3.2 + Phase 2.5 Task Contract §3.1。
ComposingState transitionComposingState({
  required ComposingState current,
  required ComposingEvent event,
}) {
  return switch ((current, event)) {
    // idle: 只能 start
    (ComposingState.idle, ComposingEvent.start) => ComposingState.composing,

    // composing: update（self-transition）/ commit / cancel
    (ComposingState.composing, ComposingEvent.update) =>
      ComposingState.composing,
    (ComposingState.composing, ComposingEvent.commit) =>
      ComposingState.committing,
    (ComposingState.composing, ComposingEvent.cancel) =>
      ComposingState.cancelling,

    // committing: 完成 → idle
    (ComposingState.committing, ComposingEvent.commitComplete) =>
      ComposingState.idle,

    // cancelling: 完成 → idle
    (ComposingState.cancelling, ComposingEvent.cancelComplete) =>
      ComposingState.idle,

    // 非法转换：抛 StateError
    _ => throw StateError(
        'Invalid Composing state transition: $current + $event',
      ),
  };
}

/// 判断转换是否合法。
///
/// 用于守门测试，不抛异常。
bool isValidComposingTransition({
  required ComposingState current,
  required ComposingEvent event,
}) {
  try {
    transitionComposingState(current: current, event: event);
    return true;
  } on StateError {
    return false;
  }
}
