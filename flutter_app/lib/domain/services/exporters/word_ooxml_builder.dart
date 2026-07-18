/// Word (.docx) 文档的 OOXML 字符串拼装器。
///
/// 把 Markdown 解析后的 DocumentElement 树转换为符合 ECMA-376 规范的
/// WordprocessingML XML 字符串。所有静态模板（styles/settings/numbering
/// 等）从 [WordOoxmlTemplates] 读取，动态字符串（document body、image
/// rels、heading/paragraph/list/code/blockquote/table/mermaid 各元素）
/// 在本类中构造。
///
/// public API：仅 [WordOoxmlBuilder.buildDocumentXml] 和
/// [WordOoxmlBuilder.buildImageRelsXml] 两个静态方法（被 [WordExporter] 调用）。
/// 其余均为 internal helpers（不导出）。
library;

import 'dart:typed_data';

import '../../../core/parser/markdown_parser.dart';
import '../../../data/models/document.dart';
import '../word_ooxml_templates.dart';

/// 公式图片注册表 entry：关联 ID + 实际尺寸（EMU）。
/// EMU = English Metric Units，1 inch = 914400 EMU，1 pixel ≈ 9525 EMU (96dpi)
class FormulaImageInfo {
  final String relId;
  final int widthEmu;
  final int heightEmu;

  const FormulaImageInfo({
    required this.relId,
    required this.widthEmu,
    required this.heightEmu,
  });
}

/// Mermaid 图片注册表 entry：关联 ID + SVG 数据。
class MermaidImageInfo {
  final String relId;
  final String? svg;

  const MermaidImageInfo({
    required this.relId,
    required this.svg,
  });
}

class WordOoxmlBuilder {
  WordOoxmlBuilder._();

