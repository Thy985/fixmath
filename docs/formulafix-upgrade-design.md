# FormulaFix 渐进式重构升级设计文档

> **版本**: v1.0  
> **日期**: 2026-06-16  
> **状态**: 待审阅  
> **目标**: 全面升级 Markdown 渲染、公式渲染、导出功能，对齐 Typora/Obsidian 核心体验

---

## 目录

1. [项目现状分析](#1-项目现状分析)
2. [升级目标与范围](#2-升级目标与范围)
3. [整体架构设计](#3-整体架构设计)
4. [阶段一：Markdown 解析器升级](#4-阶段一markdown-解析器升级)
5. [阶段二：公式渲染引擎替换](#5-阶段二公式渲染引擎替换)
6. [阶段三：实时预览编辑模式](#6-阶段三实时预览编辑模式)
7. [阶段四：导出架构统一](#7-阶段四导出架构统一)
8. [阶段五：功能补齐与体验优化](#8-阶段五功能补齐与体验优化)
9. [技术选型对比](#9-技术选型对比)
10. [风险评估与缓解策略](#10-风险评估与缓解策略)
11. [实施路线图](#11-实施路线图)
12. [测试策略](#12-测试策略)
13. [附录：现有代码问题分析](#13-附录现有代码问题分析)

---

## 1. 项目现状分析

### 1.1 技术栈

| 组件 | 当前技术 | 版本 |
|------|---------|------|
| 框架 | Flutter | SDK >=3.0.0 |
| 状态管理 | flutter_riverpod | ^2.6.1 |
| Markdown 渲染 | flutter_markdown | ^0.7.4+3 |
| 公式渲染（预览） | flutter_math_fork | ^0.7.2 |
| 公式渲染（SVG） | MathJax via WebView | flutter_inappwebview ^6.1.5 |
| PDF 导出 | pdf + printing | ^3.11.1 / ^5.13.3 |
| Word 导出 | archive (手动 OOXML) | ^3.6.1 |
| Mermaid 图表 | Mermaid.js via WebView | 共享 WebView |

### 1.2 架构现状

```
┌─────────────────────────────────────────────────────┐
│                    EditorScreen                      │
│  ┌──────────────┐  ┌──────────────────────────────┐ │
│  │ MarkdownInput │  │     PreviewContent           │ │
│  │   (编辑模式)   │  │  ┌────────────────────────┐  │ │
│  │              │  │  │  HeadingRenderer         │  │ │
│  │              │  │  │  ParagraphRenderer       │  │ │
│  │              │  │  │  ListRenderer            │  │ │
│  │              │  │  │  CodeRenderer            │  │ │
│  │              │  │  │  TableRenderer           │  │ │
│  │              │  │  │  BlockquoteRenderer      │  │ │
│  │              │  │  │  MermaidElementWidget    │  │ │
│  │              │  │  └────────────────────────┘  │ │
│  └──────────────┘  └──────────────────────────────┘ │
│                                                      │
│  ┌─────────────────────────────────────────────────┐ │
│  │              核心服务层                           │ │
│  │  MarkdownParser (手动解析, 309行)                │ │
│  │  FormulaExtractor (正则提取, 277行)              │ │
│  │  FormulaSvgService (MathJax WebView, 332行)     │ │
│  │  FormulaPdfRenderer (离屏渲染, 400行)            │ │
│  │  MermaidService (Mermaid WebView, 530行)        │ │
│  └─────────────────────────────────────────────────┘ │
│                                                      │
│  ┌─────────────────────────────────────────────────┐ │
│  │              导出层                               │ │
│  │  PdfExporter (541行)  WordExporter (246行)       │ │
│  │  TextExporter         WordOoxmlBuilder (498行)   │ │
│  │  WordOoxmlTemplates (368行)                      │ │
│  └─────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────┘
```

### 1.3 核心问题

| 问题类别 | 具体问题 | 影响 |
|---------|---------|------|
| **解析器** | 手动实现逐行解析，状态机复杂 | 不支持 GFM 扩展，难以维护 |
| **公式** | MathJax WebView 通信协议复杂 | 首次渲染 300-500ms，内存占用高 |
| **导出** | 每种格式独立实现，代码重复 | 新增格式成本高，样式不可定制 |
| **编辑** | 编辑/预览完全分离 | 无法实时看到渲染效果 |
| **模型** | DocumentElement 类型有限 | 缺少脚注、任务列表、高亮等 |

---

## 2. 升级目标与范围

### 2.1 升级目标

| 维度 | 目标 | 衡量标准 |
|------|------|---------|
| **Markdown 渲染** | 支持 GFM 完整语法 | 通过 CommonMark + GFM 测试套件 |
| **公式渲染** | 本地渲染，毫秒级响应 | 首次渲染 <50ms，后续 <20ms |
| **导出功能** | 统一 AST 架构，支持更多格式 | 新增 HTML/Markdown 导出 |
| **编辑体验** | 实时预览模式 | 输入即渲染，无模式切换 |
| **性能** | 降低内存占用，提升渲染速度 | 内存峰值降低 50%+ |

### 2.2 范围约束

- **平台**: 仅移动端（iOS + Android）
- **架构**: 保持 Flutter 原生架构，不引入 Web 框架
- **兼容性**: 保持现有文档格式兼容
- **渐进性**: 分阶段实施，每阶段可独立发布

---

## 3. 整体架构设计

### 3.1 目标架构

```
┌─────────────────────────────────────────────────────────┐
│                      EditorScreen                        │
│  ┌───────────────────────────────────────────────────┐  │
│  │           LivePreviewEditor (实时预览)              │  │
│  │  ┌─────────────┐  ┌────────────────────────────┐  │  │
│  │  │  源码输入区   │  │    实时渲染预览区            │  │  │
│  │  │  (可选隐藏)   │  │    (AST → Widget)          │  │  │
│  │  └─────────────┘  └────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────┘  │
│                                                          │
│  ┌─────────────────────────────────────────────────────┐│
│  │              核心层：统一 AST                          ││
│  │                                                      ││
│  │  ┌──────────┐    ┌──────────┐    ┌──────────────┐  ││
│  │  │ Markdown  │───▶│   AST    │───▶│  Widget      │  ││
│  │  │ Parser    │    │ (中间层)  │    │  Renderer    │  ││
│  │  └──────────┘    └──────────┘    └──────────────┘  ││
│  │       │                │                │           ││
│  │       │                │         ┌──────┴──────┐   ││
│  │       │                │         │             │   ││
│  │       │                ▼         ▼             ▼   ││
│  │       │         ┌──────────┐ ┌────────┐ ┌────────┐ ││
│  │       │         │   PDF    │ │  Word  │ │  HTML  │ ││
│  │       │         │ Exporter │ │Exporter│ │Exporter│ ││
│  │       │         └──────────┘ └────────┘ └────────┘ ││
│  │       │                                             ││
│  │  ┌────┴─────────────────────────────────────────┐  ││
│  │  │           插件式语法扩展                        │  ││
│  │  │  ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ │  ││
│  │  │  │  Math  │ │Mermaid │ │  GFM   │ │ Custom │ │  ││
│  │  │  │Extension│ │Extension│ │Extension│ │Extension│ │  ││
│  │  │  └────────┘ └────────┘ └────────┘ └────────┘ │  ││
│  │  └───────────────────────────────────────────────┘  ││
│  └─────────────────────────────────────────────────────┘│
│                                                          │
│  ┌─────────────────────────────────────────────────────┐│
│  │              渲染引擎层                               ││
│  │                                                      ││
│  │  ┌──────────┐  ┌──────────┐  ┌──────────────────┐  ││
│  │  │  KaTeX   │  │ Mermaid  │  │  Code Highlight  │  ││
│  │  │ (本地)    │  │(WebView) │  │  (highlight.js)  │  ││
│  │  └──────────┘  └──────────┘  └──────────────────┘  ││
│  └─────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────┘
```

### 3.2 核心设计原则

1. **AST 中心化**: 所有功能围绕统一的抽象语法树（AST）构建
2. **插件式扩展**: 语法规则可通过插件注册，不修改核心解析器
3. **渲染分离**: 解析与渲染解耦，同一 AST 可输出到不同目标
4. **渐进迁移**: 新旧系统可并存，逐步替换

### 3.3 目录结构规划

```
lib/
├── core/
│   ├── ast/                          # 新增：统一 AST 定义
│   │   ├── ast_node.dart             # AST 节点基类
│   │   ├── block_nodes.dart          # 块级节点（段落、标题、列表等）
│   │   ├── inline_nodes.dart         # 内联节点（文本、公式、链接等）
│   │   └── ast_visitor.dart          # AST 访问者模式
│   │
│   ├── parser/                       # 重构：Markdown 解析器
│   │   ├── markdown_parser.dart      # 基于 markdown 包的解析器
│   │   ├── formula_syntax.dart       # 公式语法扩展插件
│   │   ├── mermaid_syntax.dart       # Mermaid 语法扩展插件
│   │   ├── gfm_extensions.dart       # GFM 扩展（任务列表、脚注等）
│   │   └── syntax_registry.dart      # 语法插件注册中心
│   │
│   ├── renderer/                     # 新增：渲染器层
│   │   ├── widget_renderer.dart      # AST → Flutter Widget
│   │   ├── formula_renderer.dart     # 公式渲染统一接口
│   │   ├── katex_formula.dart        # KaTeX 本地渲染
│   │   ├── code_highlighter.dart     # 代码语法高亮
│   │   └── mermaid_renderer.dart     # Mermaid 渲染
│   │
│   └── services/                     # 保留/优化
│       ├── mermaid_service.dart      # 优化：Mermaid WebView 服务
│       └── (formula_svg_service.dart 被替换)
│       └── (formula_pdf_renderer.dart 被替换)
│
├── domain/
│   ├── exporters/                    # 重构：统一导出架构
│   │   ├── export_pipeline.dart      # 导出管线（AST → 目标格式）
│   │   ├── pdf_exporter.dart         # 基于 AST 的 PDF 导出
│   │   ├── word_exporter.dart        # 基于 AST 的 Word 导出
│   │   ├── html_exporter.dart        # 新增：HTML 导出
│   │   ├── markdown_exporter.dart    # 新增：Markdown 导出（AST → MD）
│   │   └── text_exporter.dart        # 纯文本导出
│   │
│   └── services/
│       └── export_service.dart       # 导出 facade（保持兼容）
│
├── presentation/
│   ├── editor/                       # 新增：编辑器模块
│   │   ├── live_preview_editor.dart  # 实时预览编辑器
│   │   ├── editor_controller.dart    # 编辑器控制器
│   │   ├── syntax_highlighter.dart   # 编辑器内语法高亮
│   │   └── toolbar/                  # 工具栏（公式插入、表格等）
│   │
│   └── widgets/                      # 重构：渲染组件
│       ├── block_renderers/          # 块级元素渲染器
│       ├── inline_renderers/         # 内联元素渲染器
│       └── (现有 renderer 迁移至此)
│
└── data/
    └── models/
        └── document.dart             # 扩展：新增 AST 节点类型
```

---

## 4. 阶段一：Markdown 解析器升级

### 4.1 问题诊断

**现有 `MarkdownParser`（309 行）的问题：**

1. **手动状态机**: 逐行解析，用 `inCodeBlock`、`pendingParagraph` 等状态变量跟踪上下文，容易出错
2. **嵌套列表处理混乱**: L135-161 的缩进合并逻辑复杂且有 bug
3. **不支持 GFM 扩展**: 无任务列表（`- [ ]`）、脚注（`[^1]`）、高亮（`==text==`）、定义列表
4. **内联解析不完整**: `_parseBoldAndItalic` 只处理 `**bold**`，不支持 `*italic*`、`~~strikethrough~~`、`[link](url)`、`![img](url)`
5. **表格不支持公式**: `TableElement` 存储 `List<String>` 而非 `List<InlineElement>`
6. **无错误恢复**: 格式错误直接中断解析

### 4.2 技术方案

**选型: `markdown` 包（Dart 原生）+ 自定义扩展**

```yaml
# pubspec.yaml
dependencies:
  markdown: ^7.1.1      # Dart 原生 Markdown 解析器
  # 替代 flutter_markdown（它只是 markdown 的 Widget 封装）
```

**为什么选 `markdown` 包：**
- Dart 官方维护，稳定可靠
- 支持 CommonMark + GFM 规范
- 可扩展的语法插件系统
- 生成标准 AST（`Node` 树）
- `flutter_markdown` 底层就是它，直接用更灵活

### 4.3 AST 节点设计

```dart
// lib/core/ast/ast_node.dart

/// 统一 AST 节点基类
sealed class AstNode {
  const AstNode();
  
  /// 接受访问者
  T accept<T>(AstVisitor<T> visitor);
  
  /// 子节点列表（可空）
  List<AstNode>? get children => null;
}

/// 块级节点基类
sealed class BlockNode extends AstNode {}

/// 内联节点基类
sealed class InlineNode extends AstNode {}
```

```dart
// lib/core/ast/block_nodes.dart

/// 标题节点
class HeadingNode extends BlockNode {
  final int level;              // 1-6
  final List<InlineNode> content;
  
  const HeadingNode({required this.level, required this.content});
}

/// 段落节点
class ParagraphNode extends BlockNode {
  final List<InlineNode> content;
  
  const ParagraphNode({required this.content});
}

/// 列表节点（统一有序/无序，支持嵌套）
class ListNode extends BlockNode {
  final bool ordered;
  final int start;              // 有序列表起始值
  final List<ListItemNode> items;
  
  const ListNode({
    required this.ordered,
    this.start = 1,
    required this.items,
  });
}

/// 列表项节点
class ListItemNode extends BlockNode {
  final List<BlockNode> children;  // 列表项内的块级内容
  final bool checked;              // 任务列表：是否勾选
  
  const ListItemNode({
    required this.children,
    this.checked = false,
  });
}

/// 代码块节点
class CodeBlockNode extends BlockNode {
  final String code;
  final String? language;
  
  const CodeBlockNode({required this.code, this.language});
}

/// 表格节点
class TableNode extends BlockNode {
  final List<TableColumn> columns;    // 列定义（对齐方式）
  final TableRowNode header;          // 表头
  final List<TableRowNode> rows;      // 数据行
  
  const TableNode({
    required this.columns,
    required this.header,
    required this.rows,
  });
}

/// 表格行
class TableRowNode extends AstNode {
  final List<TableCellNode> cells;
  
  const TableRowNode({required this.cells});
}

/// 表格单元格（支持内联内容）
class TableCellNode extends AstNode {
  final List<InlineNode> content;
  
  const TableCellNode({required this.content});
}

/// 引用块节点
class BlockquoteNode extends BlockNode {
  final List<BlockNode> children;
  
  const BlockquoteNode({required this.children});
}

/// Mermaid 图表节点
class MermaidNode extends BlockNode {
  final String code;
  
  const MermaidNode({required this.code});
}

/// 脚注定义节点（新增）
class FootnoteDefinitionNode extends BlockNode {
  final String label;
  final List<BlockNode> content;
  
  const FootnoteDefinitionNode({
    required this.label,
    required this.content,
  });
}

/// 空行节点
class EmptyLineNode extends BlockNode {
  const EmptyLineNode();
}
```

```dart
// lib/core/ast/inline_nodes.dart

/// 文本节点
class TextNode extends InlineNode {
  final String text;
  
  const TextNode(this.text);
}

/// 公式节点（替代 FormulaElement）
class FormulaNode extends InlineNode {
  final String latex;
  final bool displayMode;
  
  const FormulaNode({required this.latex, this.displayMode = false});
}

/// 粗体节点
class BoldNode extends InlineNode {
  final List<InlineNode> children;
  
  const BoldNode({required this.children});
}

/// 斜体节点（新增）
class ItalicNode extends InlineNode {
  final List<InlineNode> children;
  
  const ItalicNode({required this.children});
}

/// 删除线节点（新增）
class StrikethroughNode extends InlineNode {
  final List<InlineNode> children;
  
  const StrikethroughNode({required this.children});
}

/// 行内代码节点（新增）
class InlineCodeNode extends InlineNode {
  final String code;
  
  const InlineCodeNode(this.code);
}

/// 链接节点（新增）
class LinkNode extends InlineNode {
  final String url;
  final String? title;
  final List<InlineNode> children;
  
  const LinkNode({
    required this.url,
    this.title,
    required this.children,
  });
}

/// 图片节点（新增）
class ImageNode extends InlineNode {
  final String url;
  final String alt;
  final String? title;
  
  const ImageNode({
    required this.url,
    required this.alt,
    this.title,
  });
}

/// 高亮文本节点（新增，GFM）
class HighlightNode extends InlineNode {
  final List<InlineNode> children;
  
  const HighlightNode({required this.children});
}

/// 脚注引用节点（新增）
class FootnoteRefNode extends InlineNode {
  final String label;
  
  const FootnoteRefNode(this.label);
}
```

### 4.4 解析器实现

```dart
// lib/core/parser/markdown_parser.dart

import 'package:markdown/markdown.dart' as md;
import 'formula_syntax.dart';
import 'mermaid_syntax.dart';
import 'gfm_extensions.dart';

/// 基于 markdown 包的解析器
class MarkdownParser {
  /// 解析 Markdown 文本为 AST 节点列表
  static List<BlockNode> parse(String content) {
    if (content.isEmpty) return [];
    
    // 1. 构建解析器，注册扩展语法
    final document = md.Document(
      extensionSet: md.ExtensionSet(
        [
          // GFM 扩展
          md.TableSyntax(),
          md.AutolinkExtensionSyntax(),
          md.StrikethroughSyntax(),
          TaskListSyntax(),          // 自定义：任务列表
          FootnoteSyntax(),          // 自定义：脚注
          HighlightSyntax(),         // 自定义：高亮 ==text==
        ],
        [
          md.InlineHtmlSyntax(),
          md.StrikethroughSyntax(),
          md.AutolinkExtensionSyntax(),
        ],
      ),
      // 注册自定义块级语法
      blockSyntaxes: [
        FormulaBlockSyntax(),        // 自定义：$$...$$ 块级公式
        MermaidBlockSyntax(),        // 自定义：```mermaid 代码块
      ],
      // 注册自定义内联语法
      inlineSyntaxes: [
        FormulaInlineSyntax(),       // 自定义：$...$ 内联公式
      ],
    );
    
    // 2. 解析为 markdown 包的 Node 树
    final lines = content.split('\n');
    final nodes = document.parseLines(lines);
    
    // 3. 转换为我们的 AST
    return nodes.map(_convertBlock).whereType<BlockNode>().toList();
  }
  
  /// 将 markdown 包的 Node 转换为我们的 BlockNode
  static BlockNode? _convertBlock(md.Node node) {
    return switch (node) {
      md.Element(tag: 'h1', children: final c) => HeadingNode(
        level: 1, content: _convertInline(c)),
      md.Element(tag: 'h2', children: final c) => HeadingNode(
        level: 2, content: _convertInline(c)),
      // ... h3-h6 类似
      
      md.Element(tag: 'p', children: final c) => ParagraphNode(
        content: _convertInline(c)),
      
      md.Element(tag: 'ul', children: final c) => ListNode(
        ordered: false,
        items: c.whereType<md.Element>()
            .map((e) => _convertListItem(e, false))
            .toList(),
      ),
      md.Element(tag: 'ol', children: final c) => ListNode(
        ordered: true,
        items: c.whereType<md.Element>()
            .map((e) => _convertListItem(e, true))
            .toList(),
      ),
      
      md.Element(tag: 'pre', children: final c) => _convertCodeBlock(c),
      md.Element(tag: 'blockquote', children: final c) => BlockquoteNode(
        children: c.map(_convertBlock).whereType<BlockNode>().toList(),
      ),
      
      // 自定义节点
      FormulaBlockElement(:final latex, :final displayMode) => 
        ParagraphNode(content: [FormulaNode(latex: latex, displayMode: displayMode)]),
      MermaidBlockElement(:final code) => MermaidNode(code: code),
      
      _ => null,
    };
  }
  
  /// 转换内联节点
  static List<InlineNode> _convertInline(List<md.Node>? nodes) {
    if (nodes == null) return [];
    
    final result = <InlineNode>[];
    for (final node in nodes) {
      switch (node) {
        case md.Text(content: final text):
          result.add(TextNode(text));
        case md.Element(tag: 'strong', children: final c):
          result.add(BoldNode(children: _convertInline(c)));
        case md.Element(tag: 'em', children: final c):
          result.add(ItalicNode(children: _convertInline(c)));
        case md.Element(tag: 'del', children: final c):
          result.add(StrikethroughNode(children: _convertInline(c)));
        case md.Element(tag: 'code', children: final c):
          final text = c.whereType<md.Text>().map((t) => t.content).join();
          result.add(InlineCodeNode(text));
        case md.Element(tag: 'a', children: final c, attributes: final attrs):
          result.add(LinkNode(
            url: attrs['href'] ?? '',
            title: attrs['title'],
            children: _convertInline(c),
          ));
        case FormulaInlineElement(:final latex, :final displayMode):
          result.add(FormulaNode(latex: latex, displayMode: displayMode));
        // ... 其他内联节点
      }
    }
    return result;
  }
}
```

### 4.5 自定义语法插件

```dart
// lib/core/parser/formula_syntax.dart

/// 块级公式语法：$$...$$
class FormulaBlockSyntax extends md.BlockSyntax {
  @override
  RegExp get pattern => RegExp(r'^\$\$\s*$');
  
  @override
  md.Node? parse(md.BlockParser parser) {
    final buffer = md.BlockBuffer();
    parser.advance();
    
    while (!parser.isDone) {
      final line = parser.current;
      if (line.trim() == r'$$') {
        parser.advance();
        break;
      }
      buffer.write(line);
      parser.advance();
    }
    
    return FormulaBlockElement(
      latex: buffer.text,
      displayMode: true,
    );
  }
}

/// 内联公式语法：$...$
class FormulaInlineSyntax extends md.InlineSyntax {
  FormulaInlineSyntax() : super(r'\$([^\$\n]+)\$');
  
  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(FormulaInlineElement(
      latex: match.group(1)!,
      displayMode: false,
    ));
    return true;
  }
}
```

### 4.6 迁移策略

```
阶段 1a: 并存期
┌─────────────────────────────────────────┐
│  MarkdownParser (旧)  ← 保留，标记 @deprecated
│  NewMarkdownParser (新) ← 新增
│                                          │
│  PreviewContent 使用旧解析器              │
│  导出器使用旧解析器                       │
│  测试同时覆盖新旧解析器                   │
└─────────────────────────────────────────┘

阶段 1b: 切换期
┌─────────────────────────────────────────┐
│  MarkdownParser (旧)  ← 内部委托给新解析器
│  NewMarkdownParser (新) ← 实际实现
│                                          │
│  所有调用方通过旧接口使用新实现            │
│  旧 DocumentElement 通过适配器转换        │
└─────────────────────────────────────────┘

阶段 1c: 清理期
┌─────────────────────────────────────────┐
│  MarkdownParser (新)  ← 直接使用新 AST
│  旧 DocumentElement   ← 删除
│  所有调用方迁移到新 AST                   │
└─────────────────────────────────────────┘
```

---

## 5. 阶段二：公式渲染引擎替换

### 5.1 问题诊断

**现有方案的双路径架构：**

```
公式渲染路径 1（预览）:
  LaTeX → flutter_math_fork → Flutter Widget（直接渲染）

公式渲染路径 2（PDF 导出 SVG）:
  LaTeX → WebView (MathJax tex-svg.js) → SVG 字符串 → pw.SvgImage 嵌入 PDF

公式渲染路径 3（PDF/Word 导出 PNG 兜底）:
  LaTeX → FormulaRenderHost (离屏 flutter_math_fork) → RepaintBoundary.toImage() → PNG
```

**问题：**
1. **三条路径维护成本高**: 预览、SVG 导出、PNG 导出各走不同路径
2. **WebView 通信复杂**: `FormulaSvgService`（332 行）处理复杂的 JS↔Dart 通信协议
3. **性能瓶颈**: WebView 首次加载 300-500ms，每次渲染 50-100ms
4. **内存压力**: WebView 进程 + 离屏渲染的 `FormulaRenderHost` 双重内存占用
5. **`flutter_math_fork` 局限**: 不支持部分 LaTeX 命令，错误处理粗糙

### 5.2 技术方案

**选型: KaTeX 本地渲染（替代 MathJax + flutter_math_fork）**

**方案对比：**

| 方案 | 渲染速度 | 支持命令 | 集成复杂度 | 推荐 |
|------|---------|---------|-----------|------|
| KaTeX (WebView 本地) | 10-30ms | 90%+ LaTeX | 中 | ✅ 推荐 |
| KaTeX (Dart FFI) | 5-15ms | 90%+ LaTeX | 高 | 备选 |
| MathJax (当前) | 50-100ms | 99% LaTeX | 高 | ❌ 淘汰 |
| flutter_math_fork (当前) | 即时 | 70% LaTeX | 低 | ❌ 淘汰 |

**推荐方案: KaTeX via WebView（共享现有 WebView 基础设施）**

理由：
- 复用现有 `MermaidService` 的 WebView 基础设施
- KaTeX 比 MathJax 快 5-10 倍
- KaTeX 输出 HTML+CSS，可直接渲染为 Widget 或转为 SVG/PNG
- 不需要 FFI 或 native 集成

### 5.3 KaTeX 渲染服务设计

```dart
// lib/core/renderer/katex_service.dart

/// KaTeX 公式渲染服务（替代 FormulaSvgService + FormulaPdfRenderer）
/// 
/// 统一三条渲染路径为一条：
///   LaTeX → KaTeX (WebView) → HTML/SVG/PNG（按需输出）
class KatexService {
  KatexService._();
  
  /// 渲染公式为 HTML 字符串（用于预览和 HTML 导出）
  static Future<String> renderToHtml(
    String latex, {
    bool displayMode = false,
  }) async {
    // 调用 WebView 中的 katex.renderToString()
    // KaTeX 渲染速度: 10-30ms（vs MathJax 50-100ms）
  }
  
  /// 渲染公式为 SVG 字符串（用于 PDF 矢量导出）
  static Future<String> renderToSvg(
    String latex, {
    bool displayMode = false,
  }) async {
    // 先渲染为 HTML，再提取 SVG
    // 或使用 katex 的 SVG 输出模式
  }
  
  /// 渲染公式为 PNG 字节（用于 Word 导出）
  static Future<Uint8List> renderToPng(
    String latex, {
    bool displayMode = false,
    double fontSize = 16,
    bool isDark = false,
  }) async {
    // 渲染为 HTML → WebView 截图 → PNG
  }
  
  /// 渲染公式为 Flutter Widget（用于实时预览）
  static Widget renderToWidget(
    String latex, {
    bool displayMode = false,
    double fontSize = 16,
    bool isDark = false,
  }) {
    // 使用 flutter_widget_from_html 渲染 KaTeX HTML
    // 或自建 HTML→Widget 渲染器
  }
}
```

### 5.4 WebView HTML 模板

```html
<!-- assets/katex_renderer.html -->
<!DOCTYPE html>
<html>
<head>
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/katex.min.css">
  <script src="https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/katex.min.js"></script>
  <style>
    body { margin: 0; padding: 0; background: transparent; }
    .katex-display { margin: 0.5em 0; }
  </style>
</head>
<body>
  <div id="output"></div>
  <script>
    // 统一渲染接口
    window.renderFormula = function(id, latex, displayMode) {
      try {
        const html = katex.renderToString(latex, {
          displayMode: displayMode,
          throwOnError: false,
          output: 'html',  // 同时支持 html 和 mathml
        });
        
        // 写入 DOM
        const container = document.createElement('div');
        container.id = 'result-' + id;
        container.innerHTML = html;
        container.style.display = 'none';
        document.body.appendChild(container);
        
        // 通知 Dart
        console.log('KATEX_OK|' + id);
      } catch (e) {
        console.log('KATEX_ERR|' + id + '|' + e.message);
      }
    };
    
    // 渲染为 SVG（通过 foreignObject 包装 HTML）
    window.renderFormulaSvg = function(id, latex, displayMode) {
      try {
        const html = katex.renderToString(latex, {
          displayMode: displayMode,
          throwOnError: false,
        });
        
        // 测量尺寸
        const measure = document.createElement('div');
        measure.innerHTML = html;
        measure.style.position = 'absolute';
        measure.style.visibility = 'hidden';
        document.body.appendChild(measure);
        const rect = measure.getBoundingClientRect();
        document.body.removeChild(measure);
        
        // 构建 SVG
        const svg = `<svg xmlns="http://www.w3.org/2000/svg" 
          width="${rect.width}" height="${rect.height}" 
          viewBox="0 0 ${rect.width} ${rect.height}">
          <foreignObject width="100%" height="100%">
            <div xmlns="http://www.w3.org/1999/xhtml">
              ${html}
            </div>
          </foreignObject>
        </svg>`;
        
        const container = document.createElement('div');
        container.id = 'payload-' + id;
        container.textContent = svg;
        container.style.display = 'none';
        document.body.appendChild(container);
        
        console.log('KATEX_OK|' + id);
      } catch (e) {
        console.log('KATEX_ERR|' + id + '|' + e.message);
      }
    };
  </script>
</body>
</html>
```

### 5.5 统一渲染管线

```
旧架构（三条路径）:
┌──────────────────────────────────────────────────┐
│ 预览:  LaTeX → flutter_math_fork → Widget        │
│ SVG:   LaTeX → MathJax WebView → SVG → PDF      │
│ PNG:   LaTeX → 离屏 Widget → toImage → PNG      │
└──────────────────────────────────────────────────┘

新架构（统一路径）:
┌──────────────────────────────────────────────────┐
│                                                    │
│  LaTeX → KaTeX WebView → HTML                     │
│                    ├──→ Widget (预览)              │
│                    ├──→ SVG (PDF 导出)             │
│                    ├──→ PNG (Word 导出)            │
│                    └──→ HTML (HTML 导出)           │
│                                                    │
│  缓存层: LRU Cache (latex, displayMode, format)   │
│                                                    │
└──────────────────────────────────────────────────┘
```

### 5.6 性能优化

```dart
/// 预渲染策略
class KatexPreRender {
  /// 文档打开时预渲染所有公式
  static Future<void> preRenderDocument(String markdown) async {
    final formulas = FormulaExtractor.extractAllFormulas(markdown);
    
    // 并发渲染，上限 8 个（KaTeX 比 MathJax 快，可提高并发）
    await KatexService.preRenderAll(formulas, maxConcurrent: 8);
  }
  
  /// 增量预渲染：只渲染新增的公式
  static Future<void> preRenderIncremental(
    Set<String> oldFormulas,
    Set<String> newFormulas,
  ) async {
    final diff = newFormulas.difference(oldFormulas);
    if (diff.isEmpty) return;
    await KatexService.preRenderAll(diff);
  }
}
```

**预期性能提升：**

| 指标 | 旧方案 | 新方案 | 提升 |
|------|--------|--------|------|
| 首次渲染 | 300-500ms | 50-100ms | 5x |
| 后续渲染 | 50-100ms | 10-30ms | 5x |
| 内存占用 | WebView + 离屏 Host | 单个 WebView | -50% |
| 缓存命中 | 分路径缓存 | 统一缓存 | 命中率提升 |

---

## 6. 阶段三：实时预览编辑模式

### 6.1 问题诊断

**现有编辑模式：**

```dart
// editor_screen.dart L312-320
child: isPreview
    ? PreviewContent(content: ref.watch(editorContentProvider), isDark: isDark)
    : MarkdownInputField(controller: _controller, isDarkMode: isDark),
```

- 编辑和预览完全分离，切换模式才能看到渲染效果
- 编辑时只有纯文本，无法直观看到格式效果
- 预览时无法编辑

### 6.2 设计方案

**实现类似 Obsidian 的实时预览模式：**

```
┌─────────────────────────────────────────┐
│              实时预览编辑器               │
│                                          │
│  ┌─────────────────────────────────────┐│
│  │  # 标题                              ││  ← 渲染后的标题
│  │                                      ││
│  │  这是一段包含 $E=mc^2$ 的文本。      ││  ← 内联公式已渲染
│  │                                      ││
│  │  - 列表项 1                          ││  ← 渲染后的列表
│  │  - 列表项 2                          ││
│  │                                      ││
│  │  ```python                           ││
│  │  def hello():                        ││  ← 代码块（语法高亮）
│  │      print("Hello")                  ││
│  │  ```                                 ││
│  │                                      ││
│  │  | 光标在此行输入时，显示源码 |      ││  ← 当前编辑行显示源码
│  └─────────────────────────────────────┘│
│                                          │
│  ┌─────────────────────────────────────┐│
│  │ [B] [I] [S] [$$] [📊] [🔗] [📷]    ││  ← 格式化工具栏
│  └─────────────────────────────────────┘│
└─────────────────────────────────────────┘
```

### 6.3 技术实现

**核心思路: 基于 `TextField` + 自定义 `TextSpan` 渲染**

```dart
// lib/presentation/editor/live_preview_editor.dart

class LivePreviewEditor extends StatefulWidget {
  final String initialContent;
  final ValueChanged<String> onChanged;
  
  const LivePreviewEditor({
    super.key,
    required this.initialContent,
    required this.onChanged,
  });
  
  @override
  State<LivePreviewEditor> createState() => _LivePreviewEditorState();
}

class _LivePreviewEditorState extends State<LivePreviewEditor> {
  late TextEditingController _controller;
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => _showKeyboard(),
            child: _buildPreviewLayer(),
          ),
        ),
        _buildToolbar(),
      ],
    );
  }
  
  /// 预览层：渲染后的 Markdown
  Widget _buildPreviewLayer() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: _buildRenderedContent(),
      ),
    );
  }
  
  /// 渲染内容：AST → Widget
  Widget _buildRenderedContent() {
    final ast = MarkdownParser.parse(_controller.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: ast.map((node) => _renderNode(node)).toList(),
    );
  }
  
  /// 渲染单个节点
  Widget _renderNode(BlockNode node) {
    return switch (node) {
      HeadingNode(:final level, :final content) => 
        _renderHeading(level, content),
      ParagraphNode(:final content) => 
        _renderParagraph(content),
      ListNode(:final ordered, :final items) => 
        _renderList(ordered, items),
      CodeBlockNode(:final code, :final language) => 
        _renderCodeBlock(code, language),
      MermaidNode(:final code) => 
        _renderMermaid(code),
      TableNode(:final header, :final rows, :final columns) => 
        _renderTable(header, rows, columns),
      BlockquoteNode(:final children) => 
        _renderBlockquote(children),
      _ => const SizedBox.shrink(),
    };
  }
  
  /// 渲染内联内容（支持公式、粗体、斜体等）
  Widget _renderInline(List<InlineNode> nodes) {
    return RichText(
      text: TextSpan(
        children: nodes.map(_renderInlineNode).toList(),
      ),
    );
  }
  
  InlineSpan _renderInlineNode(InlineNode node) {
    return switch (node) {
      TextNode(:final text) => TextSpan(text: text),
      FormulaNode(:final latex, :final displayMode) => 
        WidgetSpan(child: KatexService.renderToWidget(latex, displayMode: displayMode)),
      BoldNode(:final children) => TextSpan(
        children: children.map(_renderInlineNode).toList(),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      ItalicNode(:final children) => TextSpan(
        children: children.map(_renderInlineNode).toList(),
        style: const TextStyle(fontStyle: FontStyle.italic),
      ),
      InlineCodeNode(:final code) => TextSpan(
        text: code,
        style: TextStyle(
          fontFamily: 'monospace',
          backgroundColor: Colors.grey.shade200,
        ),
      ),
      LinkNode(:final url, :final children) => TextSpan(
        children: children.map(_renderInlineNode).toList(),
        style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
        recognizer: TapGestureRecognizer()..onTap = () => _openLink(url),
      ),
      _ => const TextSpan(text: ''),
    };
  }
}
```

### 6.4 编辑交互设计

**点击编辑模式：**

```dart
/// 点击预览内容时，切换到源码编辑
void _onTapPreview(TapDownDetails details) {
  // 1. 计算点击位置对应的文档行号
  final lineIndex = _getLineAtPosition(details.globalPosition);
  
  // 2. 切换到源码编辑模式，光标定位到对应行
  setState(() {
    _editingLine = lineIndex;
    _mode = EditorMode.source;
  });
  
  // 3. 显示键盘
  _focusNode.requestFocus();
}

/// 编辑完成后回到预览
void _onEditingComplete() {
  setState(() {
    _mode = EditorMode.preview;
    _editingLine = null;
  });
}
```

**工具栏功能：**

```dart
// lib/presentation/editor/toolbar/editor_toolbar.dart

class EditorToolbar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          _ToolbarButton(icon: Icons.format_bold, onPressed: _insertBold),
          _ToolbarButton(icon: Icons.format_italic, onPressed: _insertItalic),
          _ToolbarButton(icon: Icons.strikethrough_s, onPressed: _insertStrikethrough),
          const VerticalDivider(),
          _ToolbarButton(icon: Icons.functions, onPressed: _insertFormula),
          _ToolbarButton(icon: Icons.table_chart, onPressed: _insertTable),
          _ToolbarButton(icon: Icons.account_tree, onPressed: _insertMermaid),
          const VerticalDivider(),
          _ToolbarButton(icon: Icons.link, onPressed: _insertLink),
          _ToolbarButton(icon: Icons.image, onPressed: _insertImage),
          _ToolbarButton(icon: Icons.code, onPressed: _insertCodeBlock),
        ],
      ),
    );
  }
  
  void _insertFormula() {
    // 弹出公式编辑对话框
    showDialog(
      context: context,
      builder: (ctx) => FormulaInsertDialog(
        onInsert: (latex, displayMode) {
          final formula = displayMode ? '\n$$\n$latex\n$$\n' : '\$$latex\$';
          _insertAtCursor(formula);
        },
      ),
    );
  }
}
```

### 6.5 三种编辑模式

```dart
enum EditorMode {
  /// 源码模式：纯文本编辑，类似 Typora 的源码模式
  source,
  
