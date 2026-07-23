/// EditorShell：编辑器外壳（布局壳，组合 chrome + workspace + status）。
///
/// 落地 Phase 3.0 Task Contract §3.2 + ADR-0009 §3（Editor Shell Architecture）。
///
/// **布局**（v1.1 修订：新增 chrome/ 目录）：
/// ```
/// ┌──────────────────────────────────────┐
/// │ AppBar（title + modified indicator） │ ← chrome/editor_app_bar.dart
/// ├────────────┬─────────────────────────┤
/// │            │                         │
/// │ SidePanel  │     EditorViewport      │
/// │ （占位）   │  （3 种 Block 渲染）    │ ← blocks/block_renderer.dart
/// │            │                         │
/// ├────────────┴─────────────────────────┤
/// │ StatusBar（块数 / 字数 / Undo 状态） │ ← chrome/editor_status_bar.dart
/// └──────────────────────────────────────┘
/// ```
///
/// **职责**：仅布局 + 传递 [EditorCoordinator]（不持有业务状态）。
/// **不实现**（Phase 3.1+）：TOC / 文件树 / 主题切换 / 快捷键 / 修改状态指示。
library;

import 'package:flutter/material.dart';

import '../blocks/block_renderer.dart';
import '../chrome/editor_app_bar.dart';
import '../chrome/editor_status_bar.dart';
import '../panels/side_panel_host.dart';
import '../states/block_view_state.dart';
import 'editor_coordinator.dart';

/// EditorShell：组合 chrome + workspace + status 的布局壳。
///
/// 由 [EditorPage] 挂载，接收 [EditorCoordinator] 并通过 [EditorScope] 注入。
class EditorShell extends StatelessWidget {
  /// 当前页面绑定的 [EditorCoordinator]。
  final EditorCoordinator coordinator;

  const EditorShell({
    super.key,
    required this.coordinator,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: EditorAppBar(
        coordinator: coordinator,
        title: coordinator.title,
        isModified: coordinator.isDirty,
      ),
      body: Workspace(coordinator: coordinator),
      bottomNavigationBar: EditorStatusBar(coordinator: coordinator),
    );
  }
}

/// Workspace：编辑区 + 侧栏组合（Phase 3.0 仅占位）。
///
/// Phase 3.0：侧栏隐藏（仅插槽），编辑区占满。
/// Phase 3.7+：侧栏接入 TOC（左侧滑出）。
/// Phase 3.8+：侧栏接入文件树（左侧滑出）。
class Workspace extends StatelessWidget {
  final EditorCoordinator coordinator;

  const Workspace({super.key, required this.coordinator});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // 侧栏插槽（Phase 3.0 占位，默认隐藏）
        if (SidePanelHost.shouldShow(context))
          SidePanelHost(coordinator: coordinator),
        // 编辑视口（BlockRenderer 渲染所有块）
        Expanded(
          child: EditorViewport(coordinator: coordinator),
        ),
      ],
    );
  }
}

/// EditorViewport：编辑视口（渲染所有 Block）。
///
/// 遍历 [coordinator.allIds]，为每个 Block 构造 [BlockRenderer]。
class EditorViewport extends StatelessWidget {
  final EditorCoordinator coordinator;

  const EditorViewport({
    super.key,
    required this.coordinator,
  });

  @override
  Widget build(BuildContext context) {
    final ids = coordinator.allIds;
    if (ids.isEmpty) {
      return const Center(
        child: Text('（空文档）', style: TextStyle(fontSize: 16)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: ids.length,
      itemBuilder: (context, index) {
        final id = ids[index];
        final element = coordinator.getBlock(id);
        // state 应已在 EditorCoordinator 构造时初始化；
        // 此处 ?? 兜底防御：若 state 未初始化，使用默认 BlockViewState
        final state = coordinator.viewStateOf(id) ?? BlockViewState(id: id);
        if (element == null) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: BlockRenderer(
            element: element,
            state: state,
            coordinator: coordinator,
          ),
        );
      },
    );
  }
}