  /// 构造 document.xml 全文。
  static String buildDocumentXml(
    List<DocumentElement> elements,
    String? title,
    Map<String, FormulaImageInfo?> formulaRels,
    Map<String, MermaidImageInfo> mermaidRels,
  ) {
    final buffer = StringBuffer();

    final docTitle = title ?? 'FormulaFix 文档';
    buffer.write(_heading(0, docTitle));

    for (final element in elements) {
      buffer.write(_elementToXml(
        element,
        formulaRels: formulaRels,
        mermaidRels: mermaidRels,
      ));
      buffer.write('\n');
    }

    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
  xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
  xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing"
  xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
  xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">
  <w:body>$buffer</w:body>
</w:document>''';
  }

  /// 构造 document.xml.rels 全文（静态 Relationship + 动态图片 Relationship）。
  static String buildImageRelsXml(
    Map<String, FormulaImageInfo?> formulaRels,
    Map<String, MermaidImageInfo> mermaidRels,
  ) {
    final buf = StringBuffer();
    for (final entry in formulaRels.entries) {
      final info = entry.value;
      if (info == null) continue; // 渲染失败的公式没有 PNG，跳过
      final i = info.relId.replaceFirst('rIdImage', '');
      buf.write(
        '<Relationship Id="${info.relId}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/formula_$i.png"/>',
      );
    }
    for (final entry in mermaidRels.entries) {
      final info = entry.value;
      if (info.svg != null) {
        final i = info.relId.replaceFirst('rIdMermaid', '');
        buf.write(
          '<Relationship Id="${info.relId}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/mermaid_$i.svg"/>',
        );
      }
    }
    // 用 WordOoxmlTemplates 提供的前缀包裹，里面已经包含 styles/settings/numbering
    // 的 Relationship（rIdStyles / rIdSettings / rIdNumbering），
    // 后面追加图片 Relationship（rIdImageN / rIdMermaidN），命名空间不冲突。
    return '''${WordOoxmlTemplates.documentRelsHeader}
$buf${WordOoxmlTemplates.documentRelsFooter}''';
  }

  // --- element → XML 派发 ---

  static String _elementToXml(
    DocumentElement element, {
    required Map<String, FormulaImageInfo?> formulaRels,
    required Map<String, MermaidImageInfo> mermaidRels,
  }) {
    if (element is HeadingElement) {
      return _heading(element.level, element.text);
    } else if (element is ParagraphElement) {
      return _paragraph(element.children, formulaRels: formulaRels);
    } else if (element is ListElement) {
      return _list(
        element.children,
        element.indent,
        element.ordered,
        formulaRels: formulaRels,
      );
    } else if (element is CodeElement) {
      return _code(element.code, element.language);
    } else if (element is BlockquoteElement) {
      return _blockquote(element.text);
    } else if (element is MermaidElement) {
      return _mermaidSvg(element.code, mermaidRels: mermaidRels);
    } else if (element is TableElement) {
      return _table(element.headers, element.rows, formulaRels: formulaRels);
    } else if (element is TaskListItemElement) {
      return _taskListItem(
        element.children,
        element.checked,
        element.indent,
        formulaRels: formulaRels,
      );
    } else if (element is HorizontalRuleElement) {
      return _horizontalRule();
    } else if (element is EmptyLineElement) {
      return '<w:p/>';
    }
    return '';
  }

  // --- 标题 / 段落 / 列表 ---

  static String _heading(int level, String text) {
    final escaped = _esc(text);
    // level 0 是文档标题（Title 样式），1..6 是 Heading1..Heading6
    // 样式表里的 size/bold 等由 pStyle 决定，run 上不再重复 <w:sz>，避免与样式冲突
    if (level == 0) {
      return '''<w:p><w:pPr><w:pStyle w:val="Title"/></w:pPr><w:r><w:t xml:space="preserve">$escaped</w:t></w:r></w:p>''';
    }
    final styleId = 'Heading$level';
    return '''<w:p><w:pPr><w:pStyle w:val="$styleId"/></w:pPr><w:r><w:t xml:space="preserve">$escaped</w:t></w:r></w:p>''';
  }

  static String _paragraph(
    List<InlineElement> children, {
    required Map<String, FormulaImageInfo?> formulaRels,
  }) {
    final runs = _renderInlineRuns(children, formulaRels);
    return '<w:p>$runs</w:p>';
  }

  static String _list(
    List<InlineElement> children,
    int indent,
    bool ordered, {
    required Map<String, FormulaImageInfo?> formulaRels,
  }) {
    // 真正使用 numbering.xml 里定义的 numId。
    // ordered → numId 1 (decimal "1.")；unordered → numId 2 (bullet "•")。
    // ilvl 0 对应 abstractNum 的第一层，Word 会根据 numFmt 自动渲染前缀，
    // 因此不再手动写 "${indent + 1}. " 文本前缀。
    final numId = ordered
        ? WordOoxmlTemplates.numIdOrdered
        : WordOoxmlTemplates.numIdBullet;
    final leftIndent = 360 + (indent * 360);
    final runs = _renderInlineRuns(children, formulaRels);
    return '''<w:p><w:pPr><w:pStyle w:val="ListParagraph"/><w:numPr><w:ilvl w:val="$indent"/><w:numId w:val="$numId"/></w:numPr><w:ind w:left="$leftIndent" w:hanging="360"/></w:pPr>$runs</w:p>''';
  }

  // --- 代码 / 引用 ---

  static String _code(String code, String? language) {
    // CodeBlock 样式已经包含 shd 灰底、Courier New 字体和左缩进，
    // 这里只在 run 上保留 <w:rPr> 上的语言徽章（如有），避免重复样式覆盖。
    final langTag = (language != null && language.isNotEmpty)
        ? '''<w:r><w:rPr><w:b/><w:color w:val="FFFFFF"/><w:sz w:val="18"/><w:highlight w:val="blue"/></w:rPr><w:t xml:space="preserve"> $language </w:t></w:r><w:r><w:br/></w:r>'''
        : '';
    return '''<w:p><w:pPr><w:pStyle w:val="CodeBlock"/></w:pPr>$langTag<w:r><w:t xml:space="preserve">${_esc(code)}</w:t></w:r></w:p>''';
  }

  static String _blockquote(String text) {
    // Blockquote 样式已经包含左边框、灰底、左缩进和斜体灰色字，
    // 这里 run 上不再重复 shd/bdr/i 样式，避免冲突并保证样式可被用户统一修改。
    return '''<w:p><w:pPr><w:pStyle w:val="Blockquote"/></w:pPr><w:r><w:t xml:space="preserve">${_esc(text)}</w:t></w:r></w:p>''';
  }

  // --- 公式图片 / 回退 ---

  static String _formulaImage(String relId, int widthEmu, int heightEmu) {
    // 限制最大尺寸，防止 Word 显示异常
    const maxDim = 2600000; // ~27cm
    const defaultWidth = 1200000;
    const defaultHeight = 360000;

    int w = widthEmu > 0 ? widthEmu : defaultWidth;
    int h = heightEmu > 0 ? heightEmu : defaultHeight;

    // 等比缩放：如果宽度超过限制，按比例缩小高度
    if (w > maxDim) {
      final scale = maxDim / w;
      w = maxDim;
      h = (h * scale).round();
    }
    // 高度也有限制（不超过最大尺寸的 50%，避免超高公式撑满页面）
    if (h > maxDim ~/ 2) {
      h = maxDim ~/ 2;
    }

    return '''<w:r><w:rPr><w:noProof/></w:rPr><w:drawing><wp:inline distT="0" distB="0" distL="0" distR="0"><wp:extent cx="$w" cy="$h"/><wp:docPr id="${relId.hashCode & 0x7FFFFFFF}" name="Formula"/><wp:cNvGraphicFramePr/><a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture"><pic:pic><pic:nvPicPr><pic:cNvPr id="0" name="formula"/><pic:cNvPicPr/></pic:nvPicPr><pic:blipFill><a:blip r:embed="$relId"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill><pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="$w" cy="$h"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr></pic:pic></a:graphicData></a:graphic></wp:inline></w:drawing></w:r>''';
  }

