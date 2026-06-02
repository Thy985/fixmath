import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/parser/markdown_parser.dart';
import '../../core/services/mermaid_renderer.dart';
import '../../core/services/mermaid_service.dart';
import '../../data/models/document.dart';
import 'heading_renderer.dart';
import 'paragraph_renderer.dart';
import 'list_renderer.dart';
import 'code_renderer.dart';
import 'blockquote_renderer.dart';
import 'table_renderer.dart';

class PreviewContent extends StatelessWidget {
  final String content;
  final bool isDark;

  const PreviewContent({
    super.key,
    required this.content,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (content.isEmpty) {
      return _buildEmpty();
    }

    final elements = MarkdownParser.parse(content);
    final bg = isDark ? AppColors.darkSurface : Colors.white;

    int orderedIndex = 0;
    int unorderedIndex = 0;
    bool lastWasOrdered = false;
    int lastIndent = -1;

    return Container(
      margin: const EdgeInsets.all(AppSpacing.pageMargin),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        boxShadow: AppShadows.card(isDark: isDark),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: elements.map((e) {
              final result = _dispatch(e, () {
                if (e is! ListElement) {
                  orderedIndex = 0;
                  unorderedIndex = 0;
                  lastWasOrdered = false;
                  lastIndent = -1;
                  return 0;
                }
                final isSameList = lastWasOrdered == e.ordered &&
                    lastIndent == e.indent;
                final idx = e.ordered
                    ? (isSameList ? orderedIndex++ : (orderedIndex = 1) - 1)
                    : (isSameList
                        ? unorderedIndex++
                        : (unorderedIndex = 1) - 1);
                lastWasOrdered = e.ordered;
                lastIndent = e.indent;
                return idx;
              });
              return result;
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _dispatch(DocumentElement element, int Function() indexProvider) {
    return switch (element) {
      HeadingElement(:final level, :final text) => HeadingRenderer(
          level: level, text: text, isDark: isDark),
      ParagraphElement(:final children) => ParagraphRenderer(
          children: children, isDark: isDark),
      ListElement(:final children, :final ordered) => ListRenderer(
          children: children,
          ordered: ordered,
          index: indexProvider(),
          isDark: isDark,
        ),
      CodeElement(:final code) => CodeRenderer(code: code, isDark: isDark),
      BlockquoteElement(:final text) => BlockquoteRenderer(
          text: text, isDark: isDark),
      MermaidElement(:final code) => MermaidElementWidget(
          code: code,
          theme: isDark ? MermaidTheme.dark : MermaidTheme.light,
        ),
      TableElement(:final headers, :final rows) => TableRenderer(
          headers: headers, rows: rows, isDark: isDark),
      EmptyLineElement() => const SizedBox(height: AppSpacing.lg),
    };
  }

  Widget _buildEmpty() {
    final iconColor = isDark ? Colors.grey[600] : Colors.grey[400];
    final textColor = isDark ? Colors.grey[500] : Colors.grey[500];

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.edit_note, size: 64, color: iconColor),
          const SizedBox(height: AppSpacing.lg),
          Text('暂无内容', style: TextStyle(fontSize: 18, color: textColor)),
          const SizedBox(height: AppSpacing.sm),
          Text('点击上方编辑按钮开始输入', style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[600] : Colors.grey[400])),
        ],
      ),
    );
  }
}
