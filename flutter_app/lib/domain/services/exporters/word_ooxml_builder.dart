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
    Map<String, FormulaImageInfo> formulaRels,
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
    Map<String, FormulaImageInfo> formulaRels,
    Map<String, MermaidImageInfo> mermaidRels,
  ) {
    final buf = StringBuffer();
    for (final entry in formulaRels.entries) {
      final info = entry.value;
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
    required Map<String, FormulaImageInfo> formulaRels,
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
      return _table(element.headers, element.rows);
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
    required Map<String, FormulaImageInfo> formulaRels,
  }) {
    final runs = StringBuffer();
    for (final c in children) {
      if (c is FormulaElement) {
        final info = formulaRels[c.latex];
        if (info != null) {
          runs.write(_formulaImage(info.relId, info.widthEmu, info.heightEmu));
        } else {
          runs.write(_formulaFallback(c.latex));
        }
      } else if (c is TextElement) {
        runs.write(
          '''<w:r><w:rPr><w:sz w:val="24"/></w:rPr><w:t xml:space="preserve">${_esc(c.text)}</w:t></w:r>''',
        );
      }
    }
    return '<w:p>$runs</w:p>';
  }

  static String _list(
    List<InlineElement> children,
    int indent,
    bool ordered, {
    required Map<String, FormulaImageInfo> formulaRels,
  }) {
    // 真正使用 numbering.xml 里定义的 numId。
    // ordered → numId 1 (decimal "1.")；unordered → numId 2 (bullet "•")。
    // ilvl 0 对应 abstractNum 的第一层，Word 会根据 numFmt 自动渲染前缀，
    // 因此不再手动写 "${indent + 1}. " 文本前缀。
    final numId = ordered
        ? WordOoxmlTemplates.numIdOrdered
        : WordOoxmlTemplates.numIdBullet;
    final leftIndent = 360 + (indent * 360);
    final runs = StringBuffer();
    for (final c in children) {
      if (c is TextElement) {
        runs.write(
          '''<w:r><w:t xml:space="preserve">${_esc(c.text)}</w:t></w:r>''',
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
    final w = widthEmu > 0 && widthEmu < maxDim ? widthEmu : 1200000;
    final h = heightEmu > 0 && heightEmu < maxDim ? heightEmu : 360000;
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

  /// 根据 SVG viewBox 比例计算 Word 绘图尺寸（EMU 单位）。
  /// 限制最大宽度为 6 英寸（5486400 EMU），高度按比例计算。
  static (int cx, int cy) calcMermaidEmu(String svg) {
    const maxWidthEmu = 5486400; // 6 inches in EMU
    const minHeightEmu = 100000; // 最小高度 1cm
    const defaultRatio = 2.0; // 默认 6x3 inches

    final dims = parseSvgViewBox(svg);
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

  static String _table(List<String> headers, List<List<String>> rows) {
    if (headers.isEmpty) return '<w:p/>';

    final headerCells = headers
        .map((h) => '''<w:tc><w:tcPr><w:tcBorders><w:top w:val="single" w:sz="4" w:color="999999"/><w:left w:val="single" w:sz="4" w:color="999999"/><w:bottom w:val="single" w:sz="4" w:color="999999"/><w:right w:val="single" w:sz="4" w:color="999999"/></w:tcBorders><w:shd w:val="clear" w:fill="DDDDDD"/></w:tcPr><w:p><w:r><w:rPr><w:b/></w:rPr><w:t>${_esc(h)}</w:t></w:r></w:p></w:tc>''')
        .join('');

    final dataRows = rows.map((row) {
      final cells = row
          .map((cell) => '''<w:tc><w:tcPr><w:tcBorders><w:top w:val="single" w:sz="4" w:color="CCCCCC"/><w:left w:val="single" w:sz="4" w:color="CCCCCC"/><w:bottom w:val="single" w:sz="4" w:color="CCCCCC"/><w:right w:val="single" w:sz="4" w:color="CCCCCC"/></w:tcBorders></w:tcPr><w:p><w:r><w:t>${_esc(cell)}</w:t></w:r></w:p></w:tc>''')
          .join('');
      return '<w:tr>$cells</w:tr>';
    }).join('');

    return '''<w:tbl><w:tblPr><w:tblStyle w:val="TableGrid"/><w:tblW w:w="0" w:type="auto"/></w:tblPr><w:tr>$headerCells</w:tr>$dataRows</w:tbl>''';
  }

  // --- XML escape ---

  static String _esc(String s) {
    final cleaned = StringBuffer();
    for (final rune in s.runes) {
      if (rune >= 0x20 && rune != 0x7F) {
        cleaned.writeCharCode(rune);
      } else {
        cleaned.write('\uFFFD');
      }
    }
    return cleaned
        .toString()
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}

/// 解析 PNG 图片的宽高（单位：像素）。
/// PNG header: signature(8) + IHDR chunk(len:4 + type:4 + data:13 + crc:4)
/// 宽度在偏移 16 处，高度在偏移 20 处，均为 4 字节 big-endian。
({int width, int height})? parsePngDimensions(Uint8List bytes) {
  if (bytes.length < 24) return null;
  if (bytes[0] != 0x89 ||
      bytes[1] != 0x50 ||
      bytes[2] != 0x4E ||
      bytes[3] != 0x47) return null; // Not PNG
  try {
    final w0 = bytes[16] & 0xFF;
    final w1 = bytes[17] & 0xFF;
    final w2 = bytes[18] & 0xFF;
    final w3 = bytes[19] & 0xFF;
    final h0 = bytes[20] & 0xFF;
    final h1 = bytes[21] & 0xFF;
    final h2 = bytes[22] & 0xFF;
    final h3 = bytes[23] & 0xFF;
    final width = (w0 << 24) | (w1 << 16) | (w2 << 8) | w3;
    final height = (h0 << 24) | (h1 << 16) | (h2 << 8) | h3;
    return (width: width, height: height);
  } catch (_) {
    return null;
  }
}