  /// 实时预览模式：渲染预览 + 点击行进入编辑
  livePreview,
  
  /// 分屏模式：左编辑 + 右预览（类似 Obsidian）
  split,
}
```

用户可在底部栏切换模式：

```
┌─────────────────────────────────────────┐
│  [源码]  [实时预览]  [分屏]    [导出 ▼]  │
└─────────────────────────────────────────┘
```

---

## 7. 阶段四：导出架构统一

### 7.1 问题诊断

**现有导出架构的问题：**

1. **代码重复**: PDF 导出（541 行）和 Word 导出（246 行 + 498 行 OOXML Builder）各自独立实现
2. **硬编码样式**: 字体、颜色、间距全部硬编码在 Exporter 内部
3. **扩展困难**: 新增 HTML 导出需要从头实现
4. **AST 不一致**: 导出器使用旧的 `DocumentElement`，与新 AST 不兼容
5. **Word OOXML 手动构建**: 498 行 XML 模板拼装，容易出错

### 7.2 统一导出管线设计

```dart
// lib/domain/exporters/export_pipeline.dart

/// 统一导出管线
/// 
/// Markdown → AST → 目标格式
/// 
/// 每种导出格式只需实现 ExportRenderer 接口
class ExportPipeline {
  /// 导出入口
  static Future<Uint8List> export<T>({
    required String markdown,
    required ExportRenderer<T> renderer,
    ExportOptions? options,
  }) async {
    // 1. 解析为 AST
    final ast = MarkdownParser.parse(markdown);
    
    // 2. 预渲染公式（按需）
    await _preRenderFormulas(ast, renderer.formulaFormat);
    
    // 3. 预渲染 Mermaid（按需）
    await _preRenderMermaid(ast, renderer.mermaidFormat);
    
    // 4. 渲染为目标格式
    final document = renderer.render(ast, options ?? ExportOptions.defaultOptions);
    
    // 5. 序列化输出
    return renderer.serialize(document);
  }
}

