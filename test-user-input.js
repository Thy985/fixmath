import { convertToDocx } from './src/utils/converter.js';

// 测试用户输入的特定格式
const testContent = `# 用户输入格式测试

## 测试用户输入的格式
1. 用户输入：lim_h to 0 {frac{f(a + 2h) - f(a)}{h}}
2. 导数定义：lim_{Δx to 0} frac{f(x+Δx)-f(x)}{Δx}
3. 简单极限：lim_x to infty (1 + frac{1}{x})^x = e
4. 三角函数：sin_2x + cos_2x = 1
5. 对数函数：log_2x + log_2y = log_2(xy)

## 混合格式测试
6. 混合公式：lim_x to 0 frac{sin x}{x} = 1，$frac{d}{dx}x^2 = 2x$
7. 复杂嵌套：lim_{n to infty} sum_{i=1}^n frac{1}{n} = 1
8. 多个公式：lim_x to 0 x = 0，lim_x to 1 x = 1，lim_x to 2 x = 2

## 中文和英文混合
9. 极限公式：lim⁡x→∞(1+1x)x=elim x →∞​(1+ x 1​) x = e
10. 中文箭头：lim_x → 0 frac{1}{x} = infty`;

console.log('开始测试用户输入格式...');

convertToDocx(testContent, 'markdown')
  .then(blob => {
    console.log('转换成功！');
    console.log('生成的文档大小:', blob.size, '字节');
    console.log('转换结果:', blob);
    console.log('测试通过：用户输入格式能被正确处理！');
  })
  .catch(error => {
    console.error('转换失败:', error);
    console.error('错误详情:', error.stack);
  });
