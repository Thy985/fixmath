import { Document, Packer, Paragraph, TextRun, Math, MathRun, HeadingLevel, AlignmentType } from 'docx';
import { marked } from 'marked';
import { formulaModel } from './ml/model.js';
import html2pdf from 'html2pdf.js';
import katex from 'katex';

// 只在浏览器环境中导入CSS，避免Node.js环境出错
if (typeof window !== 'undefined') {
  import('katex/dist/katex.min.css');
}

// PDF转换配置
const PDF_OPTIONS = {
  margin: [10, 15, 10, 15], // 调整页边距，上、右、下、左，更紧凑的布局
  filename: 'document.pdf',
  image: { type: 'jpeg', quality: 1.0 }, // 提高图像质量
  html2canvas: {
    scale: 3, // 提高缩放比例，获得更清晰的图像
    useCORS: true,
    logging: false,
    letterRendering: true,
    backgroundColor: '#ffffff',
    dpi: 300, // 提高DPI，获得更高质量
    scaleStep: 1
  },
  jsPDF: {
    unit: 'mm',
    format: 'a4',
    orientation: 'portrait',
    putOnlyUsedFonts: true, // 只包含使用的字体，减小文件大小
    compress: true // 启用压缩，减小文件大小
  },
  pagebreak: {
    mode: ['avoid-all', 'css'], // 更严格的分页控制
    before: '.page-break-before',
    after: '.page-break-after',
    avoid: ['.katex', '.katex-display', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6'] // 避免在关键元素处分页
  }
};

// 常见LaTeX命令列表
const COMMON_LATEX_COMMANDS = [
  'lim', 'frac', 'sqrt', 'int', 'sum', 'prod', 'liminf', 'limsup', 'max', 'min',
  'sin', 'cos', 'tan', 'cot', 'sec', 'csc', 'arcsin', 'arccos', 'arctan',
  'sinh', 'cosh', 'tanh', 'log', 'ln', 'exp', 'det', 'rank', 'ker', 'im',
  'gcd', 'lcm', 'mod', 'equiv', 'approx', 'sim', 'cong', 'perp', 'parallel',
  'leq', 'geq', 'll', 'gg', 'subset', 'supset', 'subseteq', 'supseteq',
  'in', 'notin', 'ni', 'cup', 'cap', 'setminus', 'times', 'div', 'pm', 'mp',
  'infty', 'aleph', 'nabla', 'partial', 'forall', 'exists', 'neg', 'land', 'lor',
  'implies', 'iff', 'because', 'therefore', 'dots', 'cdots', 'vdots', 'ddots',
  'alpha', 'beta', 'gamma', 'delta', 'epsilon', 'zeta', 'eta', 'theta', 'iota',
  'kappa', 'lambda', 'mu', 'nu', 'xi', 'omicron', 'pi', 'rho', 'sigma', 'tau',
  'upsilon', 'phi', 'chi', 'psi', 'omega'
];

// 辅助函数：检查字符串是否包含LaTeX命令
function containsLatexCommand(text) {
  return COMMON_LATEX_COMMANDS.some(cmd => text.includes(cmd));
}

// 辅助函数：识别文本中的公式片段（不处理$定界符）
function extractFormulaFragmentsWithoutDollars(text) {
  // 识别未被$包裹的公式，通过检测包含LaTeX命令的文本
  if (text.match(/(lim|frac|sqrt|int|sum|prod|sin|cos|tan|log|ln|exp)/i)) {
    return [
      {
        type: 'formula',
        content: text,
        displayMode: false
      }
    ];
  }
  
  // 否则返回文本片段
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
  
  // 定义所有支持的公式定界符对及其优先级
  // 优先级从高到低：块级公式优先处理，避免被行内公式匹配器误匹配
  const formulaDelimiters = [
    { 
      regex: /\\\[(.*?)\\\]/gs,  // \[...\] 块级公式
      displayMode: true,
      name: 'block_brackets'
    },
    { 
      regex: /\$\$(.*?)\$\$/gs,  // $$...$$ 块级公式
      displayMode: true,
      name: 'block_dollars'
    },
    { 
      regex: /\\\((.*?)\\\)/gs,  // \(...\) 行内公式
      displayMode: false,
      name: 'inline_parentheses'
    },
    { 
      regex: /\$(.*?)\$/g,       // $...$ 行内公式
      displayMode: false,
      name: 'inline_dollars'
    }
  ];
  
  // 找到所有公式匹配项及其位置
  const allMatches = [];
  
  formulaDelimiters.forEach(delimiter => {
    const regex = delimiter.regex;
    let match;
    regex.lastIndex = 0; // 重置正则表达式的lastIndex
    
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
  
  // 按起始位置排序所有匹配项
  allMatches.sort((a, b) => a.start - b.start);
  
  // 处理匹配项，避免重叠
  const validMatches = [];
  let lastEnd = 0;
  
  allMatches.forEach(match => {
    if (match.start >= lastEnd) {
      validMatches.push(match);
      lastEnd = match.end;
    }
  });
  
  // 根据有效匹配项构建片段
  validMatches.forEach(match => {
    // 处理公式前的文本
    if (match.start > lastIndex) {
      const textBefore = text.slice(lastIndex, match.start);
      if (textBefore.trim() !== '') {
        fragments.push(...extractFormulaFragmentsWithoutDollars(textBefore));
      }
    }
    
    // 添加公式片段
    fragments.push({
      type: 'formula',
      content: match.content,
      displayMode: match.displayMode
    });
    
    lastIndex = match.end;
  });
  
  // 处理剩余文本
  if (lastIndex < text.length) {
    const remainingText = text.slice(lastIndex);
    if (remainingText.trim() !== '') {
      fragments.push(...extractFormulaFragmentsWithoutDollars(remainingText));
    }
  }
  
  // 清理文本片段，移除多余空格
  return fragments.map(fragment => {
    if (fragment.type === 'text') {
      // 移除首尾空格，但保留中间空格
      fragment.content = fragment.content.trim();
      // 如果文本片段为空，不添加到结果中
      if (fragment.content === '') {
        return null;
      }
    }
    return fragment;
  }).filter(Boolean);
}

// 辅助函数：处理Markdown内联内容（strong, em, text等）
function processInlineContent(tokens, normalize = true) {
  let text = '';
  
  // 遍历内联令牌，构建完整文本
  tokens.forEach(token => {
    if (token.type === 'text') {
      text += token.text;
    } else if (token.type === 'strong' || token.type === 'em') {
      // 对于加粗和斜体，先递归处理其内容，然后添加到文本中
      text += processInlineContent(token.tokens, normalize).text;
    } else if (token.type === 'escape') {
      // 转义字符，直接添加到文本中
      text += token.text;
    } else if (token.type === 'html') {
      // HTML标签，直接添加到文本中
      text += token.text;
    } else if (token.type === 'link') {
      // 链接，添加链接文本
      text += processInlineContent(token.tokens, normalize).text;
    } else if (token.type === 'image') {
      // 图片，添加图片alt文本
      text += token.alt || '';
    } else if (token.type === 'br') {
      // 换行，添加空格
      text += ' ';
    }
  });
  
  // 处理文本内容，提取公式片段
  const formulaFragments = extractFormulaFragments(normalize ? normalizeLatex(text) : text);
  
  return { text, formulaFragments };
}

// 解析Markdown，提取文本和公式
async function parseMarkdown(content) {
  const elements = [];
  
  // 初始化机器学习模型
  await formulaModel.init();
  
  // 预处理内容，检测空行
  const lines = content.split('\n');
  let currentLine = '';
  
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    
    if (line.trim() === '' && currentLine.trim() === '') {
      // 空行
      elements.push({
        type: 'empty_line'
      });
    } else if (line.trim() === '') {
      // 行尾空行，不单独处理
      currentLine += ' ';
    } else {
      currentLine += line + '\n';
    }
  }
  
  // 使用marked解析Markdown
  const tokens = marked.lexer(content);
  
  // 辅助函数：处理列表（有序或无序）
  const processList = (listToken) => {
    // 遍历列表项
    listToken.items.forEach(item => {
      // 处理列表项中的文本内容
      const { formulaFragments } = processInlineContent(item.tokens);
      
      // 添加列表项到元素数组
      elements.push({
        type: 'list_item',
        content: formulaFragments
      });
      
      // 处理嵌套列表
      if (item.tokens) {
        item.tokens.forEach(token => {
          if (token.type === 'list') {
            processList(token);
          }
        });
      }
    });
  };
  
  for (const token of tokens) {
    if (token.type === 'heading') {
      // 处理标题中的公式和格式
      const { formulaFragments } = processInlineContent(token.tokens);
      elements.push({
        type: 'heading',
        level: token.depth,
        content: formulaFragments
      });
    } else if (token.type === 'paragraph') {
      // 处理段落中的公式和格式
      const { formulaFragments } = processInlineContent(token.tokens);
      elements.push({
        type: 'paragraph',
        content: formulaFragments
      });
    } else if (token.type === 'code') {
      // 代码块保持原样，不处理公式
      elements.push({
        type: 'code',
        content: token.text,
        language: token.lang
      });
    } else if (token.type === 'list') {
      // 处理列表（有序或无序）
      processList(token);
    } else if (token.type === 'list_item') {
      // 处理单独的列表项
      const { formulaFragments } = processInlineContent(token.tokens);
      elements.push({
        type: 'list_item',
        content: formulaFragments
      });
    } else if (token.type === 'hr') {
      elements.push({
        type: 'hr'
      });
    } else if (token.type === 'space') {
      // 处理空行，添加空行元素
      elements.push({
        type: 'empty_line'
      });
    } else if (token.type === 'text') {
      // 处理纯文本，识别并提取未包裹在$中的公式
      const { formulaFragments } = processInlineContent([token]);
      
      // 创建包含文本和公式的段落
      elements.push({
        type: 'paragraph',
        content: formulaFragments
      });
    } else {
      // 处理其他令牌类型，如blockquote、table等
      // 对于未知令牌类型，尝试将其作为文本处理
      if (token.tokens) {
        const { formulaFragments } = processInlineContent(token.tokens);
        elements.push({
          type: 'paragraph',
          content: formulaFragments
        });
      }
    }
  }
  
  return elements;
}

// 解析纯LaTeX内容
async function parseLatex(content) {
  // 让LaTeX输入支持Markdown功能：直接调用parseMarkdown函数处理
  // 这样LaTeX输入也能处理标题、列表等Markdown格式
  return await parseMarkdown(content);
}

// 将解析后的元素转换为docx.js的文档结构
function buildDocxStructure(elements) {
  const docxElements = [];
  
  // 辅助函数：处理内容片段，生成docx.js元素
  const processContentFragments = (fragments) => {
    const contentElements = [];
    
    fragments.forEach(fragment => {
      if (fragment.type === 'text') {
        // 纯文本：直接交给Word，设置普通样式
        const textContent = fragment.content || '';
        contentElements.push(new TextRun({ text: textContent }));
      } else if (fragment.type === 'formula') {
        // 数学公式：使用docx.js的Math和MathRun组件创建公式
        // 生成符合Office MathML标准的XML结构，确保Word和WPS都能正确识别
        const formulaContent = fragment.content || '';
        
        // 确保公式内容是标准的LaTeX格式，没有多余的空格或格式问题
        const cleanFormula = formulaContent.trim();
        
        try {
          // 使用MathRun和Math组件创建数学公式
          // 确保生成的Office MathML结构完整，包含所有必要的元数据
          const mathRun = new MathRun(cleanFormula);
          contentElements.push(new Math({ 
            children: [mathRun],
            // 添加额外的属性，确保WPS能正确识别
            attributes: {
              xmlns: "http://schemas.openxmlformats.org/officeDocument/2006/math"
            }
          }));
        } catch (e) {
          console.error('创建Math对象失败:', cleanFormula, e);
          // 出错时添加为普通文本，保留公式格式
          const delimiter = fragment.displayMode ? '$$' : '$';
          contentElements.push(new TextRun({ text: `${delimiter}${cleanFormula}${delimiter}` }));
        }
      }
    });
    
    return contentElements;
  };
  
  elements.forEach(element => {
    try {
      if (element.type === 'heading') {
        const headingContent = [];
        
        // 处理标题中的内容片段（文本和公式）
        if (Array.isArray(element.content)) {
          headingContent.push(...processContentFragments(element.content));
        } else if (element.text) {
          // 兼容旧格式
          headingContent.push(new TextRun({ text: element.text }));
        }
        
        docxElements.push(
          new Paragraph({
            children: headingContent,
            heading: element.level === 1 ? HeadingLevel.HEADING_1 :
                    element.level === 2 ? HeadingLevel.HEADING_2 :
                    element.level === 3 ? HeadingLevel.HEADING_3 :
                    HeadingLevel.HEADING_4,
            alignment: AlignmentType.LEFT
          })
        );
      } else if (element.type === 'paragraph') {
        const paragraphContent = [];
        
        // 确保element.content是数组且不为空
        if (Array.isArray(element.content) && element.content.length > 0) {
          paragraphContent.push(...processContentFragments(element.content));
        }
        
        // 添加空数组检查
        if (paragraphContent.length > 0) {
          docxElements.push(
            new Paragraph({
              children: paragraphContent,
              alignment: AlignmentType.LEFT
            })
          );
        }
      } else if (element.type === 'formula') {
        // 数学公式：使用docx.js的Math和MathRun组件创建公式
        // 生成符合Office MathML标准的XML结构，确保Word和WPS都能正确识别
        const formulaContent = element.content || '';
        
        // 确保公式内容是标准的LaTeX格式，没有多余的空格或格式问题
        const cleanFormula = formulaContent.trim();
        
        try {
          // 使用MathRun和Math组件创建数学公式
          // 确保生成的Office MathML结构完整，包含所有必要的元数据
          const mathRun = new MathRun(cleanFormula);
          docxElements.push(
            new Paragraph({
              children: [new Math({ 
                children: [mathRun],
                // 添加额外的属性，确保WPS能正确识别
                attributes: {
                  xmlns: "http://schemas.openxmlformats.org/officeDocument/2006/math"
                }
              })],
              alignment: AlignmentType.CENTER
            })
          );
        } catch (e) {
          console.error('创建formula段落失败:', cleanFormula, e);
          // 出错时添加为普通文本，保留公式格式
          const delimiter = element.displayMode ? '$$' : '$';
          docxElements.push(
            new Paragraph({
              children: [new TextRun({ text: `${delimiter}${cleanFormula}${delimiter}` })],
              alignment: AlignmentType.CENTER
            })
          );
        }
      } else if (element.type === 'code') {
        docxElements.push(
          new Paragraph({
            children: [new TextRun({ text: element.content })],
            alignment: AlignmentType.LEFT,
            style: 'Code'
          })
        );
      } else if (element.type === 'list_item') {
        const listItemContent = [];
        
        // 处理列表项中的内容片段（文本和公式）
        if (Array.isArray(element.content)) {
          listItemContent.push(...processContentFragments(element.content));
        } else if (element.text) {
          // 兼容旧格式
          listItemContent.push(new TextRun({ text: element.text }));
        } else if (element.content) {
          // 兼容旧格式（字符串内容）
          listItemContent.push(new TextRun({ text: element.content }));
        }
        
        docxElements.push(
          new Paragraph({
            children: listItemContent,
            bullet: { level: 0 },
            alignment: AlignmentType.LEFT
          })
        );
      } else if (element.type === 'hr') {
        // 添加分隔线
        docxElements.push(new Paragraph({}));
        docxElements.push(new Paragraph({}));
      } else if (element.type === 'empty_line') {
        // 添加空行
        docxElements.push(new Paragraph({}));
      }
    } catch (error) {
      console.error('创建docx元素失败:', error, '元素类型:', element.type, '元素内容:', element);
    }
  });
  
  return docxElements;
}

// 导出processMarkdownWithFormulas函数，统一处理Markdown中的公式
export function processMarkdownWithFormulas(content) {
  // 先处理所有公式，将其替换为占位符，避免marked.parse()破坏公式结构
  let tempContent = content;
  const formulaMap = new Map();
  let formulaIndex = 0;
  
  // 使用HTML注释作为占位符，确保Markdown解析器不会修改它们
  // 1. 提取所有块级公式 $$...$$ 和 \[...\]
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
  
  // 2. 提取所有行内公式 $...$ 和 \(...\)
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
  
  // 3. 将处理后的内容转换为HTML
  let html = marked.parse(tempContent);
  
  // 4. 将HTML实体转换回原始字符
  html = html.replace(/&#39;/g, "'");
  html = html.replace(/&quot;/g, '"');
  html = html.replace(/&lt;/g, '<');
  html = html.replace(/&gt;/g, '>');
  html = html.replace(/&amp;/g, '&');
  
  // 5. 将占位符替换为渲染后的公式
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
      // 渲染失败时，使用原始公式文本
      const delimiter = formulaInfo.displayMode ? '$$' : '$';
      html = html.replace(new RegExp(placeholder.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'g'), `${delimiter}${formulaInfo.formula}${delimiter}`);
    }
  });
  
  return html;
}

