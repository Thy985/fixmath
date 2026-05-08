import 'package:markdown/markdown.dart' as md;
import '../models/document.dart';
import 'formula_extractor.dart';

class MarkdownParser {
  static List<DocumentElement> parse(String content) {
    final List<DocumentElement> elements = [];
    
    if (content.isEmpty) return elements;

    final lines = content.split('\n');
    String currentParagraph = '';
    bool inCodeBlock = false;
    String? codeLanguage;

    void flushParagraph() {
      if (currentParagraph.trim().isNotEmpty) {
        final paragraphElements = _parseInlineContent(currentParagraph);
        elements.add(DocumentElement(
          type: ElementType.paragraph,
          content: currentParagraph,
          children: paragraphElements,
        ));
        currentParagraph = '';
      }
    }

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      if (line.startsWith('```')) {
        if (!inCodeBlock) {
          flushParagraph();
          inCodeBlock = true;
          codeLanguage = line.substring(3).trim();
        } else {
          inCodeBlock = false;
          codeLanguage = null;
        }
        continue;
      }

      if (inCodeBlock) {
        elements.add(DocumentElement(
          type: ElementType.code,
          content: line,
          attributes: {'language': codeLanguage},
        ));
        continue;
      }

      if (line.trim().isEmpty) {
        flushParagraph();
        elements.add(DocumentElement(
          type: 'empty_line',
          content: '',
        ));
        continue;
      }

      if (line.startsWith('#')) {
        flushParagraph();
        int level = 0;
        for (int j = 0; j < line.length && line[j] == '#'; j++) {
          level++;
        }
        final headingText = line.substring(level).trim();
        elements.add(DocumentElement(
          type: ElementType.heading,
          content: headingText,
          level: level,
        ));
        continue;
      }

      if (line.startsWith('- ') || line.startsWith('* ')) {
        flushParagraph();
        elements.add(DocumentElement(
          type: ElementType.list,
          content: line.substring(2).trim(),
        ));
        continue;
      }

      if (RegExp(r'^\d+\.\s').hasMatch(line)) {
        flushParagraph();
        final content = line.replaceFirst(RegExp(r'^\d+\.\s'), '');
        elements.add(DocumentElement(
          type: ElementType.list,
          content: content,
          attributes: {'ordered': true},
        ));
        continue;
      }

      if (line.startsWith('> ')) {
        flushParagraph();
        elements.add(DocumentElement(
          type: ElementType.blockquote,
          content: line.substring(2).trim(),
        ));
        continue;
      }

      if (line.startsWith('|')) {
        elements.add(DocumentElement(
          type: ElementType.table,
          content: line,
        ));
        continue;
      }

      currentParagraph += line + '\n';
    }

    flushParagraph();

    return elements;
  }

  static List<DocumentElement> _parseInlineContent(String text) {
    final List<DocumentElement> elements = [];
    final formulas = FormulaExtractor.extractFormulas(text);

    if (formulas.isEmpty) {
      elements.add(DocumentElement(
        type: ElementType.text,
        content: text.trim(),
      ));
      return elements;
    }

    int lastEnd = 0;
    for (final formula in formulas) {
      if (formula.start > lastEnd) {
        final textContent = text.substring(lastEnd, formula.start).trim();
        if (textContent.isNotEmpty) {
          elements.add(DocumentElement(
            type: ElementType.text,
            content: textContent,
          ));
        }
      }

      elements.add(DocumentElement(
        type: ElementType.formula,
        content: formula.latex,
        attributes: {'displayMode': formula.displayMode},
      ));

      lastEnd = formula.end;
    }

    if (lastEnd < text.length) {
      final remainingText = text.substring(lastEnd).trim();
      if (remainingText.isNotEmpty) {
        elements.add(DocumentElement(
          type: ElementType.text,
          content: remainingText,
        ));
      }
    }

    return elements;
  }
}
