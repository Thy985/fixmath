import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';

class MarkdownInputField extends ConsumerStatefulWidget {
  final TextEditingController controller;
  final bool isDarkMode;

  const MarkdownInputField({
    super.key,
    required this.controller,
    required this.isDarkMode,
  });

  @override
  ConsumerState<MarkdownInputField> createState() => _MarkdownInputFieldState();
}

class _MarkdownInputFieldState extends ConsumerState<MarkdownInputField> {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(AppSpacing.pageMargin),
      decoration: BoxDecoration(
        color: widget.isDarkMode ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        boxShadow: AppShadows.card(isDark: widget.isDarkMode),
      ),
      child: TextField(
        controller: widget.controller,
        maxLines: null,
        expands: true,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: AppSpacing.body,
          color: widget.isDarkMode ? AppColors.darkText : AppColors.lightText,
        ),
        decoration: InputDecoration(
          hintText: _hintText,
          hintStyle: TextStyle(color: Colors.grey[400]),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(AppSpacing.cardPadding),
        ),
      ),
    );
  }

  static const String _hintText = '''开始输入 Markdown...

标题语法:
  # 一级标题
  ## 二级标题
  ### 三级标题

列表语法:
  - 无序列表项
  1. 有序列表项

公式语法:
  \$E=mc^2\$        (行内公式)
  \$\$x^2 + y^2\$\$  (块级公式)

引用语法:
  > 这是引用文本

代码块:
  \`\`\`python
  def hello():
      print("Hello")
  \`\`\`

表格语法:
  | 列1 | 列2 |
  |-----|-----|
  | 内容 | 内容 |''';
}
