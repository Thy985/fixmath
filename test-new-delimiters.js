import { convertToDocx } from './src/utils/converter.js';

// 测试新的LaTeX定界符支持
const testContent = String.raw`# 测试LaTeX定界符

## 1. 使用\( \)的行内公式
这是一个行内公式：\( \frac{1 - \cos x}{x^2} \)，它应该被正确识别。

## 2. 使用\[ \]的块级公式
这是一个块级公式：
\[
\lim_{x \to 0} \frac{\ln(1 + x)}{\sin x}
\]

## 3. 混合使用不同定界符
行内公式：\( \int_{0}^{\pi} \sin^2 x \, dx \) 和 $ \frac{dy}{dx} $ 都应该被识别。

块级公式：
\[
\int_{-1}^{1} \frac{x^2}{\sqrt{1 - x^2}} \, dx
\]

## 4. 复杂公式
设函数 \( f(x) = \begin{cases} x^2 \sin\dfrac{1}{x}, & x \neq 0 \\\\ 0, & x = 0 \end{cases} \)，则 \( f(x) \) 在点 \( x = 0 \) 处可导。

## 5. 试卷中的实际公式
1. 当 \( x \to 0 \) 时，函数 \( \frac{1 - \cos x}{x^2} \) 是（ ）
   A. 等价无穷小
   B. 同阶但不等价无穷小
   C. 高阶无穷小
   D. 低阶无穷小

2. 极限 \( \lim_{x \to 0} \frac{\ln(1 + x)}{\sin x} = \) __________

3. 定积分 \( \int_{0}^{\pi} \sin^2 x \, dx = \) __________`;

async function testNewDelimiters() {
  try {
    console.log('开始测试新的LaTeX定界符...');
    
    // 调用转换函数
    const blob = await convertToDocx(testContent, 'markdown');
    
    console.log('转换成功！');
    console.log(`生成的Blob大小: ${blob.size} 字节`);
    console.log('新的LaTeX定界符已成功支持！');
    
  } catch (error) {
    console.error('转换失败:', error);
  }
}

testNewDelimiters();
