import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/document.dart';
import 'paragraph_renderer.dart';

/// 渲染 Markdown 任务列表项（- [ ] / - [x]）。
///
/// 复用一个可勾选样式的复选框 + 行内内容（[ParagraphRenderer]
/// 负责加粗 / 公式等 inline 渲染）。[indent] 以 [AppSpacing.md]
/// 为单位对齐嵌套层级。
class TaskListItemRenderer extends StatelessWidget {
  final List<InlineElement> children;
  final bool checked;
  final bool isDark;
  final int indent;

  const TaskListItemRenderer({
    super.key,
    required this.children,
    required this.checked,
    required this.isDark,
    this.indent = 0,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = checked
        ? AppColors.primary
        : (isDark ? Colors.grey[600] : Colors.grey[400]);
    return Padding(
      padding: EdgeInsets.only(
        left: indent * AppSpacing.md,
        top: AppSpacing.xs,
        bottom: AppSpacing.xs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              checked ? Icons.check_box : Icons.check_box_outline_blank,
              size: AppSpacing.body + 4,
              color: iconColor,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: children.isEmpty
                ? const SizedBox.shrink()
                : ParagraphRenderer(children: children, isDark: isDark),
          ),
        ],
      ),
    );
  }
}
