import React from 'react';

function OutputArea({ status, downloadUrl, filename, outputType }) {
  const statusClass = status.startsWith('success') ? 'success' : status.startsWith('error') ? 'error' : '';
  const statusText = status.replace(/^(success|error):\s*/, '');
  const downloadText = outputType === 'docx' ? '下载Word文档' : '下载PDF文档';

  return (
    <div className="output-section">
      <div className={`status ${statusClass}`}>
        {status || '准备转换'}
      </div>
      
      {downloadUrl && (
        <a 
          href={downloadUrl} 
          className="download-link"
          download={filename}
          onClick={() => {
            // 清理URL对象，避免内存泄漏
            setTimeout(() => URL.revokeObjectURL(downloadUrl), 100);
          }}
        >
          {downloadText}
        </a>
      )}
    </div>
  );
}

export default OutputArea;