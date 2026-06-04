import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formula_fix/core/parser/markdown_parser.dart';
import 'package:formula_fix/domain/services/export_service.dart';
import 'package:formula_fix/data/models/document.dart';

void main() {
  group('MarkdownExporter 集成测试', () {
    group('PDF 导出', () {
      test('导出简单文本', () async {
        const markdown = '# 标题\n\n这是一段文本。';
        final pdfBytes = await MarkdownExporter.exportToPdf(markdown);
        expect(pdfBytes.isNotEmpty, true);
        expect(pdfBytes.length, greaterThan(100));
        expect(_isPdf(pdfBytes), true);
      });

      test('导出包含多级标题的文档', () async {
        const markdown = '''
# 一级标题
## 二级标题
### 三级标题
正文内容
''';
        final pdfBytes = await MarkdownExporter.exportToPdf(markdown);
        expect(pdfBytes.isNotEmpty, true);
        expect(_isPdf(pdfBytes), true);
      });

      test('导出包含列表的文档', () async {
        const markdown = '''
# 购物清单

- 苹果
- 香蕉
- 橙子

## 有序列表

1. 第一步
2. 第二步
3. 第三步
''';
        final pdfBytes = await MarkdownExporter.exportToPdf(markdown);
        expect(pdfBytes.isNotEmpty, true);
        expect(_isPdf(pdfBytes), true);
      });

      test('导出包含表格的文档', () async {
        const markdown = '''
# 成绩单

| 姓名 | 数学 | 语文 |
| --- | --- | --- |
| 张三 | 95 | 88 |
| 李四 | 87 | 92 |
''';
        final pdfBytes = await MarkdownExporter.exportToPdf(markdown);
        expect(pdfBytes.isNotEmpty, true);
        expect(_isPdf(pdfBytes), true);
      });

      test('导出包含代码块的文档', () async {
        const markdown = '''
# 代码示例

```python
def hello():
    print("Hello, World!")
```
''';
        final pdfBytes = await MarkdownExporter.exportToPdf(markdown);
        expect(pdfBytes.isNotEmpty, true);
        expect(_isPdf(pdfBytes), true);
      });

      test('导出包含引用的文档', () async {
        const markdown = '''
# 名言

> 人生苦短，我用 Python
> —— 某位程序员
''';
        final pdfBytes = await MarkdownExporter.exportToPdf(markdown);
        expect(pdfBytes.isNotEmpty, true);
        expect(_isPdf(pdfBytes), true);
      });

      test('导出空文档应抛出异常', () async {
        expect(
          () => MarkdownExporter.exportToPdf(''),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('Word 导出', () {
      test('导出简单文本到 Word', () async {
        const markdown = '# 标题\n\n这是一段文本。';
        final wordBytes = await MarkdownExporter.exportToWord(markdown);
        expect(wordBytes.isNotEmpty, true);
        expect(_isZip(wordBytes), true);
        expect(_hasDocxStructure(wordBytes), true);
      });

      test('导出包含复杂表格的 Word 文档', () async {
        const markdown = '''
# 多列表格

| 产品 | 价格 | 数量 | 总计 |
| --- | --- | --- | --- |
| 苹果 | 5 | 10 | 50 |
| 香蕉 | 3 | 5 | 15 |
''';
        final wordBytes = await MarkdownExporter.exportToWord(markdown);
        expect(wordBytes.isNotEmpty, true);
        expect(_isZip(wordBytes), true);
        expect(_hasDocxStructure(wordBytes), true);
      });

      test('导出空文档应抛出异常', () async {
        expect(
          () => MarkdownExporter.exportToWord(''),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('Word 文档结构 (OOXML 完整性)', () {
      // 完整覆盖 Markdown 各种语法的样本，用于一次性跑全结构断言。
      const sampleDoc = r'''
# 一级标题

## 二级标题

### 三级标题

正文段落，包含**加粗**与*斜体*。

- 项目 1
- 项目 2

1. 有序 1
2. 有序 2

```python
def hello():
    print("hi")
```

> 引用内容
''';

      test('包含必需 Part：word/styles.xml, word/settings.xml, word/numbering.xml', () async {
        final bytes = await MarkdownExporter.exportToWord(sampleDoc);
        final archive = ZipDecoder().decodeBytes(bytes);
        final names = archive.files.map((f) => f.name).toSet();
        expect(names.contains('word/styles.xml'), true,
            reason: 'word/styles.xml must exist for pStyle references');
        expect(names.contains('word/settings.xml'), true,
            reason: 'word/settings.xml must exist for docDefaults');
        expect(names.contains('word/numbering.xml'), true,
            reason: 'word/numbering.xml must exist for numPr references');
        // 同时验证 document.xml 与 rels 也存在
        expect(names.contains('word/document.xml'), true);
        expect(names.contains('word/_rels/document.xml.rels'), true);
        expect(names.contains('[Content_Types].xml'), true);
        expect(names.contains('_rels/.rels'), true);
      });

      test('styles.xml 包含关键 styleId：Heading1, CodeBlock, Blockquote', () async {
        final bytes = await MarkdownExporter.exportToWord(sampleDoc);
        final archive = ZipDecoder().decodeBytes(bytes);
        final stylesFile = archive.findFile('word/styles.xml');
        expect(stylesFile, isNotNull, reason: 'styles.xml not found');
        final stylesXml = utf8.decode(stylesFile!.content as List<int>);
        // 验证 styleId 在 <w:style w:styleId="..."> 属性里出现
        expect(stylesXml.contains('w:styleId="Heading1"'), true,
            reason: 'Heading1 styleId must be defined');
        expect(stylesXml.contains('w:styleId="CodeBlock"'), true,
            reason: 'CodeBlock styleId must be defined');
        expect(stylesXml.contains('w:styleId="Blockquote"'), true,
            reason: 'Blockquote styleId must be defined');
        // 顺带验证 Heading2/3/4/5/6 + ListParagraph + Title 也都定义
        expect(stylesXml.contains('w:styleId="Heading2"'), true);
        expect(stylesXml.contains('w:styleId="Heading3"'), true);
        expect(stylesXml.contains('w:styleId="Heading4"'), true);
        expect(stylesXml.contains('w:styleId="Heading5"'), true);
        expect(stylesXml.contains('w:styleId="Heading6"'), true);
        expect(stylesXml.contains('w:styleId="ListParagraph"'), true);
        expect(stylesXml.contains('w:styleId="Title"'), true);
        expect(stylesXml.contains('w:styleId="TableGrid"'), true);
      });

      test('numbering.xml 定义 numId=1 (ordered) 和 numId=2 (bullet)', () async {
        final bytes = await MarkdownExporter.exportToWord(sampleDoc);
        final archive = ZipDecoder().decodeBytes(bytes);
        final numberingFile = archive.findFile('word/numbering.xml');
        expect(numberingFile, isNotNull, reason: 'numbering.xml not found');
        final numberingXml = utf8.decode(numberingFile!.content as List<int>);
        expect(numberingXml.contains('w:numId="1"'), true,
            reason: 'numId 1 (ordered) must be defined');
        expect(numberingXml.contains('w:numId="2"'), true,
            reason: 'numId 2 (bullet) must be defined');
        expect(numberingXml.contains('w:numFmt w:val="decimal"'), true,
            reason: 'decimal numFmt must be defined for ordered list');
        expect(numberingXml.contains('w:numFmt w:val="bullet"'), true,
            reason: 'bullet numFmt must be defined for unordered list');
      });

      test('settings.xml 包含 zoom=100 和 defaultTabStop', () async {
        final bytes = await MarkdownExporter.exportToWord(sampleDoc);
        final archive = ZipDecoder().decodeBytes(bytes);
        final settingsFile = archive.findFile('word/settings.xml');
        expect(settingsFile, isNotNull, reason: 'settings.xml not found');
        final settingsXml = utf8.decode(settingsFile!.content as List<int>);
        expect(settingsXml.contains('w:zoom'), true);
        expect(settingsXml.contains('w:defaultTabStop'), true);
      });

      test('document.xml 至少有一个段落引用 Heading1 pStyle', () async {
        final bytes = await MarkdownExporter.exportToWord(sampleDoc);
        final archive = ZipDecoder().decodeBytes(bytes);
        final docFile = archive.findFile('word/document.xml');
        expect(docFile, isNotNull, reason: 'document.xml not found');
        final docXml = utf8.decode(docFile!.content as List<int>);
        // 验证 Title 和 Heading1..4 的 pStyle 都被实际引用
        expect(docXml.contains('w:val="Title"'), true,
            reason: 'Title pStyle must be referenced (document title)');
        expect(docXml.contains('w:val="Heading1"'), true,
            reason: 'Heading1 pStyle must be referenced');
        expect(docXml.contains('w:val="Heading2"'), true);
        expect(docXml.contains('w:val="Heading3"'), true);
        expect(docXml.contains('w:val="CodeBlock"'), true);
        expect(docXml.contains('w:val="Blockquote"'), true);
        // numPr 真正使用 numId 1/2
        expect(docXml.contains('w:numPr'), true,
            reason: 'w:numPr must appear in document.xml');
        expect(docXml.contains('w:numId w:val="1"'), true,
            reason: 'ordered list must use numId=1');
        expect(docXml.contains('w:numId w:val="2"'), true,
            reason: 'bullet list must use numId=2');
      });

      test('document.xml.rels 包含 styles/settings/numbering Relationship', () async {
        final bytes = await MarkdownExporter.exportToWord(sampleDoc);
        final archive = ZipDecoder().decodeBytes(bytes);
        final relsFile = archive.findFile('word/_rels/document.xml.rels');
        expect(relsFile, isNotNull, reason: 'document.xml.rels not found');
        final relsXml = utf8.decode(relsFile!.content as List<int>);
        expect(relsXml.contains('Target="styles.xml"'), true,
            reason: 'styles Relationship must exist');
        expect(relsXml.contains('Target="settings.xml"'), true);
        expect(relsXml.contains('Target="numbering.xml"'), true);
        // 验证 Relationship Type 正确
        expect(
            relsXml.contains(
                'http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles'),
            true);
        expect(
            relsXml.contains(
                'http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings'),
            true);
        expect(
            relsXml.contains(
                'http://schemas.openxmlformats.org/officeDocument/2006/relationships/numbering'),
            true);
      });

      test('[Content_Types].xml 包含 styles/settings/numbering Override', () async {
        final bytes = await MarkdownExporter.exportToWord(sampleDoc);
        final archive = ZipDecoder().decodeBytes(bytes);
        final ctFile = archive.findFile('[Content_Types].xml');
        expect(ctFile, isNotNull, reason: '[Content_Types].xml not found');
        final ctXml = utf8.decode(ctFile!.content as List<int>);
        expect(ctXml.contains('PartName="/word/styles.xml"'), true,
            reason: 'styles.xml Override must exist');
        expect(ctXml.contains('PartName="/word/settings.xml"'), true);
        expect(ctXml.contains('PartName="/word/numbering.xml"'), true);
        // 验证 ContentType
        expect(
            ctXml.contains(
                'application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml'),
            true);
        expect(
            ctXml.contains(
                'application/vnd.openxmlformats-officedocument.wordprocessingml.settings+xml'),
            true);
        expect(
            ctXml.contains(
                'application/vnd.openxmlformats-officedocument.wordprocessingml.numbering+xml'),
            true);
        // SVG Default 仍然存在（保证 mermaid 渲染链路）
        expect(ctXml.contains('Extension="svg"'), true);
        expect(ctXml.contains('image/svg+xml'), true);
      });

      test('无标题/列表/代码的最小 docx 也能稳定打开 (zip + 内容类型 + 最小部件)', () async {
        // 即使用户只写一段文本，docx 也要包含完整 OOXML 必需部件
        final bytes = await MarkdownExporter.exportToWord('只是普通文本。');
        final archive = ZipDecoder().decodeBytes(bytes);
        final names = archive.files.map((f) => f.name).toSet();
        // 至少包含：包描述、文档、styles、settings、numbering、document rels
        expect(names.contains('[Content_Types].xml'), true);
        expect(names.contains('_rels/.rels'), true);
        expect(names.contains('word/document.xml'), true);
        expect(names.contains('word/styles.xml'), true);
        expect(names.contains('word/settings.xml'), true);
        expect(names.contains('word/numbering.xml'), true);
        expect(names.contains('word/_rels/document.xml.rels'), true);
      });
    });

    group('Text 导出', () {
      test('导出纯文本', () async {
        const markdown = '# 标题\n\n这是一段文本。';
        final txtBytes = await MarkdownExporter.exportToTxt(markdown);
        expect(txtBytes.isNotEmpty, true);
        final content = utf8.decode(txtBytes);
        expect(content.contains('标题'), true);
        expect(content.contains('文本'), true);
      });

      test('保留 Markdown 格式的文本导出', () async {
        const markdown = '''
# 主标题

- 列表项 1
- 列表项 2

```
代码块
```
''';
        final txtBytes = await MarkdownExporter.exportToTxt(markdown);
        expect(txtBytes.isNotEmpty, true);
        final content = utf8.decode(txtBytes);
        expect(content.contains('# 主标题'), true);
        expect(content.contains('- 列表项'), true);
        expect(content.contains('```'), true);
      });
    });

    group('完整文档流程测试', () {
      test('数学文档完整导出流程', () async {
        const mathDoc = r'''
# 高等数学笔记

## 第一章：微积分基础

### 1.1 导数定义

函数 $f(x)$ 在点 $x_0$ 处的导数定义为：

$$
f'(x_0) = \lim_{h \to 0} \frac{f(x_0 + h) - f(x_0)}{h}
$$

### 1.2 基本求导法则

| 法则 | 公式 |
| --- | --- |
| 常数法则 | $(c)' = 0$ |
| 幂法则 | $(x^n)' = nx^{n-1}$ |
| 乘法法则 | $(uv)' = u'v + uv'$ |

### 1.3 示例代码

```python
def derivative(f, x, h=0.0001):
    return (f(x + h) - f(x)) / h

result = derivative(lambda x: x**2, 3)
print(f"导数值: {result}")
```

> 注意：这是一个近似计算，实际使用中应考虑数值精度问题。

## 第二章：积分

### 2.1 不定积分

$$
\int x^n dx = \frac{x^{n+1}}{n+1} + C
$$

### 列表总结

基本积分公式：
1. $\int k dx = kx + C$
2. $\int x^n dx = \frac{x^{n+1}}{n+1} + C$
3. $\int e^x dx = e^x + C$
''';

        final elements = MarkdownParser.parse(mathDoc);
        expect(elements.isNotEmpty, true);

        final hasHeadings = elements.any((e) => e is HeadingElement);
        expect(hasHeadings, true);

        final hasFormulas = elements.any((e) {
          if (e is ParagraphElement) {
            return e.children.any((c) => c is FormulaElement);
          }
          return false;
        });
        expect(hasFormulas, true);

        final hasTables = elements.any((e) => e is TableElement);
        expect(hasTables, true);

        final hasCode = elements.any((e) => e is CodeElement);
        expect(hasCode, true);

        final hasBlockquotes = elements.any((e) => e is BlockquoteElement);
        expect(hasBlockquotes, true);

        final pdfBytes = await MarkdownExporter.exportToPdf(mathDoc);
        expect(pdfBytes.isNotEmpty, true);

        final wordBytes = await MarkdownExporter.exportToWord(mathDoc);
        expect(wordBytes.isNotEmpty, true);

        final txtBytes = await MarkdownExporter.exportToTxt(mathDoc);
        expect(txtBytes.isNotEmpty, true);
      });

      test('Mermaid 图表文档导出', () async {
        const diagramDoc = '''
# 系统架构图

## 架构描述

下图展示了系统的整体架构：

```mermaid
graph TD
    A[用户界面] --> B[API 网关]
    B --> C[用户服务]
    B --> D[订单服务]
    B --> E[支付服务]
    C --> F[(数据库)]
    D --> F
    E --> G[(支付网关)]
```

## 流程说明

1. 用户通过界面发起请求
2. 请求经过 API 网关路由
3. 各微服务处理业务逻辑
4. 数据持久化到数据库
''';

        final elements = MarkdownParser.parse(diagramDoc);
        expect(elements.isNotEmpty, true);

        final hasMermaid = elements.any((e) => e is MermaidElement);
        expect(hasMermaid, true);

        final pdfBytes = await MarkdownExporter.exportToPdf(diagramDoc);
        expect(pdfBytes.isNotEmpty, true);
      });
    });

    group('性能基准测试', () {
      test('大文档 PDF 导出性能', () async {
        final largeDoc = _generateLargeDocument();
        final stopwatch = Stopwatch()..start();
        final pdfBytes = await MarkdownExporter.exportToPdf(largeDoc);
        stopwatch.stop();
        expect(pdfBytes.isNotEmpty, true);
        print('大文档导出耗时: ${stopwatch.elapsedMilliseconds}ms');
        expect(stopwatch.elapsedMilliseconds, lessThan(5000));
      });
    });
  });

  group('ExportService 错误分类', () {
    test('空白 markdown 抛 emptyDocument', () async {
      bool gotEmpty = false;
      try {
        await ExportService.exportAndShare(
          markdown: '   \n  ',
          format: ExportFormat.pdf,
          exporter: (_) async => Uint8List(0),
        );
      } on ExportFailureException catch (e) {
        expect(e.info.kind, ExportFailure.emptyDocument);
        gotEmpty = true;
      }
      expect(gotEmpty, true);
    });

    test('空字符串 markdown 抛 emptyDocument', () async {
      bool gotEmpty = false;
      try {
        await ExportService.exportAndShare(
          markdown: '',
          format: ExportFormat.docx,
          exporter: (_) async => Uint8List(0),
        );
      } on ExportFailureException catch (e) {
        expect(e.info.kind, ExportFailure.emptyDocument);
        gotEmpty = true;
      }
      expect(gotEmpty, true);
    });

    test('exporter 抛 ExportException 归为 renderError', () async {
      bool got = false;
      try {
        await ExportService.exportAndShare(
          markdown: '# title',
          format: ExportFormat.pdf,
          exporter: (_) async => throw ExportException('format unsupported'),
        );
      } on ExportFailureException catch (e) {
        expect(e.info.kind, ExportFailure.renderError);
        got = true;
      }
      expect(got, true);
    });

    test('exporter 抛 ArgumentError 归为 parseError', () async {
      bool got = false;
      try {
        await ExportService.exportAndShare(
          markdown: '# title',
          format: ExportFormat.docx,
          exporter: (_) async => throw ArgumentError('bad input'),
        );
      } on ExportFailureException catch (e) {
        expect(e.info.kind, ExportFailure.parseError);
        got = true;
      }
      expect(got, true);
    });
  });
}

String _generateLargeDocument() {
  final buffer = StringBuffer();
  buffer.writeln('# 大型文档');
  buffer.writeln();

  for (int i = 1; i <= 50; i++) {
    buffer.writeln('## 第 $i 章');
    buffer.writeln();
    for (int j = 1; j <= 5; j++) {
      buffer.writeln('### 第 $i.$j 节');
      buffer.writeln();
      buffer.writeln('这是一段测试文本，包含一些内容。');
      buffer.writeln('- 列表项 1');
      buffer.writeln('- 列表项 2');
      buffer.writeln('- 列表项 3');
      buffer.writeln();
      if (j % 2 == 0) {
        buffer.writeln(r'行内公式: $x^2 + y^2$');
        buffer.writeln();
      }
    }
  }

  return buffer.toString();
}

bool _isPdf(List<int> bytes) {
  if (bytes.length < 4) return false;
  return bytes[0] == 0x25 &&
         bytes[1] == 0x50 &&
         bytes[2] == 0x44 &&
         bytes[3] == 0x46;
}

bool _isZip(List<int> bytes) {
  if (bytes.length < 4) return false;
  return bytes[0] == 0x50 && bytes[1] == 0x4B;
}

bool _hasDocxStructure(List<int> bytes) {
  return _isZip(bytes);
}

