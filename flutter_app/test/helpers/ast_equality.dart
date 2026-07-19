/// AST 等价性比较 helper（测试专用）。
///
/// 用于 BlockEditor round-trip 测试判定（ADR-0007 §Phase 2.3）：
/// `parse(source) == parse(fromElement(toElement(source, type)))`
///
/// Markdown 不是 canonical 形式（`*hello*` 与 `_hello_` 字符串不等但 AST 等价），
/// 故 round-trip 判定必须基于 AST equivalence 而非字符串等价。
///
/// 本文件仅用于 test/，不放入 lib/。
library;

import 'package:formula_fix/data/models/document.dart';

/// 递归比较两个 [DocumentElement] AST 是否等价。
bool astDeepEquals(DocumentElement a, DocumentElement b) {
  if (a.runtimeType != b.runtimeType) return false;
  return switch (a) {
    HeadingElement(:final level, :final text) =>
      b is HeadingElement && b.level == level && b.text == text,
    ParagraphElement(:final children) =>
      b is ParagraphElement &&
      children.length == b.children.length &&
      inlineListEquals(children, b.children),
    ListElement(:final children, :final ordered, :final indent) =>
      b is ListElement &&
      b.ordered == ordered &&
      b.indent == indent &&
      children.length == b.children.length &&
      inlineListEquals(children, b.children),
    TaskListItemElement(:final children, :final checked, :final indent) =>
      b is TaskListItemElement &&
      b.checked == checked &&
      b.indent == indent &&
      children.length == b.children.length &&
      inlineListEquals(children, b.children),
    CodeElement(:final code, :final language) =>
      b is CodeElement && b.code == code && b.language == language,
    TableElement(:final headers, :final rows) =>
      b is TableElement &&
      stringListEquals(headers, b.headers) &&
      rows.length == b.rows.length &&
      stringListListEquals(rows, b.rows),
    BlockquoteElement(:final text) =>
      b is BlockquoteElement && b.text == text,
    MermaidElement(:final code) =>
      b is MermaidElement && b.code == code,
    HorizontalRuleElement() => b is HorizontalRuleElement,
    EmptyLineElement() => b is EmptyLineElement,
  };
}

/// 比较两个 [InlineElement] 列表是否逐项等价。
bool inlineListEquals(List<InlineElement> a, List<InlineElement> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (!inlineDeepEquals(a[i], b[i])) return false;
  }
  return true;
}

/// 递归比较两个 [InlineElement] 是否等价。
bool inlineDeepEquals(InlineElement a, InlineElement b) {
  if (a.runtimeType != b.runtimeType) return false;
  return switch (a) {
    TextElement(:final text) => b is TextElement && b.text == text,
    FormulaElement(:final latex, :final displayMode) =>
      b is FormulaElement && b.latex == latex && b.displayMode == displayMode,
    BoldElement(:final children) =>
      b is BoldElement && inlineListEquals(children, b.children),
    ItalicElement(:final children) =>
      b is ItalicElement && inlineListEquals(children, b.children),
    StrikethroughElement(:final children) =>
      b is StrikethroughElement && inlineListEquals(children, b.children),
    InlineCodeElement(:final code) =>
      b is InlineCodeElement && b.code == code,
    LinkElement(:final text, :final url) =>
      b is LinkElement && b.text == text && b.url == url,
    ImageElement(:final alt, :final url) =>
      b is ImageElement && b.alt == alt && b.url == url,
  };
}

/// 比较两个 `List<String>` 是否相等。
bool stringListEquals(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// 比较两个 `List<List<String>>` 是否相等。
bool stringListListEquals(List<List<String>> a, List<List<String>> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (!stringListEquals(a[i], b[i])) return false;
  }
  return true;
}
