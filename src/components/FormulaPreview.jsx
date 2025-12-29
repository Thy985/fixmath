import React, { useEffect, useRef } from 'react';
import katex from 'katex';
import 'katex/dist/katex.min.css';
import { marked } from 'marked';
import { normalizeLatex } from '../utils/converter.js';

function FormulaPreview({ content, inputType }) {
  const previewRef = useRef(null);

  useEffect(() => {
    if (!content || !previewRef.current) return;

    // 规范化内容
    const normalizedContent = normalizeLatex(content);
    
    // 预处理函数：为文本中的LaTeX命令添加$分隔符
    const preprocessContent = (text) => {
      // 检测是否已经包含$符号，如果有则跳过预处理
      if (text.includes('$')) {
        return text;
      }
      
      // 处理没有被$包裹的LaTeX命令
      let processedText = text;
      
      // 只处理纯文本中的 'to' 关键字，不处理已经是命令一部分的 'to'
      processedText = processedText.replace(/(^|[^\\])\bto\b/g, '$1\\to');
      
      // 处理带下划线的命令，如 lim_h，但只处理没有反斜杠的命令
      processedText = processedText.replace(/\b(lim|frac|sqrt|int|sum|prod|sin|cos|tan|log|ln)_(\\w+)/g, '$1_{$2}');
      
      // 为没有反斜杠的常见LaTeX命令添加反斜杠
      const commonCommands = ['frac', 'lim', 'sqrt', 'int', 'sum', 'prod', 'sin', 'cos', 'tan', 'log', 'ln'];
      commonCommands.forEach(cmd => {
        // 匹配没有反斜杠的命令，如 lim 但不匹配 \lim
        const regex = new RegExp(`(^|[^\\])\\b${cmd}\\b`, 'g');
        processedText = processedText.replace(regex, (match, p1) => `${p1}\\${cmd}`);
      });
      
      // 简化：不再自动为LaTeX命令包裹$符号，只处理已有的$包裹内容
      return processedText;
    };

    if (inputType === 'markdown') {
      // 先转换Markdown为HTML，保留原始公式格式
      let html = marked.parse(normalizedContent);
      
      // 将HTML实体转换回原始字符，避免f'被转义为f&#39;等问题
      html = html.replace(/&#39;/g, "'");
      html = html.replace(/&quot;/g, '"');
      html = html.replace(/&lt;/g, '<');
      html = html.replace(/&gt;/g, '>');
      html = html.replace(/&amp;/g, '&');
      
      // 渲染块级公式 $$...$$
      html = html.replace(/\$\$(.*?)\$\$/gs, (match, formula) => {
        try {
          return katex.renderToString(formula, {
            throwOnError: false,
            displayMode: true,
            trust: true,
            strict: false
          });
        } catch (e) {
          console.error('块级公式渲染失败:', formula, e);
          return match;
        }
      });
      
      // 渲染行内公式 $...$
      html = html.replace(/\$(.*?)\$/gs, (match, formula) => {
        try {
          return katex.renderToString(formula, {
            throwOnError: false,
            displayMode: false,
            trust: true,
            strict: false
          });
        } catch (e) {
          console.error('行内公式渲染失败:', formula, e);
          return match;
        }
      });
      
      // 渲染结果到预览区域
      previewRef.current.innerHTML = html;
    } else {
      // 对于LaTeX输入类型，直接渲染，不需要预处理
      try {
        katex.render(normalizedContent, previewRef.current, {
          throwOnError: false,
          displayMode: true,
          trust: true,
          strict: false
        });
      } catch (e) {
        console.error('LaTeX渲染失败:', normalizedContent, e);
        previewRef.current.textContent = `无法渲染LaTeX: ${e.message}`;
      }
    }
  }, [content, inputType]);

  return (
    <div className="preview-section">
      <h3>实时预览</h3>
      <div className="preview-content" ref={previewRef}></div>
    </div>
  );
}

export default FormulaPreview;