import { convertToDocx } from './src/utils/converter.js';

// 简单的测试内容
const simpleMarkdown = `# 测试文档

这是一个简单的Markdown文档，包含一些公式：

1. 分数：$\frac{1}{2}$
2. 极限：$\lim_{x \to 0} \frac{sin x}{x} = 1$
3. 积分：$\int_{0}^{1} x^2 dx = \frac{1}{3}$
4. 求和：$\sum_{i=1}^{n} i = \frac{n(n+1)}{2}$

## 章节标题

这是一个章节，包含更多公式：

- 导数：$f'(x) = \frac{d}{dx} f(x)$
- 偏导数：$\frac{\partial f}{\partial x}$
- 矩阵：$\begin{pmatrix} 1 & 2 \\ 3 & 4 \end{pmatrix}$
`;

async function testConversion() {
  try {
    console.log('开始测试简单Markdown转换...');
    
    // 调用转换函数
    const blob = await convertToDocx(simpleMarkdown, 'markdown');
    
    console.log('转换成功！');
    console.log(`生成的Blob大小: ${blob.size} 字节`);
    console.log('转换完成，文档已生成。');
    
  } catch (error) {
    console.error('转换失败:', error);
  }
}

testConversion();
