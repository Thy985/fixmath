import React, { useState } from 'react';

function FormatSettings({ onOutputTypeChange, onConvert }) {
  const [outputFormat, setOutputFormat] = useState('pdf');

  const handleOutputFormatChange = (format) => {
    setOutputFormat(format);
    onOutputTypeChange(format);
  };

  return (
    <div className="format-settings">
      <h2 className="settings-title">⚙️ 转换设置</h2>

      <div className="settings-section">
        <h3 className="section-title">输出格式</h3>
        <div className="radio-group">
          <label className="radio-item">
            <input
              type="radio"
              name="outputFormat"
              value="docx"
              checked={outputFormat === 'docx'}
              onChange={() => handleOutputFormatChange('docx')}
            />
            <span className="radio-label">Word (.docx)</span>
          </label>
          <label className="radio-item">
            <input
              type="radio"
              name="outputFormat"
              value="pdf"
              checked={outputFormat === 'pdf'}
              onChange={() => handleOutputFormatChange('pdf')}
            />
            <span className="radio-label">PDF (.pdf)</span>
          </label>
        </div>
      </div>

      <div className="settings-actions">
        <button className="btn-primary btn-large" onClick={onConvert}>
          🚀 开始转换
        </button>
      </div>
    </div>
  );
}

export default FormatSettings;