// 导出normalizeLatex函数
export function normalizeLatex(content) {
  // 确保content是字符串
  let normalized = String(content);
  
  // 辅助函数：处理单个内容片段
  const processContentSegment = (text) => {
    let processed = text;
    
    // 为常见命令添加缺失的反斜杠，但避免重复添加
    COMMON_LATEX_COMMANDS.forEach(cmd => {
      // 只在命令前没有反斜杠时添加
      // 将 ' cmd ' 替换为 ' \cmd '
      processed = processed.replace(new RegExp(`(\\s|^)${cmd}(\\s|$)`, 'g'), `$1\\${cmd}$2`);
      // 将 'cmd{' 替换为 '\cmd{' 
      processed = processed.replace(new RegExp(`(\\s|^)${cmd}\\{`, 'g'), `$1\\${cmd}{`);
    });
    
    // 处理上下标（_和^），只处理简单情况，避免破坏复杂表达式
    // 只匹配单个字符的上下标，或者带括号的上下标
    processed = processed.replace(/([^\\])_([a-zA-Z0-9])/g, '$1_{$2}');
    processed = processed.replace(/([^\\])\\^([a-zA-Z0-9])/g, '$1^{$2}');
    
    // 处理dydx形式的导数，包括二阶导数
    processed = processed.replace(/d\^2y\/dx\^2/g, '\\frac{d^2y}{dx^2}');
    processed = processed.replace(/d\^2x\/dy\^2/g, '\\frac{d^2x}{dy^2}');
    processed = processed.replace(/dy\/dx/g, '\\frac{dy}{dx}');
    processed = processed.replace(/dx\/dy/g, '\\frac{dx}{dy}');
    processed = processed.replace(/d(\w+)\/d(\w+)/g, '\\frac{d$1}{d$2}');
    
    // 替换希腊字母为LaTeX格式
    const GREEK_LETTERS = {
      'Δ': '\\Delta', 'δ': '\\delta', 'π': '\\pi', 'α': '\\alpha', 'β': '\\beta',
      'γ': '\\gamma', 'ε': '\\epsilon', 'ζ': '\\zeta', 'η': '\\eta', 'θ': '\\theta',
      'ι': '\\iota', 'κ': '\\kappa', 'λ': '\\lambda', 'μ': '\\mu', 'ν': '\\nu',
      'ξ': '\\xi', 'ο': '\\omicron', 'ρ': '\\rho', 'σ': '\\sigma', 'τ': '\\tau',
      'υ': '\\upsilon', 'φ': '\\phi', 'χ': '\\chi', 'ψ': '\\psi', 'ω': '\\omega'
    };
    Object.entries(GREEK_LETTERS).forEach(([unicode, latex]) => {
      processed = processed.split(unicode).join(latex);
    });
    
    // 替换箭头符号为LaTeX格式
    processed = processed.split('→').join('\\to');
    // 处理 'to' 关键字，转换为箭头符号
    processed = processed.replace(/\\bto\\b/g, '\\to');
    // 确保\to命令能被正确处理，不被错误转义
    processed = processed.replace(/\\\\to/g, '\\to');
    
    // 特殊处理极限符号，确保lim命令能被正确识别
    // 将 'lim' 替换为 '\\lim'，确保前后有空格或边界
    processed = processed.replace(/\\blim\\b/g, '\\lim');
    processed = processed.replace(/\\bliminf\\b/g, '\\liminf');
    processed = processed.replace(/\\blimsup\\b/g, '\\limsup');
    
    // 处理带下划线的命令，如 lim_h
    processed = processed.replace(/\\b(lim|frac|sqrt|int|sum|prod|sin|cos|tan|log|ln)_(\\w+)/g, '$1_{$2}');
    
    return processed;
  };
  
  // 定义所有支持的公式定界符及其处理函数
  const formulaDelimiters = [
    {
      regex: /\\\[(.*?)\\\]/gs,  // \[...\] 块级公式
      prefix: '\\[',
      suffix: '\\]'
    },
    {
      regex: /\$\$(.*?)\$\$/gs,  // $$...$$ 块级公式
      prefix: '$$',
      suffix: '$$'
    },
    {
      regex: /\\\((.*?)\\\)/gs,  // \(...\) 行内公式
      prefix: '\\(',
      suffix: '\\)'
    },
    {
      regex: /\$(.*?)\$/g,       // $...$ 行内公式
      prefix: '$',
      suffix: '$'
    }
  ];
  
  // 收集所有匹配项
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
  
  // 按起始位置排序
  allMatches.sort((a, b) => a.start - b.start);
  
  // 处理匹配项，避免重叠
  const validMatches = [];
  let lastEnd = 0;
  
  allMatches.forEach(match => {
    if (match.start >= lastEnd) {
      validMatches.push(match);
      lastEnd = match.end;
    }
  });
  
  // 构建处理后的内容
  const segments = [];
  let lastIndex = 0;
  
  validMatches.forEach(match => {
    // 保持公式之前的内容不变
    if (match.start > lastIndex) {
      const preContent = normalized.slice(lastIndex, match.start);
      segments.push(preContent);
    }
    
    // 处理公式内容
    const processedFormula = processContentSegment(match.content);
    segments.push(match.prefix + processedFormula + match.suffix);
    
    lastIndex = match.end;
  });
  
  // 保持最后一个公式之后的内容不变
  if (lastIndex < normalized.length) {
    const postContent = normalized.slice(lastIndex);
    segments.push(postContent);
  }
  
  normalized = segments.join('');
  
  // 确保所有字符都正确处理，避免乱码
  normalized = normalized.normalize('NFC');
  
  return normalized;
}

