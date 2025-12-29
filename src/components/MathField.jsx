import React, { useRef, useState, useEffect } from 'react';
import katex from 'katex';
import 'katex/dist/katex.min.css';
// 暂时移除 MathQuill，因为它依赖 jQuery 并导致内部错误
// 只使用 KaTeX 来处理公式解析和渲染

// 防抖函数
const debounce = (func, delay) => {
  let timeoutId;
  return (...args) => {
    clearTimeout(timeoutId);
    timeoutId = setTimeout(() => func.apply(null, args), delay);
  };
};

function MathField({ value, onChange, className = '' }) {
  const textareaRef = useRef(null);
  // 添加内部值ref，用于跟踪当前内部值，避免无限循环
  const internalValueRef = useRef(value);
  const [isFocused, setIsFocused] = useState(false);
  const [isParsing, setIsParsing] = useState(false);
  const [parseError, setParseError] = useState(null);

  // 防抖处理的 onChange 函数
  const debouncedOnChange = useRef(debounce(onChange, 300)).current;

  // 处理输入变化
  const handleChange = (e) => {
    const newValue = e.target.value;
    internalValueRef.current = newValue;
    debouncedOnChange(newValue);
  };

  // 处理粘贴事件
  const handlePaste = async (e) => {
    e.preventDefault();
    
    // 清除之前的错误
    setParseError(null);
    setIsParsing(true);
    
    try {
      // 获取粘贴的文本
      const pastedText = e.clipboardData.getData('text/plain');
      
      // 尝试使用 KaTeX 解析
      let parsedSuccessfully = false;
      let parsedLatex = pastedText;

      try {
        // 尝试用 KaTeX 渲染，验证公式有效性
        katex.renderToString(pastedText, {
          throwOnError: true,
          displayMode: false
        });
        parsedSuccessfully = true;
        console.log('KaTeX 解析成功');
      } catch (katexError) {
        console.log('KaTeX 解析失败，作为普通文本处理:', katexError.message);
        parsedSuccessfully = false;
        setParseError('无法解析为公式，已作为普通文本处理');
      }

      if (parsedSuccessfully) {
        // 解析成功，使用防抖更新状态
        const newValue = value + parsedLatex;
        internalValueRef.current = newValue;
        debouncedOnChange(newValue);
      } else {
        // 解析失败，作为普通文本处理
        const combinedValue = value + pastedText;
        internalValueRef.current = combinedValue;
        debouncedOnChange(combinedValue);
      }
    } catch (error) {
      console.error('粘贴处理失败:', error);
      setParseError('粘贴处理失败，请重试');
    } finally {
      // 无论结果如何，结束解析状态
      setIsParsing(false);
      
      // 3秒后自动清除错误提示
      setTimeout(() => {
        setParseError(null);
      }, 3000);
    }
  };

  // 处理焦点事件
  const handleFocus = () => setIsFocused(true);
  const handleBlur = () => setIsFocused(false);

  return (
    <div className={`math-field-container ${isFocused ? 'focused' : ''} ${className}`}>
      {/* 使用普通 textarea 处理输入 */}
      <textarea
        ref={textareaRef}
        value={value}
        onChange={handleChange}
        onPaste={handlePaste}
        onFocus={handleFocus}
        onBlur={handleBlur}
        placeholder="请输入LaTeX公式..."
        style={{
          width: '100%',
          minHeight: '160px',
          padding: '10px',
          border: `1px solid ${isFocused ? '#4a90e2' : '#ccc'}`,
          borderRadius: '4px',
          overflow: 'auto',
          backgroundColor: '#fff',
          fontSize: '16px',
          lineHeight: '1.5',
          transition: 'border-color 0.2s ease',
          boxShadow: isFocused ? '0 0 0 2px rgba(74, 144, 226, 0.2)' : 'none',
          resize: 'vertical',
          fontFamily: 'monospace'
        }}
      />
      
      {/* 解析状态指示器 */}
      {isParsing && (
        <div style={{
          position: 'absolute',
          top: '10px',
          right: '10px',
          backgroundColor: 'rgba(255, 255, 255, 0.9)',
          padding: '4px 8px',
          borderRadius: '4px',
          fontSize: '12px',
          color: '#666',
          boxShadow: '0 2px 4px rgba(0, 0, 0, 0.1)',
          zIndex: 10
        }}>
          解析中...
        </div>
      )}
      
      {/* 错误提示 */}
      {parseError && (
        <div style={{
          marginTop: '8px',
          padding: '8px',
          backgroundColor: '#fff2f0',
          border: '1px solid #ffccc7',
          borderRadius: '4px',
          fontSize: '14px',
          color: '#f5222d'
        }}>
          ⚠️ {parseError}
        </div>
      )}
    </div>
  );
}

export default MathField;
