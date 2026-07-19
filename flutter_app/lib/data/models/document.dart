sealed class DocumentElement {
  const DocumentElement();
}

class HeadingElement extends DocumentElement {
  final int level;
  final String text;

  const HeadingElement({required this.level, required this.text});
}

class ParagraphElement extends DocumentElement {
  final List<InlineElement> children;

  const ParagraphElement({required this.children});
}

class ListElement extends DocumentElement {
  final List<InlineElement> children;
  final bool ordered;
  final int indent;

  const ListElement({
    required this.children,
    this.ordered = false,
    this.indent = 0,
  });
}

class CodeElement extends DocumentElement {
  final String code;
  final String? language;

  const CodeElement({required this.code, this.language});
}

class TableElement extends DocumentElement {
  final List<String> headers;
  final List<List<String>> rows;

  const TableElement({required this.headers, required this.rows});
}

class BlockquoteElement extends DocumentElement {
  final String text;

  const BlockquoteElement({required this.text});
}

class MermaidElement extends DocumentElement {
  final String code;

  const MermaidElement({required this.code});
}

class EmptyLineElement extends DocumentElement {
  const EmptyLineElement();
}

/// Markdown 任务列表项（- [ ] / - [x]）。
///
/// [checked] 表示是否勾选；[indent] 为嵌套层级（2 空格 = 1 级）；
/// [children] 为行内内容，可含加粗 / 公式等。
class TaskListItemElement extends DocumentElement {
  final List<InlineElement> children;
  final bool checked;
  final int indent;

  const TaskListItemElement({
    required this.children,
    this.checked = false,
    this.indent = 0,
  });
}

/// 水平分割线（--- / *** / ___）。无参数。
class HorizontalRuleElement extends DocumentElement {
  const HorizontalRuleElement();
}

sealed class InlineElement {
  const InlineElement();
}

class TextElement extends InlineElement {
  final String text;
  const TextElement(this.text);
}

class FormulaElement extends InlineElement {
  final String latex;
  final bool displayMode;

  const FormulaElement({required this.latex, this.displayMode = false});
}

class BoldElement extends InlineElement {
  final List<InlineElement> children;

  const BoldElement({required this.children});
}

/// 斜体（*text* / _text_）。内层可嵌套加粗 / 公式等 inline 元素。
class ItalicElement extends InlineElement {
  final List<InlineElement> children;

  const ItalicElement({required this.children});
}

/// 删除线（~~text~~）。内层可嵌套其他 inline 元素。
class StrikethroughElement extends InlineElement {
  final List<InlineElement> children;

  const StrikethroughElement({required this.children});
}

/// 行内代码（`code`）。内容为字面量，不再递归解析。
class InlineCodeElement extends InlineElement {
  final String code;

  const InlineCodeElement(this.code);
}

/// 行内链接（[text](url)）。text 为显示文本，url 为目标地址。
class LinkElement extends InlineElement {
  final String text;
  final String url;

  const LinkElement({required this.text, required this.url});
}

/// 行内图片（![alt](url)）。alt 为替代文本，url 为图片地址。
class ImageElement extends InlineElement {
  final String alt;
  final String url;

  const ImageElement({required this.alt, required this.url});
}

class Document {
  final String id;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Document({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });

  Document copyWith({
    String? id,
    String? title,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Document(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
