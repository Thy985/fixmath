/// OOXML 模板常量集合。
///
/// 为 [MarkdownExporter.exportToWord] 提供符合 ECMA-376 规范的 WordprocessingML
/// 部件字符串（styles/settings/numbering 等），保证导出的 .docx 在 Word/WPS/
/// LibreOffice 中能稳定打开并正确应用样式。
///
/// 选型说明：
///   - 仅补全导出器实际用到的 styleId/numId，保持 XML 体积最小
///   - 全部使用静态 const 字符串（无运行时拼接），便于测试和审计
///   - 命名约定：styleId 使用 PascalCase (Heading1)；numId 数值 1,2
///   - 所有模板都内嵌必需的 `xmlns` 声明，独立部件可直接作为 Part 写入 zip
///
/// 修改任一模板前请同步检查 export_service.dart 的 _word* 方法是否仍然引用
/// 对应的 styleId/numId。
library;

class WordOoxmlTemplates {
  WordOoxmlTemplates._();

  // ---------------------------------------------------------------------------
  // 段落/字符样式 (word/styles.xml)
  // ---------------------------------------------------------------------------

  /// Normal 样式 + 文档默认 docDefaults + Heading1..6 + ListParagraph + CodeBlock
  /// + Blockquote + TableNormal/TableGrid + Title。
  static const String stylesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
          xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <w:docDefaults>
    <w:rPrDefault>
      <w:rPr>
        <w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:eastAsia="SimSun" w:cs="Times New Roman"/>
        <w:sz w:val="22"/>
        <w:szCs w:val="22"/>
        <w:lang w:val="en-US" w:eastAsia="zh-CN" w:bidi="ar-SA"/>
      </w:rPr>
    </w:rPrDefault>
    <w:pPrDefault>
      <w:pPr>
        <w:spacing w:after="160" w:line="259" w:lineRule="auto"/>
      </w:pPr>
    </w:pPrDefault>
  </w:docDefaults>

  <w:style w:type="paragraph" w:default="1" w:styleId="Normal">
    <w:name w:val="Normal"/>
    <w:qFormat/>
  </w:style>

  <w:style w:type="paragraph" w:styleId="Title">
    <w:name w:val="Title"/>
    <w:basedOn w:val="Normal"/>
    <w:qFormat/>
    <w:pPr>
      <w:jc w:val="center"/>
    </w:pPr>
    <w:rPr>
      <w:b/>
      <w:sz w:val="44"/>
    </w:rPr>
  </w:style>

  <w:style w:type="paragraph" w:styleId="Heading1">
    <w:name w:val="heading 1"/>
    <w:basedOn w:val="Normal"/>
    <w:next w:val="Normal"/>
    <w:qFormat/>
    <w:pPr>
      <w:keepNext/>
      <w:spacing w:before="240" w:after="60"/>
      <w:outlineLvl w:val="0"/>
    </w:pPr>
    <w:rPr>
      <w:b/>
      <w:sz w:val="36"/>
    </w:rPr>
  </w:style>

  <w:style w:type="paragraph" w:styleId="Heading2">
    <w:name w:val="heading 2"/>
    <w:basedOn w:val="Normal"/>
    <w:next w:val="Normal"/>
    <w:qFormat/>
    <w:pPr>
      <w:keepNext/>
      <w:spacing w:before="200" w:after="40"/>
      <w:outlineLvl w:val="1"/>
    </w:pPr>
    <w:rPr>
      <w:b/>
      <w:sz w:val="32"/>
    </w:rPr>
  </w:style>

  <w:style w:type="paragraph" w:styleId="Heading3">
    <w:name w:val="heading 3"/>
    <w:basedOn w:val="Normal"/>
    <w:next w:val="Normal"/>
    <w:qFormat/>
    <w:pPr>
      <w:keepNext/>
      <w:spacing w:before="160" w:after="40"/>
      <w:outlineLvl w:val="2"/>
    </w:pPr>
    <w:rPr>
      <w:b/>
      <w:sz w:val="28"/>
    </w:rPr>
  </w:style>

  <w:style w:type="paragraph" w:styleId="Heading4">
    <w:name w:val="heading 4"/>
    <w:basedOn w:val="Normal"/>
    <w:next w:val="Normal"/>
    <w:qFormat/>
    <w:pPr>
      <w:keepNext/>
      <w:spacing w:before="120" w:after="20"/>
      <w:outlineLvl w:val="3"/>
    </w:pPr>
    <w:rPr>
      <w:b/>
      <w:sz w:val="24"/>
    </w:rPr>
  </w:style>

