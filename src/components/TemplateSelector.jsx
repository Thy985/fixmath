import React, { useState } from 'react';

function TemplateSelector({ onSelectTemplate }) {
  const [isOpen, setIsOpen] = useState(false);
  
  // 常用模板
  const templates = [
    {
      name: '基础数学公式',
      content: `# 基础数学公式\n\n## 代数\n\n行内公式：$a^2 + b^2 = c^2$\n\n块级公式：\n$$(a + b)^2 = a^2 + 2ab + b^2$$\n\n## 微积分\n\n导数：\n$$\\frac{dy}{dx} = \\lim_{h \\to 0} \\frac{f(x+h) - f(x)}{h}$$\n\n积分：\n$$\\int_{a}^{b} f(x) dx$$\n\n## 三角函数\n\n$$\\sin^2 x + \\cos^2 x = 1$$\n$$\\tan x = \\frac{\\sin x}{\\cos x}$$`,
      type: 'markdown'
    },
    {
      name: '高等数学试卷',
      content: `# 高等数学（一）期末试卷\n\n## 一、选择题（每小题4分，共32分）\n\n1. 设函数 $f(x) = \\begin{cases} x^2 \\sin\\dfrac{1}{x}, & x \\neq 0 \\\\ 0, & x = 0 \\end{cases}$，则 $f(x)$ 在点 $x = 0$ 处（　　）。\n\n- A. 不连续\n- B. 连续但不可导\n- C. 可导但导数不连续\n- D. 连续且可导\n\n2. 已知 $\\displaystyle\\lim_{x \\to 0} \\frac{f(x)}{x} = 1$，则当 $x \\to 0$ 时，函数 $f(x)$ 是无穷小量，且（　　）。\n\n- A. 比 $x$ 高阶\n- B. 比 $x$ 低阶\n- C. 与 $x$ 同阶但不等价\n- D. 与 $x$ 等价\n\n## 二、填空题（每小题4分，共24分）\n\n1. 设函数 $f(x) = \\begin{cases} x^2, & x \\le 0 \\\\ e^x - 1, & x > 0 \\end{cases}$，则 $f(x)$ 在 $x = 0$ 处的右导数 $f'_+(0) = $ ______。\n\n2. 若极限 $\\displaystyle\\lim_{x \\to 0} \\frac{\\ln(1 + ax)}{x} = 2$，则常数 $a = $ ______。\n\n## 三、解答题（共44分）\n\n1. 求极限 $\\displaystyle\\lim_{x \\to 0} \\frac{1 - \\cos x}{x^2}$。\n\n2. 求函数 $f(x) = x^3 - 3x^2 + 2$ 的极值。`,
      type: 'markdown'
    },
    {
      name: '线性代数',
      content: `# 线性代数\n\n## 矩阵运算\n\n设矩阵 $A = \\begin{pmatrix} 1 & 2 \\\\ 3 & 4 \\end{pmatrix}$，则 $A^{-1} = $\n\n$$\\frac{1}{-2} \\begin{pmatrix} 4 & -2 \\\\ -3 & 1 \\end{pmatrix}$$\n\n## 行列式\n\n三阶行列式：\n\n$$\\begin{vmatrix} a & b & c \\\\ d & e & f \\\\ g & h & i \\\\end{vmatrix} = a(ei - fh) - b(di - fg) + c(dh - eg)$$\n\n## 线性方程组\n\n对于线性方程组 $Ax = b$，当 $\\det(A) \\neq 0$ 时，有唯一解：\n\n$$x = A^{-1}b$$`,
      type: 'markdown'
    },
    {
      name: '概率统计',
      content: `# 概率统计\n\n## 概率公式\n\n条件概率：\n\n$$P(A|B) = \\frac{P(AB)}{P(B)}$$\n\n全概率公式：\n\n$$P(A) = \\sum_{i=1}^{n} P(B_i)P(A|B_i)$$\n\n贝叶斯公式：\n\n$$P(B_j|A) = \\frac{P(B_j)P(A|B_j)}{\\sum_{i=1}^{n} P(B_i)P(A|B_i)}$$\n\n## 随机变量\n\n期望：\n\n$$E(X) = \\sum_{i} x_i P(X = x_i)$$\n\n方差：\n\n$$D(X) = E(X^2) - [E(X)]^2$$`,
      type: 'markdown'
    },
    {
      name: 'LaTeX公式示例',
      content: `\\documentclass{article}\n\\usepackage{amsmath, amssymb}\n\\begin{document}\n\\section{常用公式}\n\\begin{align}\n% 分数和根号\\n\\frac{1}{2} + \\frac{1}{3} &= \\frac{5}{6} \\\\n\\sqrt{x^2 + y^2} &= r\\n\\end{align}\n\\begin{align}\n% 极限\\n\\lim_{x \\to 0} \\frac{\\sin x}{x} &= 1 \\\\n\\lim_{n \\to \\infty} \\\\left(1 + \\\\frac{1}{n}\\\\right)^n &= e\\n\\end{align}\n\\begin{align}\n% 导数和积分\\n\\frac{d}{dx} (x^n) &= nx^{n-1} \\\\n\\int_0^1 x^2 \\\, dx &= \\frac{1}{3}\\n\\end{align}\n\\begin{align}\n% 求和和乘积\\n\\sum_{i=1}^n i &= \\frac{n(n+1)}{2} \\\\n\\prod_{i=1}^n i &= n!\\n\\end{align}\n\\begin{align}\n% 矩阵\\n\\begin{pmatrix} a & b \\\\ c & d \\\\end{pmatrix}\\\n\\begin{pmatrix} x \\\\ y \\\\end{pmatrix} &= \\begin{pmatrix} ax + by \\\\ cx + dy \\\\end{pmatrix}\\n\\end{align}\n\\end{document}`,
      type: 'latex'
    }
  ];

  const handleSelectTemplate = (template) => {
    onSelectTemplate(template.content, template.type);
    setIsOpen(false);
  };

  return (
    <div className="template-selector">
      <button 
        className="template-toggle"
        onClick={() => setIsOpen(!isOpen)}
      >
        {isOpen ? '收起模板' : '选择模板'}
      </button>
      
      {isOpen && (
        <div className="template-content">
          <h4>常用模板</h4>
          <div className="template-list">
            {templates.map((template, index) => (
              <div key={index} className="template-item">
                <h5>{template.name}</h5>
                <p className="template-type">{template.type === 'markdown' ? 'Markdown' : 'LaTeX'}</p>
                <button 
                  className="template-select-btn"
                  onClick={() => handleSelectTemplate(template)}
                >
                  使用模板
                </button>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}

export default TemplateSelector;