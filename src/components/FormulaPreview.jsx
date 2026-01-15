import React, { useEffect, useRef, useState, useCallback } from 'react';
import katex from 'katex';
import 'katex/dist/katex.min.css';
import { normalizeLatex, processMarkdownWithFormulas } from '../utils/converter.js';

function FormulaPreview({ content, inputType }) {
  const previewRef = useRef(null);
  const [debouncedContent, setDebouncedContent] = useState(content);
  
  // 防抖函数
  const debounce = useCallback((func, delay) => {
    let timeoutId;
    return (...args) => {
      clearTimeout(timeoutId);
      timeoutId = setTimeout(() => func.apply(null, args), delay);
    };
  }, []);
  
  // 防抖处理内容更新
  const debouncedUpdate = useCallback(
    debounce((newContent) => {
      setDebouncedContent(newContent);
    }, 300), // 300ms防抖延迟
    [debounce]
  );
  
  // 监听原始内容变化，触发防抖更新
  useEffect(() => {
    debouncedUpdate(content);
  }, [content, debouncedUpdate]);

  useEffect(() => {
    if (!debouncedContent || !previewRef.current) return;

    // 规范化内容
    const normalizedContent = normalizeLatex(debouncedContent);
    
    if (inputType === 'markdown') {
      // 使用统一的processMarkdownWithFormulas函数处理Markdown内容
      const html = processMarkdownWithFormulas(normalizedContent);
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
  }, [debouncedContent, inputType]);

  return (
    <div className="preview-section">
      <h3>实时预览</h3>
      <div className="preview-content" ref={previewRef}></div>
    </div>
  );
}

export default FormulaPreview;