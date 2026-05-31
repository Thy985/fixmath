import { marked } from 'marked';
import katex from 'katex';

// 导出processMarkdownWithFormulas函数，统一处理Markdown中的公式
export function processMarkdownWithFormulas(content) {
  let tempContent = content;
  const formulaMap = new Map();
  let formulaIndex = 0;
  
  tempContent = tempContent.replace(/\$\$(.*?)\$\$/gs, (match, formula) => {
    const placeholder = `<!-- FORMULA_BLOCK_${formulaIndex} -->`;
    formulaMap.set(placeholder, {
      formula: formula,
      displayMode: true
    });
    formulaIndex++;
    return placeholder;
  });
  
  tempContent = tempContent.replace(/\\\[(.*?)\\\]/gs, (match, formula) => {
    const placeholder = `<!-- FORMULA_BLOCK_${formulaIndex} -->`;
    formulaMap.set(placeholder, {
      formula: formula,
      displayMode: true
    });
    formulaIndex++;
    return placeholder;
  });
  
  tempContent = tempContent.replace(/\$(.*?)\$/gs, (match, formula) => {
    const placeholder = `<!-- FORMULA_INLINE_${formulaIndex} -->`;
    formulaMap.set(placeholder, {
      formula: formula,
      displayMode: false
    });
    formulaIndex++;
    return placeholder;
  });
  
  tempContent = tempContent.replace(/\\\((.*?)\\\)/gs, (match, formula) => {
    const placeholder = `<!-- FORMULA_INLINE_${formulaIndex} -->`;
    formulaMap.set(placeholder, {
      formula: formula,
      displayMode: false
    });
    formulaIndex++;
    return placeholder;
  });
  
  let html = marked.parse(tempContent);
  
  html = html.replace(/&#39;/g, "'");
  html = html.replace(/&quot;/g, '"');
  html = html.replace(/&lt;/g, '<');
  html = html.replace(/&gt;/g, '>');
  html = html.replace(/&amp;/g, '&');
  
  formulaMap.forEach((formulaInfo, placeholder) => {
    try {
      const renderedFormula = katex.renderToString(formulaInfo.formula, {
        throwOnError: false,
        displayMode: formulaInfo.displayMode,
        trust: true,
        strict: false
      });
      html = html.replace(new RegExp(placeholder.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'g'), renderedFormula);
    } catch (e) {
      console.error(`公式渲染失败 (${formulaInfo.displayMode ? '块级' : '行内'}):`, formulaInfo.formula, e);
      const delimiter = formulaInfo.displayMode ? '$$' : '$';
      html = html.replace(new RegExp(placeholder.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'g'), `${delimiter}${formulaInfo.formula}${delimiter}`);
    }
  });
  
  return html;
}

// 辅助函数：创建占位符
export function createPlaceholder(formula, displayMode) {
  return {
    formula,
    displayMode,
    placeholder: displayMode ? `FORMULA_BLOCK_${Date.now()}` : `FORMULA_INLINE_${Date.now()}`
  };
}

// markdownToHtml: 将Markdown转换为HTML（不处理公式）
export function markdownToHtml(markdown) {
  return marked.parse(markdown);
}
