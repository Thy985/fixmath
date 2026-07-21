/// EditorAppBar：编辑器顶部 AppBar（chrome 组件）。
///
/// 落地 Phase 3.0 Task Contract §3.1（v1.1 新增 chrome/ 目录）+ ADR-0009 §3。
///
/// **职责**：
/// - 显示当前文档标题（Phase 3.0 用种子文档名）
/// - 显示修改状态指示器（Phase 3.0 占位：恒为"未修改"）
/// - 提供返回按钮（返回到文件管理页）
///
/// **不实现**（Phase 3.1+）：
/// - 真实修改状态接入（需要 dirty tracking）
/// - 自动保存指示
/// - 字号缩放控件
///
/// **依赖方向**（Hard Rule 8）：chrome/ 通过 [EditorCoordinator] 接收数据，
/// 不 import blocks/ / panels/。
library;

import 'package:flutter/material.dart';

import '../editor/editor_coordinator.dart';

/// 编辑器顶部 AppBar（chrome 组件）。
class EditorAppBar extends StatelessWidget implements PreferredSizeWidget {
  /// 当前页面绑定的 [EditorCoordinator]。
  final EditorCoordinator coordinator;

  /// AppBar 标题（Phase 3.0：种子文档名）。
  final String title;

  /// 是否有未保存修改（Phase 3.0 占位：恒为 false）。
  final bool isModified;

  const EditorAppBar({
    super.key,
    required this.coordinator,
    this.title = 'Phase 3.0 Demo',
    this.isModified = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Row(
        children: [
          Text(title),
          if (isModified) ...[
            const SizedBox(width: 4),
            const Text(
              '•',
              style: TextStyle(fontSize: 20),
            ),
          ],
        ],
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        tooltip: '返回',
        onPressed: () => _onBack(context),
      ),
      actions: const [
        // Phase 3.0 占位：字号缩放、TOC 切换、主题切换等控件在 Phase 3.2+ 实现
        IconButton(
          icon: Icon(Icons.more_vert),
          tooltip: '更多（Phase 3.2+）',
          onPressed: null, // Phase 3.0 占位
        ),
      ],
    );
  }

  void _onBack(BuildContext context) {
    // Phase 3.0：返回到文件管理页（路由由 main.dart 配置）
    // 若 Phase 3.0 feature flag 关闭，路由不会到此页面
    Navigator.of(context).maybePop();
  }
}
