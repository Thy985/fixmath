/// EditorStrings：编辑器 UI 字符串集中管理（Phase 3.3 PR #2B）。
///
/// 落地 Phase 3.3 PR #2 Task Contract v2.1 §2.8.1（EditorStrings 抽离）。
///
/// **目的**：
/// - 集中管理 UI 字符串，为 Phase 4+ 国际化（flutter_localizations）预备
/// - 禁止业务逻辑硬编码中文字符串（PR #2B 守门,违反则 PR 拒绝）
///
/// **演进方向**：
/// - Phase 3.3：静态常量类，集中管理 UI 字符串
/// - Phase 3.3 PR #2C：扩展模板菜单标签字符串
/// - Phase 4+：接入 flutter_localizations，实现中英文切换
library;

/// 编辑器 UI 字符串集中管理。
///
/// 使用 `abstract final class` 防止实例化与子类化（Dart 3.0+ 特性）。
/// 所有字段为 `static const String`，调用方式：`EditorStrings.codeBlockToolbarDisabled`。
abstract final class EditorStrings {
  // ============ Toolbar 禁用提示（§2.8）============

  /// CodeBlock 聚焦时工具栏禁用提示。
  ///
  /// 当聚焦块为 CodeBlock 时,所有工具栏按钮 + `+` 模板菜单全部禁用,
  /// 显示此提示文字替代工具栏按钮（§2.8 v2.0 方案）。
  static const String codeBlockToolbarDisabled = '代码块内工具栏不可用';

  // ============ Toolbar 按钮 tooltip（无障碍 / 可访问性）============

  /// 加粗按钮 tooltip。
  static const String boldTooltip = '加粗';

  /// 斜体按钮 tooltip。
  static const String italicTooltip = '斜体';

  /// 一级标题按钮 tooltip。
  static const String h1Tooltip = '一级标题';

  /// 二级标题按钮 tooltip。
  static const String h2Tooltip = '二级标题';

  /// 三级标题按钮 tooltip。
  static const String h3Tooltip = '三级标题';

  /// 行内代码按钮 tooltip。
  static const String codeTooltip = '行内代码';

  /// 链接按钮 tooltip。
  static const String linkTooltip = '链接';

  /// 引用按钮 tooltip。
  static const String quoteTooltip = '引用';

  /// 有序列表按钮 tooltip。
  static const String orderedListTooltip = '有序列表';

  /// 无序列表按钮 tooltip。
  static const String unorderedListTooltip = '无序列表';

  /// 任务列表按钮 tooltip。
  static const String taskListTooltip = '任务列表';

  // ============ 模板菜单标签（PR #2C）============

  /// `+` 模板菜单按钮 tooltip。
  static const String templateMenuTooltip = '插入模板';

  /// 表格模板菜单标签。
  static const String templateMenuTable = '表格';

  /// Mermaid 图表模板菜单标签。
  static const String templateMenuMermaid = 'Mermaid 图表';

  /// 代码块模板菜单标签。
  static const String templateMenuCodeBlock = '代码块';

  /// 任务列表模板菜单标签。
  static const String templateMenuTaskList = '任务列表';

  /// 引用块模板菜单标签。
  static const String templateMenuQuote = '引用块';

  /// 分隔线模板菜单标签。
  static const String templateMenuHorizontalRule = '分隔线';

  /// 图片模板菜单标签。
  static const String templateMenuImage = '图片';

  /// 链接模板菜单标签。
  static const String templateMenuLink = '链接';
}
