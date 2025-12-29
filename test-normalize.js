import { normalizeLatex } from './src/utils/converter.js';

// 测试用例数组
const testCases = [
  { input: 'frac{1}{2}', description: '基础分数' },
  { input: '$\frac{1}{2}$', description: '带$的分数' },
  { input: '\frac{1}{2}', description: '带\的分数' },
  { input: 'lim_{x to 0} frac{sin x}{x} = 1', description: '极限表达式' },
  { input: '$lim_{x to 0} frac{sin x}{x} = 1$', description: '带$的极限表达式' },
  { input: 'lim_{x \\to 0} frac{sin x}{x} = 1', description: '带\\to的极限表达式' },
  { input: '$lim_{x \\to 0} frac{sin x}{x} = 1$', description: '带$和\\to的极限表达式' },
  { input: 'sum_{i=1}^{n} i^2', description: '求和符号' },
  { input: '$sum_{i=1}^{n} i^2$', description: '带$的求和符号' },
  { input: 'alpha + beta = gamma', description: '希腊字母' },
  { input: '$alpha + beta = gamma$', description: '带$的希腊字母' }
];

console.log('=== 测试 normalizeLatex 函数 ===\n');

testCases.forEach((testCase, index) => {
  try {
    const result = normalizeLatex(testCase.input);
    console.log(`测试 ${index + 1}: ${testCase.description}`);
    console.log(`输入: ${testCase.input}`);
    console.log(`输出: ${result}`);
    console.log('---');
  } catch (error) {
    console.error(`测试 ${index + 1} 失败: ${error.message}`);
    console.log('---');
  }
});

console.log('=== 测试完成 ===');