/// 导出渲染器接口
abstract class ExportRenderer<T> {
  /// 公式输出格式
  FormulaOutputFormat get formulaFormat;
  
  /// Mermaid 输出格式
  MermaidOutputFormat get mermaidFormat;
  
  /// 渲染 AST 为文档对象
  T render(List<BlockNode> ast, ExportOptions options);
  
  /// 序列化文档对象为字节流
  Future<Uint8List> serialize(T document);
}

/// 导出选项
class ExportOptions {
  final String? title;
  final String? author;
  final bool isDark;
  final Map<String, dynamic> customStyles;  // 自定义样式
  
  const ExportOptions({
    this.title,
    this.author,
    this.isDark = false,
    this.customStyles = const {},
  });
  
  static const defaultOptions = ExportOptions();
}
```

### 7.3 PDF 导出器重构

```dart
// lib/domain/exporters/pdf_exporter.dart

class PdfExportRenderer implements ExportRenderer<pw.Document> {
  @override
  FormulaOutputFormat get formulaFormat => FormulaOutputFormat.svg;
  
  @override
  MermaidOutputFormat get mermaidFormat => MermaidOutputFormat.svg;
  
  @override
  pw.Document render(List<BlockNode> ast, ExportOptions options) {
    final pdf = pw.Document(
      title: options.title ?? 'FormulaFix',
      author: options.author ?? 'FormulaFix',
    );
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(40, 60, 40, 60),
        build: (context) => ast.map((node) => _renderBlock(node, options)).toList(),
      ),
    );
    
    return pdf;
  }
  
  @override
  Future<Uint8List> serialize(pw.Document document) => document.save();
  
  pw.Widget _renderBlock(BlockNode node, ExportOptions options) {
    return switch (node) {
      HeadingNode() => _renderHeading(node, options),
      ParagraphNode() => _renderParagraph(node, options),
      ListNode() => _renderList(node, options),
      CodeBlockNode() => _renderCodeBlock(node, options),
      TableNode() => _renderTable(node, options),
      BlockquoteNode() => _renderBlockquote(node, options),
      MermaidNode() => _renderMermaid(node, options),
      _ => const pw.SizedBox(),
    };
  }
  
  // ... 各类型渲染实现
}
```

### 7.4 HTML 导出器（新增）

```dart
// lib/domain/exporters/html_exporter.dart

