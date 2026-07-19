/// BlockEditor 状态机。
///
/// 5 态有限状态机，描述块编辑器的聚焦 / 失焦 / 错误生命周期。
/// 详见 ADR-0007 §1.4（双态切换）+ §1.6（error 态处理）。
///
/// 状态转换图：
///
/// ```
///         onFocus()                 onFocus() complete
/// blurred --------> focusing --------------------------------> focused
///     ^                                                       |
///     |                                                       | onBlur()
///     |                                                       v
///     +<-------- blurred <---------- blurring <--------------+
///                     parse fail     |
///                                     v
///                                    error
///                                     |
///                                     | user keeps editing
///                                     v
///                                   focused
/// ```
library;

import 'package:flutter/foundation.dart';

/// BlockEditor 状态枚举。
enum BlockEditorState {
  /// 非聚焦态：渲染最终样式。
  blurred,

  /// 聚焦中（过渡态）：onFocus 已触发，尚未完成。
  focusing,

  /// 聚焦态：TextField 可编辑。
  focused,

  /// 失焦中（过渡态）：onBlur 已触发，正尝试逆解析。
  blurring,

  /// 错误态：blur 时逆解析失败，保留 focused 编辑态。
  ///
  /// 详见 ADR-0007 §1.6。用户继续编辑后回到 focused。
  error,
}

/// 状态转换触发事件。
///
/// 与 [BlockEditorState] 共同定义状态机。
enum BlockEditorEvent {
  /// 触发聚焦。
  focus,

  /// 聚焦完成（onFocus 副作用执行完毕）。
  focusComplete,

  /// 触发失焦。
  blur,

  /// 失焦逆解析成功（onBlur 副作用执行完毕，source → DocumentElement 成功）。
  blurComplete,

  /// 失焦逆解析失败。
  ///
  /// 进入 error 态，保留 source 原样。
  blurFailed,

  /// 用户从 error 态继续编辑。
  resumeEditing,

  /// 从 error 态显式放弃（用户切走 / 关闭文档）。
  discardError,
}

/// 状态机转换函数。
///
/// 纯函数，无副作用。给定当前状态与事件，返回新状态。
/// 非法转换抛 [StateError]。
///
/// 详见 ADR-0007 §1.4 + §1.6 转换表。
@visibleForTesting
BlockEditorState transitionBlockEditorState({
  required BlockEditorState current,
  required BlockEditorEvent event,
}) {
  return switch ((current, event)) {
    // blurred: 只能 focus
    (BlockEditorState.blurred, BlockEditorEvent.focus) =>
      BlockEditorState.focusing,

    // focusing: 完成 → focused；其他事件非法（过渡态不应被中断）
    (BlockEditorState.focusing, BlockEditorEvent.focusComplete) =>
      BlockEditorState.focused,

    // focused: 失焦 → blurring
    (BlockEditorState.focused, BlockEditorEvent.blur) =>
      BlockEditorState.blurring,

    // blurring: 成功 → blurred；失败 → error
    (BlockEditorState.blurring, BlockEditorEvent.blurComplete) =>
      BlockEditorState.blurred,
    (BlockEditorState.blurring, BlockEditorEvent.blurFailed) =>
      BlockEditorState.error,

    // error: 用户继续编辑 → focused；放弃 → blurred
    (BlockEditorState.error, BlockEditorEvent.resumeEditing) =>
      BlockEditorState.focused,
    (BlockEditorState.error, BlockEditorEvent.discardError) =>
      BlockEditorState.blurred,

    // 非法转换：抛 StateError
    _ => throw StateError(
        'Invalid BlockEditor state transition: $current + $event',
      ),
  };
}

/// 判断转换是否合法。
///
/// 用于守门测试，不抛异常。
@visibleForTesting
bool isValidTransition({
  required BlockEditorState current,
  required BlockEditorEvent event,
}) {
  try {
    transitionBlockEditorState(current: current, event: event);
    return true;
  } on StateError {
    return false;
  }
}
