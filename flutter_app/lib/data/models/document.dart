class ElementType {
  static const String text = 'text';
  static const String formula = 'formula';
  static const String heading = 'heading';
  static const String list = 'list';
  static const String code = 'code';
  static const String table = 'table';
  static const String blockquote = 'blockquote';
  static const String mermaid = 'mermaid';
}

class DocumentElement {
  final String type;
  final String content;
  final Map<String, dynamic>? attributes;
  final List<DocumentElement>? children;
  final int level;

  DocumentElement({
    required this.type,
    required this.content,
    this.attributes,
    this.children,
    this.level = 0,
  });

  bool get isFormula => type == ElementType.formula;
  bool get isText => type == ElementType.text;
  bool get isHeading => type == ElementType.heading;
}

class FormulaMatch {
  final String latex;
  final int start;
  final int end;
  final bool displayMode;

  FormulaMatch({
    required this.latex,
    required this.start,
    required this.end,
    required this.displayMode,
  });
}

class Document {
  final String id;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;

  Document({
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
