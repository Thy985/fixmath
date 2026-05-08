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
│                     Flutter Framework                       │
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
│  │              Business Layer (业务层)                  │   │
│  │  ┌───────────┐ ┌───────────┐ ┌───────────┐           │   │
│  │  │  Editor   │ │  Render   │ │  Export   │           │   │
│  │  │  Service  │ │  Service  │ │  Service  │           │   │
│  │  └───────────┘ └───────────┘ └───────────┘           │   │
│  └─────────────────────────────────────────────────────┘   │
│                            │                                │
│                            ▼                                │
│  ┌─────────────────────────────────────────────────────┐   │
│  │               Core Layer (核心层)                    │   │
│  │  ┌───────────┐ ┌───────────┐ ┌───────────┐           │   │
│  │  │  Markdown │ │   Latex   │ │  Mermaid  │           │   │
│  │  │  Parser   │ │  Engine   │ │  Engine   │           │   │
│  │  └───────────┘ └───────────┘ └───────────┘           │   │
│  └─────────────────────────────────────────────────────┘   │
│                            │                                │
│                            ▼                                │
│  ┌─────────────────────────────────────────────────────┐   │
│  │           Platform Layer (平台层)                    │   │
│  │  ┌───────────┐ ┌───────────┐ ┌───────────┐           │   │
│  │  │   File    │ │  Clipboard│ │   Share   │           │   │
│  │  │   System  │ │   Handler │ │   Plugin  │           │   │
│  │  └───────────┘ └───────────┘ └───────────┘           │   │
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
| **状态管理** | flutter_bloc / Riverpod | 最新 | 推荐 Riverpod |
| **Markdown** | flutter_markdown | ^0.6.x | Markdown 渲染 |
| **LaTeX 公式** | flutter_math_fork | ^0.6.x | LaTeX 公式渲染 |
| **PDF 生成** | pdf + printing | ^3.10.x | 本地 PDF 生成 |
| **Word 生成** | docx | ^8.x | Word 文档生成 |
| **Mermaid** | flutter_inappwebview | ^6.x | WebView 渲染 |
| **文件处理** | path_provider | ^2.x | 应用目录访问 |
| **分享** | share_plus | ^7.x | 系统分享功能 |
| **文件选择** | file_picker | ^6.x | 文件选择器 |

### 2.2 依赖关系图

```
flutter_markdown
       │
       ▼
┌──────────────────┐     ┌──────────────────┐
│  Markdown Parser │────▶│   Render Engine  │
└──────────────────┘     └──────────────────┘
       │                         │
       │                         ▼
       │                ┌──────────────────┐
       │                │ flutter_math     │
       │                │     _fork        │
       │                └──────────────────┘
       │                         │
       ▼                         ▼
┌──────────────────────────────────────────┐
│              Export Service               │
├──────────────┬───────────────────────────┤
│              │                           │
▼              ▼                           ▼
┌────────┐  ┌────────┐              ┌────────┐
│   pdf  │  │  docx  │              │  Share │
└────────┘  └────────┘              └────────┘
```

---

## 3. 模块设计

### 3.1 核心模块

#### 3.1.1 Markdown 解析器 (MarkdownParser)

| 项目 | 内容 |
|------|------|
| **职责** | 解析 Markdown 文本，提取文本和公式片段 |
| **输入** | 原始 Markdown 字符串 |
| **输出** | 解析后的元素列表 (文本块、公式块) |
| **关键方法** | `parse(String content) -> List<MarkdownElement>` |

```dart
// 核心接口设计
abstract class MarkdownParser {
  /// 解析 Markdown 文本
  List<MarkdownElement> parse(String content);

  /// 提取公式片段
  List<FormulaElement> extractFormulas(String content);
}

class MarkdownElement {
  final ElementType type; // text, formula, heading, list, code
  final String content;
  final Map<String, dynamic>? attributes;
}
```

#### 3.1.2 LaTeX 渲染引擎 (LatexEngine)

| 项目 | 内容 |
|------|------|
| **职责** | 渲染 LaTeX 公式为 Flutter Widget |
| **输入** | LaTeX 公式字符串 |
| **输出** | Math.tex() Widget |
| **关键方法** | `render(String latex, {bool displayMode}) -> Widget` |

#### 3.1.3 导出服务 (ExportService)

| 项目 | 内容 |
|------|------|
| **职责** | 负责 PDF/Word 文件生成 |
| **输入** | 解析后的文档元素列表 |
| **输出** | Uint8List 文件字节流 |
| **关键方法** | `exportToPdf(List<Element> elements) -> Future<Uint8List>`<br>`exportToWord(List<Element> elements) -> Future<Uint8List>` |

```dart
abstract class ExportService {
  /// 导出为 PDF
  Future<Uint8List> exportToPdf(List<DocumentElement> elements);

  /// 导出为 Word
  Future<Uint8List> exportToWord(List<DocumentElement> elements);

  /// 分享文件
  Future<void> shareFile(Uint8List bytes, String filename);
}
```

### 3.2 Word 导出：图片桥接策略

由于 `docx` 库不支持直接绘制复杂数学公式，采用**图片桥接法**：

```
1. 解析 Markdown → 获取所有公式位置
      │
      ▼
2. 公式 → flutter_math_fork 离屏渲染
      │      (pixelRatio: 3.0, 300 DPI)
      ▼
3. 渲染结果 → 转为 PNG 图片 (Uint8List)
      │
      ▼
4. docx.addPicture() → 嵌入 Word 文档
      │
      ▼
5. 保存 .docx 文件
```

### 3.3 Mermaid 图表：WebView 离屏渲染

