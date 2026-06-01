export interface HeadingElement {
  type: 'heading';
  level: number;
  text: string;
}

export interface ParagraphElement {
  type: 'paragraph';
  children: InlineElement[];
}

export interface ListElement {
  type: 'list';
  items: string[];
}

export interface CodeElement {
  type: 'code';
  language: string | null;
  code: string;
}

export interface BlockquoteElement {
  type: 'blockquote';
  text: string;
}

export interface MermaidElement {
  type: 'mermaid';
  code: string;
}

export interface EmptyLineElement {
  type: 'empty_line';
}

export interface FormulaElement {
  type: 'formula';
  latex: string;
}

export interface TextElement {
  type: 'text';
  text: string;
}

export type InlineElement = FormulaElement | TextElement;

export type DocumentElement =
  | HeadingElement
  | ParagraphElement
  | ListElement
  | CodeElement
  | BlockquoteElement
  | MermaidElement
  | EmptyLineElement;
