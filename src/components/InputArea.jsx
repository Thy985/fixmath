import React from 'react';
import MathField from './MathField.jsx';

function InputArea({ input, inputType, outputType, onInputChange, onInputTypeChange, onOutputTypeChange, onConvert, onClear }) {
  return (
    <div className="input-section">
      <div className="input-header">
        <h3>输入内容</h3>
        <div className="input-type-selector">
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
        </div>
        <div className="output-type-selector">
          <span>输出格式：</span>
          <button 
            className={outputType === 'docx' ? 'active' : ''}
            onClick={() => onOutputTypeChange('docx')}
          >
            Word (.docx)
          </button>
          <button 
            className={outputType === 'pdf' ? 'active' : ''}
            onClick={() => onOutputTypeChange('pdf')}
          >
            PDF (.pdf)
          </button>
        </div>
      </div>
      
      {/* 根据输入类型选择使用 MathField 或普通 textarea */}
      {inputType === 'latex' ? (
        <div style={{ position: 'relative', minHeight: '160px' }}>
          <MathField
            value={input}
            onChange={onInputChange}
            className="math-field-wrapper"
          />
        </div>
      ) : (
        <textarea
          value={input}
          onChange={(e) => onInputChange(e.target.value)}
          placeholder={`请输入${inputType === 'markdown' ? 'Markdown' : 'LaTeX'}内容...`}
          rows={8}
        />
      )}
      
      <div className="button-group">
        <button className="btn-secondary" onClick={onClear}>
          清空
        </button>
        <button className="btn-primary" onClick={onConvert}>
          转换为{outputType === 'docx' ? 'Word' : 'PDF'}
        </button>
      </div>
    </div>
  );
}

export default InputArea;