  <w:style w:type="paragraph" w:styleId="Heading5">
    <w:name w:val="heading 5"/>
    <w:basedOn w:val="Normal"/>
    <w:next w:val="Normal"/>
    <w:qFormat/>
    <w:pPr>
      <w:keepNext/>
      <w:spacing w:before="100" w:after="20"/>
      <w:outlineLvl w:val="4"/>
    </w:pPr>
    <w:rPr>
      <w:b/>
      <w:i/>
      <w:sz w:val="24"/>
    </w:rPr>
  </w:style>

  <w:style w:type="paragraph" w:styleId="Heading6">
    <w:name w:val="heading 6"/>
    <w:basedOn w:val="Normal"/>
    <w:next w:val="Normal"/>
    <w:qFormat/>
    <w:pPr>
      <w:keepNext/>
      <w:spacing w:before="80" w:after="20"/>
      <w:outlineLvl w:val="5"/>
    </w:pPr>
    <w:rPr>
      <w:b/>
      <w:i/>
      <w:sz w:val="24"/>
      <w:color w:val="595959"/>
    </w:rPr>
  </w:style>

  <w:style w:type="paragraph" w:styleId="ListParagraph">
    <w:name w:val="List Paragraph"/>
    <w:basedOn w:val="Normal"/>
    <w:qFormat/>
    <w:pPr>
      <w:ind w:left="720"/>
      <w:contextualSpacing/>
    </w:pPr>
  </w:style>

  <w:style w:type="paragraph" w:styleId="CodeBlock">
    <w:name w:val="Code Block"/>
    <w:basedOn w:val="Normal"/>
    <w:qFormat/>
    <w:pPr>
      <w:shd w:val="clear" w:color="auto" w:fill="F0F0F0"/>
      <w:spacing w:before="120" w:after="120"/>
      <w:ind w:left="360" w:right="360"/>
    </w:pPr>
    <w:rPr>
      <w:rFonts w:ascii="Courier New" w:hAnsi="Courier New" w:cs="Courier New"/>
      <w:sz w:val="20"/>
    </w:rPr>
  </w:style>

  <w:style w:type="paragraph" w:styleId="Blockquote">
    <w:name w:val="Blockquote"/>
    <w:basedOn w:val="Normal"/>
    <w:qFormat/>
    <w:pPr>
      <w:pBdr>
        <w:left w:val="single" w:sz="12" w:space="8" w:color="4472C4"/>
      </w:pBdr>
      <w:shd w:val="clear" w:color="auto" w:fill="F5F5F5"/>
      <w:spacing w:before="120" w:after="120"/>
      <w:ind w:left="360" w:right="360"/>
    </w:pPr>
    <w:rPr>
      <w:i/>
      <w:color w:val="595959"/>
    </w:rPr>
  </w:style>

  <w:style w:type="table" w:default="1" w:styleId="TableNormal">
    <w:name w:val="Normal Table"/>
    <w:uiPriority w:val="99"/>
    <w:semiHidden/>
    <w:unhideWhenUsed/>
    <w:tblPr>
      <w:tblInd w:w="0" w:type="dxa"/>
      <w:tblCellMar>
        <w:top w:w="0" w:type="dxa"/>
        <w:left w:w="108" w:type="dxa"/>
        <w:bottom w:w="0" w:type="dxa"/>
        <w:right w:w="108" w:type="dxa"/>
      </w:tblCellMar>
    </w:tblPr>
  </w:style>

  <w:style w:type="table" w:styleId="TableGrid">
    <w:name w:val="Table Grid"/>
    <w:basedOn w:val="TableNormal"/>
    <w:tblPr>
      <w:tblBorders>
        <w:top w:val="single" w:sz="4" w:space="0" w:color="999999"/>
        <w:left w:val="single" w:sz="4" w:space="0" w:color="999999"/>
        <w:bottom w:val="single" w:sz="4" w:space="0" w:color="999999"/>
        <w:right w:val="single" w:sz="4" w:space="0" w:color="999999"/>
        <w:insideH w:val="single" w:sz="4" w:space="0" w:color="CCCCCC"/>
        <w:insideV w:val="single" w:sz="4" w:space="0" w:color="CCCCCC"/>
      </w:tblBorders>
    </w:tblPr>
  </w:style>
</w:styles>''';

  // ---------------------------------------------------------------------------
  // 文档设置 (word/settings.xml)
  // ---------------------------------------------------------------------------

  /// zoom=100、defaultTabStop=720(英寸) = 0.5 英寸，
  /// characterSpacingControl=doNotCompress + compatMode=15 (Word 2013+)。
  static const String settingsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:settings xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:zoom w:percent="100"/>
  <w:defaultTabStop w:val="720"/>
  <w:characterSpacingControl w:val="doNotCompress"/>
  <w:compat>
    <w:compatSetting w:name="compatibilityMode" w:uri="http://schemas.microsoft.com/office/word" w:val="15"/>
  </w:compat>
</w:settings>''';