class HtmlExportRenderer implements ExportRenderer<String> {
  @override
  FormulaOutputFormat get formulaFormat => FormulaOutputFormat.html;
  
  @override
  MermaidOutputFormat get mermaidFormat => MermaidOutputFormat.svg;
  
  @override
  String render(List<BlockNode> ast, ExportOptions options) {
    final buffer = StringBuffer();
    
    buffer.writeln('<!DOCTYPE html>');
    buffer.writeln('<html lang="zh-CN">');
    buffer.writeln('<head>');
    buffer.writeln('  <meta charset="UTF-8">');
    buffer.writeln('  <meta name="viewport" content="width=device-width, initial-scale=1.0">');
    buffer.writeln('  <title>${options.title ?? 'FormulaFix'}</title>');
    buffer.writeln('  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/katex.min.css">');
    buffer.writeln('  <style>${_buildCss(options)}</style>');
    buffer.writeln('</head>');
    buffer.writeln('<body>');
    buffer.writeln('  <article class="markdown-body">');
    
    for (final node in ast) {
      buffer.writeln('    ${_renderBlock(node)}');
    }
    
    buffer.writeln('  </article>');
    buffer.writeln('  <script src="https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/katex.min.js"></script>');
    buffer.writeln('  <script src="https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.min.js"></script>');
    buffer.writeln('  <script>mermaid.initialize({startOnLoad:true});</script>');
    buffer.writeln('</body>');
    buffer.writeln('</html>');
    
    return buffer.toString();
  }
  
