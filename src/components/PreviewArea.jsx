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
  const timerRef = useRef(null);
  const latestContentRef = useRef(content);

  useEffect(() => {
    latestContentRef.current = content;

    if (timerRef.current) {
      clearTimeout(timerRef.current);
    }

    timerRef.current = setTimeout(() => {
      setDebouncedContent(content);
    }, 300);

    return () => {
      if (timerRef.current) {
        clearTimeout(timerRef.current);
      }
    };
  }, [content]);

  useEffect(() => {
    if (!debouncedContent || !previewRef.current) return;

    const normalizedContent = normalizeLatex(debouncedContent);

    if (inputType === 'markdown') {
      const html = processMarkdownWithFormulas(normalizedContent);
      previewRef.current.innerHTML = html;
    } else {
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