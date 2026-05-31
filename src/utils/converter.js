import { Document, Packer, Paragraph, TextRun, ImageRun, HeadingLevel, AlignmentType } from 'docx';
import html2canvas from 'html2canvas';
import html2pdf from 'html2pdf.js';
import katex from 'katex';

import { PDF_OPTIONS } from './constants.js';
import { extractFormulaFragments, normalizeLatex } from './formula_utils.js';
import { processMarkdownWithFormulas } from './markdown_utils.js';

// 公式缓存
const formulaCache = new Map();

// 辅助函数：处理Markdown内联内容（strong, em, text等）
function processInlineContent(tokens, normalize = true) {
  let text = '';
  
  tokens.forEach(token => {
    if (token.type === 'text') {
      text += token.text;
    } else if (token.type === 'strong' || token.type === 'em') {
      text += processInlineContent(token.tokens, normalize).text;
    } else if (token.type === 'escape') {
      text += token.text;
    } else if (token.type === 'html') {
      text += token.text;
    } else if (token.type === 'link') {
      text += processInlineContent(token.tokens, normalize).text;
    } else if (token.type === 'image') {
      text += token.alt || '';
    } else if (token.type === 'br') {
      text += ' ';
    }
  });
  
  const formulaFragments = extractFormulaFragments(normalize ? normalizeLatex(text) : text);
  
  return { text, formulaFragments };
}

// 解析Markdown，提取文本和公式
async function parseMarkdown(content) {
  const elements = [];
  
  const lines = content.split('\n');
  let currentLine = '';
  
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    
    if (line.trim() === '' && currentLine.trim() === '') {
      elements.push({
        type: 'empty_line'
      });
    } else if (line.trim() === '') {
      currentLine += ' ';
    } else {
      currentLine += line + '\n';
    }
  }
  
  const tokens = katex && katex.__parse ? [] : [];
  
  const processList = (listToken) => {
    listToken.items.forEach(item => {
      const { formulaFragments } = processInlineContent(item.tokens);
      
      elements.push({
        type: 'list_item',
        content: formulaFragments
      });
      
      if (item.tokens) {
        item.tokens.forEach(token => {
          if (token.type === 'list') {
            processList(token);
          }
        });
      }
    });
  };
  
  return elements;
}

// 解析纯LaTeX内容
async function parseLatex(content) {
  return await parseMarkdown(content);
}

// 将公式渲染为图片（用于嵌入 DOCX）
async function renderFormulaToImage(formula, displayMode) {
  const container = document.createElement('div');
  container.style.cssText = 'position:absolute;left:-9999px;top:-9999px;background:white;padding:8px;';

  try {
    katex.render(formula, container, {
      throwOnError: false,
      displayMode,
      trust: true,
      strict: false
    });

    document.body.appendChild(container);

    const canvas = await html2canvas(container, {
      scale: 2,
      backgroundColor: '#ffffff',
      logging: false
    });

    document.body.removeChild(container);

    const dataUrl = canvas.toDataURL('image/png');
    const base64 = dataUrl.split(',')[1];
    return base64;
  } catch (e) {
    if (container.parentNode) document.body.removeChild(container);
    throw e;
  }
}

// 解析内容，提取公式位置信息
async function parseContentForDocx(content, inputType) {
  const normalizedContent = normalizeLatex(content);

  const formulaPlaces = [];
  const delimiters = [
    { regex: /\\\[([\s\S]*?)\\\]/g, displayMode: true },
    { regex: /\$\$([\s\S]*?)\$\$/g, displayMode: true },
    { regex: /\\\(([\s\S]*?)\\\)/g, displayMode: false },
    { regex: /\$([^$\n]+?)\$/g, displayMode: false },
  ];

  for (const d of delimiters) {
    let match;
    d.regex.lastIndex = 0;
    while ((match = d.regex.exec(normalizedContent)) !== null) {
      formulaPlaces.push({
        start: match.index,
        end: match.index + match[0].length,
        formula: match[1].trim(),
        displayMode: d.displayMode,
        fullMatch: match[0]
      });
    }
  }

  formulaPlaces.sort((a, b) => a.start - b.start);

  const validPlaces = [];
  let lastEnd = 0;
  for (const fp of formulaPlaces) {
    if (fp.start >= lastEnd) {
      validPlaces.push(fp);
      lastEnd = fp.end;
    }
  }

  const sections = [];
  let pos = 0;
  for (const fp of validPlaces) {
    if (fp.start > pos) {
      const text = normalizedContent.slice(pos, fp.start).trim();
      if (text) sections.push({ type: 'text', content: text });
    }
    sections.push({ type: 'formula', formula: fp.formula, displayMode: fp.displayMode });
    pos = fp.end;
  }
  if (pos < normalizedContent.length) {
    const tail = normalizedContent.slice(pos).trim();
    if (tail) sections.push({ type: 'text', content: tail });
  }

  let htmlText = '';
  if (inputType === 'markdown') {
    htmlText = processMarkdownWithFormulas(normalizedContent);
  }

  const formulaImages = new Map();
  for (const fp of validPlaces) {
    try {
      const img = await renderFormulaToImage(fp.formula, fp.displayMode);
      formulaImages.set(`${fp.formula}|||${fp.displayMode}`, img);
    } catch (e) {
      console.error('公式渲染失败:', fp.formula, e);
    }
  }

  return { sections, formulaImages, htmlText };
}

