import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:formula_fix/core/parser/markdown_parser.dart';
import 'package:formula_fix/domain/services/export_service.dart';
import 'package:formula_fix/data/models/document.dart';

void main() {
  group('ExportService 集成测试', () {
    group('PDF 导出', () {
      test('导出简单文本', () async {
        const markdown = '# 标题\n\n这是一段文本。';
        final pdfBytes = await ExportService.exportToPdf(markdown);
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
        final pdfBytes = await ExportService.exportToPdf(markdown);
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
        final pdfBytes = await ExportService.exportToPdf(markdown);
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
        final pdfBytes = await ExportService.exportToPdf(markdown);
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
        final pdfBytes = await ExportService.exportToPdf(markdown);
        expect(pdfBytes.isNotEmpty, true);
        expect(_isPdf(pdfBytes), true);
      });

      test('导出包含引用的文档', () async {
        const markdown = '''
# 名言

> 人生苦短，我用 Python
> —— 某位程序员
''';
        final pdfBytes = await ExportService.exportToPdf(markdown);
        expect(pdfBytes.isNotEmpty, true);
        expect(_isPdf(pdfBytes), true);
      });

      test('导出空文档应抛出异常', () async {
        expect(
          () => ExportService.exportToPdf(''),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('Word 导出', () {
      test('导出简单文本到 Word', () async {
        const markdown = '# 标题\n\n这是一段文本。';
        final wordBytes = await ExportService.exportToWord(markdown);
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
        final wordBytes = await ExportService.exportToWord(markdown);
        expect(wordBytes.isNotEmpty, true);
        expect(_isZip(wordBytes), true);
        expect(_hasDocxStructure(wordBytes), true);
      });

      test('导出空文档应抛出异常', () async {
        expect(
          () => ExportService.exportToWord(''),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('Text 导出', () {
      test('导出纯文本', () async {
        const markdown = '# 标题\n\n这是一段文本。';
        final txtBytes = await ExportService.exportToTxt(markdown);
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
        final txtBytes = await ExportService.exportToTxt(markdown);
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

        final pdfBytes = await ExportService.exportToPdf(mathDoc);
        expect(pdfBytes.isNotEmpty, true);

        final wordBytes = await ExportService.exportToWord(mathDoc);
        expect(wordBytes.isNotEmpty, true);

        final txtBytes = await ExportService.exportToTxt(mathDoc);
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

        final pdfBytes = await ExportService.exportToPdf(diagramDoc);
        expect(pdfBytes.isNotEmpty, true);
      });
    });

    group('性能基准测试', () {
      test('大文档 PDF 导出性能', () async {
        final largeDoc = _generateLargeDocument();
        final stopwatch = Stopwatch()..start();
        final pdfBytes = await ExportService.exportToPdf(largeDoc);
        stopwatch.stop();
        expect(pdfBytes.isNotEmpty, true);
        print('大文档导出耗时: ${stopwatch.elapsedMilliseconds}ms');
        expect(stopwatch.elapsedMilliseconds, lessThan(5000));
      });
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
