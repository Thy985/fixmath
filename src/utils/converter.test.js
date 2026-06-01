import { describe, it, expect, beforeEach, vi } from 'vitest';
import { convertToPdf, convertToDocx } from '../utils/converter.js';

vi.mock('html2canvas', () => ({
  default: vi.fn(() => Promise.resolve({
    toDataURL: () => 'data:image/png;base64,mock',
  })),
}));

vi.mock('html2pdf.js', () => ({
  default: vi.fn(() => ({
    set: vi.fn().mockReturnThis(),
    from: vi.fn().mockReturnThis(),
    output: vi.fn().mockResolvedValue(new Blob(['pdf content'], { type: 'application/pdf' })),
  })),
}));

describe('convertToPdf', () => {
  it('应该对空输入抛出错误', async () => {
    await expect(convertToPdf('', 'markdown')).rejects.toThrow('输入内容不能为空');
    await expect(convertToPdf(null, 'markdown')).rejects.toThrow('输入内容不能为空');
  });

  it('应该成功转换 Markdown 纯文本', async () => {
    const result = await convertToPdf('Hello World', 'markdown');
    expect(result).toBeInstanceOf(Blob);
    expect(result.type).toBe('application/pdf');
  });

  it('应该成功转换 Markdown 标题', async () => {
    const result = await convertToPdf('# 一级标题\n## 二级标题', 'markdown');
    expect(result).toBeInstanceOf(Blob);
  });

  it('应该成功转换 Markdown 列表', async () => {
    const result = await convertToPdf('- 项目1\n- 项目2', 'markdown');
    expect(result).toBeInstanceOf(Blob);
  });

  it('应该成功转换 Markdown 引用', async () => {
    const result = await convertToPdf('> 这是一段引用', 'markdown');
    expect(result).toBeInstanceOf(Blob);
  });

  it('应该成功转换 Markdown 代码块', async () => {
    const result = await convertToPdf('```python\nprint("hello")\n```', 'markdown');
    expect(result).toBeInstanceOf(Blob);
  });

  it('应该处理带空行的多段落', async () => {
    const result = await convertToPdf('# 标题\n\n正文第一段\n\n正文第二段', 'markdown');
    expect(result).toBeInstanceOf(Blob);
  });

  it('应该处理混合内容', async () => {
    const markdown = `# 文档标题

这是一段**加粗**和*斜体*的正文。

- 列表项1
- 列表项2

> 引用内容

\`\`\`javascript
const x = 1;
\`\`\`

更多正文内容。`;

    const result = await convertToPdf(markdown, 'markdown');
    expect(result).toBeInstanceOf(Blob);
  });
});

describe('convertToDocx', () => {
  it('应该对空输入抛出错误', async () => {
    await expect(convertToDocx('', 'markdown')).rejects.toThrow('输入内容不能为空');
    await expect(convertToDocx(null, 'markdown')).rejects.toThrow('输入内容不能为空');
  });

  it('应该成功转换 Markdown 纯文本', async () => {
    const result = await convertToDocx('Hello World', 'markdown');
    expect(result).toBeInstanceOf(Blob);
    expect(result.type).toBe('application/vnd.openxmlformats-officedocument.wordprocessingml.document');
  });

  it('应该成功转换 Markdown 标题', async () => {
    const result = await convertToDocx('# 一级标题\n## 二级标题', 'markdown');
    expect(result).toBeInstanceOf(Blob);
  });

  it('应该成功转换 Markdown 段落', async () => {
    const result = await convertToDocx('这是普通段落文本', 'markdown');
    expect(result).toBeInstanceOf(Blob);
  });

  it('应该处理带空行的多段落', async () => {
    const result = await convertToDocx('第一段\n\n第二段', 'markdown');
    expect(result).toBeInstanceOf(Blob);
  });

  it('应该成功转换 LaTeX 内容', async () => {
    const result = await convertToDocx('$x^2 + y^2 = z^2$', 'latex');
    expect(result).toBeInstanceOf(Blob);
  });
});

describe('PDF/DOCX 格式验证', () => {
  it('PDF 应该生成有效的 Blob', async () => {
    const result = await convertToPdf('Test Content', 'markdown');
    expect(result.size).toBeGreaterThan(0);
    expect(result.type).toContain('pdf');
  });

  it('DOCX 应该生成有效的 Blob', async () => {
    const result = await convertToDocx('Test Content', 'markdown');
    expect(result.size).toBeGreaterThan(0);
    expect(result.type).toContain('document');
  });
});
