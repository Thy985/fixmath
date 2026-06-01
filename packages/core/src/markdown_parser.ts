import type {
  DocumentElement,
  InlineElement,
  HeadingElement,
  ParagraphElement,
  ListElement,
  CodeElement,
  BlockquoteElement,
  MermaidElement,
  EmptyLineElement,
  FormulaElement,
  TextElement,
} from './types';
import { extractFormulaFragments, normalizeLatex } from './formula_utils';

export function parseMarkdown(markdown: string): DocumentElement[] {
  const elements: DocumentElement[] = [];
  const lines = markdown.split('\n');
  let i = 0;

  while (i < lines.length) {
    const line = lines[i];
    const trimmed = line.trim();

    if (trimmed === '') {
      elements.push({ type: 'empty_line' } as EmptyLineElement);
      i++;
      continue;
    }

    if (trimmed.startsWith('```mermaid')) {
      const codeLines: string[] = [];
      i++;
      while (i < lines.length && !lines[i].trim().startsWith('```')) {
        codeLines.push(lines[i]);
        i++;
      }
      elements.push({
        type: 'mermaid',
        code: codeLines.join('\n'),
      } as MermaidElement);
      i++;
      continue;
    }

    if (trimmed.startsWith('```')) {
      const language = trimmed.slice(3).trim() || null;
      const codeLines: string[] = [];
      i++;
      while (i < lines.length && !lines[i].trim().startsWith('```')) {
        codeLines.push(lines[i]);
        i++;
      }
      elements.push({
        type: 'code',
        language,
        code: codeLines.join('\n'),
      } as CodeElement);
      i++;
      continue;
    }

    if (trimmed.startsWith('#')) {
      const match = trimmed.match(/^(#{1,6})\s+(.+)$/);
      if (match) {
        elements.push({
          type: 'heading',
          level: match[1].length,
          text: match[2],
        } as HeadingElement);
        i++;
        continue;
      }
    }

    if (trimmed.startsWith('>')) {
      elements.push({
        type: 'blockquote',
        text: trimmed.slice(1).trim(),
      } as BlockquoteElement);
      i++;
      continue;
    }

    if (trimmed.startsWith('- ') || trimmed.startsWith('* ') || /^\d+\.\s/.test(trimmed)) {
      const items: string[] = [];
      while (i < lines.length) {
        const itemLine = lines[i].trim();
        if (itemLine.startsWith('- ') || itemLine.startsWith('* ')) {
          items.push(itemLine.slice(2));
          i++;
        } else if (/^\d+\.\s/.test(itemLine)) {
          items.push(itemLine.replace(/^\d+\.\s/, ''));
          i++;
        } else {
          break;
        }
      }
      elements.push({
        type: 'list',
        items,
      } as ListElement);
      continue;
    }

    const children = parseInlineContent(trimmed);
    elements.push({
      type: 'paragraph',
      children,
    } as ParagraphElement);
    i++;
  }

  return elements;
}

function parseInlineContent(text: string): InlineElement[] {
  const elements: InlineElement[] = [];
  const normalized = normalizeLatex(text);
  const fragments = extractFormulaFragments(normalized);

  if (fragments.length === 0) {
    elements.push({ type: 'text', text: normalized } as TextElement);
    return elements;
  }

  let lastIndex = 0;
  for (const fragment of fragments) {
    const formulaPatterns = [
      `\\\[${fragment}\\\\]`,
      `\\$\\$${fragment}\\$\\$`,
      `\\\\(${fragment}\\\\)`,
      `\\$${fragment}\\$`,
    ];

    let formulaStart = -1;
    let formulaEnd = -1;
    let matchedPattern = '';

    for (const pattern of formulaPatterns) {
      const regex = new RegExp(pattern);
      const match = normalized.slice(lastIndex).match(regex);
      if (match && match.index !== undefined) {
        formulaStart = lastIndex + match.index;
        formulaEnd = formulaStart + match[0].length;
        matchedPattern = match[0];
        break;
      }
    }

    if (formulaStart === -1) continue;

    if (formulaStart > lastIndex) {
      const textBefore = normalized.slice(lastIndex, formulaStart);
      elements.push({ type: 'text', text: textBefore } as TextElement);
    }

    elements.push({ type: 'formula', latex: fragment } as FormulaElement);
    lastIndex = formulaEnd;
  }

  if (lastIndex < normalized.length) {
    elements.push({ type: 'text', text: normalized.slice(lastIndex) } as TextElement);
  }

  return elements;
}

export { normalizeLatex, extractFormulaFragments } from './formula_utils';
export type * from './types';
