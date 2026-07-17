# ADR-0004: Markdown 解析器扩展策略

- **状态**：Proposed（Phase 1 P0 #5 执行）
- **生效日期**：待 Phase 1 P0 #5 启动时 Accept
- **决策者**：首席架构工程师

## 背景

代码分析发现 [core/parser/markdown_parser.dart](file:///d:/Projects/Active/math/flutter_app/lib/core/parser/markdown_parser.dart) 存在严重缺陷：

### 缺失的 Markdown 元素

| 元素 | 语法 | 解析器是否支持 | 工具栏是否插入 |
|------|------|--------------|--------------|
| 加粗 | `**bold**` | ✅ | ✅ |
| 斜体 | `*italic*` / `_italic_` | ❌ | ✅（工具栏可插入但解析器不识别） |
| 行内代码 | `` `code` `` | ❌ | ✅（同上） |
| 删除线 | `~~del~~` | ❌ | ✅（同上） |
| 链接 | `[text](url)` | ❌ | ✅（同上） |
| 图片 | `![alt](url)` | ❌ | ❌（工具栏也没有） |
| 任务列表 | `- [ ]` / `- [x]` | ❌ | ❌ |
| 引用链接 | `[ref]` + `[ref]: url` | ❌ | ❌ |
| HTML 行内 | `<br>` `<sub>` | ❌ | ❌ |
| 脚注 | `[^1]` | ❌ | ❌ |

### 现有解析器结构

```dart
class MarkdownParser {
  static List<DocumentElement> parse(String content) {
    // 行解析：标题 / 列表 / 代码块 / 引用 / 表格 / Mermaid / 空行
  }
  
  static List<InlineElement> parseInline(String text) {
    // 公式提取 + 加粗
    final formulas = FormulaExtractor.extractFormulas(text);
    // 在公式之间填充 _parseBoldAndItalic 的结果
  }
  
  static List<InlineElement> _parseBoldAndItalic(String text) {
    // ❌ 实际只识别 **bold**，不识别 *italic* / _italic_ / `code` / ~~del~~ / [link]()
  }
}
```

### AST 结构

```dart
sealed class InlineElement {
  const InlineElement();
}

class TextElement extends InlineElement { ... }
class FormulaElement extends InlineElement { ... }
class BoldElement extends InlineElement { ... }
// ❌ 缺 InlineCode / Link / Image / Italic / Strikethrough
```

## 决策

**采用扩展策略，而非重写。**

### 1. AST 扩展（只新增不修改）

在 [data/models/document.dart](file:///d:/Projects/Active/math/flutter_app/lib/data/models/document.dart) 新增子类：

```dart
sealed class InlineElement {
  const InlineElement();
}

// 现有（保持不变）
class TextElement extends InlineElement { ... }
class FormulaElement extends InlineElement { ... }
class BoldElement extends InlineElement { ... }

// 新增
class ItalicElement extends InlineElement {
  final List<InlineElement> children;
  const ItalicElement({required this.children});
}

class StrikethroughElement extends InlineElement {
  final List<InlineElement> children;
  const StrikethroughElement({required this.children});
}

class InlineCodeElement extends InlineElement {
  final String code;
  const InlineCodeElement(this.code);
}

class LinkElement extends InlineElement {
  final String text;
  final String url;
  const LinkElement({required this.text, required this.url});
}

class ImageElement extends InlineElement {
  final String alt;
  final String url;
  const ImageElement({required this.alt, required this.url});
}
```

### 2. 块级 AST 扩展

```dart
// 新增 BlockElement 子类
class TaskListItemElement extends DocumentElement {
  final List<InlineElement> children;
  final bool checked;
  final int indent;
  const TaskListItemElement({required this.children, required this.checked, this.indent = 0});
}

class HorizontalRuleElement extends DocumentElement {
  const HorizontalRuleElement();
}
```

### 3. 解析器增量修改

修改 `_parseBoldAndItalic` 为 `_parseInlineStyle`，按优先级匹配：

```
优先级（先匹配先返回）：
1. 图片 ![alt](url)       —— 先于链接，避免被链接规则吃掉 ! 前缀
2. 链接 [text](url)
3. 行内代码 `code`         —— 先于其他 * 包裹，避免 *xxx`yyy*zz` 被错切
4. 加粗 **text**           —— 先于斜体，避免 ** 被 * 截断
5. 斜体 *text* / _text_
6. 删除线 ~~text~~
7. 剩余纯文本
```

### 4. 优先级解析实现思路

不引入第三方 Markdown 解析库（如 `markdown` / `marked`），保留现有自研解析器：

- 理由 1：现有解析器与 PDF/Word 导出器紧密耦合，换库会破坏导出
- 理由 2：自研解析器可精确控制 AST 形态
- 理由 3：未来 WYSIWYG 块级渲染需要自定义 AST

### 5. 测试驱动

每新增一种元素必须配 3+ 测试用例：

- 基本语法
- 嵌套（如 `**bold *italic* text**`）
- 边界（空 `**`、未闭合 `**unclosed`）

## 动机

### 选择扩展而非重写的理由

1. **现有解析器结构合理**：行级 / inline 分层清晰，扩展不破坏架构
2. **AST 是 sealed class**：Dart 3 编译器会强制覆盖所有 case，新增子类时编译报错指引修复
3. **导出器复用**：现有 PDF/Word/TXT 导出器都基于 AST，新增子类时按编译错误同步修改即可
4. **风险可控**：扩展是加法，不删现有分支；如果某个新元素解析有 bug，不影响现有元素

### 否决重写的理由

#### 方案 A：用 `package:markdown` 替换

**否决理由**：
- `markdown` 库的 AST（`Node` 体系）与现有 `DocumentElement` 不兼容
- 导出器需要全面重写
- WYSIWYG 重构（Phase 2）需要更细粒度的 AST 控制

#### 方案 B：用 `package:markdown` + 适配层

**否决理由**：
- 适配层增加复杂度
- 适配层会成为性能瓶颈（双 AST 转换）

### 选择自研解析器的额外考虑

- **公式优先**：现有 `FormulaExtractor` 已正确处理 `$...$` / `$$...$$`，与 Markdown 标准不冲突但需要特殊优先级（公式内不解析 Markdown）
- **Mermaid 优先**：` ```mermaid ` 代码块需要识别为 `MermaidElement`，不是普通代码块
- **自定义渲染**：未来 WYSIWYG 需要光标态 / 非光标态切换，需要可定制的 AST

## 后果

### 正面

- 现有代码不破坏
- 新增元素按需引入，可分多个 PR
- 与导出器同步修改由编译器强制

### 负面

- 自研解析器需要持续维护
- 边界情况（嵌套、未闭合）需大量测试
- 长期看可能不如成熟库稳定

### 风险与缓解

| 风险 | 缓解 |
|------|------|
| 优先级解析 bug（如 `*` 在公式内） | 公式提取优先，文本部分才走 inline 解析（现有逻辑已如此） |
| 嵌套解析死循环 | 限制嵌套深度（如 ≤ 5 层） |
| 性能（正则回溯爆炸） | 限制单行长度（如 ≤ 10000 字符），超长降级为纯文本 |
| 与导出器不一致 | sealed class 编译期检查 + 同步 PR |

## 实施计划

### Phase 1 P0 #5（本 ADR 对应任务）

按优先级分批实现：

1. **批次 1**（最小可用）：行内代码、链接、斜体、删除线
2. **批次 2**：图片、任务列表
3. **批次 3**（可选）：引用链接、HTML 行内、脚注

每批一个 PR，配测试。

### Phase 2 WYSIWYG 重构时

- 评估是否拆分块级解析器与 inline 解析器为独立类
- 评估是否引入增量解析（只重解析光标所在块）

## 替代方案再次评估

如果未来发现自研解析器维护成本过高：

- **Plan B**：用 `package:markdown` 做 token 化，再用适配层转 AST
- **Plan C**：用 `unified` 风格的 plugin 系统（dart 暂无成熟方案）

## 参考

- [markdown_parser.dart](file:///d:/Projects/Active/math/flutter_app/lib/core/parser/markdown_parser.dart)
- [data/models/document.dart](file:///d:/Projects/Active/math/flutter_app/lib/data/models/document.dart)
- [CRITICAL_REVIEW.md §3.1](file:///d:/Projects/Active/math/docs/CRITICAL_REVIEW.md) 解析器缺失元素
- [ROADMAP.md](file:///d:/Projects/Active/math/docs/ROADMAP.md) Phase 1 P0 #5
