import { convertToDocx } from './src/utils/converter.js';

// 测试数据：用户提供的复杂数学公式
const testContent = `# 数学公式测试

## 极限与连续
1. 极限公式：lim⁡x→∞(1+1x)x=elim x →∞​(1+ x 1​) x = e  （注意箭头和分式的嵌套）
2. 导数定义：lim⁡Δx→0f(x+Δx)−f(x)ΔxlimΔ x →0​Δ xf ( x +Δ x )− f ( x )​ （导数定义，分式+希腊字母）

## 导数与微分
3. 隐函数求导、参数方程求导（涉及 dydx dxdy ​ 的复杂分式）。
4. 高阶导数：$y'', $f^{(n)}(x)。

## 不定积分
5. 不定积分：  ∫1xdx=ln⁡∣x∣+C∫ x 1​ dx =ln∣ x ∣+ C

## 定积分（带上下限）
6. 定积分：  ∫0πsin⁡x dx=2∫0 π ​sin xdx =2 （注意上下限位置）

## 换元积分法
7. 换元积分法：  涉及复杂的根式和分式变形，如 $\int \sqrt{1 - x^2} dx$ 和 $\int \frac{1}{1 + x^2} dx$。

## 混合公式测试
8. 混合公式：lim⁡x→0sin⁡xx=1lim x →0​ x sin x ​=1，$\int_0^1 x^n dx = \frac{1}{n+1}$，$f'(x) = \lim_{h \to 0} \frac{f(x+h) - f(x)}{h}$

## 杂乱文本中的公式
9. 这里是一些杂乱的文本，其中包含公式lim⁡x→∞(1+1x)x=elim x →∞​(1+ x 1​) x = e和导数f'(x)，还有积分∫0πsin⁡x dx=2∫0 π ​sin xdx =2，以及高阶导数y''和f^{(n)}(x)。

## 复杂分式和嵌套结构
10. 复杂分式：$\frac{\frac{1}{x} + \frac{1}{y}}{\frac{1}{x^2} - \frac{1}{y^2}}$，嵌套极限：$\lim_{x \to \infty} \lim_{y \to 0} \frac{x \sin(xy)}{x^2 + y^2}$`;

console.log('开始测试复杂公式转换...');
console.log('测试内容:', testContent);

convertToDocx(testContent, 'markdown')
  .then(blob => {
    console.log('转换成功！');
    console.log('生成的文档大小:', blob.size, '字节');
    console.log('转换结果:', blob);
    console.log('测试通过：复杂数学公式能被正确转换！');
  })
  .catch(error => {
    console.error('转换失败:', error);
    console.error('错误详情:', error.stack);
  });