// 导出转换为PDF的函数
export async function convertToPdf(content, inputType) {
  try {
    // 检查输入内容是否为空
    if (!content || content.trim() === '') {
      throw new Error('输入内容不能为空');
    }
    
    console.log('开始转换为PDF，输入类型:', inputType);
    
    // 规范化内容
    const normalizedContent = normalizeLatex(content);
    
    // 创建临时HTML元素，用于渲染内容
    const tempElement = document.createElement('div');
    tempElement.className = 'pdf-content';
    
    // 添加专门的PDF样式
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
      
      /* KaTeX公式样式优化 */
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
      
      /* 行内公式和文本对齐 */
      .pdf-content .katex-inline {
        vertical-align: -0.15em;
        font-size: 1.05em !important;
        margin: 0 4px;
      }
      
      /* 确保公式渲染清晰 */
      .pdf-content .katex-mathml {
        display: none;
      }
      
      .pdf-content .katex-display > .katex {
        margin: 0 auto;
        max-width: 90%;
      }
      
      /* 避免在公式中间分页 */
      .pdf-content .katex,
      .pdf-content .katex-display,
      .pdf-content .katex-block {
        page-break-inside: avoid !important;
        break-inside: avoid !important;
      }
      
      /* 表格样式优化 */
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
      
      /* 确保段落和公式之间有适当的间距 */
      .pdf-content p + .katex-display,
      .pdf-content .katex-display + p {
        margin-top: 20px;
      }
      
      /* 页面断裂控制 */
      .page-break-before {
        page-break-before: always;
      }
      
      .page-break-after {
        page-break-after: always;
      }
      
      /* 禁止在特定元素内部分页 */
      .pdf-content h1, .pdf-content h2, .pdf-content h3, .pdf-content h4,
      .pdf-content h5, .pdf-content h6, .pdf-content p, .pdf-content table,
      .pdf-content figure, .pdf-content blockquote, .pdf-content pre {
        page-break-inside: avoid;
      }
      
      /* 图片样式 */
      .pdf-content img {
        max-width: 100%;
        height: auto;
        display: block;
        margin: 15px auto;
        page-break-inside: avoid;
      }
      
      /* 水平线样式 */
      .pdf-content hr {
        border: none;
        border-top: 1px solid #000000;
        margin: 25px 0;
      }
      
      /* 确保页面顶部和底部有足够间距 */
      @page {
        margin: 15mm 20mm 15mm 20mm;
      }
    `;
    tempElement.appendChild(pdfStyle);
    
    // 创建内容容器
    const contentContainer = document.createElement('div');
    tempElement.appendChild(contentContainer);
    
    if (inputType === 'markdown') {
      // 使用统一的processMarkdownWithFormulas函数处理Markdown内容
      const html = processMarkdownWithFormulas(normalizedContent);
      contentContainer.innerHTML = html;
    } else {
      // 对于LaTeX输入类型，直接渲染
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
    
    // 添加到文档中，以便html2pdf能正确获取样式
    document.body.appendChild(tempElement);
    
    // 转换为PDF
    console.log('开始生成PDF...');
    const pdfBlob = await html2pdf().set(PDF_OPTIONS).from(tempElement).output('blob');
    
    // 从文档中移除临时元素
    document.body.removeChild(tempElement);
    
    console.log('PDF生成完成，大小:', pdfBlob.size, '字节');
    
    return pdfBlob;
  } catch (error) {
    console.error('PDF转换错误:', error);
    
    // 提供更详细的错误信息
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
    // 检查输入内容是否为空
    if (!content || content.trim() === '') {
      throw new Error('输入内容不能为空');
    }
    
    console.log('开始转换，输入类型:', inputType);
    
    // 解析输入内容
    const elements = inputType === 'markdown' 
      ? await parseMarkdown(content) 
      : await parseLatex(content);
    
    console.log('解析完成，生成', elements.length, '个元素');
    
    // 构建docx文档结构
    const docxElements = buildDocxStructure(elements);
    
    console.log('docx结构构建完成，生成', docxElements.length, '个docx元素');
    
    // 创建文档
    const doc = new Document({
      sections: [
        {
          properties: {},
          children: docxElements,
        },
      ],
    });
    
    // 生成文档并转换为Blob
    console.log('开始生成文档...');
    
    let blob;
    if (typeof window !== 'undefined') {
      // 浏览器环境：使用toBlob方法
      blob = await Packer.toBlob(doc);
    } else {
      // Node.js环境：使用toBuffer方法
      const buffer = await Packer.toBuffer(doc);
      blob = new Blob([buffer], { type: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document' });
    }
    
    console.log('文档生成完成，大小:', blob.size, '字节');
    
    return blob;
  } catch (error) {
    console.error('转换错误:', error);
    
    // 提供更详细的错误信息
    let errorMessage = '文档转换失败';
    
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