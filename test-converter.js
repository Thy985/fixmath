import { convertToDocx } from './src/utils/converter.js';

// 测试数据：数学试卷样例
const testData = `1. 极限 lim_{x to 0} frac{ln(1 + x)}{sin x} = __________
2. 设 f(x) = sqrt{x^2 + 1}，则 f'(0) = __________
3. 曲线 y = x^4 - 2x^2 + 3 的拐点坐标为 __________
4. 定积分 int_{0}^{pi} sin^2 x , dx = __________
5. 设 f(x) 在区间 [a, b] 上连续，在 (a, b) 内可导，且 f(a) = f(b) = 0，则在 (a, b) 内至少存在一点 xi ，使得 f'(xi) = __________

***三、计算题***（本大题共4小题，每小题10分，共40分）

1. 计算极限 lim_{x to 0} frac{1 - cos x}{x^2}

2. 设 y = x^sin x，求 dy/dx

3. 计算不定积分 int x e^x dx

4. 求曲线 y = x^3 - 3x^2 + 2 在点 (1, 0) 处的切线方程`;

// 测试转换功能
async function testConversion() {
  console.log('开始测试FormulaFix转换功能...');
  
  try {
    // 测试Markdown转换
    console.log('\n1. 测试Markdown转换：');
    const markdownBlob = await convertToDocx(testData, 'markdown');
    console.log('✓ Markdown转换成功，生成文件大小：', markdownBlob.size, '字节');
    
    // 测试LaTeX转换
    console.log('\n2. 测试LaTeX转换：');
    const latexBlob = await convertToDocx(testData, 'latex');
    console.log('✓ LaTeX转换成功，生成文件大小：', latexBlob.size, '字节');
    
    console.log('\n✅ 所有测试通过！FormulaFix转换功能正常工作。');
    
  } catch (error) {
    console.error('\n❌ 测试失败：', error.message);
    console.error('错误详情：', error);
  }
}

// 运行测试
testConversion();