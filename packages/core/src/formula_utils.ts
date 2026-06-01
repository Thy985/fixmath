import type { DocumentElement, InlineElement } from './types';

export const DELIMITER_PATTERNS = [
  { regex: /\\\[([\s\S]*?)\\\]/g, displayMode: true },
  { regex: /\$\$([\s\S]*?)\$\$/g, displayMode: true },
  { regex: /\\\(([\s\S]*?)\\\)/g, displayMode: false },
  { regex: /\$([^$\n]+?)\$/g, displayMode: false },
] as const;

export const COMMON_LATEX_COMMANDS: Record<string, string> = {
  '\\frac': '/',
  '\\dfrac': '/',
  '\\sqrt': '√',
  '\\sum': 'Σ',
  '\\prod': 'Π',
  '\\int': '∫',
  '\\infty': '∞',
  '\\alpha': 'α',
  '\\beta': 'β',
  '\\gamma': 'γ',
  '\\delta': 'δ',
  '\\pi': 'π',
  '\\theta': 'θ',
  '\\lambda': 'λ',
  '\\mu': 'μ',
  '\\sigma': 'σ',
  '\\phi': 'φ',
  '\\omega': 'ω',
  '\\pm': '±',
  '\\times': '×',
  '\\div': '÷',
  '\\leq': '≤',
  '\\geq': '≥',
  '\\neq': '≠',
  '\\approx': '≈',
  '\\equiv': '≡',
  '\\rightarrow': '→',
  '\\leftarrow': '←',
  '\\Rightarrow': '⇒',
  '\\Leftarrow': '⇐',
  '\\dots': '...',
  '\\cdots': '⋯',
  '\\ldots': '…',
};

export const GREEK_LETTERS: Record<string, string> = {
  '\\alpha': 'α', '\\beta': 'β', '\\gamma': 'γ', '\\delta': 'δ',
  '\\epsilon': 'ε', '\\zeta': 'ζ', '\\eta': 'η', '\\theta': 'θ',
  '\\iota': 'ι', '\\kappa': 'κ', '\\lambda': 'λ', '\\mu': 'μ',
  '\\nu': 'ν', '\\xi': 'ξ', '\\pi': 'π', '\\rho': 'ρ',
  '\\sigma': 'σ', '\\tau': 'τ', '\\upsilon': 'υ', '\\phi': 'φ',
  '\\chi': 'χ', '\\psi': 'ψ', '\\omega': 'ω',
  '\\Gamma': 'Γ', '\\Delta': 'Δ', '\\Theta': 'Θ', '\\Lambda': 'Λ',
  '\\Xi': 'Ξ', '\\Pi': 'Π', '\\Sigma': 'Σ', '\\Phi': 'Φ',
  '\\Psi': 'Ψ', '\\Omega': 'Ω',
};

export function normalizeLatex(text: string): string {
  let result = text;
  for (const [cmd, symbol] of Object.entries(GREEK_LETTERS)) {
    result = result.replace(new RegExp(cmd.replace(/\\/g, '\\\\'), 'g'), symbol);
  }
  for (const [cmd, replacement] of Object.entries(COMMON_LATEX_COMMANDS)) {
    result = result.replace(new RegExp(cmd.replace(/\\/g, '\\\\'), 'g'), replacement);
  }
  return result;
}

export function extractFormulaFragments(text: string): string[] {
  const fragments: string[] = [];
  for (const pattern of DELIMITER_PATTERNS) {
    let match;
    const regex = new RegExp(pattern.regex.source, 'g');
    while ((match = regex.exec(text)) !== null) {
      fragments.push(match[1].trim());
    }
  }
  return fragments;
}
