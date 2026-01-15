import React, { useEffect, useState, useRef } from 'react';
import InputArea from './InputArea.jsx';
import UserGuide from './UserGuide.jsx';
import FormatSettings from './FormatSettings.jsx';
import PreviewArea from './PreviewArea.jsx';
import { useAppContext } from '../context/AppContext.jsx';

function App() {
  const {
    input,
    inputType,
    outputType,
    status,
    downloadUrl,
    filename,
    isDarkMode,
    handleInputChange,
    handleInputTypeChange,
    handleOutputTypeChange,
    handleConvert,
    handleClear,
    toggleDarkMode
  } = useAppContext();

  // 拖拽调整宽度的状态
  const [leftWidth, setLeftWidth] = useState(25);
  const [rightWidth, setRightWidth] = useState(25);
  const [isDragging, setIsDragging] = useState(null);
  const containerRef = useRef(null);

  // 根据isDarkMode状态为body元素添加/移除dark类名
  useEffect(() => {
    if (isDarkMode) {
      document.body.classList.add('dark');
    } else {
      document.body.classList.remove('dark');
    }
  }, [isDarkMode]);

  // 处理鼠标按下事件，开始拖拽
  const handleMouseDown = (e, panel) => {
    setIsDragging(panel);
    document.body.style.cursor = 'col-resize';
    document.body.style.userSelect = 'none';
  };

  // 处理鼠标移动事件，更新面板宽度
  const handleMouseMove = (e) => {
    if (!isDragging || !containerRef.current) return;

    const containerRect = containerRef.current.getBoundingClientRect();
    const containerWidth = containerRect.width;
    const mouseX = e.clientX - containerRect.left;
    const widthPercent = (mouseX / containerWidth) * 100;

    if (isDragging === 'left') {
      const newLeftWidth = Math.max(15, Math.min(40, widthPercent));
      setLeftWidth(newLeftWidth);
      setRightWidth(25); // 重置右侧宽度，保持中间宽度自适应
    } else if (isDragging === 'right') {
      const newRightWidth = Math.max(15, Math.min(40, 100 - widthPercent));
      setRightWidth(newRightWidth);
      setLeftWidth(25); // 重置左侧宽度，保持中间宽度自适应
    }
  };

  // 处理鼠标释放事件，结束拖拽
  const handleMouseUp = () => {
    setIsDragging(null);
    document.body.style.cursor = '';
    document.body.style.userSelect = '';
  };

  // 添加全局鼠标事件监听
  useEffect(() => {
    if (isDragging) {
      document.addEventListener('mousemove', handleMouseMove);
      document.addEventListener('mouseup', handleMouseUp);
    }

    return () => {
      document.removeEventListener('mousemove', handleMouseMove);
      document.removeEventListener('mouseup', handleMouseUp);
    };
  }, [isDragging]);

  return (
    <div className="app">
      <div className="app-header">
        <h1>FormulaFix - LaTeX/Markdown 转 Word/PDF</h1>
        <button 
          className="dark-mode-toggle"
          onClick={toggleDarkMode}
        >
          {isDarkMode ? '🌞 切换到浅色模式' : '🌙 切换到夜间模式'}
        </button>
      </div>
      
      <UserGuide />
      
      <div className="main-container" ref={containerRef}>
        {/* 左侧格式设置区域 */}
        <div 
          className="left-panel"
          style={{ flex: `0 0 ${leftWidth}%` }}
        >
          <FormatSettings
            onOutputTypeChange={handleOutputTypeChange}
            onConvert={handleConvert}
          />
        </div>
        
        {/* 左侧拖拽手柄 */}
        <div 
          className={`resize-handle left ${isDragging === 'left' ? 'dragging' : ''}`}
          onMouseDown={(e) => handleMouseDown(e, 'left')}
        />
        
        {/* 中间输入区域 */}
        <div className="center-panel">
          <InputArea
            input={input}
            inputType={inputType}
            outputType={outputType}
            onInputChange={handleInputChange}
            onInputTypeChange={handleInputTypeChange}
            onOutputTypeChange={handleOutputTypeChange}
            onConvert={handleConvert}
            onClear={handleClear}
          />
        </div>
        
        {/* 右侧拖拽手柄 */}
        <div 
          className={`resize-handle right ${isDragging === 'right' ? 'dragging' : ''}`}
          onMouseDown={(e) => handleMouseDown(e, 'right')}
        />
        
        {/* 右侧输出预览区域 */}
        <div 
          className="right-panel"
          style={{ flex: `0 0 ${rightWidth}%` }}
        >
          <PreviewArea
            content={input}
            inputType={inputType}
            outputType={outputType}
            status={status}
            downloadUrl={downloadUrl}
            filename={filename}
          />
        </div>
      </div>
    </div>
  );
}

export default App;