/// Markdown → TXT 导出器。
///
/// 把 Markdown 文档解析为纯文本：保留 # 标题、- 列表、1. 有序列表、```代码块、
/// > 引用、| 表格 等 Markdown 语法，公式退化为 `[latex]`。
///
/// public API：仅 [TextExporter.export] 一个静态方法。
library;

import 'dart:convert';
import 'dart:typed_data';
import '../../../core/parser/markdown_parser.dart';
import '../../../data/models/document.dart';
import '../export_service.dart' show ExportException;

class TextExporter {
  TextExporter._();

  /// 入口：把 Markdown 文本导出为 UTF-8 编码的纯文本字节流。
  static Future<Uint8List> export(String markdown) async {
    if (markdown.isEmpty) {
      throw ExportException('Cannot export empty content');
    }

    final elements = MarkdownParser.parse(markdown);
    final sb = StringBuffer();

    for (final element in elements) {
      final line = _elementToText(element);
      if (line.isNotEmpty) {
        sb.writeln(line);
      }
    }

    final result = sb.toString();
    final trimmed = result.endsWith('\n')
        ? result.substring(0, result.length - 1)
        : result;
    return Uint8List.fromList(utf8.encode(trimmed));
  }

  /// 把单个 DocumentElement 序列化为单行/多行 Markdown 文本。
  static String _elementToText(DocumentElement element) {
    if (element is HeadingElement) {
      return '${'#' * element.level} ${element.text}';
    } else if (element is ParagraphElement) {
      return element.children.map((c) {
        if (c is FormulaElement) return ' [${c.latex}] ';
        if (c is TextElement) return c.text;
        return '';
      }).join('');
    } else if (element is ListElement) {
      final text = _inlineToText(element.children);
      return '${'  ' * element.indent}${element.ordered ? '${element.indent + 1}. ' : '- '}$text';
    } else if (element is CodeElement) {
      return '```${element.language ?? ''}\n${element.code}\n```';
    } else if (element is BlockquoteElement) {
      return '> ${element.text}';
    } else if (element is MermaidElement) {
      return '```mermaid\n${element.code}\n```';
    } else if (element is TableElement) {
      final lines = <String>[];
      lines.add('| ${element.headers.join(' | ')} |');
      lines.add('| ${element.headers.map((_) => '---').join(' | ')} |');
      for (final row in element.rows) {
        lines.add('| ${row.join(' | ')} |');
      }
      return lines.join('\n');
    }
    return '';
  }

  /// 把 inline 列表拼成纯文本（用于 ListElement 渲染）。
  static String _inlineToText(List<InlineElement> children) {
    final buf = StringBuffer();
    for (final c in children) {
      if (c is TextElement) {
        buf.write(c.text);
      } else if (c is FormulaElement) {
        buf.write(' [${c.latex}] ');
      }
    }
    return buf.toString();
  }
}
