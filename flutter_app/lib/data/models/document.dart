enum ElementType {
  heading,
  paragraph,
  list,
  code,
  table,
  blockquote,
  mermaid,
  emptyLine,
}

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
