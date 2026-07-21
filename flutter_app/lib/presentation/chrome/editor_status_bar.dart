/// EditorStatusBar：编辑器底部状态栏（chrome 组件）。
///
/// 落地 Phase 3.0 Task Contract §3.1（v1.1 新增 chrome/ 目录）+ §3.2 布局图。
///
/// **职责**：
/// - 显示当前块数
/// - 显示 Undo / Redo 状态（Phase 3.0 占位：仅文字，不接入按钮）
/// - 显示聚焦块 ID（调试用，Phase 3.1+ 移除）
///
/// **不实现**（Phase 3.1+）：
/// - 字数 / 字符数统计
/// - 光标位置（行 : 列）
/// - 主题切换控件
/// - 字号缩放控件
///
/// **依赖方向**（Hard Rule 8）：chrome/ 通过 [EditorCoordinator] 接收数据，
/// 不 import blocks/ / panels/。
library;

import 'package:flutter/material.dart';

import '../editor/editor_coordinator.dart';

/// 编辑器底部状态栏（chrome 组件）。
class EditorStatusBar extends StatelessWidget {
  /// 当前页面绑定的 [EditorCoordinator]。
  final EditorCoordinator coordinator;

  const EditorStatusBar({
    super.key,
    required this.coordinator,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          _buildItem('块数: ${coordinator.blockCount}'),
          const SizedBox(width: 16),
          _buildItem(coordinator.canUndo ? '可撤销' : '不可撤销'),
          const SizedBox(width: 16),
          _buildItem(coordinator.canRedo ? '可重做' : '不可重做'),
          const Spacer(),
          _buildItem('聚焦: ${coordinator.focusedId ?? '—'}'),
        ],
      ),
    );
  }

  Widget _buildItem(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
    );
  }
}