  @override
  Future<Uint8List> serialize(String html) async {
    return Uint8List.fromList(utf8.encode(html));
  }
  
  String _renderBlock(BlockNode node) {
    return switch (node) {
      HeadingNode(:final level, :final content) => 
        '<h$level>${_renderInline(content)}</h$level>',
      ParagraphNode(:final content) => 
        '<p>${_renderInline(content)}</p>',
      ListNode(:final ordered, :final items) => 
        _renderHtmlList(ordered, items),
      CodeBlockNode(:final code, :final language) => 
        '<pre><code class="language-$language">${_escapeHtml(code)}</code></pre>',
      TableNode() => _renderHtmlTable(node),
      BlockquoteNode(:final children) => 
        '<blockquote>${children.map(_renderBlock).join()}</blockquote>',
      MermaidNode(:final code) => 
        '<div class="mermaid">$code</div>',
      _ => '',
    };
  }
  
  String _renderInline(List<InlineNode> nodes) {
    return nodes.map(_renderInlineNode).join();
  }
  
  String _renderInlineNode(InlineNode node) {
    return switch (node) {
      TextNode(:final text) => _escapeHtml(text),
      FormulaNode(:final latex, :final displayMode) => 
        _renderKatexHtml(latex, displayMode),
      BoldNode(:final children) => 
        '<strong>${_renderInline(children)}</strong>',
      ItalicNode(:final children) => 
        '<em>${_renderInline(children)}</em>',
      StrikethroughNode(:final children) => 
        '<del>${_renderInline(children)}</del>',
      InlineCodeNode(:final code) => 
        '<code>${_escapeHtml(code)}</code>',
      LinkNode(:final url, :final title, :final children) => 
        '<a href="$url"${title != null ? ' title="$title"' : ''}>${_renderInline(children)}</a>',
      ImageNode(:final url, :final alt, :final title) => 
        '<img src="$url" alt="$alt"${title != null ? ' title="$title"' : ''}>',
      _ => '',
    };
  }
  
