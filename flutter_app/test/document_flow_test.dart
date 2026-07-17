import 'package:flutter_test/flutter_test.dart';
import 'package:formula_fix/core/parser/markdown_parser.dart';
import 'package:formula_fix/data/models/document.dart';

void main() {
  group('文档解析流程集成测试', () {
    test('完整文档解析流程', () {
      const markdown = '''
# 项目报告

## 概述

这是一个包含多种 Markdown 元素的测试文档。

## 功能列表

### 核心功能

- 用户管理
- 权限控制
- 数据分析

### 扩展功能

1. 报表导出
2. 数据导入
3. 批量处理

## 数据表格

| 模块 | 功能 | 状态 |
| --- | --- | --- |
| 用户模块 | 注册登录 | 完成 |
| 内容模块 | 发布管理 | 完成 |
| 分析模块 | 数据统计 | 进行中 |

## 代码示例

```javascript
const express = require('express');
const app = express();

app.get('/api/users', (req, res) => {
  res.json({ users: [] });
});

app.listen(3000);
```

## 引用

> 代码是最好的文档。

## Mermaid 图表

```mermaid
sequenceDiagram
    participant U as 用户
    participant S as 服务器
    participant DB as 数据库
    
    U->>S: 发送请求
    S->>DB: 查询数据
    DB-->>S: 返回结果
    S-->>U: 响应数据
```
''';

      final elements = MarkdownParser.parse(markdown);

      expect(elements.isNotEmpty, true);

      final headings = elements.whereType<HeadingElement>().toList();
      expect(headings.length, greaterThanOrEqualTo(5));
      expect(headings[0].level, 1);
      expect(headings[0].text, '项目报告');

      final lists = elements.whereType<ListElement>().toList();
      expect(lists.length, greaterThanOrEqualTo(2));

      final tables = elements.whereType<TableElement>().toList();
      expect(tables.length, 1);
      expect(tables[0].headers.length, 3);
      expect(tables[0].rows.length, 3);

      final codeBlocks = elements.whereType<CodeElement>().toList();
      expect(codeBlocks.length, 1);
      expect(codeBlocks[0].language, 'javascript');

      final mermaidBlocks = elements.whereType<MermaidElement>().toList();
      expect(mermaidBlocks.length, 1);

      final blockquotes = elements.whereType<BlockquoteElement>().toList();
      expect(blockquotes.length, 1);
    });

    test('嵌套列表解析', () {
      const markdown = '''
# 嵌套列表测试

- 顶级 1
  - 二级 1.1
  - 二级 1.2
    - 三级 1.2.1
- 顶级 2

1. 有序 1
   1. 有序 1.1
   2. 有序 1.2
2. 有序 2
''';

      final elements = MarkdownParser.parse(markdown);
      final lists = elements.whereType<ListElement>().toList();

      expect(lists.length, greaterThanOrEqualTo(2));
      expect(lists[0].indent, greaterThanOrEqualTo(0));
      expect(lists[1].indent, greaterThanOrEqualTo(0));
    });

    test('混合公式和文本', () {
      const markdown = r'''
行内公式: $x^2 + y^2 = r^2$

多行公式:
$$
\int_0^\infty e^{-x^2} dx = \frac{\sqrt{\pi}}{2}
$$

混合: 欧拉公式 $e^{i\pi} + 1 = 0$ 是数学中最美的公式。
''';

      final elements = MarkdownParser.parse(markdown);
      final paragraphs = elements.whereType<ParagraphElement>().toList();

      expect(paragraphs.isNotEmpty, true);
    });

    test('表格连续行', () {
      const markdown = '''
# 表格测试

| A | B | C |
| - | - | - |
| 1 | 2 | 3 |
| 4 | 5 | 6 |
| 7 | 8 | 9 |
''';

      final elements = MarkdownParser.parse(markdown);
      final tables = elements.whereType<TableElement>().toList();

      expect(tables.length, 1);
      expect(tables[0].rows.length, 3);
      expect(tables[0].rows[2], ['7', '8', '9']);
    });

    test('代码块边界情况', () {
      const markdown = '''
开始

```python
print("第一个代码块")
```

中间文本

```python
print("第二个代码块")
```

结束
''';

      final elements = MarkdownParser.parse(markdown);
      final codeBlocks = elements.whereType<CodeElement>().toList();

      expect(codeBlocks.length, 2);
      expect(codeBlocks[0].code, contains('第一个'));
      expect(codeBlocks[1].code, contains('第二个'));
    });

    test('转义字符处理', () {
      const markdown = r'''
价格: \$100
转义: \\n
混合: $x$ 和 \$y$
''';

      final elements = MarkdownParser.parse(markdown);
      expect(elements.isNotEmpty, true);
    });

    test('空文档', () {
      expect(MarkdownParser.parse(''), isEmpty);
    });

    test('仅标题文档', () {
      const markdown = '''
# 标题1
## 标题2
### 标题3
#### 标题4
##### 标题5
###### 标题6
''';

      final elements = MarkdownParser.parse(markdown);
      final headings = elements.whereType<HeadingElement>().toList();
      expect(headings.length, 6);

      for (int i = 0; i < 6; i++) {
        expect(headings[i].level, i + 1);
      }
    });
  });

  group('Document 模型测试', () {
    test('Document 创建和复制', () {
      final doc = Document(
        id: '1',
        title: '测试文档',
        content: '# 测试',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 2),
      );

      expect(doc.id, '1');
      expect(doc.title, '测试文档');

      final updated = doc.copyWith(title: '更新后的标题');
      expect(updated.title, '更新后的标题');
      expect(updated.id, '1');
      expect(updated.content, '# 测试');
    });

    test('DocumentElement 类型检查', () {
      const heading = HeadingElement(level: 1, text: '标题');
      const paragraph = ParagraphElement(children: []);
      const list = ListElement(children: [TextElement('列表项')]);
      const code = CodeElement(code: 'code');
      const table = TableElement(headers: ['A'], rows: []);
      const blockquote = BlockquoteElement(text: '引用');
      const mermaid = MermaidElement(code: 'graph TD');
      const empty = EmptyLineElement();

      expect(heading, isA<DocumentElement>());
      expect(paragraph, isA<DocumentElement>());
      expect(list, isA<DocumentElement>());
      expect(code, isA<DocumentElement>());
      expect(table, isA<DocumentElement>());
      expect(blockquote, isA<DocumentElement>());
      expect(mermaid, isA<DocumentElement>());
      expect(empty, isA<DocumentElement>());
    });

    test('InlineElement 类型检查', () {
      const text = TextElement('普通文本');
      const formula = FormulaElement(latex: 'x^2', displayMode: false);

      expect(text, isA<InlineElement>());
      expect(formula, isA<InlineElement>());
    });

    test('FormulaElement 属性', () {
      const inlineFormula = FormulaElement(latex: 'x^2', displayMode: false);
      const blockFormula = FormulaElement(latex: r'\int_0^1 x dx', displayMode: true);

      expect(inlineFormula.displayMode, false);
      expect(blockFormula.displayMode, true);
      expect(inlineFormula.latex, 'x^2');
      expect(blockFormula.latex, r'\int_0^1 x dx');
    });

    test('ListElement 属性', () {
      const unorderedList = ListElement(children: [TextElement('item')], ordered: false);
      const orderedList = ListElement(children: [TextElement('item')], ordered: true);
      const nestedList = ListElement(children: [TextElement('nested')], indent: 2, ordered: false);

      expect(unorderedList.ordered, false);
      expect(orderedList.ordered, true);
      expect(nestedList.indent, 2);
    });

    test('TableElement 结构', () {
      final table = TableElement(
        headers: ['列1', '列2', '列3'],
        rows: [
          ['a', 'b', 'c'],
          ['d', 'e', 'f'],
        ],
      );

      expect(table.headers.length, 3);
      expect(table.rows.length, 2);
      expect(table.rows[0], ['a', 'b', 'c']);
      expect(table.rows[1], ['d', 'e', 'f']);
    });
  });
}
