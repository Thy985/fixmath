import { COMMON_LATEX_COMMANDS, GREEK_LETTERS } from './constants.js';

// 辅助函数：识别文本中的公式片段（不处理$定界符）
function extractFormulaFragmentsWithoutDollars(text) {
  if (text.match(/(lim|frac|sqrt|int|sum|prod|sin|cos|tan|log|ln|exp)/i)) {
    return [
      {
        type: 'formula',
        content: text,
        displayMode: false
      }
    ];
  }
  
  return [
    {
      type: 'text',
      content: text
    }
  ];
}

// 辅助函数：识别文本中的公式片段
function extractFormulaFragments(text) {
  const fragments = [];
  let lastIndex = 0;
  
  const formulaDelimiters = [
    { 
      regex: /\\\[(.*?)\\\]/gs,
      displayMode: true,
      name: 'block_brackets'
    },
    { 
      regex: /\$\$(.*?)\$\$/gs,
      displayMode: true,
      name: 'block_dollars'
    },
    { 
      regex: /\\\((.*?)\\\)/gs,
      displayMode: false,
      name: 'inline_parentheses'
    },
    { 
      regex: /\$(.*?)\$/g,
      displayMode: false,
      name: 'inline_dollars'
    }
  ];
  
  const allMatches = [];
  
  formulaDelimiters.forEach(delimiter => {
    const regex = delimiter.regex;
    let match;
    regex.lastIndex = 0;
    
    while ((match = regex.exec(text)) !== null) {
      allMatches.push({
        start: match.index,
        end: match.index + match[0].length,
        content: match[1],
        displayMode: delimiter.displayMode,
        delimiter: delimiter.name,
        fullMatch: match[0]
      });
    }
  });
  
  allMatches.sort((a, b) => a.start - b.start);
  
  const validMatches = [];
  let lastEnd = 0;
  
  allMatches.forEach(match => {
    if (match.start >= lastEnd) {
      validMatches.push(match);
      lastEnd = match.end;
    }
  });
  
  validMatches.forEach(match => {
    if (match.start > lastIndex) {
      const textBefore = text.slice(lastIndex, match.start);
      if (textBefore.trim() !== '') {
        fragments.push(...extractFormulaFragmentsWithoutDollars(textBefore));
      }
    }
    
    fragments.push({
      type: 'formula',
      content: match.content,
      displayMode: match.displayMode
    });
    
    lastIndex = match.end;
  });
  
  if (lastIndex < text.length) {
    const remainingText = text.slice(lastIndex);
    if (remainingText.trim() !== '') {
      fragments.push(...extractFormulaFragmentsWithoutDollars(remainingText));
    }
  }
  
  return fragments.map(fragment => {
    if (fragment.type === 'text') {
      fragment.content = fragment.content.trim();
      if (fragment.content === '') {
        return null;
      }
    }
    return fragment;
  }).filter(Boolean);
}

// 导出normalizeLatex函数
export function normalizeLatex(content) {
  let normalized = String(content);
  
  const processContentSegment = (text) => {
    let processed = text;
    
    COMMON_LATEX_COMMANDS.forEach(cmd => {
      processed = processed.replace(new RegExp(`(\\s|^)${cmd}(\\s|$)`, 'g'), `$1\\${cmd}$2`);
      processed = processed.replace(new RegExp(`(\\s|^)${cmd}\\{`, 'g'), `$1\\${cmd}{`);
    });
    
    processed = processed.replace(/([^\\])_([a-zA-Z0-9])/g, '$1_{$2}');
    processed = processed.replace(/([^\\])\\^([a-zA-Z0-9])/g, '$1^{$2}');
    
    processed = processed.replace(/d\^2y\/dx\^2/g, '\\frac{d^2y}{dx^2}');
    processed = processed.replace(/d\^2x\/dy\^2/g, '\\frac{d^2x}{dy^2}');
    processed = processed.replace(/dy\/dx/g, '\\frac{dy}{dx}');
    processed = processed.replace(/dx\/dy/g, '\\frac{dx}{dy}');
    processed = processed.replace(/d(\w+)\/d(\w+)/g, '\\frac{d$1}{d$2}');
    
    Object.entries(GREEK_LETTERS).forEach(([unicode, latex]) => {
      processed = processed.split(unicode).join(latex);
    });
    
    processed = processed.split('→').join('\\to');
    processed = processed.replace(/\\bto\\b/g, '\\to');
    processed = processed.replace(/\\\\to/g, '\\to');
    
    processed = processed.replace(/\\blim\\b/g, '\\lim');
    processed = processed.replace(/\\bliminf\\b/g, '\\liminf');
    processed = processed.replace(/\\blimsup\\b/g, '\\limsup');
    
    processed = processed.replace(/\\b(lim|frac|sqrt|int|sum|prod|sin|cos|tan|log|ln)_(\\w+)/g, '$1_{$2}');
    
    return processed;
  };
  
  const formulaDelimiters = [
    {
      regex: /\\\[(.*?)\\\]/gs,
      prefix: '\\[',
      suffix: '\\]'
    },
    {
      regex: /\$\$(.*?)\$\$/gs,
      prefix: '$$',
      suffix: '$$'
    },
    {
      regex: /\\\((.*?)\\\)/gs,
      prefix: '\\(',
      suffix: '\\)'
    },
    {
      regex: /\$(.*?)\$/g,
      prefix: '$',
      suffix: '$'
    }
  ];
  
  const allMatches = [];
  formulaDelimiters.forEach(delimiter => {
    let match;
    delimiter.regex.lastIndex = 0;
    while ((match = delimiter.regex.exec(normalized)) !== null) {
      allMatches.push({
        start: match.index,
        end: match.index + match[0].length,
        content: match[1],
        prefix: delimiter.prefix,
        suffix: delimiter.suffix,
        fullMatch: match[0]
      });
    }
  });
  
  allMatches.sort((a, b) => a.start - b.start);
  
  const validMatches = [];
  let lastEnd = 0;
  
  allMatches.forEach(match => {
    if (match.start >= lastEnd) {
      validMatches.push(match);
      lastEnd = match.end;
    }
  });
  
  const segments = [];
  let lastIndex = 0;
  
  validMatches.forEach(match => {
    if (match.start > lastIndex) {
      const preContent = normalized.slice(lastIndex, match.start);
      segments.push(preContent);
    }
    
    const processedFormula = processContentSegment(match.content);
    segments.push(match.prefix + processedFormula + match.suffix);
    
    lastIndex = match.end;
  });
  
  if (lastIndex < normalized.length) {
    const postContent = normalized.slice(lastIndex);
    segments.push(postContent);
  }
  
  normalized = segments.join('');
  normalized = normalized.normalize('NFC');
  
  return normalized;
}

export { extractFormulaFragments, extractFormulaFragmentsWithoutDollars };