  String _renderKatexHtml(String latex, bool displayMode) {
    if (displayMode) {
      return '<div class="katex-display">\\[$latex\\]</div>';
    }
    return '\\($latex\\)';
  }
  
  String _buildCss(ExportOptions options) {
    return '''
      .markdown-body {
        max-width: 800px;
        margin: 0 auto;
        padding: 2rem;
        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
        line-height: 1.6;
        color: ${options.isDark ? '#c9d1d9' : '#24292f'};
        background: ${options.isDark ? '#0d1117' : '#ffffff'};
      }
      h1, h2, h3, h4, h5, h6 { margin-top: 1.5em; margin-bottom: 0.5em; }
      code { 
        background: ${options.isDark ? '#161b22' : '#f6f8fa'};
        padding: 0.2em 0.4em;
        border-radius: 3px;
        font-family: "SFMono-Regular", Consolas, monospace;
      }
      pre { 
        background: ${options.isDark ? '#161b22' : '#f6f8fa'};
        padding: 1em;
        border-radius: 6px;
        overflow-x: auto;
      }
      blockquote {
        border-left: 4px solid ${options.isDark ? '#3b434b' : '#d0d7de'};
        padding: 0 1em;
        color: ${options.isDark ? '#8b949e' : '#57606a'};
      }
      table { border-collapse: collapse; width: 100%; }
      th, td { border: 1px solid ${options.isDark ? '#30363d' : '#d0d7de'}; padding: 6px 13px; }
    ''';
  }
}
```

### 7.5 Markdown 导出器（新增）

```dart
// lib/domain/exporters/markdown_exporter.dart

/// AST → Markdown 文本（用于格式化和导出）
class MarkdownExportRenderer implements ExportRenderer<String> {
  @override
  FormulaOutputFormat get formulaFormat => FormulaOutputFormat.latex;
  
  @override
  MermaidOutputFormat get mermaidFormat => MermaidOutputFormat.code;
  
  @override
  String render(List<BlockNode> ast, ExportOptions options) {
    return ast.map(_renderBlock).join('\n\n');
  }
  
  @override
  Future<Uint8List> serialize(String markdown) async {
    return Uint8List.fromList(utf8.encode(markdown));
  }
  
