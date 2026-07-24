/// EditorTokens：主题 token（Phase 3.0 仅占位，不实现切换）。
///
/// 落地 Phase 3.0 Task Contract §3.1（themes/ 目录）+ §3.5（UI Design Reference）。
///
/// **Phase 3.0 职责**：
/// - 提供颜色 / 间距 / 字号 / 圆角等常量 token
/// - 供 chrome/ / blocks/ / panels/ 引用，避免硬编码 magic number
///
/// **不实现**（Phase 3.9+）：
/// - 主题切换（light / dark / sepia）
/// - 用户字号缩放（0.8x / 1.0x / 1.2x）
/// - 自定义 accent color
///
/// **设计参考**：Material Design 3 type scale + Apple HIG spacing。
library;

import 'package:flutter/material.dart';

/// 编辑器主题 token（Phase 3.0 仅占位常量）。
///
/// 所有 UI 组件应优先使用 [EditorTokens] 而非硬编码值，
/// 便于 Phase 3.9+ 接入主题切换。
class EditorTokens {
  const EditorTokens._();

  // ============ 颜色（Phase 3.0 占位，Phase 3.9+ 接入主题） ============

  /// 主文本颜色（light 模式）。
  static const Color textPrimary = Color(0xFF1A1A1A);

  /// 次要文本颜色（标注、占位）。
  static const Color textSecondary = Color(0xFF6B6B6B);

  /// 编辑态边框颜色（聚焦时）。
  static const Color borderFocused = Color(0xFF2196F3);

  /// 渲染态边框颜色（hover / 默认）。
  static const Color borderDefault = Color(0xFFE0E0E0);

  /// 代码块背景色。
  static const Color codeBackground = Color(0xFFF5F5F5);

  /// 代码块 language chip 颜色。
  static const Color codeLanguageChip = Color(0xFFE0E0E0);

  /// 引用块左侧竖线颜色（Phase 3.2 §3.4 QuoteBlock）。
  static const Color quoteBorderColor = Color(0xFFC0C0C0);

  /// 表格边框颜色（Phase 3.2 §3.5 TableBlock）。
  static const Color tableBorderColor = Color(0xFFE0E0E0);

  /// 表格表头背景色（Phase 3.2 §3.5 TableBlock）。
  static const Color tableHeaderBackground = Color(0xFFF5F5F5);

  /// 行内链接颜色（Phase 3.2 §3.7 LinkElement inline rendering）。
  ///
  /// 注：与 [ThemeData.colorScheme.primary] 的关系——
  /// 此 token 用于 ParagraphBlock 的 inline TextSpan（TextSpan 不支持
  /// 运行时 Theme.of(context) 查找,需要编译时常量）。
  /// Phase 3.9+ 主题切换时此 token 将改为 Theme 驱动。
  static const Color linkColor = Color(0xFF2196F3);

  // ============ 间距 ============

  /// 块间距（块与块之间的垂直间距）。
  static const double blockSpacing = 8.0;

  /// 块内边距（水平）。
  static const double blockPaddingHorizontal = 12.0;

  /// 块内边距（垂直）。
  static const double blockPaddingVertical = 6.0;

  /// EditorViewport 整体内边距。
  static const double viewportPadding = 16.0;

  // ============ 字号 ============

  /// 段落字号。
  static const double paragraphFontSize = 16.0;

  /// 代码字号。
  static const double codeFontSize = 14.0;

  /// 表格单元格字号（Phase 3.2 §3.5 TableBlock,与 code 字号一致但语义独立）。
  static const double tableCellFontSize = 14.0;

  /// 状态栏字号。
  static const double statusBarFontSize = 11.0;

  /// heading 字号映射（level 1-6）。
  static const List<double> headingFontSizes = [28, 24, 22, 20, 18, 16];

  // ============ 圆角 ============

  /// 块圆角。
  static const double blockRadius = 4.0;

  /// chip 圆角（language chip 等）。
  static const double chipRadius = 3.0;

  // ============ 状态栏 ============

  /// 状态栏高度。
  static const double statusBarHeight = 24.0;

  /// AppBar 高度（对齐 [kToolbarHeight]）。
  static const double appBarHeight = kToolbarHeight;
}
