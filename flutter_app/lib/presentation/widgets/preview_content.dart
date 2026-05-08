import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import '../../core/parser/formula_extractor.dart';
import '../../core/parser/markdown_parser.dart';

class PreviewContent extends StatelessWidget {
  final String content;
  final bool isDarkMode;

  const PreviewContent({
    super.key,
    required this.content,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    if (content.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.edit_note,
              size: 64,
              color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              '暂无内容',
              style: TextStyle(
                fontSize: 18,
                color: isDarkMode ? Colors.grey[500] : Colors.grey[500],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '点击上方编辑按钮开始输入',
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
              ),
            ),
          ],
        ),
      );
    }

    final elements = MarkdownParser.parse(content);

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: elements.map((element) => _buildElement(element)).toList(),
        ),
      ),
    );
  }

  Widget _buildElement(element) {
    switch (element.type) {
      case 'heading':
        return _buildHeading(element);
      case 'paragraph':
        return _buildParagraph(element);
      case 'list':
        return _buildList(element);
      case 'code':
        return _buildCode(element);
      case 'blockquote':
        return _buildBlockquote(element);
      case 'empty_line':
        return const SizedBox(height: 16);
      case 'table':
        return _buildTable(element);
      default:
        return Text(
          element.content,
          style: TextStyle(
            fontSize: 16,
            height: 1.6,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        );
    }
  }

  Widget _buildHeading(element) {
    double fontSize;
    switch (element.level) {
      case 1:
        fontSize = 28;
        break;
      case 2:
        fontSize = 24;
        break;
      case 3:
        fontSize = 20;
        break;
      default:
        fontSize = 18;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        element.content,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: isDarkMode ? Colors.white : Colors.black87,
        ),
      ),
    );
  }

  Widget _buildParagraph(element) {
    final children = element.children ?? [];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: children.map((child) {
          if (child.type == 'formula') {
            final displayMode = child.attributes?['displayMode'] ?? false;
            return displayMode
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Math.tex(
                        FormulaExtractor.normalizeLatex(child.content),
                        textStyle: const TextStyle(fontSize: 20),
                        onErrorFallback: (err) => Text(
                          child.content,
                          style: TextStyle(
                            color: Colors.red[300],
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ),
                  )
                : Math.tex(
                    FormulaExtractor.normalizeLatex(child.content),
                    textStyle: TextStyle(
                      fontSize: 16,
                      backgroundColor: isDarkMode
                          ? const Color(0xFF2D2D2D)
                          : const Color(0xFFF5F5F5),
                    ),
                    onErrorFallback: (err) => Text(
                      child.content,
                      style: TextStyle(
                        color: Colors.red[300],
                        fontFamily: 'monospace',
                      ),
                    ),
                  );
          } else {
            return Text(
              child.content,
              style: TextStyle(
                fontSize: 16,
                height: 1.6,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            );
          }
        }).toList(),
      ),
    );
  }

  Widget _buildList(element) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '•  ',
            style: TextStyle(
              fontSize: 16,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          Expanded(
            child: Text(
              element.content,
              style: TextStyle(
                fontSize: 16,
                height: 1.6,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCode(element) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2D2D2D) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        element.content,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 14,
          color: isDarkMode ? Colors.white : Colors.black87,
        ),
      ),
    );
  }

  Widget _buildBlockquote(element) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: const Color(0xFF165DFF),
            width: 4,
          ),
        ),
        color: isDarkMode
            ? const Color(0xFF2D2D2D)
            : const Color(0xFFF5F5F5),
      ),
      child: Text(
        element.content,
        style: TextStyle(
          fontSize: 16,
          height: 1.6,
          fontStyle: FontStyle.italic,
          color: isDarkMode ? Colors.white70 : Colors.black54,
        ),
      ),
    );
  }

  Widget _buildTable(element) {
    final rows = element.content.trim().split('\n');
    if (rows.length < 2) {
      return Text(element.content);
    }

    final headers = rows[0].split('|').where((s) => s.trim().isNotEmpty).toList();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF2D2D2D) : const Color(0xFFF5F5F5),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              children: headers.map((header) {
                return Expanded(
                  child: Text(
                    header.trim(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          for (int i = 2; i < rows.length; i++)
            Container(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: rows[i].split('|').where((s) => s.trim().isNotEmpty).map((cell) {
                  return Expanded(
                    child: Text(
                      cell.trim(),
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}
