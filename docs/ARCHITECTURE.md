# FormulaFix 架构总览

> 本文描述 FormulaFix 的**当前架构、目标架构、已知问题与重构风险**。  
> 所有内容基于实际代码分析，不凭空设计。

---

## 1. 当前架构（As-Is）

### 1.1 六层分层架构

```
┌──────────────────────────────────────────────────┐
│ presentation/    UI 组件、屏幕、主题、对话框、菜单 │
├──────────────────────────────────────────────────┤
│ providers/       全局 Riverpod Provider           │
├──────────────────────────────────────────────────┤
│ domain/          业务领域：导出服务、业务 Provider  │
├──────────────────────────────────────────────────┤
│ data/            数据模型：Document、Template      │
├──────────────────────────────────────────────────┤
│ core/            基础设施：解析器、渲染器、服务     │
├──────────────────────────────────────────────────┤
│ main.dart        App 入口 + ProviderScope         │
└──────────────────────────────────────────────────┘
```

依赖方向严格自上而下。详细目录见 [README.md](file:///d:/Projects/Active/math/flutter_app/README.md)。

### 1.2 模块职责

#### `lib/core/`

| 子模块 | 职责 |
|--------|------|
| `constants/` | 颜色 / 间距 / 阴影常量（[app_constants.dart](file:///d:/Projects/Active/math/flutter_app/lib/core/constants/app_constants.dart)） |
| `parser/` | Markdown 解析 + 公式提取 |
| `renderers/` | 自研 SVG AST + SVG→PDF |
| `router/` | go_router 配置 |
| `services/` | 文档 / 文件 / 公式 / Mermaid / 剪贴板 |
| `utils/` | 撤销重做栈 |

#### `lib/data/`

- `models/document.dart`：sealed class `DocumentElement` + `InlineElement` + `Document`
- `models/template.dart`：内置 3 类模板

#### `lib/domain/`

- `providers/`：业务级 Provider
- `services/export_service.dart`：导出 facade + 错误分类
- `services/exporters/`：PDF / Word / TXT 导出器 + OOXML 拼装
- `services/word_ooxml_templates.dart`：OOXML 模板

#### `lib/presentation/`

- `screens/`：编辑器 / 文档列表（死代码）/ 文件管理
- `widgets/`：渲染器、对话框、菜单
- `components/`：通用组件
- `theme/`：浅色 / 深色主题

#### `lib/providers/`

全局 Provider。**与 `domain/providers/` 职责重叠**，待重构合并。

### 1.3 数据流

#### 编辑流

```
用户输入
  └→ TextEditingController
      └→ _onTextChanged → editorContentProvider.state = text
          ├→ 500ms 防抖 → SharedPreferences
          └→ PreviewContent 重建
              └→ MarkdownParser.parse(content)
                  └→ List<DocumentElement>
                      └→ 各 *Renderer Widget 渲染
```

**问题**：每次按键全量重解析，文档 > 500 行时卡顿。

#### 导出流

```
用户点击导出
  └→ ExportService.exportAndShare
      ├→ 阶段 1: exporter(markdown)
      │   ├→ PDF: parse → collectAllFormulas → FormulaSvgService.preRenderAll
      │   │       → FormulaRenderPlan → PdfExporter 拼装
      │   ├→ Word: parse → FormulaPdfRenderer.preRenderAll → WordOoxmlBuilder
      │   └→ TXT: parse → TextExporter 序列化
      ├→ 阶段 2: getTemporaryDirectory → 写文件 → Share.shareXFiles
      └→ 异常 → classifyError → ExportFailureException → UI 本地化
```

详见 [domain/services/export_service.dart](file:///d:/Projects/Active/math/flutter_app/lib/domain/services/export_service.dart)。

### 1.4 关键设计决策（已落地）

| 决策 | ADR |
|------|-----|
| 项目命名为 FormulaFix，目录结构 6 层 | [ADR-0001](file:///d:/Projects/Active/math/docs/ADR/0001-project-naming-and-structure.md) |
| 状态管理选 Riverpod | [ADR-0002](file:///d:/Projects/Active/math/docs/ADR/0002-state-management-riverpod.md) |
| 存储目标：.md 文件作为单一真相（未达成） | [ADR-0003](file:///d:/Projects/Active/math/docs/ADR/0003-storage-single-source-md-files.md) |
| 解析器扩展策略：补齐缺失元素而非重写 | [ADR-0004](file:///d:/Projects/Active/math/docs/ADR/0004-markdown-parser-extension-strategy.md) |
| 导出器 facade + 依赖注入 | [ADR-0005](file:///d:/Projects/Active/math/docs/ADR/0005-exporter-facade-dependency-injection.md) |
| CI 选 GitHub Actions | [ADR-0006](file:///d:/Projects/Active/math/docs/ADR/0006-ci-github-actions.md) |

---

## 2. 当前架构问题

完整列表见 [CRITICAL_REVIEW.md](file:///d:/Projects/Active/math/docs/CRITICAL_REVIEW.md)。摘要：

### 2.1 P0 阻塞

1. **范式错位**：编辑/预览分离，与 Typora WYSIWYG 灵魂对立  
   证据：[editor_screen.dart:300-321](file:///d:/Projects/Active/math/flutter_app/lib/presentation/screens/editor_screen.dart#L300-321)
2. **三套存储并存**：SharedPreferences / JSON 文档库 / .md 文件互不同步  
   证据：[providers/editor_providers.dart:43-54](file:///d:/Projects/Active/math/flutter_app/lib/providers/editor_providers.dart#L43-54) + [document_service.dart:68-72](file:///d:/Projects/Active/math/flutter_app/lib/core/services/document_service.dart#L68-72) + [file_service.dart:69-77](file:///d:/Projects/Active/math/flutter_app/lib/core/services/file_service.dart#L69-77)
3. **DocumentListScreen 是死代码**：240 行实现无路由入口  
   证据：[app_router.dart](file:///d:/Projects/Active/math/flutter_app/lib/core/router/app_router.dart) 只注册 `/editor` 和 `/files`
4. **Provider 重复定义**：`sharedPreferencesProvider` / `darkModeProvider` 在 [providers/providers.dart](file:///d:/Projects/Active/math/flutter_app/lib/providers/providers.dart) 与 [providers/editor_providers.dart](file:///d:/Projects/Active/math/flutter_app/lib/providers/editor_providers.dart) 各定义一次
5. **解析器缺 7 类元素**：斜体 / 行内代码 / 链接 / 图片 / 删除线 / 任务列表 / 引用链接  
   证据：[markdown_parser.dart:279-308](file:///d:/Projects/Active/math/flutter_app/lib/core/parser/markdown_parser.dart#L279-308)
6. **工具栏与解析器矛盾**：工具栏能插入但解析器不识别  
   证据：[markdown_input_field.dart:175-225](file:///d:/Projects/Active/math/flutter_app/lib/presentation/widgets/markdown_input_field.dart#L175-225) vs [markdown_parser.dart](file:///d:/Projects/Active/math/flutter_app/lib/core/parser/markdown_parser.dart)

### 2.2 P1 体验

- 预览被卡片包裹，浪费手机宽度
- AppBar 标题写死 "FormulaFix"
- 每次按键全量重解析（性能瓶颈）
- WebView 冷启动 2-3 秒
- 单条公式 30s 超时，导出整体 120s 超时
- 导出无进度反馈
- 剪贴板自动弹对话框骚扰用户
- 退出编辑器清空所有缓存
- 代码块无语法高亮

### 2.3 P2 完善

- 主题只有 light/dark 两套
- 字号不可缩放
- 颜色定义两套并存（`AppColors` / `AppTheme.*Color`）
- 缺大纲 / TOC 面板
- 缺焦点模式 / 打字机模式
- 错误消息透传 `detail` 给用户
- 异常被静默吞（[file_manager_screen.dart:46](file:///d:/Projects/Active/math/flutter_app/lib/presentation/screens/file_manager_screen.dart#L46)）

### 2.4 P3 工程化

- 缺 `pubspec.yaml`（CI 阻塞）
- 残留文件 [export_service_tail.txt](file:///d:/Projects/Active/math/flutter_app/lib/domain/services/export_service_tail.txt)
- [web/manifest.json](file:///d:/Projects/Active/math/flutter_app/web/manifest.json) 描述仍是默认 "A new Flutter project."
- `main()` 多余 async
- 静态状态污染测试（CJK 字体、缓存等）
- 测试覆盖不足（缺 UI / 路由 / Provider 集成测试）

---

## 3. 目标架构（To-Be）

### 3.1 范式重构目标（Phase 2）

```
┌────────────────────────────────────────────────────────┐
│ presentation/                                          │
│   screens/                                              │
│     - WysiwygEditorScreen（块级渲染 + 光标态切换）       │
│     - FileTreeScreen（侧滑，替代 DocumentListScreen）   │
│     - OutlineScreen（侧滑大纲，跳转标题）                │
│   widgets/                                              │
│     - BlockEditor（每个 DocumentElement 一个块）        │
│     - InlineEditor（光标所在块渲染为 TextField）         │
│     - RenderedBlock（非聚焦块渲染为最终样式）           │
├────────────────────────────────────────────────────────┤
│ providers/  统一到一处，删除重复                        │
├────────────────────────────────────────────────────────┤
│ domain/                                                │
│   services/file_repository.dart  ← 单一存储入口        │
│   services/export/               ← 不变                │
├────────────────────────────────────────────────────────┤
│ data/                                                  │
│   models/  AST 扩展：InlineCode / Link / Image 等      │
├────────────────────────────────────────────────────────┤
│ core/                                                  │
│   parser/   完整 Markdown + GFM 语法                    │
│   renderers/  SVG 不变                                 │
└────────────────────────────────────────────────────────┘
```

### 3.2 数据存储目标

- **单一真相**：`.md` 文件（应用沙盒内 + 用户可见目录）
- 文档列表 = 扫描 `.md` 文件 + 元数据缓存
- **废弃**：`formula_fix_documents.json`、`SharedPreferences['pref_last_content']`
- 文档元数据（最近打开、收藏、置顶）走 `SharedPreferences` 或 SQLite

详见 [ADR-0003](file:///d:/Projects/Active/math/docs/ADR/0003-storage-single-source-md-files.md)。

### 3.3 解析器目标

- 完整支持 CommonMark + GFM（任务列表 / 删除线 / 表格 / 自动链接）
- AST 扩展，每个 inline 元素一个子类
- 块级渲染时**只重解析光标所在块**，非全量

详见 [ADR-0004](file:///d:/Projects/Active/math/docs/ADR/0004-markdown-parser-extension-strategy.md)。

---

## 4. 重构风险

### 4.1 数据迁移风险（最高）

**风险**：把 JSON 文档库迁到 .md 文件可能丢用户数据。

**缓解**：
- 迁移前做一次性 `DocumentService.exportAllToJsonBackup()` 写一份完整备份
- 迁移逻辑幂等：检测到旧 JSON 文件存在则迁移，迁移成功后**保留** JSON 作为 `.bak`
- 提供回滚脚本

### 4.2 解析器重写风险

**风险**：`DocumentElement` 类型变化会破坏 PDF/Word 导出器与所有 renderer。

**缓解**：
- AST 扩展**只新增不修改**现有子类签名
- 新增子类时通过 sealed class 让 Dart 3 强制 exhaustive switch 报错
- 导出器与 renderer 必须同步更新，且 PR 内同时改

### 4.3 范式重构风险

**风险**：从编辑/预览分离改为 WYSIWYG 是大规模 UI 重写，可能引入大量 bug。

**缓解**：
- 渐进式：先实现"块级实时渲染"（聚焦块渲染、非聚焦块渲染为预览态），不动整体架构
- 保留旧 `EditorScreen` 一段时间，通过 feature flag 切换
- 每个 PR 只改一个块类型的渲染

### 4.4 WebView 缓存策略风险

**风险**：改 `MermaidService._cache` 等静态状态会让现有缓存失效。

**缓解**：
- 重构期间不删除静态状态，先抽出接口
- 测试用 `MarkdownExporter.register({...})` 注入 fake 避开 WebView 依赖

### 4.5 Provider 重命名风险

**风险**：合并重复 Provider 时，identity 变化会导致状态丢失（用户感觉暗色模式被重置）。

**缓解**：
- 重命名 PR 单独提交，不混入功能改动
- 在 release notes 中告知用户

### 4.6 pubspec 缺失风险（当前阻塞）

**风险**：CI 无法运行，新人无法启动。

**缓解**：见 [ROADMAP.md](file:///d:/Projects/Active/math/docs/ROADMAP.md) Phase 0 前置任务。

### 4.7 静态状态污染测试风险

**风险**：CJK 字体加载状态、SVG 缓存等跨测试用例共享。

**缓解**：
- 测试 `setUp` / `tearDown` 显式调用 `clearCache()`
- 后续重构时把静态状态抽成 instance + DI

---

## 5. 相关文档

- [AGENTS.md](file:///d:/Projects/Active/math/AGENTS.md) — AI 协作规范
- [ROADMAP.md](file:///d:/Projects/Active/math/docs/ROADMAP.md) — 路线图
- [CODING_RULES.md](file:///d:/Projects/Active/math/docs/CODING_RULES.md) — 详细编码规范
- [GIT_WORKFLOW.md](file:///d:/Projects/Active/math/docs/GIT_WORKFLOW.md) — Git 流程
- [CRITICAL_REVIEW.md](file:///d:/Projects/Active/math/docs/CRITICAL_REVIEW.md) — 现状批判
- [ADR/](file:///d:/Projects/Active/math/docs/ADR) — 架构决策记录
