# FormulaFix

一个基于 Flutter 的 Markdown 数学文档编辑器，专为数学试卷、学术论文、项目报告等含 LaTeX 公式与 Mermaid 图表的文档场景设计。支持实时预览、矢量 PDF / Word / 纯文本导出与系统分享。

## 核心能力

| 能力 | 说明 |
|------|------|
| Markdown 编辑 | 标题、段落、有序/无序列表、代码块、引用、表格、空行 |
| LaTeX 公式 | 行内 `$...$` 与块级 `$$...$$`，覆盖 150+ 命令（积分、矩阵、希腊字母等） |
| Mermaid 图表 | ` ```mermaid ` 代码块自动识别并渲染为 SVG |
| 矢量导出 | PDF 优先走 SVG 矢量路径，失败回退 PNG 位图 |
| Word 导出 | 生成符合 ECMA-376 规范的 .docx（含公式图片 + Mermaid SVG） |
| TXT 导出 | 保留 Markdown 语法，公式退化为 `[latex]` |
| 文档管理 | 本地 JSON 持久化、自动保存、剪贴板导入 |
| 多平台 | Android / Windows / Web（共享 WebView 资产，100% 离线） |
| 模板 | 内置数学试卷、学术论文、项目报告三类模板 |
| 错误分类 | `ExportFailure` 7 类分类，UI 按类别展示本地化消息 |

## 快速开始

```bash
cd flutter_app
flutter pub get
flutter run
```

> 注：本项目当前缺失 `pubspec.yaml`，需补齐依赖后才能运行（见 [ARCHITECTURE.md](../docs/ARCHITECTURE.md) 中的"依赖清单"章节）。

## 技术栈

- **框架**：Flutter + Dart 3（sealed class / records / 模式匹配）
- **状态管理**：flutter_riverpod（StateNotifier + StateProvider）
- **路由**：go_router（`/editor`、`/files`）
- **本地存储**：shared_preferences（设置）+ JSON 文件（文档库）
- **PDF 生成**：pdf + pdf/widgets
- **Word 生成**：archive（ZIP 打包 OOXML）
- **公式 / Mermaid 渲染**：flutter_inappwebview + MathJax（tex-svg.js）+ mermaid.min.js
- **SVG 解析**：自研 `SvgParser` + `SvgAst`（不依赖第三方 SVG 库）
- **文件分享**：share_plus、path_provider、file_picker
- **编码兜底**：自研 `decodeBytesAuto`（UTF-8 → GBK → Latin-1 多级解码）

## 项目结构

```
flutter_app/
├── lib/
│   ├── main.dart                      # App 入口
│   ├── core/                          # 基础设施（与业务无关）
│   │   ├── constants/                 # 颜色 / 间距 / 阴影常量
│   │   ├── parser/                    # Markdown + 公式提取
│   │   ├── renderers/                 # SVG AST + SVG→PDF
│   │   ├── router/                    # go_router 配置
│   │   ├── services/                  # 文档 / 文件 / 公式 / Mermaid / 剪贴板
│   │   └── utils/                     # 撤销重做栈
│   ├── data/                          # 数据模型
│   │   └── models/                    # Document / Template
│   ├── domain/                        # 业务领域
│   │   ├── providers/                 # 业务级 Provider
│   │   └── services/
│   │       ├── exporters/             # PDF / Word / TXT 导出器
│   │       └── export_service.dart    # 导出 facade + 错误分类
│   ├── presentation/                  # UI 层
│   │   ├── components/                # 通用组件（loading / bottom sheet）
│   │   ├── screens/                   # 编辑器 / 文档列表 / 文件管理
│   │   ├── theme/                     # 浅色 / 深色主题
│   │   └── widgets/                   # 渲染器、对话框、菜单
│   └── providers/                     # 全局 Provider（编辑器内容 / 暗色模式）
├── test/                              # 单元测试 + 集成测试
├── web/                               # PWA 资产
└── build/                             # 构建产物（不提交）
```

详细架构与目录说明见 [../docs/ARCHITECTURE.md](../docs/ARCHITECTURE.md)。

## 关键设计决策

### 1. 公式 / Mermaid 渲染走共享 WebView

为避免每个公式 / Mermaid 单独起 WebView 的开销，`MermaidRendererHost` 在 `main.dart` 中作为隐藏组件挂载（`Positioned(left: -10000)`），`MermaidService` 持有其 `InAppWebViewController`，`FormulaSvgService` 共享同一控制器。

### 2. SVG 矢量优先 + PNG 位图回退

PDF 导出时优先通过 MathJax 渲染 SVG 嵌入（保持矢量），SVG 失败时回退到 `FormulaPdfRenderer` 的 PNG 缓存。保证文档质量的同时具备健壮性。

### 3. v2 console 协议

旧协议 `LATEX_OK|<id>|<len>|<svg>` 在 SVG 含 `|` 字符时会丢字符。新协议把 SVG 写入隐藏 DOM，console 只传 `LATEX_OK|<id>`，Dart 端通过 `evaluateJavascript` 读取 `textContent`；DOM 不可用时回退到 base64 编码。

### 4. 错误分类与本地化

`classifyError` 把任意异常映射到 `ExportFailure` 枚举（emptyDocument / offline / parseError / renderError / writeError / timeout / unknown），UI 按 `kind` 决定文案，避免 raw stack 泄漏给用户。

### 5. 编码兜底

中国用户的 `.md` 文件常混入 GBK 字节，`decodeBytesAuto` 实现 UTF-8 BOM → 严格 UTF-8 → 容错 UTF-8 → GBK → Latin-1 的多级降级，永不抛错。

## 测试

```bash
cd flutter_app
flutter test
```

测试覆盖：
- Markdown 解析（标题 / 列表 / 表格 / 代码块 / 引用）
- 公式提取（行内 / 块级 / 嵌套）
- SVG 解析与 AST
- 公式渲染计划
- Word OOXML 构建器
- 导出集成（PDF / Word）
- 文档流转端到端
- 文件服务解码

## 相关文档

- [架构与目录说明](../docs/ARCHITECTURE.md)
