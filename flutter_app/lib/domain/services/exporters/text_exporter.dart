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
    // 关键：清洗未配对 UTF-16 surrogate / 不可编码字符，避免
    // utf8.encode 抛 "Unexpected extension byte" 致整份 txt 导出失败。
    // Markdown 源文本理论上不应有 surrogate，但 WebView 桥接回 Dart
    // 的某些内容（嵌入的 SVG、Mermaid 提示文本等）可能残留。
    final safe = _sanitize(trimmed);
    return Uint8List.fromList(utf8.encode(safe));
  }

  /// 清洗字符串为可安全 utf8.encode 的 Dart String。
  /// 复用 word_exporter 的 _safeXml 策略的精简版。
  ///
  /// **关键**：用 `String.fromCharCodes` 一次性重建字符串（不是
  /// `String.fromCharCode` 逐字符）。后者对 rune > 0xFFFF 会截断为
  /// 低 16 位 → 产生孤立 surrogate → utf8.encode 抛 "Unexpected
  /// extension byte (at offset 1)"。Dart 的 fromCharCodes 会自动为
  /// 非 BMP 字符生成合法 surrogate pair。
  static String _sanitize(String s) {
    if (s.isEmpty) return s;
    final safeRunes = <int>[];
    for (final r in s.runes) {
      if (r >= 0xD800 && r <= 0xDFFF) {
        // 孤立 surrogate
        safeRunes.add(0xFFFD);
      } else if (r == 0xFFFE || r == 0xFFFF) {
        // Unicode noncharacter
        safeRunes.add(0xFFFD);
      } else if (r >= 0x00 && r < 0x20 && r != 0x09 && r != 0x0A && r != 0x0D) {
        // C0 控制字符
        safeRunes.add(0xFFFD);
      } else if (r == 0x7F) {
        // DEL
        safeRunes.add(0xFFFD);
      } else {
        safeRunes.add(r);
      }
    }
    final cleaned = String.fromCharCodes(safeRunes);
    try {
      final bytes = utf8.encode(cleaned);
      return utf8.decode(bytes, allowMalformed: true);
    } on FormatException {
      return '';
    }
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
