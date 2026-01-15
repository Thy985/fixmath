// 测试converter.js中的公式识别功能
const { extractFormulaFragments } = require('./src/utils/converter.js');

console.log('=== 测试公式识别功能 ===\n');

// 测试用例1：使用\( \)的行内公式
const test1 = '这是一个行内公式：\\( \\frac{1 - \\cos x}{x^2} \\)，它应该被正确识别。';
console.log('测试1：使用\\( \\)的行内公式');
console.log('输入：', test1);
const result1 = extractFormulaFragments(test1);
console.log('输出：', result1);
console.log('识别到的公式数量：', result1.formulas.length);
console.log();

// 测试用例2：使用\[ \]的块级公式
const test2 = '这是一个块级公式：\\[ \\lim_{x \\to 0} \\frac{\\ln(1 + x)}{\\sin x} \\]';
console.log('测试2：使用\\[ \\]的块级公式');
console.log('输入：', test2);
const result2 = extractFormulaFragments(test2);
console.log('输出：', result2);
console.log('识别到的公式数量：', result2.formulas.length);
console.log();

// 测试用例3：混合使用不同定界符
const test3 = '行内公式：\\( \\int_{0}^{\\pi} \\sin^2 x \\, dx \\) 和 $ \\frac{dy}{dx} $ 都应该被识别。\\[ \\int_{-1}^{1} \\frac{x^2}{\\sqrt{1 - x^2}} \\, dx \\]';
console.log('测试3：混合使用不同定界符');
console.log('输入：', test3);
const result3 = extractFormulaFragments(test3);
console.log('输出：', result3);
console.log('识别到的公式数量：', result3.formulas.length);
console.log('识别到的公式：');
result3.formulas.forEach((formula, index) => {
    console.log(`  ${index + 1}. ${formula}`);
});
console.log();

// 测试用例4：试卷中的实际公式
const test4 = '设函数 \\( f(x) = \\begin{cases} x^2 \\sin\\dfrac{1}{x}, & x \\neq 0 \\\\ 0, & x = 0 \\end{cases} \\)，则 \\( f(x) \\) 在点 \\( x = 0 \\) 处可导。';
console.log('测试4：试卷中的实际公式');
console.log('输入：', test4);
const result4 = extractFormulaFragments(test4);
console.log('输出：', result4);
console.log('识别到的公式数量：', result4.formulas.length);
console.log('识别到的公式：');
result4.formulas.forEach((formula, index) => {
    console.log(`  ${index + 1}. ${formula}`);
});
console.log();

// 测试用例5：选择题中的公式
const test5 = '1. 设函数 \\( f(x) = \\begin{cases} x^2 \\sin\\dfrac{1}{x}, & x \\neq 0 \\\\ 0, & x = 0 \\end{cases} \\)，则 \\( f(x) \\) 在点 \\( x = 0 \\) 处（　　）。';
console.log('测试5：选择题中的公式');
console.log('输入：', test5);
const result5 = extractFormulaFragments(test5);
console.log('输出：', result5);
console.log('识别到的公式数量：', result5.formulas.length);
console.log('识别到的公式：');
result5.formulas.forEach((formula, index) => {
    console.log(`  ${index + 1}. ${formula}`);
});
console.log();

console.log('=== 测试完成 ===');
