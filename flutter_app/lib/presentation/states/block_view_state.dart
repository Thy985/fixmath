/// BlockViewState：UI 层块的视图状态（与 AST 解耦）。
///
/// 落地 ADR-0009 §3.4（UI 状态模型）+ UI-ARCHITECTURE.md §3。
///
/// **核心原则（Hard Rule 1：AST 零污染）**：
/// - UI 状态（focus / selection / composing / render mode）单独建模
/// - 通过 [BlockId] 关联到 AST（[DocumentElement]），不在 AST 中新增字段
/// - [BlockViewState] 是 immutable，修改通过 [copyWith]
///
/// **与 ComposingController 的关系**（UI-ARCHITECTURE.md §3.1.1）：
/// - [ComposingController] 是 composing 态的 SoT（守门 + 状态机）
/// - [BlockViewState.composingRegion] 是其只读镜像，仅用于 UI 渲染
/// - UI 不得直接修改 [composingRegion]，必须经 [ComposingController] 守门后回调同步
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show TextSelection;

import '../../core/editing/block_types.dart';

/// 渲染模式（双态切换，ADR-0007 §1.4）。
enum RenderMode {
  /// 渲染态：显示最终样式（如加粗、列表符号、代码块）。
  rendered,

  /// 编辑态：显示 Markdown source（可编辑 TextField）。
  editing,
}

/// 块的 UI 视图状态。
///
/// 一个 [BlockViewState] 对应一个 [BlockId]，描述该块的 UI 交互状态。
/// 不保存 [DocumentElement]（AST 数据），仅保存 UI 状态。
@immutable
class BlockViewState {
  /// 对应的块 [BlockId]（稳定 identity，关联到 AST）。
  final BlockId id;

  /// 是否聚焦（当前活动块）。
  final bool isFocused;

  /// 渲染模式（rendered ↔ editing 双态切换）。
  final RenderMode mode;

  /// 块内选区（null = 单光标点）。
  final TextSelection? selection;

  /// IME composing region（只读镜像，UI 不直接修改）。
  ///
  /// 详见 UI-ARCHITECTURE.md §3.1.1 与 ComposingController 同步策略。
  final ComposingRegion? composingRegion;

  const BlockViewState({
    required this.id,
    this.isFocused = false,
    this.mode = RenderMode.rendered,
    this.selection,
    this.composingRegion,
  });

  /// 是否处于编辑态。
  bool get isEditing => mode == RenderMode.editing;

  BlockViewState copyWith({
    bool? isFocused,
    RenderMode? mode,
    TextSelection? selection,
    Object? composingRegion = _sentinel,
  }) {
    return BlockViewState(
      id: id,
      isFocused: isFocused ?? this.isFocused,
      mode: mode ?? this.mode,
      selection: selection ?? this.selection,
      composingRegion: identical(composingRegion, _sentinel)
          ? this.composingRegion
          : composingRegion as ComposingRegion?,
    );
  }

  /// 清空 composing region（composing cancel / commit 后调用）。
  BlockViewState clearComposing() => BlockViewState(
        id: id,
        isFocused: isFocused,
        mode: mode,
        selection: selection,
        composingRegion: null,
      );

  @override
  String toString() =>
      'BlockViewState(id=$id, isFocused=$isFocused, mode=$mode, '
      'hasSelection=${selection != null}, hasComposing=${composingRegion != null})';
}

const Object _sentinel = Object();
