import React, { useState } from 'react';

function FormatSettings({ onOutputTypeChange, onConvert }) {
  const [outputFormat, setOutputFormat] = useState('docx');
  const [documentTemplate, setDocumentTemplate] = useState('学术论文');
  const [pageSize, setPageSize] = useState('A4');
  const [margins, setMargins] = useState('普通');
  const [lineSpacing, setLineSpacing] = useState('1.5倍');
  const [includeFormulas, setIncludeFormulas] = useState(true);
  const [preserveImageQuality, setPreserveImageQuality] = useState(true);
  const [generateTableOfContents, setGenerateTableOfContents] = useState(false);

  // 处理输出格式变化
  const handleOutputFormatChange = (format) => {
    setOutputFormat(format);
    onOutputTypeChange(format);
  };

  // 处理开始转换
  const handleConvert = () => {
    onConvert();
  };

  return (
    <div className="format-settings">
      <h2 className="settings-title">⚙️ 转换设置</h2>

      {/* 输出格式 */}
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

      {/* 文档模板 */}
      <div className="settings-section">
        <h3 className="section-title">文档模板</h3>
        <select
          className="template-select"
          value={documentTemplate}
          onChange={(e) => setDocumentTemplate(e.target.value)}
        >
          <option value="学术论文">学术论文</option>
          <option value="简历模板">简历模板</option>
          <option value="报告模板">报告模板</option>
          <option value="自定义模板">自定义模板...</option>
        </select>
      </div>

      {/* 页面设置 */}
      <div className="settings-section">
        <h3 className="section-title">页面设置</h3>
        <div className="setting-item">
          <label>纸张大小：</label>
          <select
            className="small-select"
            value={pageSize}
            onChange={(e) => setPageSize(e.target.value)}
          >
            <option value="A4">A4</option>
            <option value="A3">A3</option>
            <option value="Letter">Letter</option>
            <option value="Legal">Legal</option>
          </select>
        </div>
        <div className="setting-item">
          <label>页边距：</label>
          <select
            className="small-select"
            value={margins}
            onChange={(e) => setMargins(e.target.value)}
          >
            <option value="普通">普通</option>
            <option value="窄">窄</option>
            <option value="宽">宽</option>
          </select>
        </div>
        <div className="setting-item">
          <label>行间距：</label>
          <select
            className="small-select"
            value={lineSpacing}
            onChange={(e) => setLineSpacing(e.target.value)}
          >
            <option value="1倍">1倍</option>
            <option value="1.5倍">1.5倍</option>
            <option value="2倍">2倍</option>
          </select>
        </div>
      </div>

      {/* 转换选项 */}
      <div className="settings-section">
        <h3 className="section-title">转换选项</h3>
        <div className="checkbox-group">
          <label className="checkbox-item">
            <input
              type="checkbox"
              checked={includeFormulas}
              onChange={(e) => setIncludeFormulas(e.target.checked)}
            />
            <span className="checkbox-label">包含数学公式</span>
          </label>
          <label className="checkbox-item">
            <input
              type="checkbox"
              checked={preserveImageQuality}
              onChange={(e) => setPreserveImageQuality(e.target.checked)}
            />
            <span className="checkbox-label">保留图片质量</span>
          </label>
          <label className="checkbox-item">
            <input
              type="checkbox"
              checked={generateTableOfContents}
              onChange={(e) => setGenerateTableOfContents(e.target.checked)}
            />
            <span className="checkbox-label">生成目录</span>
          </label>
        </div>
      </div>

      {/* 操作按钮 */}
      <div className="settings-actions">
        <button className="btn-primary btn-large" onClick={handleConvert}>
          🚀 开始转换
        </button>
        <button className="btn-secondary">
          💾 保存设置
        </button>
      </div>
    </div>
  );
}

export default FormatSettings;