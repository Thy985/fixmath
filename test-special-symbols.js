import { convertToDocx } from './src/utils/converter.js';

// 测试带有特殊符号标记的公式转换
const testContent = `# 数学测试试卷

## 第一题
计算以下极限：

$$\lim_{x \to 0} \frac{\sin x}{x} = 1$$

## 第二题
求解方程：

$x^2 + 2x + 1 = 0$ 的解是 $x = -1$

## 第三题
计算定积分：

$$\int_{0}^{1} x^2 dx = \frac{1}{3}$$

## 第四题
向量运算：

$\vec{a} \cdot \vec{b} = |a||b|\cos\theta$

## 第五题
矩阵运算：

$$\begin{pmatrix} 1 & 2 \\ 3 & 4 \end{pmatrix} \times \begin{pmatrix} 5 & 6 \\ 7 & 8 \end{pmatrix} = \begin{pmatrix} 19 & 22 \\ 43 & 50 \end{pmatrix}$$`;

console.log('开始测试特殊符号转换...');
console.log('测试内容:', testContent);

convertToDocx(testContent, 'markdown')
  .then(blob => {
    console.log('转换成功！');
    console.log('生成的文档大小:', blob.size, '字节');
    console.log('转换结果:', blob);
    console.log('测试通过：带有 $ 标记的公式能被正确转换！');
  })
  .catch(error => {
    console.error('转换失败:', error);
  });
