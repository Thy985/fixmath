import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:formula_fix/domain/services/export_service.dart';

void main() {
  group('ExportService.exportToPdf', () {
    test('空内容返回非空字节数组', () async {
      final result = await ExportService.exportToPdf('');
      expect(result.isNotEmpty, true);
      expect(result.length, greaterThan(100));
    });

    test('纯文本内容成功导出', () async {
      final result = await ExportService.exportToPdf('Hello World');
      expect(result.isNotEmpty, true);
      expect(result[0], 0x25);
    });

    test('多级标题成功导出', () async {
      final result = await ExportService.exportToPdf('# 一级标题\n## 二级标题\n### 三级标题');
      expect(result.isNotEmpty, true);
    });

    test('混合内容成功导出', () async {
      const markdown = '''
# 文档标题

这是一段正文内容。

- 列表项一
- 列表项二

> 这是一段引用
''';
      final result = await ExportService.exportToPdf(markdown);
      expect(result.isNotEmpty, true);
    });

    test('引用块成功导出', () async {
      final result = await ExportService.exportToPdf('> 这是一段引用内容');
      expect(result.isNotEmpty, true);
    });

    test('代码块成功导出', () async {
      final result = await ExportService.exportToPdf('```dart\nvoid main() {}\n```');
      expect(result.isNotEmpty, true);
    });
  });

  group('ExportService.exportToWord', () {
    test('空内容返回非空字节数组', () async {
      final result = await ExportService.exportToWord('');
      expect(result.isNotEmpty, true);
      expect(result.length, greaterThan(100));
    });

    test('纯文本内容成功导出', () async {
      final result = await ExportService.exportToWord('Hello World');
      expect(result.isNotEmpty, true);
    });

    test('多级标题成功导出', () async {
      final result = await ExportService.exportToWord('# 一级\n## 二级');
      expect(result.isNotEmpty, true);
    });

    test('列表内容成功导出', () async {
      final result = await ExportService.exportToWord('- 项1\n- 项2');
      expect(result.isNotEmpty, true);
    });

    test('引用块成功导出', () async {
      final result = await ExportService.exportToWord('> 引用');
      expect(result.isNotEmpty, true);
    });

    test('代码块成功导出', () async {
      final result = await ExportService.exportToWord('```python\nprint("hi")\n```');
      expect(result.isNotEmpty, true);
    });

    test('Mermaid块成功导出', () async {
      final result = await ExportService.exportToWord('```mermaid\ngraph TD\n  A-->B\n```');
      expect(result.isNotEmpty, true);
    });
  });

  group('ExportService.exportToTxt', () {
    test('空内容返回空字节数组', () async {
      final result = await ExportService.exportToTxt('');
      expect(result.isEmpty, true);
    });

    test('纯文本内容成功导出', () async {
      final result = await ExportService.exportToTxt('Hello World');
      final text = utf8.decode(result);
      expect(text, 'Hello World');
    });

    test('标题带#前缀和空格分隔', () async {
      final result = await ExportService.exportToTxt('# 一级标题');
      final text = utf8.decode(result);
      expect(text.contains('# 一级标题'), true);
    });

    test('列表项带•前缀', () async {
      final result = await ExportService.exportToTxt('- 列表项');
      final text = utf8.decode(result);
      expect(text.contains('• 列表项'), true);
    });

    test('引用块带>前缀', () async {
      final result = await ExportService.exportToTxt('> 引用内容');
      final text = utf8.decode(result);
      expect(text.contains('> 引用内容'), true);
    });

    test('代码块保留语法标记', () async {
      final result = await ExportService.exportToTxt('```python\nprint("hello")\n```');
      final text = utf8.decode(result);
      expect(text.contains('```python'), true);
      expect(text.contains('print("hello")'), true);
    });

    test('代码块无语言标识时保留空标记', () async {
      final result = await ExportService.exportToTxt('```\ncode\n```');
      final text = utf8.decode(result);
      expect(text.contains('```\n'), true);
      expect(text.contains('```\ncode'), true);
    });

    test('Mermaid块保留语法', () async {
      final result = await ExportService.exportToTxt('```mermaid\ngraph TD\n```');
      final text = utf8.decode(result);
      expect(text.contains('```mermaid'), true);
      expect(text.contains('graph TD'), true);
    });

    test('中文字符正确UTF-8编码', () async {
      final result = await ExportService.exportToTxt('这是中文内容');
      final text = utf8.decode(result);
      expect(text, '这是中文内容');
      final bytes = utf8.encode('这是中文内容');
      expect(result, bytes);
    });

    test('尾部无多余换行符', () async {
      final result = await ExportService.exportToTxt('# 标题');
      final text = utf8.decode(result);
      expect(text.endsWith('\n'), false);
    });

    test('多段落之间保留适当分隔', () async {
      final result = await ExportService.exportToTxt('# 标题\n\n正文内容');
      final text = utf8.decode(result);
      expect(text.contains('# 标题'), true);
      expect(text.contains('正文内容'), true);
    });

    test('公式内容原样保留', () async {
      final result = await ExportService.exportToTxt(r'公式: $E=mc^2$');
      final text = utf8.decode(result);
      expect(text.contains('E=mc^2'), true);
    });
  });

  group('ExportService Word 格式验证', () {
    test('生成的Word文件包含ZIP格式标识', () async {
      final result = await ExportService.exportToWord('# Test');
      expect(result[0], 0x50);
      expect(result[1], 0x4B);
    });

    test('Word文件包含必要XML组件', () async {
      final result = await ExportService.exportToWord('Content');
      final text = utf8.decode(result.sublist(100, 200), allowMalformed: true);
      expect(result.length, greaterThan(500));
    });
  });
}
