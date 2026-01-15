import React, { useState } from 'react';

function UserGuide() {
  const [isOpen, setIsOpen] = useState(false);

  return (
    <div className="user-guide-section">
      <button 
        className="guide-toggle"
        onClick={() => setIsOpen(!isOpen)}
      >
        {isOpen ? '收起帮助' : '使用帮助'}
      </button>
      
      {isOpen && (
        <div className="guide-content">
          <h4>使用指南</h4>
          
          <div className="guide-section">
            <h5>输入格式</h5>
            <ul>
              <li><strong>Markdown</strong>：支持标准Markdown语法，可混合使用LaTeX公式</li>
              <li><strong>LaTeX</strong>：直接输入LaTeX代码，专注于公式编辑</li>
            </ul>
          </div>
          
          <div className="guide-section">
            <h5>公式输入</h5>
            <ul>
              <li><strong>行内公式</strong>：使用 $...$ 或 \(...\)</li>
              <li><strong>块级公式</strong>：使用 $$...$$ 或 \[...\]</li>
              <li><strong>常用命令</strong>：\frac{}{}（分数）、\lim（极限）、\sqrt{}（平方根）等</li>
            </ul>
          </div>
          
          <div className="guide-section">
            <h5>输出格式</h5>
            <ul>
              <li><strong>Word (.docx)</strong>：生成可编辑的Word文档，公式以Office MathML格式保存</li>
              <li><strong>PDF (.pdf)</strong>：生成不可编辑的PDF文档，公式以KaTeX渲染</li>
            </ul>
          </div>
          
          <div className="guide-section">
            <h5>示例</h5>
            <div className="example">
              <p><strong>Markdown示例：</strong></p>
              <pre># 标题

这是一个段落，包含行内公式：$\frac{1}{2}$。

块级公式：
$$\int_{0}^{1} x^2 dx$$</pre>
            </div>
            <div className="example">
              <p><strong>LaTeX示例：</strong></p>
              <pre>{`\\frac{dy}{dx} = \\lim_{h \\to 0} \\frac{f(x+h) - f(x)}{h}`}</pre>
            </div>
          </div>
          
          <div className="guide-section">
            <h5>提示</h5>
            <ul>
              <li>使用实时预览查看渲染效果</li>
              <li>复杂公式可能需要稍长的转换时间</li>
              <li>确保公式语法正确，避免转换失败</li>
              <li>大文档建议使用PDF格式，渲染效果更好</li>
            </ul>
          </div>
        </div>
      )}
    </div>
  );
}

export default UserGuide;