/// BlockEditor 抽象接口。
///
/// Phase 2.2 仅定义接口骨架，不实现：
/// - fromElement / toElement 双向映射（Phase 2.3）
/// - 增量解析（Phase 2.3）
/// - IME 接入 UI（Phase 2.5）
/// - 块级操作原语（Phase 2.6）
/// - Markdown 快捷映射（Phase 2.7）
///
/// 详见 ADR-0007 §1.1（接口定义）。
library;

import 'package:flutter/foundation.dart';

import 'block_editor_state.dart';
import 'block_types.dart';

/// 块编辑器抽象。
///
/// 一个 Block = 一段可独立编辑的内容（段落 / 标题 / 代码 / ...）。
///
/// 双态切换（ADR-0007 §1.4）：
/// - focused: 渲染为 TextField，可编辑 [source]
/// - blurred: 渲染为最终样式（Phase 3 实现）
///
/// 状态机由 [BlockEditorState] 管理（ADR-0007 §1.4 + §1.6）。
@immutable
abstract class BlockEditor {
  /// 块唯一标识。
  BlockId get id;

  /// 块类型。
  BlockType get type;

  /// 当前状态。
  BlockEditorState get state;

  /// 是否处于聚焦编辑态。
  ///
  /// 等价于 `state == BlockEditorState.focused ||
  /// state == BlockEditorState.focusing`。
  bool get isFocused =>
      state == BlockEditorState.focused ||
      state == BlockEditorState.focusing;

  /// 块内可编辑内容（Markdown 源文本）。
  ///
  /// 编辑态默认显示 source，不实现 syntax hiding（ADR-0007 §1.5）。
  /// 与 .md 单一真相源对齐（ADR-0003）。
  String get source;

  /// 编辑态切换回调。
  ///
  /// Phase 2.2 仅定义接口；Phase 2.2 实现由状态机驱动。
  /// Phase 2.5 IME 接入后，onBlur 会先 commit composing region。
  ///
  /// 详见 ADR-0007 §1.4 + §3.2 铁律 1（组合态中间不切块）。
  void onFocus();

  void onBlur();

  /// 源文本变更回调。
  ///
  /// Phase 2.3 接入增量解析后，仅触发当前块的重解析。
  /// Phase 2.5 IME 接入后，commit 阶段调用此方法（不丢字）。
  ///
  /// 详见 ADR-0007 §3.2 铁律 2。
  void onSourceChanged(String newSource);

  /// IME 组合态取消回调。
  ///
  /// Phase 2.5 实现：恢复 commit 前 source。
  ///
  /// 详见 ADR-0007 §3.2 铁律 3。
  void onComposingCancelled();
}
