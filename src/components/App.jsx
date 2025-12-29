import React, { useState } from 'react';
import InputArea from './InputArea.jsx';
import OutputArea from './OutputArea.jsx';
import FormulaPreview from './FormulaPreview.jsx';
import { convertToDocx, convertToPdf } from '../utils/converter.js';

function App() {
  const [input, setInput] = useState('');
  const [inputType, setInputType] = useState('markdown'); // 'markdown' or 'latex'
  const [outputType, setOutputType] = useState('pdf'); // 'docx' or 'pdf', 默认PDF
  const [status, setStatus] = useState('');
  const [downloadUrl, setDownloadUrl] = useState('');
  const [filename, setFilename] = useState('output.pdf');

  const handleInputChange = (value) => {
    // 兼容两种情况：1. 事件对象（来自普通textarea）；2. 直接字符串（来自MathField）
    const inputValue = value.target ? value.target.value : value;
    setInput(inputValue);
  };

  const handleInputTypeChange = (type) => {
    setInputType(type);
  };

  const handleOutputTypeChange = (type) => {
    setOutputType(type);
  };

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

  const handleClear = () => {
    setInput('');
    setStatus('');
    setDownloadUrl('');
  };

  return (
    <div className="app">
      <h1>FormulaFix - LaTeX/Markdown 转 Word/PDF</h1>
      
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
      
      <FormulaPreview 
        content={input} 
        inputType={inputType} 
      />
      
      <OutputArea 
        status={status}
        downloadUrl={downloadUrl}
        filename={filename}
        outputType={outputType}
      />
    </div>
  );
}

export default App;