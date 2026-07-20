import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import 'formula_insert_dialog.dart';

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
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _insertAtCursor(String text) {
    final selection = widget.controller.selection;
    final newText = widget.controller.text;
    final start = selection.isValid ? selection.start : newText.length;
    final end = selection.isValid ? selection.end : newText.length;
    final updated = newText.replaceRange(start, end, text);
    widget.controller.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: start + text.length),
    );
  }

  void _insertWrap(String left, String right) {
    final selection = widget.controller.selection;
    final newText = widget.controller.text;
    final start = selection.isValid ? selection.start : newText.length;
    final end = selection.isValid ? selection.end : newText.length;
    final selected = newText.substring(start, end);
    final inserted = '$left$selected$right';
    final updated = newText.replaceRange(start, end, inserted);
    widget.controller.value = TextEditingValue(
      text: updated,
      selection: TextSelection(
        baseOffset: start + left.length,
        extentOffset: start + left.length + selected.length,
      ),
    );
  }

  Future<void> _openFormulaDialog({required bool displayMode}) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => FormulaInsertDialog(
        displayMode: displayMode,
        isDark: widget.isDarkMode,
      ),
    );
    if (result != null && result.isNotEmpty && mounted) {
      final wrapped = displayMode ? '\$\$$result\$\$' : '\$$result\$';
      _insertAtCursor(wrapped);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hintColor = widget.isDarkMode ? Colors.grey[500] : Colors.grey[400];
    return Container(
      margin: const EdgeInsets.all(AppSpacing.pageMargin),
      decoration: BoxDecoration(
        color: widget.isDarkMode ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        boxShadow: AppShadows.card(isDark: widget.isDarkMode),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildToolbar(),
          const Divider(height: 1),
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: AppSpacing.body,
                height: 1.5,
                color: widget.isDarkMode
                    ? AppColors.darkText
                    : AppColors.lightText,
              ),
              decoration: InputDecoration(
                hintText: _hintText,
                hintStyle: TextStyle(
                  color: hintColor,
                  fontFamily: 'monospace',
                  fontSize: AppSpacing.body - 1,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(AppSpacing.cardPadding),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    final iconColor =
        widget.isDarkMode ? AppColors.darkText : AppColors.lightText;

    Widget toolBtn({
      required IconData icon,
      required String tooltip,
      required VoidCallback onTap,
      bool highlight = false,
    }) {
      return Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: highlight ? AppColors.primary.withValues(alpha: 0.15) : null,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: widget.isDarkMode
            ? Colors.black26
            : Colors.grey.withValues(alpha: 0.06),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            toolBtn(
              icon: Icons.functions,
              tooltip: '插入行内公式 \$\$.',
              onTap: () => _openFormulaDialog(displayMode: false),
              highlight: true,
            ),
            toolBtn(
              icon: Icons.straighten,
              tooltip: '插入块级公式 \$\$\$.',
              onTap: () => _openFormulaDialog(displayMode: true),
            ),
            Container(
              width: 1,
              height: 20,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              color: iconColor.withValues(alpha: 0.2),
            ),
            toolBtn(
              icon: Icons.format_bold,
              tooltip: '加粗 **',
              onTap: () => _insertWrap('**', '**'),
            ),
            toolBtn(
              icon: Icons.format_italic,
              tooltip: '斜体 *',
              onTap: () => _insertWrap('*', '*'),
            ),
            toolBtn(
              icon: Icons.format_strikethrough,
              tooltip: '删除线 ~~',
              onTap: () => _insertWrap('~~', '~~'),
            ),
            toolBtn(
              icon: Icons.code,
              tooltip: '行内代码 `',
              onTap: () => _insertWrap('`', '`'),
            ),
            Container(
              width: 1,
              height: 20,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              color: iconColor.withValues(alpha: 0.2),
            ),
            toolBtn(
              icon: Icons.title,
              tooltip: '标题 #',
              onTap: () => _insertAtCursor('\n## '),
            ),
            toolBtn(
              icon: Icons.format_list_bulleted,
              tooltip: '无序列表 -',
              onTap: () => _insertAtCursor('\n- '),
            ),
            toolBtn(
              icon: Icons.format_list_numbered,
              tooltip: '有序列表 1.',
              onTap: () => _insertAtCursor('\n1. '),
            ),
            toolBtn(
              icon: Icons.format_quote,
              tooltip: '引用 >',
              onTap: () => _insertAtCursor('\n> '),
            ),
            toolBtn(
              icon: Icons.link,
              tooltip: '链接 []()',
              onTap: () => _insertAtCursor('[text](url)'),
            ),
            Container(
              width: 1,
              height: 20,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              color: iconColor.withValues(alpha: 0.2),
            ),
            toolBtn(
              icon: Icons.image,
              tooltip: '图片 ![]()',
              onTap: () => _insertAtCursor('![alt](url)'),
            ),
            toolBtn(
              icon: Icons.check_box,
              tooltip: '任务列表 - [ ]',
              onTap: () => _insertAtCursor('\n- [ ] '),
            ),
            toolBtn(
              icon: Icons.horizontal_rule,
              tooltip: '水平分割线 ---',
              onTap: () => _insertAtCursor('\n---\n'),
            ),
            toolBtn(
              icon: Icons.data_object,
              tooltip: '代码块 ```',
              onTap: () => _insertAtCursor('\n```\n\n```\n'),
            ),
            toolBtn(
              icon: Icons.table_chart,
              tooltip: '表格 |...|',
              onTap: () =>
                  _insertAtCursor('\n| 列1 | 列2 |\n| --- | --- |\n| 内容 | 内容 |\n'),
            ),
          ],
        ),
      ),
    );
  }

  static const String _hintText = '''开始输入 Markdown...
工具栏：点击上方 f(x) 按钮快速插入公式

标题:
  # 一级
  ## 二级

公式:
  \$E=mc^2\$         (行内)
  \$\$x^2+y^2=z^2\$\$ (块级)

代码块:
  ```python
  print("hi")
  ```

Mermaid:
  ```mermaid
  graph TD; A-->B
  ```''';
}
