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

    final List<ListElement> pendingListItems = [];

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

    void flushListItems() {
      if (pendingListItems.isEmpty) return;
      for (final item in pendingListItems) {
        elements.add(item);
      }
      pendingListItems.clear();
    }

    int getIndent(String line) {
      int indent = 0;
      for (int i = 0; i < line.length; i++) {
        if (line[i] == ' ') {
          indent++;
        } else if (line[i] == '\t') {
          indent += 4;
        } else {
          break;
        }
      }
      return indent ~/ 2;
    }

    TableElement? currentTable;
    void flushTable() {
      if (currentTable != null) {
        elements.add(currentTable!);
        currentTable = null;
      }
    }

    for (int lineIndex = 0; lineIndex < lines.length; lineIndex++) {
      final line = lines[lineIndex];

      if (line.startsWith('```')) {
        if (!inCodeBlock) {
          flushParagraph();
          flushListItems();
          flushTable();
          inCodeBlock = true;
          codeLanguage = line.length > 3 ? line.substring(3).trim() : '';
        } else {
          inCodeBlock = false;
          flushCodeBlock();
          codeLanguage = null;
        }
        continue;
      }

      if (inCodeBlock) {
        codeLines.add(line);
        continue;
      }

      if (line.trim().isEmpty) {
        flushParagraph();
        flushListItems();
        flushTable();
        elements.add(const EmptyLineElement());
        continue;
      }

      if (line.startsWith('#')) {
        flushParagraph();
        flushListItems();
        flushTable();
        int level = 0;
        int i = 0;
        while (i < line.length && line[i] == '#') {
          level++;
          i++;
        }
        elements.add(HeadingElement(
          level: level,
          text: line.substring(level).trim(),
        ));
        continue;
      }

      final trimmedLine = line.trim();
      if (trimmedLine.startsWith('- ') || trimmedLine.startsWith('* ') || 
          trimmedLine.startsWith('+ ') || RegExp(r'^\d+\.\s').hasMatch(trimmedLine)) {
        flushParagraph();
        flushTable();
        
        final indent = getIndent(line);
        final isOrdered = RegExp(r'^\d+\.\s').hasMatch(trimmedLine);
        String itemText;
        
        if (isOrdered) {
          itemText = trimmedLine.replaceFirst(RegExp(r'^\d+\.\s'), '');
        } else {
          itemText = trimmedLine.substring(2);
        }
        
        if (indent > 0 && pendingListItems.isNotEmpty) {
          final lastItem = pendingListItems.removeLast();
          itemText = '${lastItem.text}\n${'  ' * indent}$itemText';
          pendingListItems.add(ListElement(text: itemText, ordered: lastItem.ordered, indent: indent));
        } else {
          pendingListItems.add(ListElement(text: itemText, ordered: isOrdered, indent: indent));
        }
        continue;
      }

      if (trimmedLine.startsWith('> ')) {
        flushParagraph();
        flushListItems();
        flushTable();
        elements.add(BlockquoteElement(text: trimmedLine.substring(2).trim()));
        continue;
      }

      if (trimmedLine.startsWith('|')) {
        flushParagraph();
        flushListItems();
        
        if (_isTableSeparatorRow(trimmedLine)) {
          continue;
        }
        
        final cells = _parseTableRow(trimmedLine);
        if (cells != null && cells.isNotEmpty) {
          if (currentTable == null) {
            currentTable = TableElement(headers: cells, rows: []);
          } else {
            currentTable!.rows.add(cells);
          }
        }
        continue;
      } else if (currentTable != null) {
        flushTable();
      }

      pendingParagraph ??= ParagraphElement(children: []);
      final inline = _parseInline(trimmedLine);
      pendingParagraph!.children.addAll(inline);
    }

    if (inCodeBlock && codeLines.isNotEmpty) {
      elements.add(CodeElement(code: codeLines.join('\n'), language: codeLanguage));
    }
    flushParagraph();
    flushListItems();
    flushTable();

    return elements;
  }

  static bool _isTableSeparatorRow(String line) {
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

  static List<String>? _parseTableRow(String line) {
    if (!line.startsWith('|') || !line.endsWith('|')) return null;
    
    final inner = line.substring(1, line.length - 1);
    if (inner.trim().isEmpty) return null;
    
    final cells = inner.split('|').map((s) => s.trim()).toList();
    if (cells.isEmpty || (cells.length == 1 && cells[0].isEmpty)) return null;
    
    return cells;
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
}
