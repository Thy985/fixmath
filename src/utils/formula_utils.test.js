import { describe, it, expect } from 'vitest';
import { normalizeLatex, extractFormulaFragments } from '../utils/formula_utils.js';

describe('normalizeLatex', () => {
  it('应该保留已有的 LaTeX 格式', () => {
    const input = '\\frac{a}{b}';
    const output = normalizeLatex(input);
    expect(output).toBe('\\frac{a}{b}');
  });

  it('应该处理混合内容中的公式', () => {
    const input = '令 $\\alpha = \\beta$，则有 $x$';
    const output = normalizeLatex(input);
    expect(output).toContain('$');
    expect(output).toContain('\\alpha');
  });

  it('应该处理行内公式 $...$', () => {
    const input = '$x^2 + y^2 = z^2$';
    const output = normalizeLatex(input);
    expect(output).toContain('$');
    expect(output).toContain('x^2');
  });

  it('应该处理块级公式 $$...$$', () => {
    const input = '$$E = mc^2$$';
    const output = normalizeLatex(input);
    expect(output).toContain('$$');
    expect(output).toContain('E = mc^2');
  });

  it('应该处理混合内容', () => {
    const input = '令 $\\alpha = \\beta$，则有 $$x = \\frac{-b \\pm \\sqrt{b^2-4ac}}{2a}$$';
    const output = normalizeLatex(input);
    expect(output).toContain('$');
    expect(output).toContain('$$');
  });

  it('应该处理空字符串', () => {
    expect(normalizeLatex('')).toBe('');
  });
});

describe('extractFormulaFragments', () => {
  it('应该提取单个行内公式', () => {
    const fragments = extractFormulaFragments('$x^2$');
    expect(fragments).toHaveLength(1);
    expect(fragments[0].content).toBe('x^2');
    expect(fragments[0].displayMode).toBe(false);
  });

  it('应该提取多个行内公式', () => {
    const fragments = extractFormulaFragments('$a$ 和 $b$');
    expect(fragments.length).toBeGreaterThanOrEqual(2);
    expect(fragments.some(f => f.content === 'a')).toBe(true);
    expect(fragments.some(f => f.content === 'b')).toBe(true);
  });

  it('应该提取块级公式 $$...$$', () => {
    const fragments = extractFormulaFragments('$$\\int_0^1 x dx$$');
    expect(fragments.some(f => f.content.includes('int'))).toBe(true);
    expect(fragments.some(f => f.displayMode === true)).toBe(true);
  });

  it('应该处理 \\[...\\] 格式', () => {
    const fragments = extractFormulaFragments('\\[\\sum_{i=1}^n i\\]');
    expect(fragments.length).toBeGreaterThan(0);
  });

  it('应该处理 \\(...\\) 格式', () => {
    const fragments = extractFormulaFragments('\\(\\frac{a}{b}\\)');
    expect(fragments.length).toBeGreaterThan(0);
  });

  it('应该提取有效的公式', () => {
    const fragments = extractFormulaFragments('$$E = mc^2$$ 和 $E = mc^2$');
    expect(fragments.some(f => f.type === 'formula')).toBe(true);
  });

  it('应该处理普通文本（返回文本片段）', () => {
    const fragments = extractFormulaFragments('这只是普通文本');
    expect(fragments.length).toBeGreaterThanOrEqual(1);
  });

  it('应该处理复杂的数学表达式', () => {
    const fragments = extractFormulaFragments('$\\frac{-b \\pm \\sqrt{b^2-4ac}}{2a}$');
    expect(fragments.length).toBe(1);
    expect(fragments[0].content).toContain('frac');
  });
});
