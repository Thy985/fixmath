/// BlockEditor 双向映射：source ↔ DocumentElement。
///
/// 实现两个顶层纯函数：
/// - [toElement]：单块 Markdown source + BlockType → [DocumentElement]
/// - [fromElement]：[DocumentElement] → 单块 Markdown source
///
/// 私有 [InlineSerializer] 类负责 8 类 [InlineElement] 的递归序列化。
///
/// 详见 ADR-0007 §1.3（Wrapping 而非 Flattening）+ §Phase 2.3。
///
/// **Round-trip 一致性边界**（docstring 标注，非 bit-perfect）：
/// - [TextElement] 含未配对 `*` / `_` / `` ` `` / `[` / `!` / `~` → 重解析时可能误识别
/// - [TableElement] cell 含 `|` → parser 用 `split('|')` 会误拆
/// - [CodeElement.code] 含 ``` ``` ``` → fence 冲突
/// - [CodeElement.language] 大小写不保（` ```MERMAID ``` ` round-trip 后变 `mermaid`）
library;

import '../../data/models/document.dart';
import '../parser/markdown_parser.dart';
import 'block_types.dart';

/// 单块解析：source + type → [DocumentElement]。
///
/// 按 [BlockType] 分派，对需要 inline 解析的类型调用 [MarkdownParser.parseInline]。
/// 不修改 AST 类型签名，与 [MarkdownParser.parse] 整篇解析的字段语义对齐。
DocumentElement toElement(String source, BlockType type) {
  switch (type) {
    case BlockType.heading:
      return _parseHeading(source);
    case BlockType.paragraph:
      return ParagraphElement(children: MarkdownParser.parseInline(source));
    case BlockType.listItem:
      return _parseListItem(source);
    case BlockType.taskListItem:
      return _parseTaskListItem(source);
    case BlockType.code:
      return _parseCode(source);
    case BlockType.table:
      return _parseTable(source);
    case BlockType.blockquote:
      return _parseBlockquote(source);
    case BlockType.mermaid:
      return _parseMermaid(source);
    case BlockType.horizontalRule:
      return const HorizontalRuleElement();
  }
}

/// 单块序列化：[DocumentElement] → Markdown source。
///
/// 9 类 [DocumentElement] 子类全覆盖（exhaustive switch）。
/// [EmptyLineElement] 不在 BlockEditor 范围，调用方需自行过滤。
String fromElement(DocumentElement element) {
  switch (element) {
    case HeadingElement(:final level, :final text):
      return '${'#' * level} $text';
    case ParagraphElement(:final children):
      return InlineSerializer.serialize(children);
    case ListElement(:final children, :final ordered, :final indent):
      final prefix = ordered ? '1. ' : '- ';
      return '${'  ' * indent}$prefix${InlineSerializer.serialize(children)}';
    case TaskListItemElement(:final children, :final checked, :final indent):
      final mark = checked ? 'x' : ' ';
      return '${'  ' * indent}- [$mark] ${InlineSerializer.serialize(children)}';
    case CodeElement(:final code, :final language):
      final lang = language ?? '';
      return '```$lang\n$code\n```';
    case TableElement(:final headers, :final rows):
      return _serializeTable(headers, rows);
    case BlockquoteElement(:final text):
      return '> $text';
    case MermaidElement(:final code):
      return '```mermaid\n$code\n```';
    case HorizontalRuleElement():
      return '---';
    case EmptyLineElement():
      // 不在 BlockEditor 范围（BlockType 不含 emptyLine）。
      // 调用方（Document ↔ List<Block> 层）应过滤 EmptyLineElement。
      throw ArgumentError(
        'EmptyLineElement is not serializable as a Block (it is a block separator)',
      );
  }
}

// ---------------------------------------------------------------------------
// toElement 内部实现
// ---------------------------------------------------------------------------

HeadingElement _parseHeading(String source) {
  final match = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(source);
  if (match == null) {
    // 非法 heading 源，降级为 level=1 + 原文
    return HeadingElement(level: 1, text: source);
  }
  return HeadingElement(
    level: match.group(1)!.length,
    text: match.group(2) ?? '',
  );
}

ListElement _parseListItem(String source) {
  // ^(\s*)([-*+]\s|\d+\.\s)([\s\S]*)$
  // 注：content 组用 [\s\S]* 而非 (.*)，以支持跨换行的多行列表源
  // （如自动续列表产生的 "- item\n- "）。(.*) 无法匹配内嵌 \n，
  // 会导致回退到"整段当文本"分支并重复前缀。
  final match = RegExp(r'^(\s*)([-*+]|\d+\.)\s+([\s\S]*)$').firstMatch(source);
  if (match == null) {
    // 非法 list 源，降级为无序 + 0 indent + 原文
    return ListElement(
      children: MarkdownParser.parseInline(source),
      ordered: false,
      indent: 0,
    );
  }
  final indent = match.group(1)!.length ~/ 2;
  final marker = match.group(2)!;
  final itemText = match.group(3) ?? '';
  return ListElement(
    children: MarkdownParser.parseInline(itemText),
    ordered: RegExp(r'^\d+\.$').hasMatch(marker),
    indent: indent,
  );
}