  static String _formulaFallback(String latex) {
    return '''<w:r><w:rPr><w:i/><w:rFonts w:ascii="Cambria Math" w:hAnsi="Cambria Math"/><w:sz w:val="24"/></w:rPr><w:t xml:space="preserve">${_esc(latex)}</w:t></w:r>''';
  }

  // --- Mermaid SVG 嵌入 ---

  /// 解析 SVG viewBox 属性，返回 (width, height) 比例。
  /// 解析失败时返回 null。
  static ({double width, double height})? parseSvgViewBox(String svg) {
    try {
      final match = RegExp(r'''viewBox\s*=\s*["']([^"']+)["']''').firstMatch(svg);
      if (match == null) return null;
      final parts = match.group(1)!.split(RegExp(r'[\s,]+'));
      if (parts.length < 4) return null;
      final w = double.tryParse(parts[2]);
      final h = double.tryParse(parts[3]);
      if (w == null || h == null || w <= 0 || h <= 0) return null;
      return (width: w, height: h);
    } catch (_) {
      return null;
    }
  }

  /// 解析 SVG width/height 属性，返回 (width, height) 像素值。
  /// 返回 null 如果解析失败。
  static ({double width, double height})? parseSvgDimensions(String svg) {
    try {
      double? w, h;
      // 匹配 width="100" 或 width="100px"
      final widthMatch = RegExp(r'''width\s*=\s*["'](\d+(?:\.\d+)?)[^"']*["']''').firstMatch(svg);
      if (widthMatch != null) {
        w = double.tryParse(widthMatch.group(1)!);
      }
      final heightMatch = RegExp(r'''height\s*=\s*["'](\d+(?:\.\d+)?)[^"']*["']''').firstMatch(svg);
      if (heightMatch != null) {
        h = double.tryParse(heightMatch.group(1)!);
      }
      if (w != null && h != null && w > 0 && h > 0) {
        return (width: w, height: h);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// 根据 SVG viewBox 比例计算 Word 绘图尺寸（EMU 单位）。
  /// 优先级：viewBox > width/height 属性 > 默认比例
  /// 限制最大宽度为 6 英寸（5486400 EMU），高度按比例计算。
  static (int cx, int cy) calcMermaidEmu(String svg) {
    const maxWidthEmu = 5486400; // 6 inches in EMU
    const minHeightEmu = 100000; // 最小高度 1cm
    const defaultRatio = 2.0; // 默认 6x3 inches

    // 优先使用 viewBox
    var dims = parseSvgViewBox(svg);
    // fallback 到 width/height 属性
    dims ??= parseSvgDimensions(svg);

    if (dims == null) {
      return (maxWidthEmu, (maxWidthEmu / defaultRatio).round());
    }

    final ratio = dims.width / dims.height;
    final widthEmu = maxWidthEmu;
    final heightEmu = (widthEmu / ratio).round().clamp(minHeightEmu, maxWidthEmu);
    return (widthEmu, heightEmu);
  }

  static String _mermaidSvg(String code, {required Map<String, MermaidImageInfo> mermaidRels}) {
    final info = mermaidRels[code];
    if (info != null && info.svg != null && info.svg!.isNotEmpty) {
      final (cx, cy) = calcMermaidEmu(info.svg!);
      return '''<w:p><w:pPr><w:shd w:fill="F0F0F0" w:val="clear"/><w:bdr><w:top w:val="single" w:sz="4" w:space="4" w:color="CCCCCC"/><w:bottom w:val="single" w:sz="4" w:space="4" w:color="CCCCCC"/></w:bdr></w:pPr><w:r><w:rPr><w:noProof/></w:rPr><w:drawing><wp:inline distT="0" distB="0" distL="0" distR="0" xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing"><wp:extent cx="$cx" cy="$cy"/><wp:docPr id="1" name="Mermaid Diagram"/><a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture"><pic:pic xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture"><pic:nvPicPr><pic:cNvPr id="0" name="mermaid"/><pic:cNvPicPr/></pic:nvPicPr><pic:blipFill><a:blip r:embed="${info.relId}"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill><pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="$cx" cy="$cy"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr></pic:pic></a:graphicData></a:graphic></a:graphic></wp:inline></w:drawing></w:r><w:r><w:rPr><w:sz w:val="16"/></w:rPr><w:t xml:space="preserve"> (Mermaid 图表)</w:t></w:r></w:p>''';
    }
    // 渲染失败，显示代码作为回退
    return '''<w:p><w:pPr><w:shd w:fill="F0F0F0" w:val="clear"/><w:bdr><w:top w:val="single" w:sz="4" w:space="4" w:color="CCCCCC"/><w:bottom w:val="single" w:sz="4" w:space="4" w:color="CCCCCC"/></w:bdr></w:pPr><w:r><w:rPr><w:b/><w:sz w:val="20"/></w:rPr><w:t xml:space="preserve">[Mermaid 图表 - 代码]</w:t></w:r><w:r><w:br/></w:r><w:r><w:rPr><w:rFonts w:ascii="Courier New" w:hAnsi="Courier New"/><w:sz w:val="18"/><w:color w:val="888888"/></w:rPr><w:t xml:space="preserve">${_esc(code)}</w:t></w:r></w:p>''';
  }

  // --- 表格 ---

  static String _table(
    List<String> headers,
    List<List<String>> rows, {
    required Map<String, FormulaImageInfo?> formulaRels,
  }) {
    if (headers.isEmpty) return '<w:p/>';

    // 渲染表头单元格（支持行内格式）
    final headerCells = headers.map((h) {
      final inlines = MarkdownParser.parseInline(h);
      return '''<w:tc><w:tcPr><w:tcBorders><w:top w:val="single" w:sz="4" w:color="999999"/><w:left w:val="single" w:sz="4" w:color="999999"/><w:bottom w:val="single" w:sz="4" w:color="999999"/><w:right w:val="single" w:sz="4" w:color="999999"/></w:tcBorders><w:shd w:val="clear" w:fill="DDDDDD"/></w:tcPr>${_renderInlineCell(inlines, formulaRels, bold: true)}</w:tc>''';
    }).join('');

    // 渲染数据行单元格（支持行内格式：公式、粗体、代码）
    final dataRows = rows.map((row) {
      final cells = row.map((cell) {
        final inlines = MarkdownParser.parseInline(cell);
        return '''<w:tc><w:tcPr><w:tcBorders><w:top w:val="single" w:sz="4" w:color="CCCCCC"/><w:left w:val="single" w:sz="4" w:color="CCCCCC"/><w:bottom w:val="single" w:sz="4" w:color="CCCCCC"/><w:right w:val="single" w:sz="4" w:color="CCCCCC"/></w:tcBorders></w:tcPr>${_renderInlineCell(inlines, formulaRels)}</w:tc>''';
      }).join('');
      return '<w:tr>$cells</w:tr>';
    }).join('');

    return '''<w:tbl><w:tblPr><w:tblStyle w:val="TableGrid"/><w:tblW w:w="0" w:type="auto"/></w:tblPr><w:tr>$headerCells</w:tr>$dataRows</w:tbl>''';
  }

  /// 渲染表格单元格内容（支持 TextElement, FormulaElement, BoldElement, CodeElement）
  static String _renderInlineCell(
    List<InlineElement> inlines,
    Map<String, FormulaImageInfo?> formulaRels, {
    bool bold = false,
  }) {
    final runs = _renderInlineRuns(inlines, formulaRels, bold: bold, inCell: true);
    return '<w:p>$runs</w:p>';
  }

  /// 渲染粗体内部的行内元素
  static String _renderBoldInline(
    List<InlineElement> children,
    Map<String, FormulaImageInfo?> formulaRels,
  ) {
    return _renderInlineRuns(children, formulaRels, bold: true);
  }

  /// 统一的行内渲染：覆盖 Text / Formula / Bold / Italic / Strikethrough /
  /// InlineCode / Link / Image，供段落 / 列表 / 表格单元格 / 粗体内部复用。
  ///
  /// [bold] 在 TextElement run 上附加 `<w:b/>`；[inCell] 让字号用 22
  /// （表格单元格更小）。嵌套元素（如加粗内的斜体）递归处理。
  static String _renderInlineRuns(
    List<InlineElement> children,
    Map<String, FormulaImageInfo?> formulaRels, {
    bool bold = false,
    bool inCell = false,
  }) {
    final runs = StringBuffer();
    final sz = inCell ? '22' : '24';
    for (final c in children) {
      if (c is TextElement) {
        final style = bold
            ? '<w:rPr><w:b/><w:sz w:val="$sz"/></w:rPr>'
            : '<w:rPr><w:sz w:val="$sz"/></w:rPr>';
        runs.write(
          '''<w:r>$style<w:t xml:space="preserve">${_esc(c.text)}</w:t></w:r>''',
        );
      } else if (c is FormulaElement) {
        final info = formulaRels[c.latex];
        if (info != null) {
          runs.write(_formulaImage(info.relId, info.widthEmu, info.heightEmu));
        } else {
          runs.write(_formulaFallback(c.latex));
        }
      } else if (c is BoldElement) {
        runs.write(_renderInlineRuns(c.children, formulaRels,
            bold: true, inCell: inCell));
      } else if (c is ItalicElement) {
        runs.write(_renderItalicInline(c.children, formulaRels, inCell: inCell));
      } else if (c is StrikethroughElement) {
        runs.write(_renderStrikeInline(c.children, formulaRels, inCell: inCell));
      } else if (c is InlineCodeElement) {
        runs.write(_renderCodeInline(c.code));
      } else if (c is LinkElement) {
        runs.write(_renderLinkInline(c.text, c.url));
      } else if (c is ImageElement) {
        runs.write(_renderImageInline(c.alt, c.url));
      }
    }
    return runs.toString();
  }

  static String _renderItalicInline(
    List<InlineElement> children,
    Map<String, FormulaImageInfo?> formulaRels, {
    bool inCell = false,
  }) {
    final sz = inCell ? '22' : '24';
    final runs = StringBuffer();
    for (final c in children) {
      if (c is TextElement) {
        runs.write(
          '''<w:r><w:rPr><w:i/><w:sz w:val="$sz"/></w:rPr><w:t xml:space="preserve">${_esc(c.text)}</w:t></w:r>''',
        );
      } else if (c is FormulaElement) {
        final info = formulaRels[c.latex];
        if (info != null) {
          runs.write(_formulaImage(info.relId, info.widthEmu, info.heightEmu));
        } else {
          runs.write(_formulaFallback(c.latex));
        }
      }
    }
    return runs.toString();
  }

  static String _renderStrikeInline(
    List<InlineElement> children,
    Map<String, FormulaImageInfo?> formulaRels, {
    bool inCell = false,
  }) {
    final sz = inCell ? '22' : '24';
    final runs = StringBuffer();
    for (final c in children) {
      if (c is TextElement) {
        runs.write(
          '''<w:r><w:rPr><w:strike/><w:sz w:val="$sz"/></w:rPr><w:t xml:space="preserve">${_esc(c.text)}</w:t></w:r>''',
        );
      } else if (c is FormulaElement) {
        final info = formulaRels[c.latex];
        if (info != null) {
          runs.write(_formulaImage(info.relId, info.widthEmu, info.heightEmu));
        } else {
          runs.write(_formulaFallback(c.latex));
        }
      }
    }
    return runs.toString();
  }

  static String _renderCodeInline(String code) {
    return '''<w:r><w:rPr><w:rFonts w:ascii="Courier New" w:hAnsi="Courier New"/><w:sz w:val="22"/></w:rPr><w:t xml:space="preserve">${_esc(code)}</w:t></w:r>''';
  }

  static String _renderLinkInline(String text, String url) {
    return '''<w:r><w:rPr><w:color w:val="0563C1"/><w:u w:val="single"/></w:rPr><w:t xml:space="preserve">${_esc(text)}</w:t></w:r>''';
  }

  static String _renderImageInline(String alt, String url) {
    final label = alt.isNotEmpty ? '[图片: $alt]' : '[图片]';
    return '''<w:r><w:rPr><w:color w:val="888888"/></w:rPr><w:t xml:space="preserve">${_esc(label)}</w:t></w:r>''';
  }

  /// 渲染任务列表项（- [ ] / - [x]）。
  static String _taskListItem(
    List<InlineElement> children,
    bool checked,
    int indent, {
    required Map<String, FormulaImageInfo?> formulaRels,
  }) {
    final box = checked ? '\u2611' : '\u2610';
    final leftIndent = 360 + (indent * 360);
    final runs = _renderInlineRuns(children, formulaRels);
    return '''<w:p><w:pPr><w:ind w:left="$leftIndent" w:hanging="360"/></w:pPr><w:r><w:t xml:space="preserve">$box </w:t></w:r>$runs</w:p>''';
  }

  /// 渲染水平分割线（--- / *** / ___）。
  static String _horizontalRule() {
    return '''<w:p><w:pPr><w:pBdr><w:bottom w:val="single" w:sz="6" w:space="1" w:color="999999"/></w:pBdr></w:pPr></w:p>''';
  }

  // --- XML escape ---

  /// XML 字符串转义 + 过滤非合法字符。
  ///
  /// 关键点：Dart String 的 `runes` 是 Unicode code points（不是 UTF-16
  /// code units）。`StringBuffer.writeCharCode(int)` 只写一个 16-bit code
  /// unit，对 BMP 外字符（如 emoji、U+1D400 数学字母数字）会**截断为低
  /// 16 位**，产生未配对 surrogate，后续 utf8.encode 抛
  /// "Unexpected extension byte" → docx 解析失败。
  ///
  /// 正确做法：用 `String.fromCharCodes(runesIterable)` 一次性写回
  /// —— Dart 内部会自动编码为合法 UTF-16（必要时拆成 surrogate pair）。
  static String _esc(String s) {
    // 第一遍：过滤非合法 XML 字符（NUL / DEL 等），把 surrogate 区域
    // 替换为 U+FFFD。这一步我们重建一个干净的 runes 列表。
    final safeRunes = <int>[];
    for (final rune in s.runes) {
      if (rune >= 0x20 && rune != 0x7F) {
        safeRunes.add(rune);
      } else if (rune == 0x09 || rune == 0x0A || rune == 0x0D) {
        // Tab / LF / CR 是合法 XML 字符
        safeRunes.add(rune);
      } else if (rune >= 0xD800 && rune <= 0xDFFF) {
        // 漏网的未配对 surrogate：替换为 U+FFFD
        safeRunes.add(0xFFFD);
      } else {
        // NUL / DEL 等控制字符：替换为 U+FFFD
        safeRunes.add(0xFFFD);
      }
    }
    // 第二遍：用 fromCharCodes 一次性写回，fromCharCodes 会正确生成
    // surrogate pair 来表示 BMP 外字符（U+10000-U+10FFFF）。
    return String.fromCharCodes(safeRunes)
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}

/// 解析 PNG 图片的宽高（单位：像素）。
///
/// PNG 文件结构：
///   - 8 字节 signature (89 50 4E 47 0D 0A 1A 0A)
///   - N 个 chunk: 4 字节 length + 4 字节 type + data + 4 字节 CRC
///   - 第一个 chunk 必须是 IHDR，data 长度固定 13 字节：
///       width (4 bytes BE) | height (4 bytes BE) | bit depth | color type | ...
///
/// 我们的解析只读取前 24 字节覆盖 IHDR 头 25 字节的前 24 字节，依赖
/// "首个 chunk 是 IHDR" 这一约定。如果第一个 chunk 不是 IHDR (非标准 PNG)，
/// 我们仍然会读出 width/height 字段，但语义错误——为此我们额外校验
/// 偏移 12-15 字节为 "IHDR" magic，否则返回 null。
({int width, int height})? parsePngDimensions(Uint8List bytes) {
  if (bytes.length < 24) return null;
  // 校验 PNG signature
  if (bytes[0] != 0x89 ||
      bytes[1] != 0x50 ||
      bytes[2] != 0x4E ||
      bytes[3] != 0x47 ||
      bytes[4] != 0x0D ||
      bytes[5] != 0x0A ||
      bytes[6] != 0x1A ||
      bytes[7] != 0x0A) {
    return null; // Not PNG
  }
  // 校验第一个 chunk 是 IHDR
  if (bytes[12] != 0x49 || // I
      bytes[13] != 0x48 || // H
      bytes[14] != 0x44 || // D
      bytes[15] != 0x52) { // R
    return null; // 第一个 chunk 不是 IHDR，无法安全解析
  }
  try {
    // Dart int 是 64-bit 有符号，因此先做 unsigned-extend
    // 拼成无符号 32-bit 整数（最终仍是 int，但值正确）
    final wBig = (BigInt.from(bytes[16] & 0xFF) << 24) |
        (BigInt.from(bytes[17] & 0xFF) << 16) |
        (BigInt.from(bytes[18] & 0xFF) << 8) |
        BigInt.from(bytes[19] & 0xFF);
    final hBig = (BigInt.from(bytes[20] & 0xFF) << 24) |
        (BigInt.from(bytes[21] & 0xFF) << 16) |
        (BigInt.from(bytes[22] & 0xFF) << 8) |
        BigInt.from(bytes[23] & 0xFF);
    final width = wBig.toUnsigned(32).toInt();
    final height = hBig.toUnsigned(32).toInt();
    // PNG 规范: width/height 不能为 0，且上限约为 2^31 - 1
    if (width <= 0 || height <= 0) return null;
    if (width > 0x7FFFFFFF || height > 0x7FFFFFFF) return null;
    return (width: width, height: height);
  } catch (_) {
    return null;
  }
}
