// PDF转换配置
export const PDF_OPTIONS = {
  margin: [10, 15, 10, 15],
  filename: 'document.pdf',
  image: { type: 'jpeg', quality: 1.0 },
  html2canvas: {
    scale: 3,
    useCORS: true,
    logging: false,
    letterRendering: true,
    backgroundColor: '#ffffff',
    dpi: 300,
    scaleStep: 1
  },
  jsPDF: {
    unit: 'mm',
    format: 'a4',
    orientation: 'portrait',
    putOnlyUsedFonts: true,
    compress: true
  },
  pagebreak: {
    mode: ['avoid-all', 'css'],
    before: '.page-break-before',
    after: '.page-break-after',
    avoid: ['.katex', '.katex-display', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6']
  }
};

// 常见LaTeX命令列表
export const COMMON_LATEX_COMMANDS = [
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

// 希腊字母映射
export const GREEK_LETTERS = {
  'Δ': '\\Delta', 'δ': '\\delta', 'π': '\\pi', 'α': '\\alpha', 'β': '\\beta',
  'γ': '\\gamma', 'ε': '\\epsilon', 'ζ': '\\zeta', 'η': '\\eta', 'θ': '\\theta',
  'ι': '\\iota', 'κ': '\\kappa', 'λ': '\\lambda', 'μ': '\\mu', 'ν': '\\nu',
  'ξ': '\\xi', 'ο': '\\omicron', 'ρ': '\\rho', 'σ': '\\sigma', 'τ': '\\tau',
  'υ': '\\upsilon', 'φ': '\\phi', 'χ': '\\chi', 'ψ': '\\psi', 'ω': '\\omega'
};