  String _renderBlock(BlockNode node) {
    return switch (node) {
      HeadingNode(:final level, :final content) => 
        '${'#' * level} ${_renderInline(content)}',
      ParagraphNode(:final content) => _renderInline(content),
      ListNode(:final ordered, :final items) => 
        items.asMap().entries.map((e) => 
          '${ordered ? '${e.key + 1}.' : '-'} ${_renderBlockContent(e.value)}'
        ).join('\n'),
      CodeBlockNode(:final code, :final language) => 
        '```$language\n$code\n```',
      TableNode() => _renderMarkdownTable(node),
      BlockquoteNode(:final children) => 
        children.map((c) => '> ${_renderBlock(c)}').join('\n'),
      MermaidNode(:final code) => '```mermaid\n$code\n```',
      _ => '',
    };
  }
}
```

### 7.6 导出格式支持矩阵

| 格式 | 现有 | 重构后 | 说明 |
|------|------|--------|------|
| PDF | ✅ | ✅ | 基于 AST，SVG 矢量公式 |
| Word | ✅ | ✅ | 基于 AST，简化 OOXML 构建 |
| TXT | ✅ | ✅ | 纯文本，去除格式 |
| HTML | ❌ | ✅ | 新增，支持 KaTeX + Mermaid |
| Markdown | ❌ | ✅ | 新增，AST 格式化输出 |

---

## 8. 阶段五：功能补齐与体验优化

### 8.1 GFM 扩展支持

| 功能 | 语法 | 优先级 |
|------|------|--------|
| 任务列表 | `- [ ]` / `- [x]` | P0 |
| 删除线 | `~~text~~` | P0 |
| 表格对齐 | `\| :--- \| :---: \| ---: \|` | P0 |
| 脚注 | `[^1]` / `[^1]: text` | P1 |
| 高亮文本 | `==text==` | P1 |
| 自动链接 | `https://example.com` | P1 |
| 定义列表 | `Term\n: Definition` | P2 |

### 8.2 内联语法完善

**现有缺失：**

| 语法 | 现有支持 | 目标 |
|------|---------|------|
| `**bold**` | ✅ | ✅ |
| `*italic*` | ❌ | ✅ |
| `~~strikethrough~~` | ❌ | ✅ |
| `` `code` `` | ❌ | ✅ |
| `[link](url)` | ❌ | ✅ |
| `![img](url)` | ❌ | ✅ |
| `$formula$` | ✅ | ✅ |
| `==highlight==` | ❌ | ✅ |

### 8.3 主题系统

```dart
// lib/core/theme/editor_theme.dart

/// 编辑器主题（可扩展）
class EditorTheme {
  final String name;
  final Color backgroundColor;
  final Color textColor;
  final Color headingColor;
  final Color codeBackgroundColor;
  final Color linkColor;
  final Color blockquoteBorderColor;
  final TextStyle headingStyle;
  final TextStyle bodyStyle;
  final TextStyle codeStyle;
  
  const EditorTheme({
    required this.name,
    required this.backgroundColor,
    required this.textColor,
    // ...
  });
  
  /// 内置主题
  static const light = EditorTheme(
    name: 'Light',
    backgroundColor: Colors.white,
    textColor: Color(0xFF24292F),
    // ...
  );
  
  static const dark = EditorTheme(
    name: 'Dark',
    backgroundColor: Color(0xFF0D1117),
    textColor: Color(0xFFC9D1D9),
    // ...
  );
  
  /// 未来：支持自定义主题加载
  static Future<EditorTheme> fromJson(String json) async {
    // 从 JSON 配置加载自定义主题
  }
}
```

### 8.4 公式编辑器增强

```dart
// lib/presentation/widgets/formula_insert_dialog.dart

/// 增强的公式插入对话框
class FormulaInsertDialog extends StatefulWidget {
  @override
  State<FormulaInsertDialog> createState() => _FormulaInsertDialogState();
}

class _FormulaInsertDialogState extends State<FormulaInsertDialog> {
  final _controller = TextEditingController();
  String _previewHtml = '';
  
  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: 500,
        height: 400,
        child: Column(
          children: [
            // 符号面板
            _buildSymbolPanel(),
            
            // 公式输入
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'LaTeX 公式',
                hintText: r'例如: \frac{a}{b}',
              ),
              onChanged: _onFormulaChanged,
            ),
            
            // 实时预览
            Expanded(child: _buildPreview()),
            
            // 常用公式模板
            _buildTemplatePanel(),
            
            // 操作按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
                ElevatedButton(onPressed: _onInsert, child: const Text('插入')),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSymbolPanel() {
    // 常用数学符号快捷面板
    // α β γ δ ε ... ∑ ∏ ∫ √ ∞ ...
  }
  
  Widget _buildTemplatePanel() {
    // 常用公式模板
    // 分数: \frac{}{}  根号: \sqrt{}  积分: \int_{}^{}  
    // 矩阵: \begin{matrix}...\end{matrix}
  }
}
```

---

## 9. 技术选型对比

### 9.1 Markdown 解析器

| 方案 | 优点 | 缺点 | 推荐 |
|------|------|------|------|
| `markdown` 包 | Dart 官方、CommonMark 兼容、可扩展 | 需自定义公式语法 | ✅ |
| `markdown_it` Dart 移植 | 插件丰富 | 非官方维护、更新慢 | ❌ |
| 继续手动解析 | 完全控制 | 维护成本高、功能缺失 | ❌ |

### 9.2 公式渲染

| 方案 | 渲染速度 | LaTeX 支持 | 集成难度 | 推荐 |
|------|---------|-----------|---------|------|
| KaTeX (WebView) | 10-30ms | 90%+ | 中 | ✅ |
| KaTeX (Dart FFI) | 5-15ms | 90%+ | 高 | 备选 |
| MathJax (当前) | 50-100ms | 99% | 高 | ❌ |
| flutter_math_fork (当前) | 即时 | 70% | 低 | ❌ |

### 9.3 PDF 生成

| 方案 | 优点 | 缺点 | 推荐 |
|------|------|------|------|
| `pdf` 包 (当前) | 纯 Dart、无 native 依赖 | Widget 系统学习成本 | ✅ 保持 |
| `printing` 包 | 系统打印支持 | 底层仍用 pdf 包 | 配合使用 |
| WebView → PDF | 完美还原 HTML 渲染 | 依赖网络、体积大 | ❌ |

### 9.4 Word 导出

| 方案 | 优点 | 缺点 | 推荐 |
|------|------|------|------|
| 手动 OOXML (当前) | 无外部依赖 | 代码复杂、易出错 | 改进保持 |
| Pandoc (进程调用) | 功能强大 | 需打包 Pandoc binary | ❌ 移动端不适用 |
| `docx` 包 | Dart 原生 | 生态不成熟 | 备选 |

---

## 10. 风险评估与缓解策略

### 10.1 技术风险

| 风险 | 概率 | 影响 | 缓解策略 |
|------|------|------|---------|
| KaTeX 不支持某些 LaTeX 命令 | 中 | 中 | 保留 MathJax 作为 fallback |
| `markdown` 包扩展性不足 | 低 | 高 | 可 fork 或切换到其他解析器 |
| WebView 在低端设备卡顿 | 中 | 中 | 降级到 flutter_math_fork |
| AST 迁移破坏现有功能 | 中 | 高 | 分阶段迁移，保持旧接口兼容 |
| 实时预览性能问题 | 中 | 中 | 增量解析 + 防抖渲染 |

### 10.2 兼容性风险

| 风险 | 缓解策略 |
|------|---------|
| 旧文档格式不兼容 | 新旧 AST 适配器，保证向后兼容 |
| 导出的 PDF/Word 样式变化 | 保持样式参数一致，提供对比测试 |
| 第三方依赖版本冲突 | 锁定版本，定期更新 |

### 10.3 进度风险

| 风险 | 缓解策略 |
|------|---------|
| 阶段间依赖导致阻塞 | 每阶段独立可发布 |
| 测试覆盖不足 | 每个阶段配套测试 |
| 需求变更 | 模块化设计，降低变更成本 |

---

## 11. 实施路线图

### 阶段一：Markdown 解析器升级（4-6 周）

```
Week 1-2: 基础设施
├── 引入 markdown 包
├── 定义 AST 节点类型
├── 实现基础解析器（标题、段落、列表、代码块）
└── 编写单元测试

Week 3-4: 扩展语法
├── 实现公式语法插件（$...$ 和 $$...$$）
├── 实现 Mermaid 语法插件
├── 实现 GFM 扩展（任务列表、删除线、表格对齐）
└── 集成测试

Week 5-6: 迁移与清理
├── 旧解析器标记 @deprecated
├── 渲染组件迁移到新 AST
├── 导出器迁移到新 AST
├── 删除旧解析器代码
└── 回归测试
```

