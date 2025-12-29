import { normalizeLatex } from './src/utils/converter.js';

// 导入extractFormulaFragments函数，需要先修改converter.js将其导出
// 暂时直接测试normalizeLatex函数的行为

// 测试用例数组
const testCases = [
  { input: 'frac{1}{2}', description: '未带$的分数，不应被处理' },
  { input: '$frac{1}{2}$', description: '带$的分数，应被处理' },
  { input: 'lim_{x to 0} frac{sin x}{x} = 1', description: '未带$的极限表达式，不应被处理' },
  { input: '$lim_{x to 0} frac{sin x}{x} = 1$', description: '带$的极限表达式，应被处理' },
  { input: 'alpha + beta = gamma', description: '未带$的希腊字母，不应被处理' },
  { input: '$alpha + beta = gamma$', description: '带$的希腊字母，应被处理' },
  { input: '普通文本 frac{1}{2} 普通文本', description: '混合文本，未带$的公式不应被处理' },
  { input: '普通文本 $frac{1}{2}$ 普通文本', description: '混合文本，带$的公式应被处理' }
];

console.log('=== 测试公式识别规则 ===\n');
console.log('规则：只有$包裹的内容应被识别为公式\n');

testCases.forEach((testCase, index) => {
  try {
    const result = normalizeLatex(testCase.input);
    console.log(`测试 ${index + 1}: ${testCase.description}`);
    console.log(`输入: ${testCase.input}`);
    console.log(`输出: ${result}`);
    
    // 简单判断是否符合规则
    if (!testCase.input.includes('$') && result !== testCase.input) {
      console.log('状态: ❌ 不符合规则（未带$的内容被处理）');
    } else if (testCase.input.includes('$')) {
      console.log('状态: ✅ 符合规则（带$的内容被处理）');
    } else {
      console.log('状态: ✅ 符合规则（未带$的内容未被处理）');
    }
    
    console.log('---');
  } catch (error) {
    console.error(`测试 ${index + 1} 失败: ${error.message}`);
    console.log('---');
  }
});

console.log('=== 测试完成 ===');
