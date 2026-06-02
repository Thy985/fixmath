# FormulaFix 架构设计文档

## 1. 架构概述

### 1.1 设计原则

| 原则 | 说明 |
|------|------|
| **纯本地架构** | 100% 离线运行，无服务端依赖 |
| **模块化设计** | 各功能模块职责清晰，独立可测试 |
| **性能优先** | 注重渲染性能优化，避免卡顿 |
| **可扩展性** | 预留功能扩展接口，便于迭代 |

### 1.2 整体架构

```
┌─────────────────────────────────────────────────────────────┐
│                     Flutter Framework                         │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │                   UI Layer (表现层)                   │   │
│  │  ┌───────────┐ ┌───────────┐ ┌───────────┐           │   │
│  │  │  Editor   │ │  Preview  │ │  Export   │           │   │
│  │  │  Screen   │ │  Screen   │ │  Dialog   │           │   │
│  │  └───────────┘ └───────────┘ └───────────┘           │   │
│  └─────────────────────────────────────────────────────┘   │
│                            │                                │
│                            ▼                                │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              Domain Layer (业务层)                   │   │
│  │  ┌───────────┐ ┌───────────┐ ┌───────────┐           │   │
│  │  │  Export   │ │ Document  │ │  Editor   │           │   │
│  │  │  Service  │ │ Provider  │ │ Provider  │           │   │
│  │  └───────────┘ └───────────┘ └───────────┘           │   │
│  └─────────────────────────────────────────────────────┘   │
│                            │                                │
│                            ▼                                │
│  ┌─────────────────────────────────────────────────────┐   │
│  │               Core Layer (核心层)                    │   │
│  │  ┌───────────┐ ┌───────────┐ ┌───────────┐           │   │
│  │  │  Markdown │ │   Latex   │ │  Export   │           │   │
│  │  │  Parser   │ │ Extractor │ │ Utilities │           │   │
│  │  └───────────┘ └───────────┘ └───────────┘           │   │
│  └─────────────────────────────────────────────────────┘   │
│                            │                                │
│                            ▼                                │
│  ┌─────────────────────────────────────────────────────┐   │
│  │           Data Layer (数据层)                        │   │
│  │  ┌───────────┐ ┌───────────┐                        │   │
│  │  │  Document │ │  Template │                        │   │
│  │  │   Model   │ │   Model   │                        │   │
│  │  └───────────┘ └───────────┘                        │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. 技术栈

### 2.1 核心技术选型

| 模块 | 技术/库 | 版本 | 说明 |
|------|---------|------|------|
| **开发框架** | Flutter | 3.x | 跨平台 UI 框架 |
| **语言** | Dart | 3.x | Flutter 专用语言 |
| **状态管理** | flutter_riverpod | ^2.4.5 | 轻量级状态管理 |
| **Markdown** | flutter_markdown | ^0.6.18 | Markdown 渲染 |
| **LaTeX 公式** | flutter_math_fork | ^0.7.4 | LaTeX 公式渲染 |
| **PDF 生成** | pdf + printing | ^3.10.4 | 本地 PDF 生成 |
| **Word 生成** | archive | ^3.4.10 | 手写 XML 生成 |
| **Mermaid** | flutter_inappwebview | ^6.1.5 | WebView 渲染 |
| **文件处理** | path_provider | ^2.1.1 | 应用目录访问 |
| **分享** | share_plus | ^9.0.0 | 系统分享功能 |
| **文件选择** | file_picker | ^8.0.0 | 文件选择器 |

### 2.2 依赖关系图

```
MarkdownParser
       │
       ▼
┌──────────────────┐     ┌──────────────────┐
│ FormulaExtractor │────▶│ DocumentElement  │
└──────────────────┘     │       List       │
       │                 └────────┬────────┘
       │                          │
       ▼                          ▼
┌──────────────────────────────────────────┐
│           ExportService (Domain)          │
├──────────────┬───────────────────────────┤
│              │                           │
▼              ▼                           ▼
┌────────┐  ┌────────┐              ┌────────┐
│   pdf  │  │ archive│              │  Share │
└────────┘  │ (docx) │              └────────┘
            └────────┘
```

---

## 3. 目录结构

```
lib/
├── main.dart                           # 应用入口
│
├── core/                               # 核心层
│   ├── constants/
│   │   └── app_constants.dart         # 常量定义
│   ├── parser/
│   │   ├── markdown_parser.dart       # Markdown 解析器
│   │   └── formula_extractor.dart     # 公式提取器
│   ├── router/
│   │   └── app_router.dart            # 路由配置
│   ├── services/
│   │   ├── clipboard_service.dart      # 剪贴板服务
│   │   ├── document_service.dart       # 文档服务
│   │   ├── export_service.dart         # 导出服务（UI层）
│   │   ├── file_service.dart           # 文件服务
│   │   └── formula_pdf_renderer.dart   # 公式PDF渲染
│   └── utils/
│       └── history_manager.dart        # 历史记录管理
│
├── data/                               # 数据层
│   └── models/
│       ├── document.dart               # 文档模型
│       └── template.dart               # 模板模型
│
├── domain/                             # 业务层
│   ├── providers/
│   │   ├── document_provider.dart      # 文档状态
│   │   └── editor_provider.dart       # 编辑器状态
│   └── services/
│       └── export_service.dart         # 导出服务（业务层）
│
├── presentation/                      # 表现层
│   ├── components/
│   │   ├── bottom_sheet.dart          # 底部弹窗
│   │   └── loading.dart                # 加载指示器
│   ├── screens/
│   │   ├── document_list_screen.dart   # 文档列表
│   │   ├── editor_screen.dart          # 编辑器页面
│   │   └── file_manager_screen.dart    # 文件管理
│   ├── theme/
│   │   └── app_theme.dart              # 主题配置
│   └── widgets/
│       ├── blockquote_renderer.dart     # 引用渲染
│       ├── code_renderer.dart           # 代码渲染
│       ├── editor_bottom_bar.dart      # 底部操作栏
│       ├── export_menu.dart             # 导出菜单
│       ├── heading_renderer.dart        # 标题渲染
│       ├── list_renderer.dart           # 列表渲染
│       ├── markdown_input_field.dart    # Markdown输入框
│       ├── mermaid_renderer.dart        # Mermaid渲染
│       ├── paragraph_renderer.dart       # 段落渲染
│       ├── preview_content.dart         # 预览内容
│       ├── table_renderer.dart         # 表格渲染
│       └── template_selector.dart      # 模板选择
│
└── providers/
    ├── editor_providers.dart           # 编辑器状态管理
    └── providers.dart                  # 全局状态
