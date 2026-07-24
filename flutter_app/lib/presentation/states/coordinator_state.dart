/// CoordinatorState：EditorCoordinator 的不可变 UI 状态聚合。
///
/// 落地 Phase 3.1-A Task Contract §3.1.A.3（弱化版 R1 评审反馈）。
///
/// **背景**：Phase 3.0 时 `EditorCoordinator` 直接持有可变
/// `Map<BlockId, BlockViewState> _viewStates` + `BlockId? _focusedId` 两个独立字段，
/// 多次连续修改时（如 setFocus 切块）会留下中间不一致状态。
///
/// **R1 弱化方案**：
/// - **不拆分 Notifier**（避免 Phase 3.1-A 阶段过度设计，3.1-B 性能触发后再评估）
/// - **聚合 state**：把 viewStates + focusedId 合并为单一不可变 [CoordinatorState]
/// - **不可变更新**：每次修改产生新 [CoordinatorState] 副本，
///   EditorCoordinator 持有单字段 `_state`，由 ChangeNotifier 统一通知
///
/// **R1 强方案（不在 Phase 3.1-A 做）**：
/// - 拆 `DocumentStateNotifier` / `FocusStateNotifier` / `HistoryStateNotifier`
/// - 触发条件：实测 ≥500 Block 时 EditorCoordinator 重建 > 16ms 才做
///
/// **依赖方向**（Hard Rule 8）：states/ → core/editing/（单向依赖）。
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show TextSelection;

import '../../core/editing/block_types.dart';
import 'block_view_state.dart';

/// EditorCoordinator 的 UI 状态聚合（不可变）。
///
/// 包含：
/// - [viewStates]：按 [BlockId] 索引的 UI 视图状态
/// - [focusedId]：当前聚焦的块（null = 无聚焦）
@immutable
class CoordinatorState {
  /// 按 [BlockId] 索引的 UI 视图状态。
  final Map<BlockId, BlockViewState> viewStates;

  /// 当前聚焦的块（null = 无聚焦）。
  final BlockId? focusedId;

  const CoordinatorState({
    required this.viewStates,
    this.focusedId,
  });

  /// 空状态（无 viewStates / 无焦点）。
  const CoordinatorState.empty()
      : viewStates = const {},
        focusedId = null;

  /// 用初始 viewStates 构造（[focusedId] 默认 null）。
  factory CoordinatorState.initial(
      Map<BlockId, BlockViewState> initialViewStates) {
    return CoordinatorState(
      viewStates: Map.unmodifiable(initialViewStates),
      focusedId: null,
    );
  }

  // ============ 不可变更新（返回新 [CoordinatorState]）============

  /// 更新指定块的 [BlockViewState]。
  ///
  /// 返回新 [CoordinatorState]，原对象不变。
  CoordinatorState updateViewState(BlockId id, BlockViewState state) {
    final next = Map<BlockId, BlockViewState>.from(viewStates);
    next[id] = state;
    return CoordinatorState(
      viewStates: Map.unmodifiable(next),
      focusedId: focusedId,
    );
  }

  /// 聚焦指定块，旧块自动切回渲染态。
  CoordinatorState focusOn(BlockId id) {
    if (focusedId == id) return this;
    final next = Map<BlockId, BlockViewState>.from(viewStates);
    if (focusedId != null) {
      final oldState = next[focusedId!];
      if (oldState != null) {
        next[focusedId!] =
            oldState.copyWith(isFocused: false, mode: RenderMode.rendered);
      }
    }
    final curState = next[id];
    if (curState != null) {
      next[id] =
          curState.copyWith(isFocused: true, mode: RenderMode.editing);
    }
    return CoordinatorState(
      viewStates: Map.unmodifiable(next),
      focusedId: id,
    );
  }

  /// 清除指定块的焦点。
  CoordinatorState clearFocusOf(BlockId id) {
    final next = Map<BlockId, BlockViewState>.from(viewStates);
    final state = next[id];
    if (state == null) return this;
    next[id] = state.copyWith(isFocused: false, mode: RenderMode.rendered);
    return CoordinatorState(
      viewStates: Map.unmodifiable(next),
      focusedId: focusedId == id ? null : focusedId,
    );
  }

  /// 同步 viewStates：移除已不在 [currentIds] 的 BlockId，补全新增的 BlockId。
  CoordinatorState syncViewStates(Iterable<BlockId> currentIds) {
    final currentSet = currentIds.toSet();
    final next = <BlockId, BlockViewState>{};
    for (final id in currentIds) {
      next[id] = viewStates[id] ?? BlockViewState(id: id);
    }
    return CoordinatorState(
      viewStates: Map.unmodifiable(next),
      focusedId:
          focusedId != null && currentSet.contains(focusedId) ? focusedId : null,
    );
  }

  /// 查询指定块的 [BlockViewState]。
  BlockViewState? viewStateOf(BlockId id) => viewStates[id];

  // ============ Phase 3.3 PR #2B: focused block 便捷查询 ============

  /// 当前聚焦块的 [TextSelection]（null = 无聚焦块或无选区）。
  ///
  /// 从 [viewStates] 中按 [focusedId] 查询。Toolbar 通过此值判断
  /// 是否有选区（决定 InsertText vs WrapSelection 路径）。
  ///
  /// **节流说明**（§2.7）：此值由 BaseBlockState 通过 PostFrameCallback
  /// 节流同步,可能滞后一帧。Toolbar 按钮 onPressed 中应通过
  /// [EditorCoordinator.focusedSelection] 强一致读取（§2.7.1）。
  TextSelection? get focusedSelection {
    if (focusedId == null) return null;
    final state = viewStates[focusedId!];
    return state?.selection;
  }

  /// 当前聚焦块是否有非空选区（baseOffset != extentOffset）。
  bool get hasSelection {
    final sel = focusedSelection;
    return sel != null && sel.baseOffset != sel.extentOffset;
  }

  @override
  String toString() =>
      'CoordinatorState(blockCount=${viewStates.length}, focused=$focusedId)';
}
