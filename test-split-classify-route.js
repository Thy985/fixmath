// 测试文件：验证切分、分类和分流处理
import { normalizeLatex, convertToDocx } from './src/utils/converter.js';

// 测试用例1：简单文本和公式混合
const testCase1 = {
  name: '简单文本和公式混合',
  content: '这是一个简单的公式：lim_{x \to 0} frac{sin(x)}{x} = 1',
  inputType: 'latex'
};

// 测试用例2：复杂嵌套公式
const testCase2 = {
  name: '复杂嵌套公式',
  content: '这是一个复杂公式：\frac{1}{1+\frac{1}{1+\frac{1}{x}}} = \frac{x}{x+1}',
  inputType: 'latex'
};

// 测试用例3：Markdown格式，包含标题和列表
const testCase3 = {
  name: 'Markdown格式，包含标题和列表',
  content: '# 公式测试\n\n这是一个段落，包含公式：$E=mc^2$\n\n## 子标题\n\n- 列表项1：$a^2 + b^2 = c^2$\n- 列表项2：$\sum_{i=1}^n i = \frac{n(n+1)}{2}$\n',
  inputType: 'markdown'
};

// 测试用例4：包含块级公式
const testCase4 = {
  name: '包含块级公式',
  content: '这是一个块级公式：\n\n$$\int_{-\infty}^{\infty} e^{-x^2} dx = \sqrt{\pi}$$\n\n后面跟着一些文本。',
  inputType: 'markdown'
};

// 测试用例5：包含各种公式类型
const testCase5 = {
  name: '包含各种公式类型',
  content: '\n1. 导数：$f\'(x) = \lim_{h \to 0} \frac{f(x+h) - f(x)}{h}$\n2. 偏导数：$\frac{\partial^2 f}{\partial x \partial y}$\n3. 向量：$\vec{v} = (v_1, v_2, v_3)$\n4. 矩阵：$\begin{pmatrix}1 & 0 \\ 0 & 1\end{pmatrix}$\n5. 求和：$\sum_{i=1}^n i^2 = \frac{n(n+1)(2n+1)}{6}$\n6. 积分：$\int_a^b f(x) dx$\n7. 极限：$\lim_{n \to \infty} (1 + \frac{1}{n})^n = e$\n',
  inputType: 'markdown'
};

// 运行所有测试用例
async function runTests() {
  const testCases = [testCase1, testCase2, testCase3, testCase4, testCase5];
  
  console.log('开始测试切分、分类和分流处理...\n');
  
  for (const testCase of testCases) {
    console.log(`=== 测试用例：${testCase.name} ===`);
    console.log(`输入内容：\n${testCase.content}`);
    console.log(`输入类型：${testCase.inputType}`);
    
    try {
      // 测试normalizeLatex函数
      const normalized = normalizeLatex(testCase.content);
      console.log(`\n规范化结果：\n${normalized}`);
      
      // 测试convertToDocx函数
      const blob = await convertToDocx(testCase.content, testCase.inputType);
      console.log(`\n转换成功！生成的Blob大小：${blob.size}字节`);
      console.log('✓ 测试通过\n');
    } catch (error) {
      console.error(`\n转换失败：${error.message}`);
      console.error('✗ 测试失败\n');
    }
  }
  
  console.log('所有测试用例执行完毕！');
}

// 运行测试
runTests();
