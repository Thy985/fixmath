import type { DocumentElement } from './types';
import { normalizeLatex } from './formula_utils';

export interface ExportOptions {
  includeEmptyLines?: boolean;
  codeLanguageLabel?: boolean;
}

export function toPlainText(elements: DocumentElement[], options: ExportOptions = {}): string {
  const { includeEmptyLines = false } = options;
  const lines: string[] = [];

  for (const element of elements) {
    const line = renderElementToText(element);
    if (line === '' && !includeEmptyLines) continue;
    lines.push(line);
  }

  let result = lines.join('\n');
  if (result.endsWith('\n')) {
    result = result.slice(0, -1);
  }
  return result;
}

function renderElementToText(element: DocumentElement): string {
  switch (element.type) {
    case 'heading':
      return `${'#'.repeat(element.level)} ${element.text}`;

    case 'paragraph':
      return element.children
        .map((child) => {
          if (child.type === 'formula') return normalizeLatex(child.latex);
          return child.text;
        })
        .join('');

    case 'list':
      return element.items.map((item) => `• ${item}`).join('\n');

    case 'code':
      return `\`\`\`${element.language || ''}\n${element.code}\n\`\`\``;

    case 'blockquote':
      return `> ${element.text}`;

    case 'mermaid':
      return `\`\`\`mermaid\n${element.code}\n\`\`\``;

    case 'empty_line':
      return '';

    default:
      return '';
  }
}