### 阶段二：公式渲染引擎替换（3-4 周）

```
Week 1: KaTeX 集成
├── 创建 katex_renderer.html
├── 实现 KatexService（替代 FormulaSvgService）
├── 与 MermaidService 共享 WebView
└── 基础渲染测试

Week 2: 统一渲染管线
├── 实现 renderToHtml / renderToSvg / renderToPng
├── 统一缓存层
├── 替换预览中的 flutter_math_fork
└── 性能基准测试

Week 3: 导出集成
├── PDF 导出使用 KaTeX SVG
├── Word 导出使用 KaTeX PNG
├── 删除 FormulaPdfRenderer 离屏渲染
└── 导出质量对比测试

Week 4: 清理与优化
├── 删除旧公式渲染代码
├── 预渲染策略优化
├── 内存占用优化
└── 低端设备兼容性测试
```

### 阶段三：实时预览编辑模式（4-6 周）

```
Week 1-2: 编辑器核心
├── 实现 LivePreviewEditor 组件
├── AST → Widget 渲染器
├── 点击编辑交互
└── 基础交互测试

Week 3-4: 工具栏与增强
├── 格式化工具栏
├── 公式插入对话框增强
├── 表格/图片/链接插入
└── 编辑体验测试

Week 5-6: 模式切换与优化
├── 三种编辑模式切换
├── 增量解析（防抖）
├── 大文档性能优化
└── 用户测试与迭代
```

### 阶段四：导出架构统一（3-4 周）

```
Week 1: 导出管线
├── 实现 ExportPipeline
├── 定义 ExportRenderer 接口
├── PDF 导出器重构
└── 对比测试（新旧 PDF 输出一致）

Week 2: 新增导出格式
├── HTML 导出器
├── Markdown 导出器
├── Word 导出器简化
└── 导出格式测试

Week 3-4: 样式与模板
├── 导出样式配置
├── 自定义 CSS 支持（HTML 导出）
├── 导出选项 UI
└── 端到端测试
```

### 阶段五：功能补齐（2-3 周）

```
Week 1: GFM 与内联语法
├── 脚注支持
├── 高亮文本
├── 定义列表
└── 完整 GFM 测试套件

Week 2: 体验优化
├── 主题系统基础
├── 公式编辑器增强
├── 代码语法高亮
└── 用户反馈迭代

Week 3: 收尾
├── 文档更新
├── 性能调优
├── 全平台测试
└── 发布准备
```

**总计: 16-23 周（约 4-6 个月）**

---

## 12. 测试策略

### 12.1 单元测试

```dart
// test/core/parser/markdown_parser_test.dart

void main() {
  group('MarkdownParser', () {
    test('解析标题', () {
      final ast = MarkdownParser.parse('# Hello');
      expect(ast, hasLength(1));
      expect(ast[0], isA<HeadingNode>());
      expect((ast[0] as HeadingNode).level, 1);
    });
    
    test('解析内联公式', () {
      final ast = MarkdownParser.parse(r'Text $E=mc^2$ text');
      // ...
    });
    
    test('解析块级公式', () {
      final ast = MarkdownParser.parse('$$\n\\frac{a}{b}\n$$');
      // ...
    });
    
    test('解析任务列表', () {
      final ast = MarkdownParser.parse('- [ ] Todo\n- [x] Done');
      // ...
    });
    
    // CommonMark 规范测试
    test('CommonMark 规范兼容', () {
      // 运行 CommonMark 测试套件
    });
  });
}
```

### 12.2 渲染测试

```dart
// test/core/renderer/katex_service_test.dart

void main() {
  group('KatexService', () {
    test('渲染简单公式', () async {
      final html = await KatexService.renderToHtml(r'E=mc^2');
      expect(html, contains('katex'));
    });
    
    test('渲染性能 <50ms', () async {
      final sw = Stopwatch()..start();
      await KatexService.renderToHtml(r'\frac{a}{b}');
      expect(sw.elapsedMilliseconds, lessThan(50));
    });
    
    test('缓存命中', () async {
      await KatexService.renderToHtml(r'x^2');
      final sw = Stopwatch()..start();
      await KatexService.renderToHtml(r'x^2');  // 应命中缓存
      expect(sw.elapsedMilliseconds, lessThan(5));
    });
  });
}
```

### 12.3 导出对比测试

```dart
// test/domain/exporters/export_golden_test.dart

void main() {
  group('导出对比测试', () {
    test('PDF 输出与旧版一致', () async {
      final markdown = '# Title\n\nText with $formula$';
      
      final oldBytes = await OldPdfExporter.export(markdown);
      final newBytes = await ExportPipeline.export(
        markdown: markdown,
        renderer: PdfExportRenderer(),
      );
      
      // 视觉对比（或字节级对比）
      expect(newBytes.length, closeTo(oldBytes.length, 1000));
    });
  });
}
```

---

## 13. 附录：现有代码问题分析

### 13.1 `MarkdownParser`（309 行）

| 行号 | 问题 | 严重程度 |
|------|------|---------|
| L11-13 | 状态变量过多（inCodeBlock, codeLanguage, codeLines） | 中 |
| L44-56 | `getIndent` 硬编码缩进规则（2 空格 = 1 级） | 中 |
| L115-163 | 列表解析逻辑混乱，嵌套处理有 bug | 高 |
| L209-220 | `_isTableSeparatorRow` 正则不够严格 | 低 |
| L279-308 | `_parseBoldAndItalic` 只处理 `**bold**`，不支持 `*italic*` | 高 |
| 整体 | 无错误恢复机制 | 中 |

### 13.2 `FormulaSvgService`（332 行）

| 行号 | 问题 | 严重程度 |
|------|------|---------|
| L14-23 | 通信协议注释说明曾出现 `|` 字符解析 bug | 中 |
| L53-58 | 依赖 MermaidService 的 WebView（耦合） | 中 |
| L155-169 | `_evaluate` 超时后重置整个渲染器（过重） | 中 |
| L190-230 | `handleConsoleMessage` 协议解析复杂 | 中 |
| L234-261 | `_fetchSvgFromDom` 异步 DOM 读取（脆弱） | 中 |
| 整体 | 332 行仅处理公式→SVG，过于复杂 | 高 |

### 13.3 `FormulaPdfRenderer`（400 行）

| 行号 | 问题 | 严重程度 |
|------|------|---------|
| L16-24 | 离屏渲染参数（pixelRatio, timeout）靠经验调优 | 中 |
| L40-124 | `FormulaRenderHost` 全局单例（测试困难） | 中 |
| L142-244 | `_OffscreenCapture` 离屏渲染逻辑复杂 | 高 |
| L173-198 | `_capture` 方法有 GPU 内存泄漏风险 | 中 |
| 整体 | 400 行实现离屏 PNG 渲染，可被 KaTeX 替代 | 高 |

### 13.4 `PdfExporter`（541 行）

| 行号 | 问题 | 严重程度 |
|------|------|---------|
| L27-68 | CJK 字体加载重试逻辑（应抽取为独立服务） | 低 |
| L169-179 | 元素→Widget 转换用 if-else 链（应改为 visitor） | 中 |
| L285-321 | `_pdfParagraphAsync` 异步渲染段落（性能） | 中 |
| L323-363 | `_wrapListItem` 列表前缀硬编码 | 低 |
| L480-519 | 表格不支持跨页 | 中 |
| 整体 | 541 行，职责过多（字体、布局、渲染混合） | 高 |

### 13.5 `WordExporter`（246 行）+ `WordOoxmlBuilder`（498 行）

| 问题 | 严重程度 |
|------|---------|
| 手动构建 OOXML XML（容易格式错误） | 高 |
| 公式以 PNG 嵌入（非矢量，缩放模糊） | 中 |
| 368 行 XML 模板常量（难以维护） | 中 |
| UTF-8 编码处理需要特殊注释说明 | 中 |

---

## 变更记录

| 日期 | 版本 | 变更内容 |
|------|------|---------|
| 2026-06-16 | v1.0 | 初始版本，完整设计方案 |

---

*文档结束*
