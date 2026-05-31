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
  final String text;
  final bool ordered;

  const ListElement({required this.text, this.ordered = false});
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
