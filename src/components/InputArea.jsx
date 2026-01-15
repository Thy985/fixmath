import React, { useState, useEffect, useRef } from 'react';
import MathField from './MathField.jsx';
import TemplateSelector from './TemplateSelector.jsx';

function InputArea({ input, inputType, outputType, onInputChange, onInputTypeChange, onOutputTypeChange, onConvert, onClear, onSelectTemplate }) {
  const [wordCount, setWordCount] = useState(0);
  const [formulaCount, setFormulaCount] = useState(0);
  const [imageCount, setImageCount] = useState(0);
  const textareaRef = useRef(null);
  const [isDragging, setIsDragging] = useState(false);

  // 处理模板选择
  const handleSelectTemplate = (content, type) => {
    onInputChange(content);
    onInputTypeChange(type);
  };

  // 计算统计信息
  useEffect(() => {
    if (input) {
      // 字数统计
      const words = input.trim().split(/\s+/).filter(word => word.length > 0).length;
      setWordCount(words);

      // 公式统计
      const formulaRegex = /(\$\$[^$]+\$\$|\$[^$]+\$|\\\[[^\]]+\\\]|\\\([^\)]+\\\))/g;
      const formulas = input.match(formulaRegex);
      setFormulaCount(formulas ? formulas.length : 0);

      // 图片统计
      const imageRegex = /!\[.*?\]\(.*?\)/g;
      const images = input.match(imageRegex);
      setImageCount(images ? images.length : 0);
    } else {
      setWordCount(0);
      setFormulaCount(0);
      setImageCount(0);
    }
  }, [input]);

  // 处理文件拖拽
  const handleDragOver = (e) => {
    e.preventDefault();
    setIsDragging(true);
  };

  const handleDragLeave = () => {
    setIsDragging(false);
  };

  const handleDrop = (e) => {
    e.preventDefault();
    setIsDragging(false);

    const files = e.dataTransfer.files;
    if (files.length > 0) {
      const file = files[0];
      if (file.type === 'text/plain' || file.name.endsWith('.md') || file.name.endsWith('.tex')) {
        const reader = new FileReader();
        reader.onload = (event) => {
          onInputChange(event.target.result);
        };
        reader.readAsText(file);
      }
    }
  };

  // 处理导入文件
  const handleImportFile = () => {
    const input = document.createElement('input');
    input.type = 'file';
    input.accept = '.md,.tex,.txt';
    input.onchange = (e) => {
      const file = e.target.files[0];
      if (file) {
        const reader = new FileReader();
        reader.onload = (event) => {
          onInputChange(event.target.result);
        };
        reader.readAsText(file);
      }
    };
    input.click();
  };

  return (
    <div className="input-section">
      <div className="input-header">
        <h2 className="input-title">📝 编辑内容</h2>
        <div className="input-type-tabs">
          <button 
            className={inputType === 'markdown' ? 'active' : ''}
            onClick={() => onInputTypeChange('markdown')}
          >
            Markdown
          </button>
          <button 
            className={inputType === 'latex' ? 'active' : ''}
            onClick={() => onInputTypeChange('latex')}
          >
            LaTeX
          </button>
          <button 
            className={inputType === 'plain' ? 'active' : ''}
            onClick={() => onInputTypeChange('plain')}
          >
            纯文本
          </button>
        </div>
      </div>
      
      <TemplateSelector onSelectTemplate={handleSelectTemplate} />
      
      {/* 输入编辑区 */}
      <div 
        className={`input-editor-container ${isDragging ? 'dragging' : ''}`}
        onDragOver={handleDragOver}
        onDragLeave={handleDragLeave}
        onDrop={handleDrop}
      >
        {/* 根据输入类型选择使用 MathField 或普通 textarea */}
        {inputType === 'latex' ? (
          <div style={{ position: 'relative', minHeight: '400px' }}>
            <MathField
              value={input}
              onChange={onInputChange}
              className="math-field-wrapper"
            />
          </div>
        ) : (
          <textarea
            ref={textareaRef}
            value={input}
            onChange={(e) => onInputChange(e.target.value)}
            placeholder={`请输入${inputType === 'markdown' ? 'Markdown' : inputType === 'latex' ? 'LaTeX' : '纯文本'}内容...\n\n支持：\n• 语法高亮\n• 自动补全\n• 拖拽文件\n• 字数统计`}
            rows={15}
            className="input-textarea"
          />
        )}
        
        {/* 拖拽提示 */}
        {isDragging && (
          <div className="drag-overlay">
            <p>📁 拖拽文件到这里导入</p>
          </div>
        )}
      </div>
      
      {/* 统计信息 */}
      <div className="input-stats">
        <div className="stats-info">
          <span className="stat-item">📊 字数 {wordCount}</span>
          <span className="stat-item">📝 公式 {formulaCount}</span>
          <span className="stat-item">🖼️ 图片 {imageCount}</span>
        </div>
        <div className="input-actions">
          <button className="btn-secondary" onClick={handleImportFile}>
            📁 导入文件
          </button>
          <button className="btn-secondary" onClick={onClear}>
            🔄 清空
          </button>
          <button className="btn-secondary" onClick={() => console.log('保存草稿')}>
            💾 保存草稿
          </button>
        </div>
      </div>
    </div>
  );
}

export default InputArea;