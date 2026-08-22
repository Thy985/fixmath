# FormulaFix 2.0 重构方案

> **角色**：架构评审人员
> **输出范围**：设计文档，不含代码改动
> **基准**：已建立的 [AGENTS.md](file:///d:/Projects/Active/math/AGENTS.md) / [ARCHITECTURE.md](file:///d:/Projects/Active/math/docs/ARCHITECTURE.md) / [CRITICAL_REVIEW.md](file:///d:/Projects/Active/math/docs/CRITICAL_REVIEW.md) / [ADR/](file:///d:/Projects/Active/math/docs/ADR)
> **目标**：从"Markdown + 公式预览原型"演进为"移动端 Typora 类体验"

---

## 0. 设计哲学

FormulaFix 2.0 的设计基于以下核心哲学：

1. **块即一等公民**：文档 = 块序列；每个块独立编辑、独立渲染、独立追踪焦点
2. **AST 是单一真相**：UI 不持有文本，UI 持有 AST；文本只是 AST 的序列化产物
3. **渲染即解释**：渲染器只是 AST 节点的解释器，可替换、可缓存、可并行
4. **状态即派生**：所有 UI 状态都从 AST + 用户操作派生，禁止"全局可变单例"
5. **渐进式迁移**：旧路径与新路径并存，feature flag 切换，每个 PR 单一职责
6. **文件即文档**：任意路径的 .md 文件即可作为文档打开，无需导入到私有 Vault；只读查看模式与编辑模式具有同等地位

---

## 1. 总体架构图

### 1.1 分层架构（To-Be）

```
┌─────────────────────────────────────────────────────────────────┐
│ presentation/                                                   │
│   screens/                                                      │
│     - WysiwygEditorScreen     ← 替代 EditorScreen                │
│     - DocumentListScreen      ← 启用（修复 P0 #3）                │
│     - FileManagerScreen       ← 兼容外部 .md                     │
│   widgets/blocks/                                               │
│     - BlockEditor             ← 容器                             │
│     - BlockWidget             ← 单块 wrapper（聚焦/非聚焦切换）  │
│     - EditableBlockMixin      ← 编辑态接口                       │
│     - RenderedBlockMixin      ← 渲染态接口                       │
│     - HeadingBlock / ParagraphBlock / ListBlock / CodeBlock /   │
│       TableBlock / BlockquoteBlock / MermaidBlock / ImageBlock  │
│   widgets/inline/                                              │
│     - InlineRenderer          ← 节点 → Widget 解释器            │
│     - FormulaInline / CodeInline / LinkInline / BoldInline /   │
│       ItalicInline / StrikethroughInline / ImageInline          │
│   widgets/renderers/                                            │
│     - FormulaRenderer         ← WebView 路径                    │
│     - CodeHighlighter        ← highlight.js / 自研              │
│     - MermaidRenderer         ← WebView 路径                    │
│     - ImageRenderer           ← 缓存 + 占位                      │
│   theme/                                                        │
│     - AppTheme / ThemeRegistry / 4+ 主题                         │
├─────────────────────────────────────────────────────────────────┤
│ providers/                                                      │
│   - editor_state_provider     ← EditorStateNotifier             │
│   - document_list_provider   ← DocumentListNotifier            │
│   - render_cache_provider    ← RenderCacheNotifier              │
│   - theme_provider / settings_provider                          │
├─────────────────────────────────────────────────────────────────┤
│ domain/                                                         │
│   editor/                                                       │
│     - BlockRegistry           ← BlockType → WidgetBuilder       │
│     - InlineRegistry          ← InlineType → Renderer           │
│     - FocusController         ← 焦点链 / 光标转移                │
│     - SelectionController     ← 跨块选择（Phase 3）              │
│     - HistoryManager          ← 撤销重做（基于 AST diff）         │
│   services/                                                     │
│     - FileRepository          ← 替代 DocumentService             │
│     - StorageMigration        ← 一次性 JSON → .md                │
│     - ExportService           ← 保留 facade                      │
│     - exporters/              ← 保留                             │
├─────────────────────────────────────────────────────────────────┤
│ data/                                                           │
│   models/                                                       │
│     - document_model.dart     ← 新：DocumentModel + Block +     │
│       InlineNode（含 id / source / range）                      │
│     - document_metadata.dart  ← 新：最近打开 / 收藏 / 置顶       │
│     - template.dart            ← 保留                             │
├─────────────────────────────────────────────────────────────────┤
│ core/                                                           │
│   parser/                                                       │
│     - MarkdownParser         ← 重写：完整 CommonMark + GFM     │
│     - MarkdownSerializer     ← 新：AST → Markdown（保格式）     │
│     - IncrementalParser      ← 新：单块重解析                    │
│     - FormulaExtractor       ← 保留                             │
│   renderers/                 ← 保留 SVG AST                     │
│   services/                                                     │
│     - FormulaSvgService      ← 重构为 instance + DI              │
│     - MermaidService         ← 重构为 instance + DI              │
│     - ImageCacheService      ← 新                               │
│   utils/                      ← 保留 HistoryManager              │
└─────────────────────────────────────────────────────────────────┘
```

### 1.2 数据流（编辑流）

```
[用户输入]
    │
    ▼
[EditableBlock TextEditingController]
    │
    ├─ onTextChanged(text)
    │       │
    │       ▼
    │   [EditorStateNotifier.updateBlockText(blockId, text)]
    │       │
    │       ├─ IncrementalParser.reparseBlock(blockId, text)
    │       │       │
    │       │       ▼
    │       │   [DocumentModel.blocks[i] ← new Block]
    │       │       │
    │       │       ▼
    │       │   [DocumentModel 变更通知]
    │       │       │
    │       │       ▼
    │       │   [BlockWidget rebuild]
    │       │       │
    │       │       ▼
    │       │   聚焦态 → 仍是 TextField（光标不动）
    │       │
    │       └─ 防抖 500ms → FileRepository.write(path, serialize(model))
    │
    └─ onLostFocus()
            │
            ▼
        [EditorStateNotifier.setFocusedBlock(null)]
            │
            ▼
        [BlockWidget rebuild → 切换为 RenderedBlock]
```

**关键点**：
- 聚焦块不重渲染为最终样式（避免光标跳动）
- 非聚焦块在 AST 变更时立即重渲染
- 文件写入与 UI 解耦（防抖 + 异步队列）

### 1.3 数据流（导出流）

```
[用户点击导出]
    │
    ▼
[ExportService.exportAndShare(model, format)]
    │
    ├─ MarkdownSerializer.serialize(model) → markdown 字符串
    │       │
    │       ▼
    │   [Exporter.export(markdown)]
    │       │
    │       ├─ PDF: collectAllFormulas → FormulaRenderer.preRenderAll
    │       │       → PdfDocument 拼装 → Uint8List
    │       ├─ Word: OOXML Builder + archive → Uint8List
    │       └─ TXT: serialize → String
    │
    └─ Share.shareXFiles([tempFile])
```

**关键变化**：导出器输入从 `markdown String` 改为 `DocumentModel`，可保留元数据（标题、作者、front matter）。

---

## 2. 模块拆分

### 2.1 编辑器内核（Block-based WYSIWYG）

#### 核心抽象

```
BlockEditor
  ├─ ScrollablePositionList        // 大文档虚拟化
  ├─ List<BlockWidget>             // 每个块一个 Widget
  ├─ FocusController               // 焦点链管理
  └─ KeyboardInterceptor           // Enter / Backspace / Tab 截获

BlockWidget
  ├─ blockId: String
  ├─ isFocused: bool                // 由 FocusController 驱动
  ├─ build():
  │     if isFocused → EditableBlockView（TextField + 源码态）
  │     else         → RenderedBlockView（Inline AST 渲染）
  └─ onTap() → FocusController.focus(blockId)

EditableBlockView
  ├─ TextEditingController
  ├─ 当前 block 的 source markdown
  └─ onChange(text) → EditorStateNotifier.updateBlockText

RenderedBlockView
  ├─ BlockRendererRegistry.get(block.runtimeType)
  └─ Renderer.build(block, inlineRegistry)
```

#### 焦点机制

```
FocusController
  ├─ focusedBlockId: ValueNotifier<String?>
  ├─ focus(blockId) → 旧块失焦（重渲染为 RenderedBlock）+ 新块聚焦
  ├─ moveUp() / moveDown() → 焦点移到上/下一块
  ├─ enterAt(blockId, offset) → 拆分块为两块，新块聚焦
  ├─ backspaceAtStart(blockId) → 与前一块合并
  └─ tabAt(blockId, offset) → 调整缩进（列表场景）
```

#### 块类型与源码态切换策略

| BlockType | 聚焦态显示 | 非聚焦态渲染 |
|-----------|----------|------------|
| Heading | TextField，含 `# ` 前缀 | 渲染为大字号 + 加粗 |
| Paragraph | TextField，纯 inline | 渲染所有 inline 节点 |
| List item | TextField，含 `- ` / `1. ` 前缀 | 渲染 + 项目符号 |
| Code block | 多行 TextField，含 ` ``` ` 围栏 | 高亮 + 等宽字体 |
| Table | **特例**：弹出表格编辑器 | 渲染为表格 |
| Blockquote | TextField，含 `> ` 前缀 | 渲染 + 左边框 |
| Mermaid | 多行 TextField，含 ` ```mermaid ` | 渲染为 SVG |
| Image | 输入框（url + alt） | 渲染图片 |
| HorizontalRule | 自动插入 | 渲染水平线 |

#### 关键设计决策

1. **聚焦块不渲染公式/链接**：避免光标位置漂移。聚焦态显示源码（`$\alpha$` / `[text](url)`），失焦态渲染最终样式。
2. **块级粒度**：不引入"行级"或"字级"渲染（如 Notion 的字符级 WYSIWYG），降低复杂度。
3. **表格例外**：表格作为整体编辑，弹出独立编辑器（点击 cell 进入）。
4. **撤销重做基于 AST diff**：每次 `updateBlockText` 产生 `(oldBlock, newBlock)` 对，推入 HistoryManager。

#### 性能策略

- **虚拟化列表**：`ScrollablePositionList`（dart `scrollable_position_list` 包）替代 `ListView.builder`，支持大文档
- **增量解析**：仅聚焦块解析，非聚焦块缓存
- **AST 浅比较**：`Block` 不可变，`oldBlock == newBlock` 时跳过 rebuild
- **WebView 渲染队列**：公式/Mermaid 异步渲染，结果缓存到 RenderCacheProvider

---

### 2.2 Markdown 引擎（AST-based）

#### Document Model 设计

```dart
// data/models/document_model.dart

class DocumentModel {
  final String id;
  final FrontMatter? frontMatter;        // YAML 元数据
  final List<Block> blocks;                // 块序列
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // copyWith / equality / hashCode
}

sealed class Block {
  final String blockId;                   // 唯一标识，跨重解析稳定
  final SourceRange? sourceRange;         // 在原始 markdown 中的位置（错误定位 + 序列化）
  const Block({required this.blockId, this.sourceRange});
}

// 现有保留
class HeadingBlock extends Block {
  final int level;
  final List<InlineNode> children;
}

class ParagraphBlock extends Block {
  final List<InlineNode> children;
}

class ListBlock extends Block {
  final List<InlineNode> children;
  final bool ordered;
  final int indent;
  final bool checked;                     // 新：任务列表
}

class CodeBlock extends Block {
  final String code;
  final String? language;
}

class TableBlock extends Block {
  final List<List<InlineNode>> cells;     // 改：cells 含 inline（支持链接）
  final int columnCount;
}

class BlockquoteBlock extends Block {
  final List<InlineNode> children;
  final int level;                        // 新：嵌套引用
}

class MermaidBlock extends Block {
  final String code;
}

// 新增
class ImageBlock extends Block {
  final String url;
  final String? alt;
  final String? title;
}

class HorizontalRuleBlock extends Block {}

class EmptyBlock extends Block {}          // 空行

// === Inline 节点 ===

sealed class InlineNode {
  final SourceRange? sourceRange;
  const InlineNode({this.sourceRange});
}

class TextNode extends InlineNode { ... }

class FormulaNode extends InlineNode {
  final String latex;
  final bool displayMode;
}

class BoldNode extends InlineNode {
  final List<InlineNode> children;
}

class ItalicNode extends InlineNode { ... }       // 新
class StrikethroughNode extends InlineNode { ... } // 新
class InlineCodeNode extends InlineNode { ... }    // 新

class LinkNode extends InlineNode {
  final List<InlineNode> children;        // 链接文本可以是任意 inline
  final String url;
  final String? title;
}

class ImageNode extends InlineNode { ... }         // 新：行内图片
class LineBreakNode extends InlineNode {}          // 新：硬换行
```

#### 解析器架构

```dart
// core/parser/markdown_parser.dart

class MarkdownParser {
  DocumentModel parse(String markdown) {
    // 1. 切分 front matter
    // 2. 按行扫描，识别块边界
    // 3. 对每个块调用 _parseBlock(lineBlock)
    // 4. 对块内 inline 调用 _parseInline(text)
    // 5. 为每个块分配稳定 blockId（基于内容 hash + 位置）
  }
  
  Block _parseBlock(LineBlock lineBlock) {
    return switch (lineBlock.type) {
      LineType.heading => _parseHeading(...),
      LineType.codeFence => _parseCode(...),
      // ...
    };
  }
  
  List<InlineNode> _parseInline(String text) {
    // 优先级（见 ADR-0004）：
    // 1. 图片 ![alt](url)
    // 2. 公式 $...$ / $$...$$（FormulaExtractor）
    // 3. 链接 [text](url)
    // 4. 行内代码 `code`
    // 5. 加粗 **text**
    // 6. 斜体 *text* / _text_
    // 7. 删除线 ~~text~~
    // 8. 硬换行 \n
    // 9. 剩余纯文本
  }
}

class MarkdownSerializer {
  String serialize(DocumentModel model) {
    // 1. 写 front matter
    // 2. 逐块序列化，块间空行分隔
    // 3. 块内 inline 序列化保留原始标记
  }
  
  String _serializeBlock(Block block) { ... }
  String _serializeInline(InlineNode node) { ... }
}

class IncrementalParser {
  // 单块重解析
  Block reparseBlock(Block oldBlock, String newSource) {
    // 保留 oldBlock.blockId
    // 重新解析 source → 新 Block
  }
}
```

#### 关键设计决策

1. **AST 不可变**：所有 Block / InlineNode 不可变，变更通过 `copyWith` 创建新对象
2. **blockId 稳定**：跨重解析保持相同，用于焦点追踪 + AST diff
3. **sourceRange 可选**：仅在需要错误定位 / 编辑器跳转时填充，平时为 null 节省内存
4. **Serializer 保格式**：尽量保留用户原始标记（`**bold**` 不被改写为 `__bold__`）
5. **不引入第三方库**：自研解析器（见 [ADR-0004](file:///d:/Projects/Active/math/docs/ADR/0004-markdown-parser-extension-strategy.md)）

---

### 2.3 数据层（单一真相源）

#### 存储架构

```
┌──────────────────────────────────────────────────────┐
│ UI / Provider                                         │
└──────────────────────────────────────────────────────┘
                    ↓
┌──────────────────────────────────────────────────────┐
│ FileRepository（domain/services/file_repository.dart）│
│   - listDocuments() → List<DocumentMetadata>          │
│   - readDocument(id) → DocumentModel                  │
│   - writeDocument(model) → void                       │
│   - deleteDocument(id) → void                         │
│   - renameDocument(id, newTitle) → void              │
│   - importFile(path) → DocumentId                     │
│   - exportDocument(id, destPath) → void               │
└──────────────────────────────────────────────────────┘
        ↓                            ↓
┌──────────────────────┐   ┌─────────────────────────┐
│ .md 文件存储          │   │ 元数据存储              │
│ /documents/*.md       │   │ SharedPreferences kv    │
└──────────────────────┘   │   - lastOpened          │
                            │   - recents: [ids]       │
                            │   - favorites: [ids]    │
                            └─────────────────────────┘
```

#### 迁移逻辑（一次性，幂等）

```
StorageMigration.migrate():
  if exists(formula_fix_documents.json):
    backup ← read(json) → write(json.bak)
    docs ← parse(json)
    for doc in docs:
      safeTitle ← sanitize(doc.title)
      path ← "/documents/${safeTitle}.md"
      write(path, doc.content)
      metadata[id] ← {title: doc.title, createdAt, updatedAt}
    writeMetadata(metadata)
    # 不删 json（保留 .bak）
```

#### DocumentMetadata 设计

```dart
class DocumentMetadata {
  final String id;                // = 文件名（无扩展名）
  final String title;             // 用于显示
  final String filePath;           // 绝对路径
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isFavorite;
  final int openCount;
  final DateTime? lastOpenedAt;
  
  // copyWith
}
```

#### 关键设计决策

1. **文件名 = 文档 ID**：简单直观，避免 ID 与文件名不一致
2. **同名冲突处理**：自动追加 `_2` / `_3`
3. **元数据 kv 存储**：不引入 SQLite，避免平台依赖。如果元数据复杂化（标签、目录），Phase 4 再评估 SQLite
4. **导入 / 导出**：导入外部 .md 时复制到 `/documents/`；导出时复制到用户选择目录
5. **front matter**：元数据可同步写入 .md front matter（YAML header），实现跨设备同步

---

### 2.4 渲染系统（统一）

#### Renderer Registry 架构

```dart
// domain/editor/block_registry.dart

abstract interface class BlockRenderer<T extends Block> {
  Widget build(BuildContext context, T block, InlineRenderer inlineRenderer);
}

class BlockRendererRegistry {
  final Map<Type, BlockRenderer> _renderers;
  
  register<T extends Block>(BlockRenderer<T> renderer) { ... }
  Widget build(BuildContext context, Block block, InlineRenderer inlineRenderer) { ... }
}

class InlineRenderer {
  final RenderCacheProvider cache;       // 公式 / Mermaid / 图片缓存
  final ThemeProvider theme;
  
  List<InlineSpan> buildSpans(List<InlineNode> nodes) { ... }
  Widget buildWidget(InlineNode node) { ... }
}
```

#### 各渲染器职责

| Renderer | 输入 | 输出 | 后端 | 缓存策略 |
|----------|------|------|------|---------|
| HeadingRenderer | HeadingBlock | Text Span | Flutter Text | 无（即时） |
| ParagraphRenderer | ParagraphBlock | RichText | Flutter Text | 无 |
| ListRenderer | ListBlock | Row(bullet + RichText) | Flutter | 无 |
| CodeBlockRenderer | CodeBlock | 高亮代码 | highlight.js（WebView / dart） | 按 language + code hash 缓存 |
| TableRenderer | TableBlock | Table Widget | Flutter Table | 无 |
| BlockquoteRenderer | BlockquoteBlock | Container + RichText | Flutter | 无 |
| MermaidRenderer | MermaidBlock | SVG Widget | WebView | 按 code hash + theme 缓存 |
| ImageRenderer | ImageBlock / ImageNode | Image Widget | cached_network_image | 标准 HTTP 缓存 |
| FormulaInlineRenderer | FormulaNode | SVG / Text | WebView | 按 latex + theme 缓存 |
| LinkInlineRenderer | LinkNode | TextSpan + onTap | Flutter | 无 |

#### 公式 / Mermaid 渲染策略

```
FormulaInlineRenderer
  ├─ RenderCacheProvider.get(latex, theme)
  │     ├─ 命中 → 直接 Widget
  │     └─ 未命中 → 入队 WebView
  ├─ WebView 队列（共享 InAppWebView）
  │     ├─ 单控制器 + 并发上限 4
  │     ├─ v2 console 协议（DOM payload）
  │     └─ 超时 30s → fallback 纯文本
  └─ 结果写回 RenderCacheProvider
```

#### 代码高亮策略（待 ADR-0007 决策）

候选方案：
- **A. highlight.js + WebView**：与公式/Mermaid 共享 WebView，性能好但启动慢
- **B. flutter_highlight（dart 原生）**：无 WebView 开销，但语言覆盖有限
- **C. 自研轻量 lexer**：可控但维护成本高

**建议**：方案 B 起步，方案 A 作为复杂语言（如 Rust / Kotlin）的 fallback。

#### 图片渲染策略

```
ImageRenderer
  ├─ 本地路径 → Image.file
  ├─ 网络 URL → cached_network_image
  ├─ data URI → Image.memory
  └─ 占位 + 错误态
```

#### 关键设计决策

1. **统一渲染接口**：所有 Renderer 通过 Registry 注册，新增块类型只需注册 Renderer
2. **WebView 集中管理**：公式 + Mermaid + 代码高亮共享一个隐藏 WebView
3. **缓存隔离**：公式（svg / png）/ Mermaid（svg）/ 代码高亮（html）各自独立 cache key
4. **错误隔离**：单个 Renderer 失败不影响其他块，显示 fallback 占位

---

### 2.5 状态管理（Riverpod 重组）

#### Provider 架构

```
providers/
├── editor_state_provider.dart
│   └── editorStateProvider: StateNotifierProvider<EditorStateNotifier, EditorState>
│
├── document_list_provider.dart
│   └── documentListProvider: StateNotifierProvider<DocumentListNotifier, AsyncValue<List<DocumentMetadata>>>
│
├── render_cache_provider.dart
│   └── renderCacheProvider: StateNotifierProvider<RenderCacheNotifier, RenderCacheState>
│
├── theme_provider.dart
│   └── themeProvider: StateNotifierProvider<ThemeNotifier, AppTheme>
│
├── settings_provider.dart
│   └── settingsProvider: StateNotifierProvider<SettingsNotifier, Settings>
│
└── shared_providers.dart
    ├── sharedPreferencesProvider: FutureProvider<SharedPreferences>
    ├── fileRepositoryProvider: Provider<FileRepository>
    ├── parserProvider: Provider<MarkdownParser>
    ├── serializerProvider: Provider<MarkdownSerializer>
    ├── blockRegistryProvider: Provider<BlockRendererRegistry>
    └── formulaServiceProvider: Provider<FormulaSvgService>
```

#### EditorState 设计

```dart
class EditorState {
  final DocumentModel document;
  final String? focusedBlockId;
  final int? cursorOffset;                // 当前光标位置
  final SelectionRange? selection;       // 选区
  final HistoryStack history;             // 撤销重做栈
  final bool isDirty;                     // 是否有未保存改动
}

class EditorStateNotifier extends StateNotifier<EditorState> {
  void openDocument(DocumentId id) { ... }
  void updateBlockText(String blockId, String newSource) { ... }   // 增量解析
  void focusBlock(String? blockId) { ... }
  void splitBlock(String blockId, int offset) { ... }
  void mergeBlocks(String upperBlockId, String lowerBlockId) { ... }
  void insertBlockAfter(String blockId, Block newBlock) { ... }
  void deleteBlock(String blockId) { ... }
  void moveBlock(String blockId, int delta) { ... }
  
  void undo() { ... }
  void redo() { ... }
  
  void save() async { ... }                // 调 FileRepository.write
}
```

#### 关键设计决策

1. **单一编辑器状态**：所有编辑器状态集中在 `EditorState`，避免多个 StateProvider 散乱
2. **HistoryStack 基于 AST diff**：每次 updateBlockText 产生 (oldBlock, newBlock)，栈深度 50
3. **renderCacheProvider 独立**：渲染缓存与编辑器状态解耦，避免编辑时频繁失效
4. **autoDispose 谨慎使用**：编辑器状态不能 autoDispose（用户切换屏幕需保留）
5. **删除** `previewModeProvider`（WYSIWYG 无切换）、`isExportingProvider` 保留但下沉到 ExportService 内部状态

#### Provider 依赖图

```
sharedPreferencesProvider
    ↓
fileRepositoryProvider   parserProvider   serializerProvider
    ↓                       ↓                  ↓
documentListProvider   editorStateProvider   formulaServiceProvider
    ↓                       ↓                  ↓
    └────────────────── renderCacheProvider ───┘
                              ↓
                       blockRegistryProvider
                              ↓
                       BlockEditor widget
```

---

## 3. 重构顺序

按风险从低到高、依赖从底到上排序：

### Stage R1：地基重构（数据层 + Provider 重组）

**目标**：解决多存储源问题，统一 Provider，为后续重构扫清地基。

**任务**：
1. 实现 `FileRepository` 接口（封装现有 `DocumentService` + `FileService`）
2. 实现 `StorageMigration`（JSON → .md，幂等 + 备份）
3. 合并 `providers.dart` 与 `editor_providers.dart` 的重复 Provider
4. 修复 [editor_screen.dart:230-253](file:///d:/Projects/Active/math/flutter_app/lib/presentation/screens/editor_screen.dart#L230-253) 错误 detail 透传
5. 启用 `DocumentListScreen` 路由（修复 P0 #3）
6. 修正路由初始位置为文档列表

**风险**：
- 数据迁移丢用户文档（缓解：备份 + 回滚）
- Provider 重命名导致状态丢失（缓解：单独 PR，不混功能改动）

**退出条件**：
- 单一存储源（.md 文件）
- 无重复 Provider
- 无死代码路由
- 错误消息对用户友好

---

### Stage R2：解析器与 Document Model

**目标**：建立完整 AST，补齐缺失的 Markdown 元素，为 WYSIWYG 提供数据基础。

**任务**：
1. 设计 `DocumentModel` + `Block` + `InlineNode` 体系（替换现有 `Document` + `DocumentElement` + `InlineElement`）
2. 重写 `MarkdownParser`，输出 `DocumentModel`
3. 实现 `MarkdownSerializer`（AST → Markdown，保格式）
4. 实现 `IncrementalParser`（单块重解析）
5. 补齐 7 类缺失元素（按 ADR-0004 批次）
6. 同步更新 PDF/Word/TXT 导出器，消费新 AST
7. 同步更新现有 `PreviewContent`，消费新 AST（仍保留 Preview 模式作为过渡）

**风险**：
- AST 类型变化破坏现有导出器与所有 renderer（缓解：sealed class 编译期检查 + 同步 PR）
- 序列化保格式难（缓解：参考 `cmark` 实现，必要时降级为"语义保真"而非"字符保真"）
- 增量解析与全量解析结果不一致（缓解：随机测试 + 黄金测试集）

**退出条件**：
- `DocumentModel` 含 13 种 Block + 10 种 InlineNode
- Markdown → AST → Markdown 往返保真度 ≥ 95%
- 现有测试全部通过 + 新增元素测试覆盖

---

### Stage R3：渲染系统统一

**目标**：建立 Renderer Registry，统一公式 / 代码 / 表格 / 图片 / Mermaid 渲染。

**任务**：
1. 实现 `BlockRendererRegistry` + `InlineRenderer`
2. 迁移现有 8 个 Renderer 到新接口
3. 重构 `FormulaSvgService` / `MermaidService` 为 instance + DI
4. 实现 `RenderCacheProvider`（替代现有静态缓存）
5. 实现代码高亮（按 ADR-0007 决策）
6. 实现图片渲染（cached_network_image）
7. WebView 共享控制器重构（隐藏 `MermaidHost` 提到 `main.dart`，所有渲染器共享）

**风险**：
- 缓存策略改变导致性能回归（缓解：基准测试对比）
- WebView 实例化时机错（缓解：App 启动即预热，加 ready 标志）
- 图片缓存占内存（缓解：LRU + 上限 50 张）

**退出条件**：
- 所有 Renderer 通过 Registry 注册
- 无静态缓存状态
- 公式 / Mermaid / 图片渲染统一走 RenderCacheProvider

---

### Stage R4：编辑器内核 WYSIWYG

**目标**：替换 `EditorScreen` + `PreviewContent` 双模式为 `WysiwygEditorScreen` 单模式。

**任务**：
1. 实现 `BlockEditor`（容器 + 焦点链 + 键盘拦截）
2. 实现 `BlockWidget`（聚焦 / 非聚焦切换）
3. 实现 `EditableBlockView` + `RenderedBlockView`
4. 实现 `FocusController`（焦点转移 + 块拆分 / 合并 / 删除 / 移动）
5. 实现 `EditorStateNotifier`
6. 实现 `HistoryManager` 基于 AST diff
7. 实现 `WysiwygEditorScreen`（替代 `EditorScreen`）
8. Feature flag 切换：`const enableWysiwyg = true`
9. 移除 `previewModeProvider` + 编辑/预览切换按钮
10. 移除预览卡片包裹（沉浸式全屏）

**风险**（最高风险阶段）：
- 焦点机制 bug 导致光标丢失 / 跳跃（缓解：每块类型独立测试 + 集成测试）
- 大文档性能（缓解：虚拟化列表 + 增量解析 + AST 浅比较）
- 用户习惯变更（缓解：保留 feature flag 回退路径 1 个版本）
- 富文本编辑边界情况（多选 / 复制粘贴 / 拖拽）

**退出条件**：
- 用户不需要切换"编辑/预览"
- 1000 行文档输入流畅（每按键 < 16ms）
- WebView 冷启动 < 500ms 或预热后无感

---

### Stage R5：体验完善

**目标**：对齐 Typora 专业写作体验。

**任务**（按价值排序）：
1. 大纲 / TOC 侧滑面板，跳转标题
2. 文件树侧滑
3. 多套主题（GitHub / Night / Sepia / Newsprint）
4. 字号可缩放（双指 + 系统设置）
5. 焦点模式 / 打字机模式
6. 实时字数统计（底部状态栏）
7. 撤销 / 重做按钮接入 UI
8. 自动配对（`$` / `(` / `[` / `*`）
9. 表格可视化编辑
10. 快捷键支持（Android 物理键盘 + Web）
11. 导出进度反馈
12. 自定义 CSS 主题

**风险**：
- 主题多导致样式维护成本（缓解：Token 系统 + 主题测试套件）
- 自动配对干扰用户（缓解：可关闭 + 智能识别上下文）

**退出条件**：
- Typora 21 项核心特性对齐度 ≥ 80%

---

## 4. 阶段目标对照表

| Stage | 核心目标 | 风险等级 | 依赖 |
|-------|---------|---------|------|
| R1 | 数据层单一真相源 + Provider 统一 | 中（数据迁移） | 无 |
| R2 | 完整 AST + 解析器 + 序列化器 | 中（破坏性变更） | R1 |
| R3 | 渲染系统统一 + WebView 集中管理 | 中（性能回归） | R2 |
| R4 | Block-based WYSIWYG 编辑器内核 | **高**（核心范式重构） | R1 + R2 + R3 |
| R5 | 体验完善，对齐 Typora | 低 | R4 |

## 5. 阶段风险总览

### R1 风险

| 风险 | 概率 | 影响 | 缓解 |
|------|------|------|------|
| 数据迁移丢用户文档 | 中 | 极高 | 备份 .bak + 回滚脚本 + 幂等迁移 |
| Provider 重命名状态丢失 | 高 | 中 | 单独 PR + release notes 告知 |
| 路由初始位置改变用户感知 | 高 | 低 | 引导提示 |

### R2 风险

| 风险 | 概率 | 影响 | 缓解 |
|------|------|------|------|
| AST 类型变化破坏导出器 | 高 | 高 | sealed class 编译期检查 + 同步 PR |
| 序列化保格式失败 | 中 | 中 | 黄金测试集 + 必要时降级为语义保真 |
| 增量解析与全量解析不一致 | 中 | 高 | 随机测试 + 不一致时降级为全量 |

### R3 风险

| 风险 | 概率 | 影响 | 缓解 |
|------|------|------|------|
| 缓存策略性能回归 | 中 | 中 | 基准测试 + 缓存命中率监控 |
| WebView 实例化时机 | 高 | 中 | 启动预热 + ready 标志 + 等待超时 |
| 图片缓存内存占用 | 中 | 中 | LRU + 上限 50 张 + 弱引用 |

### R4 风险（最高）

| 风险 | 概率 | 影响 | 缓解 |
|------|------|------|------|
| 焦点机制 bug | 高 | 极高 | 块类型独立测试 + 集成测试 + 灰度发布 |
| 大文档卡顿 | 中 | 高 | 虚拟化 + 增量解析 + 16ms 帧预算 |
| 用户习惯不适 | 高 | 中 | Feature flag 回退 + 1 版本兼容期 |
| 富文本边界情况 | 高 | 中 | 多选 / 粘贴 / 拖拽专项测试 |
| 撤销重做栈溢出 | 低 | 中 | 50 步上限 + 内存监控 |

### R5 风险

| 风险 | 概率 | 影响 | 缓解 |
|------|------|------|------|
| 主题样式漂移 | 中 | 低 | Token 系统 + 主题测试套件 |
| 自动配对干扰 | 中 | 低 | 可关闭 + 上下文识别 |

---

## 6. 与现有 ADR 的对应关系

| Stage | 涉及 ADR | 是否需新增 ADR |
|-------|---------|--------------|
| R1 | ADR-0003（存储单一真相） | 是：ADR-0007 StorageMigration 设计 |
| R2 | ADR-0004（解析器扩展） | 是：ADR-0008 DocumentModel 设计 |
| R3 | - | 是：ADR-0009 Renderer Registry、ADR-0010 代码高亮选型、ADR-0011 WebView 共享 |
| R4 | - | 是：ADR-0012 Block-based WYSIWYG、ADR-0013 FocusController、ADR-0014 增量解析 |
| R5 | - | 是：按需新增主题 / 大纲等 ADR |

---

## 7. 关键技术决策摘要

| 决策点 | 选择 | 理由 |
|--------|------|------|
| 编辑器范式 | Block-based WYSIWYG | 对齐 Typora；规避字符级 WYSIWYG 复杂度 |
| AST 设计 | sealed class + 不可变 | Dart 3 编译期检查 + Riverpod 友好 |
| blockId 稳定策略 | 内容 hash + 位置 | 焦点追踪 + AST diff |
| 解析器实现 | 自研扩展（不引第三方） | 与导出器 / WYSIWYG 紧耦合，需自定义控制 |
| 序列化保真度 | 语义保真 + 尽量字符保真 | 平衡实现成本与用户体验 |
| 存储方案 | .md 文件 + kv 元数据 | 用户可访问 + 跨平台同步 |
| 渲染缓存 | 独立 RenderCacheProvider | 与编辑器状态解耦 |
| WebView 策略 | 单控制器 + 共享队列 | 启动开销分摊 + 缓存复用 |
| 状态管理 | EditorStateNotifier 集中 | 单一编辑器状态源 |
| Feature flag | 是 | R4 渐进式切换 + 回退 |
| 撤销重做 | AST diff 栈 | 粒度合适 + 可序列化 |

---

## 8. 不在本次方案范围内的事项

1. **协同编辑**（CRDT / OT）：Phase 4 评估
2. **AI 辅助写作**：Phase 4 评估
3. **桌面端原生适配**：Phase 4
4. **iOS 平台**：Phase 3 评估
5. **文档加密**：Phase 4
6. **插件系统**：Phase 4+

---

## 9. 评审结论

### 9.1 可行性

**结论**：方案可行，但 R4 是高风险阶段，需要充分测试 + 灰度发布。

### 9.2 关键成功因素

1. **R2 AST 设计的稳健性**：决定后续 R3 / R4 能否平滑推进
2. **R4 焦点机制的可靠性**：决定 WYSIWYG 体验是否成立
3. **Feature flag 的执行纪律**：决定 R4 失败时能否回退
4. **测试覆盖**：每个 Stage 退出条件必须有自动化验证

### 9.3 建议优先级调整

如果资源受限，可考虑：
- **优先 R1 + R2 + R4 简化版**：先实现块级编辑，但不追求完整 WYSIWYG（聚焦块编辑、非聚焦块渲染），R3 渲染系统可借用现有 Renderer
- **延后 R5**：体验完善可分多次小版本

### 9.4 风险红线

**不可接受的风险**：
- 数据迁移导致用户文档丢失 → 必须 backup + 回滚
- R4 上线后无法回退 → 必须 feature flag
- 测试覆盖 < 70% 即上线 R4 → 必须达到 80%+

---

## 10. 下一步行动建议

1. **本方案评审**：召集相关人员评审本文档，确认范围与优先级
2. **补齐 ADR**：按 §6 列表新增 ADR-0007 至 ADR-0014
3. **更新 ROADMAP**：将 [ROADMAP.md](file:///d:/Projects/Active/math/docs/ROADMAP.md) 的 Phase 1-3 与本方案 R1-R5 对齐
4. **启动 R1**：R1 不依赖 R2-R5，可立即启动
5. **建立基准测试**：R3 启动前建立渲染性能基准，用于回归对比

---

**文档版本**：v1.0  
**评审日期**：2026-07-18  
**评审人**：架构评审人员

---

## 附录 A：相关文档索引

- [AGENTS.md](file:///d:/Projects/Active/math/AGENTS.md) — AI 协作规范
- [ARCHITECTURE.md](file:///d:/Projects/Active/math/docs/ARCHITECTURE.md) — 当前架构总览
- [CRITICAL_REVIEW.md](file:///d:/Projects/Active/math/docs/CRITICAL_REVIEW.md) — 现状批判报告
- [ROADMAP.md](file:///d:/Projects/Active/math/docs/ROADMAP.md) — 路线图
- [ADR-0003](file:///d:/Projects/Active/math/docs/ADR/0003-storage-single-source-md-files.md) — 存储单一真相
- [ADR-0004](file:///d:/Projects/Active/math/docs/ADR/0004-markdown-parser-extension-strategy.md) — 解析器扩展
- [ADR-0005](file:///d:/Projects/Active/math/docs/ADR/0005-exporter-facade-dependency-injection.md) — 导出器 facade
