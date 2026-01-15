import React, { useEffect, useRef, useState, useCallback } from 'react';
import katex from 'katex';
import 'katex/dist/katex.min.css';
import { normalizeLatex, processMarkdownWithFormulas } from '../utils/converter.js';

function PreviewArea({ content, inputType, outputType, status, downloadUrl, filename }) {
  const previewRef = useRef(null);
  const [debouncedContent, setDebouncedContent] = useState(content);
  const [previewStyle, setPreviewStyle] = useState('word');
  const [zoom, setZoom] = useState(1);
  const [isFullscreen, setIsFullscreen] = useState(false);
  
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
    }, 300),
    [debounce]
  );
  
  // 监听原始内容变化，触发防抖更新
  useEffect(() => {
    debouncedUpdate(content);
  }, [content, debouncedUpdate]);

  // 渲染预览内容
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
  }, [debouncedContent, inputType, previewStyle]);

  // 切换全屏模式
  const toggleFullscreen = () => {
    setIsFullscreen(!isFullscreen);
  };

  // 调整缩放级别
  const handleZoomChange = (delta) => {
    const newZoom = Math.max(0.5, Math.min(2, zoom + delta));
    setZoom(newZoom);
  };

  // 刷新预览
  const handleRefreshPreview = () => {
    setDebouncedContent(content);
  };

  // 下载文件
  const handleDownload = () => {
    if (downloadUrl) {
      const link = document.createElement('a');
      link.href = downloadUrl;
      link.download = filename;
      link.click();
      // 清理URL对象，避免内存泄漏
      setTimeout(() => URL.revokeObjectURL(downloadUrl), 100);
    }
  };

  return (
    <div className={`preview-section ${isFullscreen ? 'fullscreen' : ''}`}>
      <div className="preview-header">
        <h3>👁️ 实时预览</h3>
        <div className="preview-controls">
          <div className="preview-style-selector">
            <button 
              className={previewStyle === 'word' ? 'active' : ''}
              onClick={() => setPreviewStyle('word')}
            >
              Word样式
            </button>
            <button 
              className={previewStyle === 'pdf' ? 'active' : ''}
              onClick={() => setPreviewStyle('pdf')}
            >
              PDF样式
            </button>
            <button 
              className={previewStyle === 'web' ? 'active' : ''}
              onClick={() => setPreviewStyle('web')}
            >
              网页样式
            </button>
          </div>
          <div className="zoom-controls">
            <button onClick={() => handleZoomChange(-0.1)}>-</button>
            <span>{Math.round(zoom * 100)}%</span>
            <button onClick={() => handleZoomChange(0.1)}>+</button>
          </div>
        </div>
      </div>
      
      <div 
        className={`preview-content ${previewStyle}`}
        ref={previewRef}
        style={{ transform: `scale(${zoom})`, transformOrigin: 'top left' }}
      ></div>
      
      <div className="preview-footer">
        <div className="page-info">
          第1页/共1页
        </div>
        <div className="preview-actions">
          <button className="btn-secondary" onClick={handleRefreshPreview}>
            🔄 刷新预览
          </button>
          <button className="btn-secondary" onClick={toggleFullscreen}>
            📄 {isFullscreen ? '退出全屏' : '全屏预览'}
          </button>
          {downloadUrl && (
            <button className="btn-primary" onClick={handleDownload}>
              ⬇️ 导出
            </button>
          )}
        </div>
      </div>
      
      {status && (
        <div className={`status ${status.startsWith('success') ? 'success' : status.startsWith('error') ? 'error' : ''}`}>
          {status.replace(/^(success|error):\s*/, '')}
        </div>
      )}
    </div>
  );
}

export default PreviewArea;