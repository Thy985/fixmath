// 测试公式识别功能
const { normalizeLatex, extractFormulaFragments } = require('./src/utils/converter.js');

// 测试用例
const testCases = [
  {
    name: '带$定界符的行内公式',
    input: '$\\frac{1 - \\cos x}{x^2}$',
    expected: '公式应该被正确识别'
  },
  {
    name: '不带$定界符的公式',
    input: '\\frac{1 - \\cos x}{x^2}',
    expected: '公式应该被正确识别'
  },
  {
    name: '简化形式的公式',
    input: 'frac{1 - cos x}{x^2}',
    expected: '公式应该被正确规范化并识别'
  },
  {
    name: '极限公式',
    input: 'lim_{h to 0} frac{f(a+2h)-f(a)}{h}',
    expected: '极限公式应该被正确识别'
  },
  {
    name: '带下划线的命令',
    input: 'lim_h',
    expected: '带下划线的命令应该被正确处理'
  }
];

console.log('开始测试公式识别功能...\n');

testCases.forEach((testCase, index) => {
  console.log(`测试用例 ${index + 1}: ${testCase.name}`);
  console.log(`输入: ${testCase.input}`);
  
  try {
    // 测试规范化
    const normalized = normalizeLatex(testCase.input);
    console.log(`规范化后: ${normalized}`);
    
    // 测试公式片段提取
    const fragments = extractFormulaFragments(normalized);
    console.log(`提取的片段: ${JSON.stringify(fragments, null, 2)}`);
    
    // 检查是否提取到公式
    const hasFormula = fragments.some(fragment => fragment.type === 'formula');
    console.log(`是否包含公式: ${hasFormula ? '是 ✅' : '否 ❌'}`);
    
    console.log('---\n');
  } catch (error) {
    console.error(`错误: ${error.message} ❌`);
    console.log('---\n');
  }
});

console.log('测试完成！');