TaskListItemElement _parseTaskListItem(String source) {
  // ^(\s*)[-*+]\s\[(?: |x|X)\]\s(.*)$
  final match = RegExp(r'^(\s*)[-*+]\s\[( |x|X)\]\s+([\s\S]*)$').firstMatch(source);
  if (match == null) {
    // 非法 task list 源，降级为 unchecked + 原文
    return TaskListItemElement(
      children: MarkdownParser.parseInline(source),
      checked: false,
      indent: 0,
    );
  }
  final indent = match.group(1)!.length ~/ 2;
  final checked = match.group(2)! != ' ';
  final itemText = match.group(3) ?? '';
  return TaskListItemElement(
    children: MarkdownParser.parseInline(itemText),
    checked: checked,
    indent: indent,
  );
}

DocumentElement _parseCode(String source) {
  // ^```(\w*)\n([\s\S]*)\n```$
  final match = RegExp(r'^```(\w*)\n([\s\S]*)\n```$', dotAll: true).firstMatch(source);
  if (match == null) {
    // 非法 code 源，降级为无语言 + 原文
    return CodeElement(code: source, language: null);
  }
  final language = match.group(1)!;
  final code = match.group(2) ?? '';
  // 与 markdown_parser.dart:49 对齐：language.toLowerCase() == 'mermaid' → MermaidElement
  if (language.toLowerCase() == 'mermaid') {
    return MermaidElement(code: code);
  }
  return CodeElement(code: code, language: language.isEmpty ? null : language);
}

MermaidElement _parseMermaid(String source) {
  // mermaid block: ```mermaid\n...\n```
  final match = RegExp(r'^```mermaid\n([\s\S]*)\n```$', dotAll: true).firstMatch(source);
  if (match == null) {
    return MermaidElement(code: source);
  }
  return MermaidElement(code: match.group(1) ?? '');
}

TableElement _parseTable(String source) {
  final lines = source.split('\n');
  final dataRows = <List<String>>[];
  for (final line in lines) {
    if (_isTableSeparatorRow(line)) continue;
    final cells = _parseTableRow(line);
    if (cells != null && cells.isNotEmpty) {
      dataRows.add(cells);
    }
  }
  if (dataRows.isEmpty) {
    return const TableElement(headers: [], rows: []);
  }
  return TableElement(headers: dataRows.first, rows: dataRows.skip(1).toList());
}

BlockquoteElement _parseBlockquote(String source) {
  final match = RegExp(r'^>\s?(.*)$').firstMatch(source);
  if (match == null) {
    return BlockquoteElement(text: source);
  }
  return BlockquoteElement(text: (match.group(1) ?? '').trim());
}

bool _isTableSeparatorRow(String line) {
  if (!line.startsWith('|') || !line.endsWith('|')) return false;
  final inner = line.substring(1, line.length - 1);
  final cells = inner.split('|');
  for (final cell in cells) {
    final trimmed = cell.trim();
    if (trimmed.isEmpty) continue;
    if (!RegExp(r'^[-:]+$').hasMatch(trimmed)) {
      return false;
    }
  }
  return true;
}

List<String>? _parseTableRow(String line) {
  if (!line.startsWith('|') || !line.endsWith('|')) return null;
  final inner = line.substring(1, line.length - 1);
  if (inner.trim().isEmpty) return null;
  final cells = inner.split('|').map((s) => s.trim()).toList();
  if (cells.isEmpty || (cells.length == 1 && cells[0].isEmpty)) return null;
  return cells;
}

String _serializeTable(List<String> headers, List<List<String>> rows) {
  final buffer = StringBuffer();
  // header row
  buffer.write('|');
  buffer.write(headers.join('|'));
  buffer.writeln('|');
  // separator row
  buffer.write('|');
  buffer.write(headers.map((_) => '---').join('|'));
  buffer.writeln('|');
  // data rows
  for (final row in rows) {
    buffer.write('|');
    buffer.write(row.join('|'));
    buffer.writeln('|');
  }
  // 移除末尾换行
  final result = buffer.toString();
  return result.endsWith('\n') ? result.substring(0, result.length - 1) : result;
}

// ---------------------------------------------------------------------------
// InlineSerializer：8 类 InlineElement 递归序列化
// ---------------------------------------------------------------------------

/// 8 类 [InlineElement] 的递归序列化器。
///
/// 详见 ADR-0007 §1.3（Wrapping）+ data/models/document.dart。
class InlineSerializer {
  const InlineSerializer._();

  /// 把 [InlineElement] 列表序列化为 Markdown inline 文本。
  static String serialize(List<InlineElement> elements) {
    return elements.map(serializeOne).join();
  }

  /// 把单个 [InlineElement] 序列化为 Markdown inline 片段。
  static String serializeOne(InlineElement element) {
    return switch (element) {
      TextElement(:final text) => text,
      FormulaElement(:final latex, :final displayMode) =>
        displayMode ? '\$\$$latex\$\$' : '\$$latex\$',
      BoldElement(:final children) => '**${serialize(children)}**',
      ItalicElement(:final children) => '*${serialize(children)}*',
      StrikethroughElement(:final children) => '~~${serialize(children)}~~',
      InlineCodeElement(:final code) => '`$code`',
      LinkElement(:final text, :final url) => '[$text]($url)',
      ImageElement(:final alt, :final url) => '![$alt]($url)',
    };
  }
}
