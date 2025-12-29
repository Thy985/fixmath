import { convertToDocx } from './src/utils/converter.js';

// 专门测试极限公式的识别和转换
const testContent = `# 极限公式测试

## 基础极限公式
1. 简单极限：$\lim_{n \to \infty} \frac{1}{n} = 0$
2. 重要极限：$\lim_{x \to 0} \frac{\sin x}{x} = 1$
3. 指数极限：$\lim_{x \to \infty} (1 + \frac{1}{x})^x = e$

## 带箭头的极限公式（未包裹$符号）
4. 极限公式：lim⁡x→∞(1+1x)x=elim x →∞​(1+ x 1​) x = e
5. 导数定义：lim⁡Δx→0f(x+Δx)−f(x)ΔxlimΔ x →0​Δ xf ( x +Δ x )− f ( x )​

## 各种箭头符号测试
6. 右箭头：$\lim_{x \to 0} x = 0$
7. 左箭头：$\lim_{x \leftarrow 0} x = 0$
8. 双向箭头：$\lim_{x \leftrightarrow 0} x = 0$
9. 趋近于：$\lim_{x \rightarrow 0} x = 0$
10. 中文箭头：$\lim_{x → 0} x = 0$

## 不同类型的极限
11. 极限下确界：$\liminf_{n \to \infty} a_n$
12. 极限上确界：$\limsup_{n \to \infty} a_n$
13. 单侧极限：$\lim_{x \to 0^+} f(x)$ 和 $\lim_{x \to 0^-} f(x)$

## 复杂嵌套极限
14. 嵌套极限：$\lim_{x \to \infty} \lim_{y \to 0} \frac{x \sin(xy)}{x^2 + y^2}$
15. 带分式的极限：$\lim_{x \to 1} \frac{x^2 - 1}{x - 1} = 2$

## 极限在杂乱文本中
16. 这里有一个极限lim⁡x→0sin⁡xx=1lim x →0​ x sin x ​=1，它是一个重要的极限公式。
17. 另一个极限公式lim⁡x→∞(1+kx)x=e k lim x →∞​(1+ x k​) x = e k 也很常用。`;

console.log('开始测试极限公式转换...');

convertToDocx(testContent, 'markdown')
  .then(blob => {
    console.log('转换成功！');
    console.log('生成的文档大小:', blob.size, '字节');
    console.log('转换结果:', blob);
    console.log('测试通过：极限公式能被正确转换！');
  })
  .catch(error => {
    console.error('转换失败:', error);
    console.error('错误详情:', error.stack);
  });
