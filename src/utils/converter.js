import { Document, Packer, Paragraph, TextRun, ImageRun, HeadingLevel, AlignmentType } from 'docx';
import html2canvas from 'html2canvas';
import html2pdf from 'html2pdf.js';
import katex from 'katex';

import { PDF_OPTIONS } from './constants.js';
import { normalizeLatex } from './formula_utils.js';
import { processMarkdownWithFormulas } from './markdown_utils.js';
import { buildPdfElement } from './pdf_styles.js';

const FORMULA_DELIMITERS = [
  { regex: /\\\[([\s\S]*?)\\\]/g, displayMode: true },
  { regex: /\$\$([\s\S]*?)\$\$/g, displayMode: true },
  { regex: /\\\(([\s\S]*?)\\\)/g, displayMode: false },
  { regex: /\$([^$\n]+?)\$/g, displayMode: false },
];

function findFormulaRanges(content) {
  const places = [];
  for (const d of FORMULA_DELIMITERS) {
    d.regex.lastIndex = 0;
    let match;
    while ((match = d.regex.exec(content)) !== null) {
      places.push({
        start: match.index,
        end: match.index + match[0].length,
        formula: match[1].trim(),
        displayMode: d.displayMode,
      });
    }
  }
  places.sort((a, b) => a.start - b.start);

  const valid = [];
  let lastEnd = 0;
  for (const fp of places) {
    if (fp.start >= lastEnd) {
      valid.push(fp);
      lastEnd = fp.end;
    }
  }
  return valid;
}

function splitContentByFormulas(content) {
  const ranges = findFormulaRanges(content);
  const sections = [];
  let pos = 0;
  for (const fp of ranges) {
    if (fp.start > pos) {
      const text = content.slice(pos, fp.start).trim();
      if (text) sections.push({ type: 'text', content: text });
    }
    sections.push({ type: 'formula', formula: fp.formula, displayMode: fp.displayMode });
    pos = fp.end;
  }
  if (pos < content.length) {
    const tail = content.slice(pos).trim();
    if (tail) sections.push({ type: 'text', content: tail });
  }
  return sections;
}

async function renderFormulaToImage(formula, displayMode) {
  const container = document.createElement('div');
  container.style.cssText = 'position:absolute;left:-9999px;top:-9999px;background:white;padding:8px;';
  try {
    katex.render(formula, container, {
      throwOnError: false,
      displayMode,
      trust: true,
      strict: false,
    });
    document.body.appendChild(container);
    const canvas = await html2canvas(container, { scale: 2, backgroundColor: '#ffffff', logging: false });
    document.body.removeChild(container);
    return canvas.toDataURL('image/png').split(',')[1];
  } catch (e) {
    if (container.parentNode) document.body.removeChild(container);
    throw e;
  }
}

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
  const widthPx = section.displayMode ? 600 : 300;
  const heightPx = section.displayMode ? 120 : 40;
  return new ImageRun({
    data: base64ToUint8Array(base64),
    transformation: {
      width: Math.round(widthPx / 2),
      height: Math.round(heightPx / 2),
    },
    type: 'png',
  });
}

