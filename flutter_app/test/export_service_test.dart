import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:formula_fix/domain/services/export_service.dart';
import 'package:formula_fix/core/parser/markdown_parser.dart';
import 'package:formula_fix/data/models/document.dart';

void main() {
  group('ExportService.exportToPdf', () {
    test('空内容返回非空字节数组', () async {
      final result = await ExportService.exportToPdf('');
      expect(result.isNotEmpty, true);
      expect(result.length, greaterThan(0));
    });

    test('纯文本内容成功导出', () async {
      const content = 'Hello World\n\nThis is a test.';
      final result = await ExportService.exportToPdf(content);
      expect(result.isNotEmpty, true);
    });

    test('多级标题成功导出', () async {
      const content = '# 一级标题\n## 二级标题\n### 三级标题';
      final result = await ExportService.exportToPdf(content);
      expect(result.isNotEmpty, true);
    });

    test('混合内容成功导出', () async {
      const content = '# 文档标题\n\n这是第一段内容。\n\n## 子标题\n\n- 列表项1\n- 列表项2';
      final result = await ExportService.exportToPdf(content);
      expect(result.isNotEmpty, true);
    });

    test('引用块成功导出', () async {
      const content = '> 这是一段引用内容';
      final result = await ExportService.exportToPdf(content);
      expect(result.isNotEmpty, true);
    });

    test('代码块成功导出', () async {
      const content = '```python\nprint("hello")\n```';
      final result = await ExportService.exportToPdf(content);
      expect(result.isNotEmpty, true);
    });
  });

  group('ExportService.exportToWord', () {
    test('空内容返回非空字节数组', () async {
      final result = await ExportService.exportToWord('');
      expect(result.isNotEmpty, true);
    });

    test('纯文本内容成功导出', () async {
      const content = 'Hello World';
      final result = await ExportService.exportToWord(content);
      expect(result.isNotEmpty, true);
    });

    test('多级标题成功导出', () async {
      const content = '# 标题一\n## 标题二\n### 标题三';
      final result = await ExportService.exportToWord(content);
      expect(result.isNotEmpty, true);
    });

    test('列表内容成功导出', () async {
      const content = '- 项目一\n- 项目二\n- 项目三';
      final result = await ExportService.exportToWord(content);
      expect(result.isNotEmpty, true);
    });

    test('引用块成功导出', () async {
      const content = '> 引用内容\n> 第二行引用';
      final result = await ExportService.exportToWord(content);
      expect(result.isNotEmpty, true);
    });

    test('代码块成功导出', () async {
      const content = '```javascript\nconst x = 1;\n```';
      final result = await ExportService.exportToWord(content);
      expect(result.isNotEmpty, true);
    });

    test('Mermaid块成功导出', () async {
      const content = '```mermaid\ngraph TD\n  A --> B\n```';
      final result = await ExportService.exportToWord(content);
      expect(result.isNotEmpty, true);
    });
  });

  String _decodeTxt(Uint8List bytes) => utf8.decode(bytes);

  group('ExportService.exportToTxt', () {
    test('空内容返回空字节数组', () async {
      final result = await ExportService.exportToTxt('');
      expect(result.isEmpty, true);
    });

    test('纯文本内容成功导出', () async {
      const content = 'Hello World';
      final result = await ExportService.exportToTxt(content);
      final text = _decodeTxt(result);
      expect(text.contains('Hello World'), true);
    });

    test('标题带#前缀和空格分隔', () async {
      const content = '# 主标题\n## 副标题';
      final result = await ExportService.exportToTxt(content);
      final text = _decodeTxt(result);
      expect(text.contains('# 主标题'), true);
      expect(text.contains('## 副标题'), true);
    });

    test('列表项带•前缀', () async {
      const content = '- 项目一\n- 项目二';
      final result = await ExportService.exportToTxt(content);
      final text = _decodeTxt(result);
      expect(text.contains('• 项目一'), true);
    });

    test('引用块带>前缀', () async {
      const content = '> 引用内容';
      final result = await ExportService.exportToTxt(content);
      final text = _decodeTxt(result);
      expect(text.contains('> 引用内容'), true);
    });

    test('代码块保留语法标记', () async {
      const content = '```python\ndef foo():\n    pass\n```';
      final result = await ExportService.exportToTxt(content);
      final text = _decodeTxt(result);
      expect(text.contains('```python'), true);
      expect(text.contains('def foo():'), true);
    });

    test('Mermaid块保留语法', () async {
      const content = '```mermaid\ngraph TD\n  A --> B\n```';
      final result = await ExportService.exportToTxt(content);
      final text = _decodeTxt(result);
      expect(text.contains('```mermaid'), true);
      expect(text.contains('A --> B'), true);
    });

    test('中文字符正确UTF-8编码', () async {
      const content = '这是中文内容';
      final result = await ExportService.exportToTxt(content);
      final text = _decodeTxt(result);
      expect(text, '这是中文内容');
    });
  });

  group('MarkdownParser.parse', () {
    test('heading解析level正确', () {
      final elements = MarkdownParser.parse('# 标题');
      expect(elements.length, 1);
      expect(elements[0], isA<HeadingElement>());
      expect((elements[0] as HeadingElement).level, 1);
      expect((elements[0] as HeadingElement).text, '标题');
    });

    test('多级heading解析', () {
      final elements = MarkdownParser.parse('## 二级\n### 三级');
      expect(elements.length, 2);
      expect((elements[0] as HeadingElement).level, 2);
      expect((elements[1] as HeadingElement).level, 3);
    });

    test('空内容返回空列表', () {
      final elements = MarkdownParser.parse('');
      expect(elements.isEmpty, true);
    });

    test('纯空白返回EmptyLineElement列表', () {
      final elements = MarkdownParser.parse('   \n   \n   ');
      expect(elements.isNotEmpty, true);
      expect(elements.every((e) => e is EmptyLineElement), true);
    });

    test('代码块多行合并为单个元素', () {
      final elements = MarkdownParser.parse('```python\nline1\nline2\nline3\n```');
      final codeBlocks = elements.whereType<CodeElement>().toList();
      expect(codeBlocks.length, 1);
      expect(codeBlocks[0].code.contains('line1'), true);
      expect(codeBlocks[0].code.contains('line2'), true);
      expect(codeBlocks[0].code.contains('line3'), true);
    });

    test('Mermaid代码块正确识别', () {
      final elements = MarkdownParser.parse('```mermaid\ngraph TD\n  A --> B\n```');
      final mermaidBlocks = elements.whereType<MermaidElement>().toList();
      expect(mermaidBlocks.length, 1);
      expect(mermaidBlocks[0].code.contains('A --> B'), true);
    });
  });
}
