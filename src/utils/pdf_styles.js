export const PDF_STYLES = `
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

  .pdf-content h2 { font-size: 18pt; padding-bottom: 8px; text-align: left; margin-top: 35px; margin-bottom: 25px; }
  .pdf-content h3 { font-size: 16pt; text-align: left; margin-top: 30px; margin-bottom: 20px; }
  .pdf-content h4 { font-size: 14pt; margin-top: 25px; margin-bottom: 15px; }
  .pdf-content h5 { font-size: 12pt; margin-top: 20px; margin-bottom: 12px; }
  .pdf-content h6 { font-size: 11pt; margin-top: 18px; margin-bottom: 10px; }

  .pdf-content p {
    margin: 12px 0;
    text-align: justify;
    text-indent: 2em;
    line-height: 1.8;
    text-align-last: left;
  }

  .pdf-content p:first-of-type { text-indent: 0; }

  .pdf-content ul { margin: 15px 0 15px 25px; padding-left: 20px; list-style-type: disc; }
  .pdf-content ol { margin: 15px 0 15px 25px; padding-left: 20px; list-style-type: decimal; }
  .pdf-content li { margin: 8px 0; text-align: justify; line-height: 1.7; list-style-position: outside; }

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

  .pdf-content .katex-inline { vertical-align: -0.15em; font-size: 1.05em !important; margin: 0 4px; }
  .pdf-content .katex-mathml { display: none; }
  .pdf-content .katex-display > .katex { margin: 0 auto; max-width: 90%; }

  .pdf-content .katex,
  .pdf-content .katex-display,
  .pdf-content .katex-block {
    page-break-inside: avoid !important;
    break-inside: avoid !important;
  }

  .pdf-content table { border-collapse: collapse; width: 100%; margin: 15px 0; page-break-inside: avoid; }
  .pdf-content th, .pdf-content td { border: 1px solid #000000; padding: 8px 12px; text-align: left; font-size: 11pt; }
  .pdf-content th { background-color: #f0f0f0; font-weight: bold; }

  .pdf-content p + .katex-display,
  .pdf-content .katex-display + p { margin-top: 20px; }

  .page-break-before { page-break-before: always; }
  .page-break-after { page-break-after: always; }

  .pdf-content h1, .pdf-content h2, .pdf-content h3, .pdf-content h4,
  .pdf-content h5, .pdf-content h6, .pdf-content p, .pdf-content table,
  .pdf-content figure, .pdf-content blockquote, .pdf-content pre {
    page-break-inside: avoid;
  }

  .pdf-content img { max-width: 100%; height: auto; display: block; margin: 15px auto; page-break-inside: avoid; }
  .pdf-content hr { border: none; border-top: 1px solid #000000; margin: 25px 0; }

  @page { margin: 15mm 20mm 15mm 20mm; }
`;

export function buildPdfElement(contentHtml, pdfStyles = PDF_STYLES) {
  const tempElement = document.createElement('div');
  tempElement.className = 'pdf-content';

  const pdfStyle = document.createElement('style');
  pdfStyle.textContent = pdfStyles;
  tempElement.appendChild(pdfStyle);

  const contentContainer = document.createElement('div');
  tempElement.appendChild(contentContainer);
  contentContainer.innerHTML = contentHtml;

  return { wrapper: tempElement, container: contentContainer };
}
