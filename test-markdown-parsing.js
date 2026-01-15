// 测试Markdown解析功能
import { parseMarkdown } from './src/utils/converter.js';

async function testMarkdownParsing() {
  console.log('=== 测试Markdown解析功能 ===\n');

  // 测试用例1：简单的Markdown内容
  const test1 = `# 标题1

这是一个段落，包含行内公式：\\( \\frac{1}{2} \\)。

## 标题2

这是一个块级公式：
\\[
\\int_{0}^{1} x^2 \\, dx
\\]

另一个段落。`;

  console.log('测试1：简单的Markdown内容');
  console.log('输入：', test1);
  try {
    const result1 = await parseMarkdown(test1);
    console.log('解析结果：', JSON.stringify(result1, null, 2));
    console.log('✓ 测试1通过\n');
  } catch (error) {
    console.error('✗ 测试1失败：', error.message, '\n');
  }

  // 测试用例2：包含选择题的Markdown
  const test2 = `1. 设函数 \\( f(x) = \\begin{cases} x^2 \\sin\\dfrac{1}{x}, & x \\neq 0 \\\\ 0, & x = 0 \\end{cases} \\)，则 \\( f(x) \\) 在点 \\( x = 0 \\) 处（　　）。

- A. 不连续
- B. 连续但不可导
- C. 可导但导数不连续
- D. 连续且可导`;

  console.log('测试2：包含选择题的Markdown');
  console.log('输入：', test2);
  try {
    const result2 = await parseMarkdown(test2);
    console.log('解析结果：', JSON.stringify(result2, null, 2));
    console.log('✓ 测试2通过\n');
  } catch (error) {
    console.error('✗ 测试2失败：', error.message, '\n');
  }

  // 测试用例3：混合使用不同定界符
  const test3 = `# 混合定界符测试

行内公式1：\\( \\frac{1}{2} \\)
行内公式2：$ \\frac{1}{2} $

块级公式1：
\\[
\\int_{0}^{\\pi} \\sin^2 x \\, dx
\\]

块级公式2：
$$
\\int_{0}^{\\pi} \\sin^2 x \\, dx
$$`;

  console.log('测试3：混合使用不同定界符');
  console.log('输入：', test3);
  try {
    const result3 = await parseMarkdown(test3);
    console.log('解析结果：', JSON.stringify(result3, null, 2));
    console.log('✓ 测试3通过\n');
  } catch (error) {
    console.error('✗ 测试3失败：', error.message, '\n');
  }

  // 测试用例4：试卷内容
  const test4 = `# 聊城大学《高等数学（一）》期末模拟试题

## 一、 单项选择题

1. 设函数 \\( f(x) = \\begin{cases} x^2 \\sin\\dfrac{1}{x}, & x \\neq 0 \\\\ 0, & x = 0 \\end{cases} \\)，则 \\( f(x) \\) 在点 \\( x = 0 \\) 处（　　）。
   - A. 不连续
   - B. 连续但不可导
   - C. 可导但导数不连续
   - D. 连续且可导

2. 已知 \\( \\displaystyle\\lim_{x \\to 0} \\frac{f(x)}{x} = 1 \\)，则当 \\( x \\to 0 \\) 时，函数 \\( f(x) \\) 是无穷小量，且（　　）。
   - A. 比 \\( x \\) 高阶
   - B. 比 \\( x \\) 低阶
   - C. 与 \\( x \\) 同阶但不等价
   - D. 与 \\( x \\) 等价

## 二、 填空题

1. 设函数 \\( f(x) = \\begin{cases} x^2, & x \\le 0 \\\\ e^x - 1, & x > 0 \\end{cases} \\)，则 \\( f(x) \\) 在 \\( x = 0 \\) 处的右导数 \\( f'_+(0) = \\) ______。

2. 若极限 \\( \\displaystyle\\lim_{x \\to 0} \\frac{\\ln(1 + ax)}{x} = 2 \\)，则常数 \\( a = \\) ______。

## 三、 计算题

1. **（极限计算）**
   求极限：\\( \\displaystyle\\lim_{x \\to 0} \\frac{e^x - \\cos x - x}{x^2} \\)。

2. **（不定积分）**
   计算不定积分：\\( \\displaystyle\\int \\frac{2x+3}{x^2+3x-10} \\, dx \\)。`;

  console.log('测试4：试卷内容');
  console.log('输入：', test4);
  try {
    const result4 = await parseMarkdown(test4);
    console.log('解析结果：', JSON.stringify(result4, null, 2));
    console.log('✓ 测试4通过\n');
  } catch (error) {
    console.error('✗ 测试4失败：', error.message, '\n');
  }

  console.log('=== 测试完成 ===');
}

testMarkdownParsing();
