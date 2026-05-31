import '../../data/models/document.dart';
import 'formula_extractor.dart';

class MarkdownParser {
  static List<DocumentElement> parse(String content) {
    if (content.isEmpty) return [];

    final List<DocumentElement> elements = [];
    final lines = content.split('\n');

    bool inCodeBlock = false;
    String? codeLanguage;
    final List<String> codeLines = [];

    void flushCodeBlock() {
      if (codeLines.isEmpty) return;
      final code = codeLines.join('\n');
      if (codeLanguage?.toLowerCase() == 'mermaid') {
        elements.add(MermaidElement(code: code));
      } else {
        elements.add(CodeElement(code: code, language: codeLanguage));
      }
      codeLines.clear();
    }

    ParagraphElement? pendingParagraph;
    void flushParagraph() {
      if (pendingParagraph != null) {
        elements.add(pendingParagraph!);
        pendingParagraph = null;
      }
    }

    for (final line in lines) {
      if (line.startsWith('```')) {
        if (!inCodeBlock) {
          flushParagraph();
          inCodeBlock = true;
          codeLanguage = line.substring(3).trim();
        } else {
          inCodeBlock = false;
          flushCodeBlock();
        }
        continue;
      }

      if (inCodeBlock) {
        codeLines.add(line);
        continue;
      }

      if (line.trim().isEmpty) {
        flushParagraph();
        elements.add(const EmptyLineElement());
        continue;
      }

      if (line.startsWith('#')) {
        flushParagraph();
        int level = 0;
        while (level < line.length && line[level] == '#') level++;
        elements.add(HeadingElement(
          level: level,
          text: line.substring(level).trim(),
        ));
        continue;
      }

      if (line.startsWith('- ') || line.startsWith('* ')) {
        flushParagraph();
        elements.add(ListElement(text: line.substring(2).trim()));
        continue;
      }

      if (RegExp(r'^\d+\.\s').hasMatch(line)) {
        flushParagraph();
        elements.add(ListElement(
          text: line.replaceFirst(RegExp(r'^\d+\.\s'), ''),
          ordered: true,
        ));
        continue;
      }

      if (line.startsWith('> ')) {
        flushParagraph();
        elements.add(BlockquoteElement(text: line.substring(2).trim()));
        continue;
      }

      if (line.startsWith('|')) {
        flushParagraph();
        final table = _parseTableLine(line);
        if (table != null) elements.add(table);
        continue;
      }

      pendingParagraph ??= ParagraphElement(children: []);
      final inline = _parseInline(line);
      pendingParagraph!.children.addAll(inline);
    }

    if (inCodeBlock) flushCodeBlock();
    flushParagraph();

    return elements;
  }

  static List<InlineElement> _parseInline(String text) {
    final List<InlineElement> elements = [];
    final formulas = FormulaExtractor.extractFormulas(text);

    if (formulas.isEmpty) {
      if (text.trim().isNotEmpty) {
        elements.add(TextElement(text.trim()));
      }
      return elements;
    }

    int lastEnd = 0;
    for (final formula in formulas) {
      if (formula.start > lastEnd) {
        final textContent = text.substring(lastEnd, formula.start).trim();
        if (textContent.isNotEmpty) {
          elements.add(TextElement(textContent));
        }
      }
      elements.add(FormulaElement(
        latex: formula.latex,
        displayMode: formula.displayMode,
      ));
      lastEnd = formula.end;
    }

    if (lastEnd < text.length) {
      final remaining = text.substring(lastEnd).trim();
      if (remaining.isNotEmpty) {
        elements.add(TextElement(remaining));
      }
    }

    return elements;
  }

  static TableElement? _parseTableLine(String line) {
    final cells = line.split('|').where((s) => s.trim().isNotEmpty).toList();
    if (cells.isEmpty) return null;
    return TableElement(headers: cells.map((c) => c.trim()).toList(), rows: []);
  }
}
