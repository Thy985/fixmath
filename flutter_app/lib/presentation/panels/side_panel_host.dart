/// SidePanelHost：侧栏容器（Phase 3.0 仅占位，不实现功能）。
///
/// 落地 Phase 3.0 Task Contract §3.1（panels/ 目录）+ §3.2（布局插槽）。
///
/// **Phase 3.0 职责**：
/// - 仅提供 [shouldShow] 静态方法（默认 false，侧栏隐藏）
/// - 占位 [SidePanelHost] widget 类，方便 Phase 3.7+ 接入 TOC
/// - 占位 [TocPanel] / [FilePanel]（Phase 3.7 / 3.8 实现）
///
/// **不实现**（Phase 3.7+）：
/// - TOC 大纲面板（监听 coordinator.allIds 变化）
/// - 文件树面板（接入 .md 文件列表）
/// - 拖拽 / 隐藏 / 显示动画
///
/// **依赖方向**（Hard Rule 8）：panels/ → editor/ → core/editing/。
library;

import 'package:flutter/material.dart';

import '../editor/editor_coordinator.dart';

/// 侧栏容器（Phase 3.0 占位）。
///
/// Phase 3.0：默认隐藏，[shouldShow] 恒返回 false。
/// Phase 3.7+：接入 TOC 面板后改为根据屏幕宽度自适应显示。
class SidePanelHost extends StatelessWidget {
  /// 当前页面绑定的 [EditorCoordinator]。
  final EditorCoordinator coordinator;

  const SidePanelHost({
    super.key,
    required this.coordinator,
  });

  /// 是否应该显示侧栏（Phase 3.0 恒为 false，侧栏隐藏）。
  ///
  /// Phase 3.7+：根据屏幕宽度 + 用户偏好决定。
  static bool shouldShow(BuildContext context) {
    // Phase 3.0：永远不显示侧栏（占位）
    // Phase 3.7+：接入 MediaQuery.of(context).size.width >= 1024 等条件
    return false;
  }

  @override
  Widget build(BuildContext context) {
    // Phase 3.0：侧栏默认隐藏，[shouldShow] = false 时不会构造此 widget。
    // 此处仅占位，Phase 3.7+ 接入真实 TOC。
    return Container(
      width: 240,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Center(
        child: Text(
          'Side Panel\n(Phase 3.7+)',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ),
    );
  }
}
