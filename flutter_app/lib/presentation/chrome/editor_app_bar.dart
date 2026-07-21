/// EditorAppBar：编辑器顶部 AppBar（chrome 组件）。
///
/// 落地 Phase 3.0 Task Contract §3.1（v1.1 新增 chrome/ 目录）+ ADR-0009 §3。
/// Phase 3.1-A PR #2：新增"切换到旧版"隐藏入口（§3.4）。
///
/// **职责**：
/// - 显示当前文档标题（Phase 3.0 用种子文档名）
/// - 显示修改状态指示器（Phase 3.0 占位：恒为"未修改"）
/// - 提供返回按钮（返回到文件管理页）
/// - **Phase 3.1-A PR #2**：more_vert 菜单含"切换到旧版编辑器"入口（跳 `/editor-legacy`）
///
/// **不实现**（Phase 3.2+）：
/// - 真实修改状态接入（需要 dirty tracking）
/// - 自动保存指示
/// - 字号缩放控件
///
/// **依赖方向**（Hard Rule 8）：chrome/ 通过 [EditorCoordinator] 接收数据，
/// 不 import blocks/ / panels/。
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
      actions: [
        // Phase 3.1-A PR #2：more_vert 菜单含"切换到旧版编辑器"隐藏入口。
        // 入口不直接暴露在 AppBar 主操作区，需要点开 more_vert 才能看到，
        // 满足"普通用户不会发现，方便需要回退的用户找到"的产品要求。
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          tooltip: '更多',
          onSelected: (value) => _onMenuSelected(context, value),
          itemBuilder: (context) => const [
            PopupMenuItem<String>(
              value: 'about',
              child: ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('关于'),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem<String>(
              value: 'legacy',
              child: ListTile(
                leading: Icon(Icons.history),
                title: Text('切换到旧版编辑器'),
                subtitle: Text('fallback · 迁移期保留'),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _onBack(BuildContext context) {
    // Phase 3.0：返回到文件管理页（路由由 main.dart 配置）
    Navigator.of(context).maybePop();
  }

  /// 处理 PopupMenu 选择。
  ///
  /// - `about`：显示 AboutDialog（Phase 3.1-A PR #2 占位实现）
  /// - `legacy`：跳转到 `/editor-legacy`（旧 EditorScreen fallback）
  void _onMenuSelected(BuildContext context, String value) {
    switch (value) {
      case 'about':
        showAboutDialog(
          context: context,
          applicationName: 'FormulaFix',
          applicationVersion: 'Phase 3.1-A',
          applicationLegalese: 'WYSIWYG 编辑器 · Phase 3.0+',
        );
        break;
      case 'legacy':
        // Phase 3.1-A PR #2：跳转到 legacy fallback 路由。
        // 旧 EditorScreen 保留一个 release 周期，收集用户反馈后移除。
        context.go('/editor-legacy');
        break;
    }
  }
}
