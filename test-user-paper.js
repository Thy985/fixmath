import { convertToDocx } from './src/utils/converter.js';

// 用户提供的试卷内容
const userPaperContent = `# 第一部分 单项选择题（共10题，每题3分，共30分）

1. 已知函数 $f(x) = x^3 - 3x^2 + 2x$，则 $f'(x) = $（ ）
   A. $x^2 - 6x + 2$  B. $3x^2 - 6x + 2$  C. $3x^2 - 6x$  D. $3x^2 - 3x + 2$

2. 极限 $\lim_{x \to 0} \frac{\sin 3x}{x} = $（ ）
   A. 0  B. 1  C. 3  D. 不存在

3. 定积分 $\int_0^1 x^2 dx = $（ ）
   A. $\frac{1}{3}$  B. $\frac{1}{2}$  C. 1  D. 2

4. 函数 $y = x^2 - 4x + 3$ 的极小值为（ ）
   A. -1  B. 0  C. 1  D. 2

5. 微分方程 $y' = 2x$ 的通解为（ ）
   A. $y = x^2 + C$  B. $y = 2x^2 + C$  C. $y = x + C$  D. $y = 2x + C$

# 第二部分 填空题（共5题，每题4分，共20分）

1. 函数 $f(x) = \frac{1}{x - 1}$ 的定义域为 ______

2. 极限 $\lim_{x \to \infty} \left(1 + \frac{1}{x}\right)^x = $ ______

3. 导数 $\frac{d}{dx}(e^x \sin x) = $ ______

4. 不定积分 $\int \cos x dx = $ ______

5. 曲线 $y = x^3$ 在点 $(1,1)$ 处的切线方程为 ______

# 第三部分 解答题（共5题，每题10分，共50分）

1. 计算极限 $\lim_{x \to 1} \frac{x^2 - 1}{x - 1}$

2. 求函数 $f(x) = x^3 - 3x^2 + 3x - 1$ 的极值

3. 计算定积分 $\int_0^\pi \sin x dx$

4. 求微分方程 $y' + y = e^{-x}$ 的通解

5. 计算二重积分 $\iint_D x^2 y dxdy$，其中 $D$ 是由 $x = 0$，$x = 1$，$y = 0$ 和 $y = x$ 围成的区域
`;

async function testUserPaperConversion() {
  console.log('开始测试用户试卷转换...');
  try {
    // 转换用户提供的试卷内容
    const blob = await convertToDocx(userPaperContent, 'markdown');
    console.log('转换成功！');
    console.log(`生成的Blob大小: ${blob.size} 字节`);
    console.log('转换完成，文档已生成。');
  } catch (error) {
    console.error('转换失败:', error.message);
  }
}

testUserPaperConversion();