function buildDocxElements(sections, formulaImages) {
  const docxElements = [];
  for (const section of sections) {
    if (section.type === 'formula') {
      const imageRun = makeFormulaImage(section, formulaImages);
      if (imageRun) {
        docxElements.push(new Paragraph({
          children: [imageRun],
          alignment: AlignmentType.CENTER,
        }));
      }
    } else if (section.type === 'text') {
      const paragraphs = section.content.split(/\n{2,}/);
      for (const para of paragraphs) {
        const trimmed = para.trim();
        if (!trimmed) continue;
        const headingMatch = trimmed.match(/^(#{1,6})\s+(.+)$/);
        if (headingMatch) {
          const level = headingMatch[1].length;
          const levels = [HeadingLevel.HEADING_1, HeadingLevel.HEADING_2, HeadingLevel.HEADING_3,
            HeadingLevel.HEADING_4, HeadingLevel.HEADING_4, HeadingLevel.HEADING_4];
          docxElements.push(new Paragraph({
            children: [new TextRun({ text: headingMatch[2] })],
            heading: levels[level - 1] ?? HeadingLevel.HEADING_4,
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
      }
    }
  }
  return docxElements;
}

export async function convertToDocx(content, inputType) {
  if (!content?.trim()) throw new Error('输入内容不能为空');
  const normalized = normalizeLatex(content);
  const sections = splitContentByFormulas(normalized);

  const formulaImages = new Map();
  for (const section of sections) {
    if (section.type !== 'formula') continue;
    try {
      const img = await renderFormulaToImage(section.formula, section.displayMode);
      formulaImages.set(`${section.formula}|||${section.displayMode}`, img);
    } catch (e) {
      console.error('公式渲染失败:', section.formula, e);
    }
  }

  const docxElements = buildDocxElements(sections, formulaImages);
  const doc = new Document({ sections: [{ properties: {}, children: docxElements }] });
  return Packer.toBlob(doc);
}

export async function convertToPdf(content, inputType) {
  if (!content?.trim()) throw new Error('输入内容不能为空');

  const normalized = normalizeLatex(content);
  let contentHtml;

  if (inputType === 'markdown') {
    contentHtml = processMarkdownWithFormulas(normalized);
  } else {
    try {
      contentHtml = katex.renderToString(normalized, {
        throwOnError: false,
        displayMode: true,
        trust: true,
        strict: false,
      });
    } catch (e) {
      throw new Error(`LaTeX渲染失败: ${e.message}`);
    }
  }

  const { wrapper } = buildPdfElement(contentHtml);
  document.body.appendChild(wrapper);

  try {
    return await html2pdf().set(PDF_OPTIONS).from(wrapper).output('blob');
  } finally {
    document.body.removeChild(wrapper);
  }
}

export function captureFormulas(container) {
  const formulas = container.querySelectorAll('.katex, .katex-display');
  const cache = new Map();
  formulas.forEach((el, index) => {
    const formula = el.textContent;
    if (!cache.has(formula)) cache.set(formula, { index, element: el });
  });
  return cache;
}

export async function renderToCanvas(element, options = {}) {
  return html2canvas(element, {
    scale: options.scale || 2,
    backgroundColor: options.backgroundColor || '#ffffff',
    logging: options.logging || false,
    useCORS: options.useCORS !== false,
    ...options,
  });
}

export function createDocxDocument(elements) {
  return new Document({ sections: [{ properties: {}, children: elements }] });
}

export async function exportToPdf(element, options = {}) {
  return html2pdf().set({ ...PDF_OPTIONS, ...options }).from(element).output('blob');
}

function _triggerDownload(blob, filename) {
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
}

export function downloadPdf(blob, filename = 'document.pdf') { _triggerDownload(blob, filename); }
export function downloadDocx(blob, filename = 'document.docx') { _triggerDownload(blob, filename); }

export function downloadTxt(content, filename = 'document.txt') {
  const blob = new Blob([content], { type: 'text/plain;charset=utf-8' });
  _triggerDownload(blob, filename);
}

export function downloadHtml(html, filename = 'document.html') {
  const blob = new Blob([html], { type: 'text/html;charset=utf-8' });
  _triggerDownload(blob, filename);
}

export async function makeFormulaImg(formula, displayMode) {
  return renderFormulaToImage(formula, displayMode);
}

export { PDF_OPTIONS } from './constants.js';
export { COMMON_LATEX_COMMANDS, GREEK_LETTERS } from './constants.js';
export { extractFormulaFragments, normalizeLatex, extractFormulaFragmentsWithoutDollars } from './formula_utils.js';
export { processMarkdownWithFormulas, createPlaceholder, markdownToHtml } from './markdown_utils.js';