```

---

## 4. 模块设计

### 4.1 Markdown 解析器

| 项目 | 内容 |
|------|------|
| **职责** | 解析 Markdown 文本，提取各种元素 |
| **输入** | 原始 Markdown 字符串 |
| **输出** | DocumentElement 列表 |
| **关键方法** | `parse(String content) -> List<DocumentElement>` |

**支持元素类型：**
- HeadingElement - 标题
- ParagraphElement - 段落（含公式）
- ListElement - 列表（支持缩进）
- CodeElement - 代码块
- TableElement - 表格
- BlockquoteElement - 引用
- MermaidElement - 图表
- EmptyLineElement - 空行

### 4.2 公式提取器

| 项目 | 内容 |
|------|------|
| **职责** | 从文本中提取 LaTeX 公式 |
| **输入** | 包含公式的文本 |
| **输出** | FormulaMatch 列表 |
| **关键方法** | `extractFormulas(String text) -> List<FormulaMatch>` |

**支持的公式格式：**
- `$$...$$` - 块级公式
- `$...$` - 行内公式
- `\[...\]` - LaTeX 块级公式
- `\ (...)` - LaTeX 行内公式

### 4.3 导出服务

| 项目 | 内容 |
|------|------|
| **职责** | 负责 PDF/Word/Text 文件生成 |
| **输入** | Markdown 字符串或 DocumentElement 列表 |
| **输出** | Uint8List 文件字节流 |

**导出格式：**
- PDF - 使用 pdf 包生成
- Word (.docx) - 手写 OOXML 结构
- Text - 纯文本格式

---

## 5. 数据流设计

### 5.1 编辑到预览流程

```
用户输入
    │
    ▼
┌─────────────────┐
│  TextEditing    │ ◀── 原始输入
│  Controller     │
└────────┬────────┘
         │
         ▼
┌─────────────────┐     ┌─────────────────┐
│  MarkdownParser │ ──▶ │ DocumentElement │
└────────┬────────┘     │     List       │
         │              └────────┬────────┘
         │                       │
         ▼                       ▼
┌─────────────────┐     ┌─────────────────┐
│ FormulaExtractor│     │  Preview Widget │
└────────┬────────┘     └─────────────────┘
         │
         ▼
┌─────────────────┐
│   FormulaList   │
└─────────────────┘
```

### 5.2 导出流程

```
用户点击导出
    │
    ├──[PDF]──▶ ExportService.exportToPdf()
    │                 │
    │                 ▼
    │           ┌─────────────────┐
    │           │  Build PDF Page │
    │           │  - 文本渲染     │
    │           │  - 表格渲染     │
    │           └────────┬────────┘
    │                    │
    │                    ▼
    │              ┌─────────────────┐
    │              │   Uint8List     │
    │              │   (PDF 文件)    │
    │              └────────┬────────┘
    │                       │
    ├──[Word]──▶ ExportService.exportToWord()
    │                 │
    │                 ▼
    │           ┌─────────────────┐
    │           │ Build DOCX XML  │
    │           │ - OOXML 结构    │
    │           │ - 表格 XML      │
    │           └────────┬────────┘
    │                    │
    └────────────────────┼───────────────────────┐
                         │                       │
                         ▼                       ▼
                  ┌─────────────┐         ┌─────────────┐
                  │   Share     │         │   Share     │
                  │   (PDF)     │         │   (Word)    │
                  └─────────────┘         └─────────────┘
```

---

## 6. 组件设计

### 6.1 EditorScreen

**职责：** 主编辑器界面

**子组件：**
- MarkdownInputField - Markdown 输入框
- PreviewContent - 实时预览
- EditorBottomBar - 底部操作栏
- ExportMenu - 导出菜单
- TemplateSelector - 模板选择

### 6.2 PreviewContent

**职责：** Markdown 预览渲染

**渲染规则：**
- 标题使用 HeadingRenderer
- 段落使用 ParagraphRenderer
- 列表使用 ListRenderer
- 代码块使用 CodeRenderer
- 表格使用 TableRenderer
- 引用使用 BlockquoteRenderer
- Mermaid 使用 MermaidRenderer

---

## 7. 状态管理

### 7.1 Riverpod Providers

```dart
// 主题状态
final darkModeProvider = StateNotifierProvider<DarkModeNotifier, bool>

// 预览模式
final previewModeProvider = StateProvider<bool>

// 导出状态
final isExportingProvider = StateProvider<bool>

// 编辑内容
final editorContentProvider = StateNotifierProvider<EditorContentNotifier, String>
```

---

## 8. 版本历史

| 版本 | 日期 | 修改内容 |
|------|------|----------|
| v2.0.0 | 2026-06-02 | 重构代码结构，修复解析器bug，改进导出服务 |
| v1.0.0 | 2026-05-06 | 初始架构设计 |
