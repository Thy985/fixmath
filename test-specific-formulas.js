import { normalizeLatex, convertToDocx } from './src/utils/converter.js';

// 测试特定公式
const testFormulas = [
  { name: '二阶导数', content: '$\\frac{d^2y}{dx^2}$' },
  { name: '带上下限的积分', content: '$\\int_{-1}^{1} \\frac{x^2}{\\sqrt{1 - x^2}} \\, dx$' }
];

// 测试normalizeLatex函数
console.log('=== 测试 normalizeLatex 函数 ===\n');
testFormulas.forEach((testCase, index) => {
  try {
    const result = normalizeLatex(testCase.content);
    console.log(`测试 ${index + 1}: ${testCase.name}`);
    console.log(`输入: ${testCase.content}`);
    console.log(`输出: ${result}`);
    console.log('状态: ✅ 成功');
    console.log('---');
  } catch (error) {
    console.error(`测试 ${index + 1} 失败: ${error.message}`);
    console.log('---');
  }
});

// 测试完整转换流程
async function testConversion() {
  console.log('\n=== 测试完整转换流程 ===\n');
  
  for (const testCase of testFormulas) {
    try {
      console.log(`开始转换: ${testCase.name}`);
      const blob = await convertToDocx(testCase.content, 'markdown');
      console.log(`${testCase.name} 转换成功！`);
      console.log(`生成的Blob大小: ${blob.size} 字节`);
      console.log('---');
    } catch (error) {
      console.error(`${testCase.name} 转换失败: ${error.message}`);
      console.log('---');
    }
  }
}

testConversion();