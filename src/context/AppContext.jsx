import React, { createContext, useContext, useState } from 'react';
import { convertToDocx, convertToPdf } from '../utils/converter.js';

// 创建Context
const AppContext = createContext();

// 创建Provider组件
export function AppProvider({ children }) {
  const [input, setInput] = useState('');
  const [inputType, setInputType] = useState('markdown'); // 'markdown' or 'latex'
  const [outputType, setOutputType] = useState('pdf'); // 'docx' or 'pdf', 默认PDF
  const [status, setStatus] = useState('');
  const [downloadUrl, setDownloadUrl] = useState('');
  const [filename, setFilename] = useState('output.pdf');
  const [isDarkMode, setIsDarkMode] = useState(false);

  // 处理输入内容变化
  const handleInputChange = (value) => {
    // 兼容两种情况：1. 事件对象（来自普通textarea）；2. 直接字符串（来自MathField）
    const inputValue = value.target ? value.target.value : value;
    setInput(inputValue);
  };

  // 处理输入类型变化
  const handleInputTypeChange = (type) => {
    setInputType(type);
  };

  // 处理输出类型变化
  const handleOutputTypeChange = (type) => {
    setOutputType(type);
  };

  // 处理转换
  const handleConvert = async () => {
    if (!input.trim()) {
      setStatus('error: 请输入内容');
      return;
    }

    setStatus('转换中...');
    try {
      let blob;
      let ext;
      
      if (outputType === 'docx') {
        blob = await convertToDocx(input, inputType);
        ext = 'docx';
      } else {
        blob = await convertToPdf(input, inputType);
        ext = 'pdf';
      }
      
      const url = URL.createObjectURL(blob);
      setDownloadUrl(url);
      setFilename(`formulafix_${new Date().toISOString().slice(0, 10)}.${ext}`);
      setStatus('success: 转换完成');
    } catch (error) {
      console.error('转换错误:', error);
      setStatus(`error: 转换失败 - ${error.message}`);
    }
  };

  // 处理清空
  const handleClear = () => {
    setInput('');
    setStatus('');
    setDownloadUrl('');
  };

  // 切换夜间模式
  const toggleDarkMode = () => {
    setIsDarkMode(!isDarkMode);
  };

  // 提供的Context值
  const contextValue = {
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
  };

  return (
    <AppContext.Provider value={contextValue}>
      {children}
    </AppContext.Provider>
  );
}

// 创建自定义Hook，方便组件使用Context
export function useAppContext() {
  const context = useContext(AppContext);
  if (!context) {
    throw new Error('useAppContext must be used within an AppProvider');
  }
  return context;
}