```
1. assets/mermaid.min.js ──加载──▶ 隐形 WebView
                                              │
2. 用户 Mermaid 代码 ──注入──▶ JS 执行
                                              │
3. SVG 输出 ◀──回调── JavascriptChannel
                                              │
4. Flutter 接收 SVG ──展示/导出──▶ 完成
```

---

## 4. 数据流设计

### 4.1 编辑到预览流程

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
│  MarkdownParser │ ──▶ │ MarkdownElement│
└────────┬────────┘     │     List       │
         │              └────────┬────────┘
         │                       │
         ▼                       ▼
┌─────────────────┐     ┌─────────────────┐
│  ExtractFormulas│     │  Render Engine  │
└────────┬────────┘     └────────┬────────┘
         │                       │
         ▼                       ▼
┌─────────────────┐     ┌─────────────────┐
│   FormulaList   │     │  Preview Widget │
│                 │     │  (ListView)     │
└─────────────────┘     └─────────────────┘
```

### 4.2 导出流程

```
用户点击导出
    │
    ├──[PDF]──▶ ExportService.exportToPdf()
    │                 │
    │                 ▼
    │           ┌─────────────────┐
    │           │  Build PDF Page  │
    │           │  - 文本渲染      │
    │           │  - 公式渲染图片  │
    │           └────────┬────────┘
    │                    │
    │                    ▼
    │              ┌─────────────────┐
    │              │   Uint8List     │
    │              │   (PDF 文件)    │
    │              └────────┬────────┘
    │                       │
    └───────────────────────┼───────────────────────┐
                            │                       │
                            ▼                       ▼
                     ┌─────────────┐         ┌─────────────┐
                     │ Save to     │         │   Share     │
                     │ Local File  │         │   Plugin    │
                     └─────────────┘         └─────────────┘
```

---

## 5. 目录结构设计

```
lib/
├── main.dart                      # 应用入口
├── app.dart                       # App 根组件
│
├── core/                          # 核心层
│   ├── parser/
│   │   ├── markdown_parser.dart  # Markdown 解析器
│   │   └── formula_extractor.dart# 公式提取器
│   ├── engine/
│   │   ├── latex_engine.dart     # LaTeX 渲染引擎
│   │   └── mermaid_engine.dart  # Mermaid 渲染引擎
│   └── utils/
│       ├── constants.dart        # 常量定义
│       └── extensions.dart       # 扩展方法
│
├── data/                          # 数据层
│   ├── models/
│   │   ├── document.dart         # 文档模型
│   │   ├── element.dart          # 元素模型
│   │   └── template.dart         # 模板模型
│   └── repositories/
│       └── document_repo.dart    # 文档仓库
│
├── domain/                        # 业务层
│   ├── services/
│   │   ├── editor_service.dart   # 编辑服务
│   │   ├── render_service.dart   # 渲染服务
│   │   └── export_service.dart   # 导出服务
│   └── providers/
│       ├── editor_provider.dart  # 编辑器状态
│       └── export_provider.dart  # 导出状态
│
├── presentation/                  # 表现层 (UI)
│   ├── screens/
│   │   ├── editor_screen.dart   # 编辑器页面
│   │   ├── preview_screen.dart  # 预览页面
│   │   └── settings_screen.dart # 设置页面
│   ├── widgets/
│   │   ├── editor/
│   │   │   ├── markdown_input.dart
│   │   │   └── formula_field.dart
│   │   ├── preview/
│   │   │   ├── markdown_render.dart
│   │   │   └── formula_widget.dart
│   │   └── common/
│   │       ├── app_button.dart
│   │       └── app_card.dart
│   └── theme/
│       ├── app_theme.dart
│       └── app_colors.dart
│
└── platform/                      # 平台层
    ├── file_system.dart           # 文件系统操作
    ├── clipboard_handler.dart     # 剪贴板处理
    └── share_handler.dart         # 分享处理
```

---

## 6. 关键技术决策

### 6.1 状态管理选型

| 选项 | 优点 | 缺点 | 推荐 |
|------|------|------|------|
| setState | 简单 | 大项目难以维护 | ❌ |
| Provider | 简单易用 | 功能有限 | ⚠️ |
| Riverpod | 功能强、测试友好 | 有学习成本 | ✅ |
| flutter_bloc | 架构清晰 | 样板代码多 | ⚠️ |

**推荐：Riverpod** - 灵活、简洁、适合中大型项目

### 6.2 渲染性能优化

| 策略 | 说明 |
|------|------|
| **分页渲染** | 长文档使用 ListView.builder 懒加载 |
| **公式缓存** | 相同公式只渲染一次，缓存结果 |
| **防抖输入** | 编辑器输入防抖，避免频繁渲染 |
| **图片复用** | 导出时公式图片可复用 |

### 6.3 错误处理策略

| 场景 | 处理方式 |
|------|----------|
| 公式渲染失败 | 显示原始 LaTeX 文本 + 错误提示 |
| 文件保存失败 | 弹窗提示 + 重试选项 |
| 导出失败 | 详细错误信息 + 日志记录 |
| Mermaid 语法错误 | 显示错误位置的红色提示 |

---

## 7. 可扩展性设计

### 7.1 模板系统接口

```dart
abstract class DocumentTemplate {
  String get id;
  String get name;
  String get description;
  Map<String, dynamic> get settings; // 页边距、字体等
  String generateSample(); // 生成示例内容
}
```

### 7.2 导出格式扩展

```dart
abstract class Exporter {
  Future<Uint8List> export(List<DocumentElement> elements);
}

class PdfExporter implements Exporter { }
class DocxExporter implements Exporter { }
// 未来可扩展: HtmlExporter, LatexExporter 等
```

---

## 8. 版本历史

| 版本 | 日期 | 修改内容 |
|------|------|----------|
| v1.0.0 | 2026-05-06 | 初始架构设计 |