  // ---------------------------------------------------------------------------
  // 列表编号 (word/numbering.xml)
  // ---------------------------------------------------------------------------

  /// numId 1 = 有序列表 (decimal: "1.", "2." ...)，numId 2 = 无序列表 (bullet "•")。
  /// 每种列表仅定义 ilvl=0 一层；缩进 720 twip，悬挂 360 twip。
  /// 嵌套层级可由 abstractNumId 0/1 扩展后续 ilvl，但当前导出的 _wordList 只用
  /// 顶层 (indent=0)；如需多级列表可在 export_service 内对应扩展。
  static const String numberingXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:numbering xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:abstractNum w:abstractNumId="0">
    <w:multiLevelType w:val="hybridMultilevel"/>
    <w:lvl w:ilvl="0">
      <w:start w:val="1"/>
      <w:numFmt w:val="decimal"/>
      <w:lvlText w:val="%1."/>
      <w:lvlJc w:val="left"/>
      <w:pPr>
        <w:ind w:left="720" w:hanging="360"/>
      </w:pPr>
    </w:lvl>
  </w:abstractNum>
  <w:abstractNum w:abstractNumId="1">
    <w:multiLevelType w:val="hybridMultilevel"/>
    <w:lvl w:ilvl="0">
      <w:start w:val="1"/>
      <w:numFmt w:val="bullet"/>
      <w:lvlText w:val="\u2022"/>
      <w:lvlJc w:val="left"/>
      <w:pPr>
        <w:ind w:left="720" w:hanging="360"/>
      </w:pPr>
      <w:rPr>
        <w:rFonts w:ascii="Symbol" w:hAnsi="Symbol" w:hint="default"/>
      </w:rPr>
    </w:lvl>
  </w:abstractNum>
  <w:num w:numId="1">
    <w:abstractNumId w:val="0"/>
  </w:num>
  <w:num w:numId="2">
    <w:abstractNumId w:val="1"/>
  </w:num>
</w:numbering>''';

  // ---------------------------------------------------------------------------
  // [Content_Types].xml —— 整个 .docx 包的内容类型声明
  // ---------------------------------------------------------------------------

  /// 在原有的 document.xml override 基础上追加 styles/settings/numbering 三个
  /// Part 声明（ContentType 一律使用 wordprocessingml.* 系列的 +xml 变体）。
  static const String contentTypesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Default Extension="png" ContentType="image/png"/>
  <Default Extension="svg" ContentType="image/svg+xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
  <Override PartName="/word/settings.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.settings+xml"/>
  <Override PartName="/word/numbering.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.numbering+xml"/>
</Types>''';

  // ---------------------------------------------------------------------------
  // _rels/.rels —— 包级关系（指向 word/document.xml）
  // ---------------------------------------------------------------------------

  /// 包级 relationship：rId1 → word/document.xml。styles/settings/numbering
  /// 不出现在这里，而是通过 word/_rels/document.xml.rels 引用。
  static const String rootRelsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''';

  // ---------------------------------------------------------------------------
  // document.xml.rels 静态前缀（图片 rId 动态追加在后）
  // ---------------------------------------------------------------------------

  /// document.xml 关系文件的前缀：包含 styles/settings/numbering 三个固定
  /// Relationship，后接由 _buildImageRelsXml 动态追加的图片 Relationship。
  /// Id 使用语义化命名（rIdStyles/rIdSettings/rIdNumbering），不与图片使用的
  /// `rIdImageN` / `rIdMermaidN` 冲突。
  static const String documentRelsHeader = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rIdStyles" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
  <Relationship Id="rIdSettings" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings" Target="settings.xml"/>
  <Relationship Id="rIdNumbering" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/numbering" Target="numbering.xml"/>''';

  /// document.xml.rels 关闭标签。
  static const String documentRelsFooter = '</Relationships>';

  // ---------------------------------------------------------------------------
  // 便捷常量 —— 给测试 / 调试使用
  // ---------------------------------------------------------------------------

  /// 在 _wordList / _wordHeading 等方法里引用的 styleId/numId 名字面量。
  /// 集中在这里方便测试断言和重构时静态检查。
  static const Map<String, String> styleIds = {
    'normal': 'Normal',
    'title': 'Title',
    'heading1': 'Heading1',
    'heading2': 'Heading2',
    'heading3': 'Heading3',
    'heading4': 'Heading4',
    'heading5': 'Heading5',
    'heading6': 'Heading6',
    'listParagraph': 'ListParagraph',
    'codeBlock': 'CodeBlock',
    'blockquote': 'Blockquote',
    'tableGrid': 'TableGrid',
  };

  /// numId 字面量：1=ordered，2=bullet。
  static const int numIdOrdered = 1;
  static const int numIdBullet = 2;
}