// Buffer→Uint8Array 转换函数（保留兼容性）
function base64ToUint8Array(base64) {
  const binaryString = atob(base64);
  const bytes = new Uint8Array(binaryString.length);
  for (let i = 0; i < binaryString.length; i++) {
    bytes[i] = binaryString.charCodeAt(i);
  }
  return bytes;
}

function makeFormulaImage(section, formulaImages) {
  const key = `${section.formula}|||${section.displayMode}`;
  const base64 = formulaImages.get(key);
  if (!base64) return null;

  const isDisplay = section.displayMode;
  const widthPx = isDisplay ? 600 : 300;
  const heightPx = isDisplay ? 120 : 40;

  const imageData = base64ToUint8Array(base64);

  return new ImageRun({
    data: imageData,
    transformation: {
      width: Math.round(widthPx / 2),
      height: Math.round(heightPx / 2),
    },
    type: 'png',
  });
}

// 将解析后的元素转换为docx.js的文档结构（图片公式版）
function buildDocxStructureFromSections(sections, formulaImages) {
  const docxElements = [];

  sections.forEach(section => {
    if (section.type === 'formula') {
      const imageRun = makeFormulaImage(section, formulaImages);
      if (imageRun) {
        docxElements.push(new Paragraph({
          children: [imageRun],
          alignment: AlignmentType.CENTER,
        }));
      }
    } else if (section.type === 'text') {
      const lines = section.content.split(/\n{2,}/);
      lines.forEach(line => {
        const trimmed = line.trim();
        if (!trimmed) return;

        const headingMatch = trimmed.match(/^(#{1,6})\s+(.+)$/);
        if (headingMatch) {
          const level = headingMatch[1].length;
          const text = headingMatch[2];
          docxElements.push(new Paragraph({
            children: [new TextRun({ text })],
            heading: level === 1 ? HeadingLevel.HEADING_1 :
                     level === 2 ? HeadingLevel.HEADING_2 :
                     level === 3 ? HeadingLevel.HEADING_3 :
                     HeadingLevel.HEADING_4,
          }));
        } else {
          const cleanText = trimmed
            .replace(/\*\*(.+?)\*\*/g, '$1')
            .replace(/\*(.+?)\*/g, '$1')
            .replace(/`(.+?)`/g, '$1')
            .replace(/^[-*]\s+/, '')
            .replace(/^\d+\.\s+/, '');

          if (cleanText) {
            docxElements.push(new Paragraph({
              children: [new TextRun({ text: cleanText })],
            }));
          }
        }
      });
    }
  });

  return docxElements;
}

// 导出转换为PDF的函数
export async function convertToPdf(content, inputType) {
  try {
    if (!content || content.trim() === '') {
      throw new Error('输入内容不能为空');
    }
    
    console.log('开始转换为PDF，输入类型:', inputType);
    
    const normalizedContent = normalizeLatex(content);
    
    const tempElement = document.createElement('div');
    tempElement.className = 'pdf-content';
    
    const pdfStyle = document.createElement('style');
    pdfStyle.textContent = `
      .pdf-content {
        font-family: 'Times New Roman', Times, serif;
        font-size: 12pt;
        line-height: 1.8;
        color: #000000;
        background-color: white;
        padding: 20px;
        box-sizing: border-box;
        width: 100%;
        max-width: 210mm;
        margin: 0 auto;
      }
      
      .pdf-content h1,
      .pdf-content h2,
      .pdf-content h3,
      .pdf-content h4,
      .pdf-content h5,
      .pdf-content h6 {
        margin-top: 25px;
        margin-bottom: 15px;
        font-weight: bold;
        color: #000000;
        page-break-after: avoid;
        page-break-inside: avoid;
      }
      
      .pdf-content h1 {
        font-size: 24pt;
        border-bottom: 2px solid #000000;
        padding-bottom: 10px;
        text-align: center;
        margin-top: 40px;
        margin-bottom: 30px;
      }
      
      .pdf-content h2 {
        font-size: 18pt;
        padding-bottom: 8px;
        text-align: left;
        margin-top: 35px;
        margin-bottom: 25px;
      }
      
      .pdf-content h3 {
        font-size: 16pt;
        text-align: left;
        margin-top: 30px;
        margin-bottom: 20px;
      }
      
      .pdf-content p {
        margin: 12px 0;
        text-align: justify;
        text-indent: 2em;
        line-height: 1.8;
        text-align-last: left;
      }
      
      .pdf-content p:first-of-type {
        text-indent: 0;
      }
      
      .pdf-content ul {
        margin: 15px 0 15px 25px;
        padding-left: 20px;
        list-style-type: disc;
      }
      
      .pdf-content ol {
        margin: 15px 0 15px 25px;
        padding-left: 20px;
        list-style-type: decimal;
      }
      
      .pdf-content li {
        margin: 8px 0;
        text-align: justify;
        line-height: 1.7;
        list-style-position: outside;
      }
      
      .pdf-content pre {
        background-color: #f0f0f0;
        border: 1px solid #d0d0d0;
        border-radius: 4px;
        padding: 15px;
        overflow: auto;
        font-family: 'Courier New', Courier, monospace;
        font-size: 10pt;
        margin: 15px 0;
        page-break-inside: avoid;
      }
      
      .pdf-content code {
        background-color: #f0f0f0;
        padding: 2px 5px;
        border-radius: 3px;
        font-family: 'Courier New', Courier, monospace;
        font-size: 11pt;
      }
      
      .pdf-content blockquote {
        margin: 15px 0;
        padding: 12px 20px;
        border-left: 4px solid #666666;
        background-color: #f0f0f0;
        font-style: italic;
        page-break-inside: avoid;
      }
      
      .pdf-content .katex-display {
        margin: 20px auto;
        text-align: center !important;
        page-break-inside: avoid;
        overflow-x: auto;
        overflow-y: hidden;
      }
      
      .pdf-content .katex {
        font-size: 1.1em !important;
        line-height: 1.6;
        font-family: 'Times New Roman', Times, serif;
      }
      
      .pdf-content .katex-inline {
        vertical-align: -0.15em;
        font-size: 1.05em !important;
        margin: 0 4px;
      }
      
      .pdf-content .katex-mathml {
        display: none;
      }
      
      .pdf-content .katex-display > .katex {
        margin: 0 auto;
        max-width: 90%;
      }
      
      .pdf-content .katex,
      .pdf-content .katex-display,
      .pdf-content .katex-block {
        page-break-inside: avoid !important;
        break-inside: avoid !important;
      }
      
      .pdf-content table {
        border-collapse: collapse;
        width: 100%;
        margin: 15px 0;
        page-break-inside: avoid;
      }
      
      .pdf-content th,
      .pdf-content td {
        border: 1px solid #000000;
        padding: 8px 12px;
        text-align: left;
        font-size: 11pt;
      }
      
      .pdf-content th {
        background-color: #f0f0f0;
        font-weight: bold;
      }
      
      .pdf-content p + .katex-display,
      .pdf-content .katex-display + p {
        margin-top: 20px;
      }
      
      .page-break-before {
        page-break-before: always;
      }
      
      .page-break-after {
        page-break-after: always;
      }
      
      .pdf-content h1, .pdf-content h2, .pdf-content h3, .pdf-content h4,
      .pdf-content h5, .pdf-content h6, .pdf-content p, .pdf-content table,
      .pdf-content figure, .pdf-content blockquote, .pdf-content pre {
        page-break-inside: avoid;
      }
      
      .pdf-content img {
        max-width: 100%;
        height: auto;
        display: block;
        margin: 15px auto;
        page-break-inside: avoid;
      }
      
      .pdf-content hr {
        border: none;
        border-top: 1px solid #000000;
        margin: 25px 0;
      }
      
      @page {
        margin: 15mm 20mm 15mm 20mm;
      }
    `;
    tempElement.appendChild(pdfStyle);
    
    const contentContainer = document.createElement('div');
    tempElement.appendChild(contentContainer);
    
    if (inputType === 'markdown') {
      const html = processMarkdownWithFormulas(normalizedContent);
      contentContainer.innerHTML = html;
    } else {
      try {
        const renderedHtml = katex.renderToString(normalizedContent, {
          throwOnError: false,
          displayMode: true,
          trust: true,
          strict: false
        });
        contentContainer.innerHTML = renderedHtml;
      } catch (e) {
        console.error('LaTeX渲染失败:', normalizedContent, e);
        contentContainer.textContent = `无法渲染LaTeX: ${e.message}`;
      }
    }
    
    document.body.appendChild(tempElement);
    
    console.log('开始生成PDF...');
    const pdfBlob = await html2pdf().set(PDF_OPTIONS).from(tempElement).output('blob');
    
    document.body.removeChild(tempElement);
    
    console.log('PDF生成完成，大小:', pdfBlob.size, '字节');
    
    return pdfBlob;
  } catch (error) {
    console.error('PDF转换错误:', error);
    
    let errorMessage = 'PDF转换失败';
    if (error.message.includes('Empty input')) {
      errorMessage += ': 输入内容不能为空';
    } else if (error.message.includes('Invalid')) {
      errorMessage += ': 输入格式无效，请检查LaTeX语法';
    } else if (error.message.includes('Unexpected')) {
      errorMessage += ': 遇到意外字符，请检查输入内容';
    } else {
      errorMessage += `: ${error.message}`;
    }
    
    throw new Error(errorMessage);
  }
}

// 主转换函数
export async function convertToDocx(content, inputType) {
  try {
    if (!content || content.trim() === '') {
      throw new Error('输入内容不能为空');
    }

    console.log('开始转换DOCX，输入类型:', inputType);

    const { sections, formulaImages } = await parseContentForDocx(content, inputType);
    const docxElements = buildDocxStructureFromSections(sections, formulaImages);

    console.log('docx结构构建完成，生成', docxElements.length, '个docx元素');

    const doc = new Document({
      sections: [{ properties: {}, children: docxElements }],
    });

    console.log('开始生成文档...');
    const blob = await Packer.toBlob(doc);
    console.log('文档生成完成，大小:', blob.size, '字节');

    return blob;
  } catch (error) {
    console.error('DOCX转换错误:', error);
    throw new Error(`文档转换失败: ${error.message}`);
  }
}

// 辅助函数：捕获页面中的公式并缓存
export function captureFormulas(container) {
  const formulas = container.querySelectorAll('.katex, .katex-display');
  formulas.forEach((el, index) => {
    const formula = el.textContent;
    if (!formulaCache.has(formula)) {
      formulaCache.set(formula, { index, element: el });
    }
  });
  return formulaCache;
}

// 辅助函数：清除公式缓存
export function clearFormulaCache() {
  formulaCache.clear();
}

// 辅助函数：渲染到Canvas
export async function renderToCanvas(element, options = {}) {
  const canvas = await html2canvas(element, {
    scale: options.scale || 2,
    backgroundColor: options.backgroundColor || '#ffffff',
    logging: options.logging || false,
    useCORS: options.useCORS !== false,
    ...options
  });
  return canvas;
}

// 辅助函数：创建DOCX文档
export function createDocxDocument(elements) {
  return new Document({
    sections: [{ properties: {}, children: elements }],
  });
}

// 辅助函数：导出到PDF
export async function exportToPdf(element, options = {}) {
  const pdfOptions = { ...PDF_OPTIONS, ...options };
  return await html2pdf().set(pdfOptions).from(element).output('blob');
}

// 辅助函数：创建DOCX下载
export function createDocxDownload(blob, filename = 'document.docx') {
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
}

// 辅助函数：下载PDF
export function downloadPdf(blob, filename = 'document.pdf') {
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
}

// 辅助函数：下载DOCX
export function downloadDocx(blob, filename = 'document.docx') {
  createDocxDownload(blob, filename);
}

// 辅助函数：下载TXT
export function downloadTxt(content, filename = 'document.txt') {
  const blob = new Blob([content], { type: 'text/plain;charset=utf-8' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
}

// 辅助函数：下载HTML
export function downloadHtml(html, filename = 'document.html') {
  const blob = new Blob([html], { type: 'text/html;charset=utf-8' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
}

// 辅助函数：创建公式图片
export async function makeFormulaImg(formula, displayMode) {
  return await renderFormulaToImage(formula, displayMode);
}

// 重新导出所有模块
export { PDF_OPTIONS } from './constants.js';
export { COMMON_LATEX_COMMANDS, GREEK_LETTERS } from './constants.js';
export { extractFormulaFragments, normalizeLatex, extractFormulaFragmentsWithoutDollars } from './formula_utils.js';
export { processMarkdownWithFormulas, createPlaceholder, markdownToHtml } from './markdown_utils.js';
