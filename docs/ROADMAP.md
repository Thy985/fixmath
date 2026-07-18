# FormulaFix Roadmap

> 从"Markdown + 公式预览原型"演进为"移动端 Typora 类产品"的分阶段路线图。  
> 每个 Phase 内的任务尽量独立，可并行 / 可独立 PR。

---

## Phase 0：工程化 + UI Prototype Freeze（当前阶段）

**目标**：建立工程基础设施，让项目可构建、可测试、可协作；冻结当前 UI 作为重构基线。

**禁止**：修改业务代码、新增功能、修改 UI 行为。

**UI Prototype Freeze**：当前 UI 是原型，不是最终产品。本阶段不修改 UI，但需明确：
- 当前 UI 的交互流程作为 Phase 3 的参考基线
- Phase 1-2 期间 UI 可能出现退化，这不视为 bug
- 重构完成后（Phase 3）才会重新实现 UI

### 任务

| # | 任务 | 责任人 | 状态 |
|---|------|--------|------|
| 0.1 | 补齐 `pubspec.yaml`（含依赖最小集 + assets 声明） | 架构师 | ✅ 已完成 |
| 0.2 | 创建 `AGENTS.md`（AI 协作规范） | 架构师 | ✅ 已完成 |
| 0.3 | 建立 `docs/` 文档体系（ARCHITECTURE / ROADMAP / CODING_RULES / GIT_WORKFLOW / ADR） | 架构师 | ✅ 已完成 |
| 0.4 | 配置 GitHub Actions CI（pub get / analyze / test / build） | 架构师 | ✅ 已完成 |
| 0.5 | 建立 AI 工程治理层（`.agent/AI_POLICY.md` / `loading-rules.md` / `task-contract.md`） | 架构师 | ✅ 已完成 |
| 0.6 | 清理工程残留（`export_service_tail.txt` / `manifest.json` 默认描述） | 架构师 | ✅ 已完成 |
| 0.7 | Android 构建修复（依赖版本兼容性 + 构建工具链对齐） | 架构师 | ✅ 已完成 |
| 0.8 | 设计开发流程文档（`.github/pull_request_template.md` / `WORKFLOW.md`） | 架构师 | ✅ 已完成 |

### 退出条件

- [x] `flutter pub get` 在干净环境成功
- [x] `flutter analyze` 无 error
- [x] `flutter test` 全部通过
- [x] `flutter build apk --debug` 成功
- [x] `flutter build web` 成功
- [x] CI 在 PR 上自动运行全部步骤
- [x] AI 治理层文档到位

---

## Phase 1：底层重构

**目标**：解决阻塞性架构问题，统一数据层、状态层、解析层的基础。

**前置条件**：Phase 0 全部退出。

**UI 退化的接受**：本阶段聚焦底层，UI 可能出现退化（如预览/编辑切换失效、渲染异常），不视为 bug。UI 在 Phase 3 重新实现。

### 任务

| # | 任务 | 优先级 | 关联 ADR | 状态 |
|---|------|--------|---------|------|
| 1.1 | 合并重复 Provider（`sharedPreferencesProvider` / `darkModeProvider`） | P0 | ADR-0002 | ✅ ec76f06 |
| 1.2 | 存储统一为 .md 文件单一真相；废弃 `formula_fix_documents.json` 与 `pref_last_content` | P0 | ADR-0003 | ✅ b43e5c1 |
| 1.3 | 处理 `DocumentListScreen`：合并到 `FileManagerScreen` 或注册路由 | P0 | - | ✅ b36d930 |
| 1.4 | 修正路由初始位置为文件列表，而非空白编辑器 | P0 | - | ✅ b36d930 |
| 1.5 | 补齐解析器：行内代码 / 链接 / 图片 / 斜体 / 删除线 / 任务列表 / 引用链接 | P0 | ADR-0004 | ✅ da4ab00 |
| 1.6 | 修复工具栏与解析器矛盾（移除不支持的按钮，或同步实现） | P0 | ADR-0004 | ✅ d57d2f2 |
| 1.7 | 修复错误消息透传 `detail`（[editor_screen.dart:221-253](file:///d:/Projects/Active/math/flutter_app/lib/presentation/screens/editor_screen.dart#L221-253)） | P1 | - | ✅ f6a73af |
| 1.8 | 补齐 UI / 路由 / Provider 集成测试 | P1 | - | 🔄 部分（1.3/1.4 ✓ 1.6 ✓ 1.7 ✓）；严格测试方案见 [PHASE1_TEST_PLAN.md](file:///d:/Projects/Active/math/docs/PHASE1_TEST_PLAN.md) |

### 退出条件

- [x] 单一存储源，.md 文件为唯一数据源
- [x] 解析器与工具栏一致，无自相矛盾（1.6 已修复）
- [x] 所有 Provider 定义唯一
- [x] 路由无死代码
- [x] 错误消息对用户友好
- [ ] 核心模块测试覆盖（1.8 待按 [PHASE1_TEST_PLAN.md](file:///d:/Projects/Active/math/docs/PHASE1_TEST_PLAN.md) 严格测试通过）

---

## Phase 2：编辑模型

**目标**：设计并实现块级编辑模型，建立 AST 驱动的编辑内核。

**前置条件**：Phase 1 全部退出。

**核心理念**：本阶段定义"怎么编辑"，不定义"长什么样"。UI 在 Phase 3 实现。

### 任务

| # | 任务 | 备注 |
|---|------|------|
| 2.1 | 设计 `BlockEditor` 抽象：块类型、聚焦态/非聚焦态、光标模型 | 参考 Notion / Typora 块编辑 |
| 2.2 | 实现"光标所在块渲染为可编辑组件，离开光标渲染为最终样式" | 核心机制 |
| 2.3 | 增量解析：只重解析光标所在块 | 性能优化 |
| 2.4 | AST 重构：Document 模型对齐 BlockEditor 的块类型 | 类型系统完善 |
| 2.5 | 输入法（IME）兼容：中文输入组合态在块编辑中的正确处理 | 移动端关键 |
| 2.6 | 块级操作：插入/删除/合并/拆分/移动块 | 编辑原语 |
| 2.7 | Markdown 快捷输入映射（`# ` → 标题块，`- ` → 列表块 等） | 用户习惯保留 |

### 退出条件

- [ ] 块编辑内核可脱离 UI 独立运行（纯 Dart 逻辑）
- [ ] 所有块类型有单元测试覆盖
- [ ] 1000 行文档增量解析 < 16ms
- [ ] 中文输入法组合态正确处理

---

## Phase 3：UI Implementation

**目标**：基于 Phase 2 的编辑模型，实现所见即所得 UI。

**前置条件**：Phase 2 全部退出。

### 任务

| # | 任务 | 来源 |
|---|------|------|
| 3.1 | 移除 `previewModeProvider` 与"编辑/预览"切换按钮 | 范式完成的标志 |
| 3.2 | 移除预览卡片包裹，改为沉浸式全屏编辑 | [preview_content.dart:38-47](file:///d:/Projects/Active/math/flutter_app/lib/presentation/widgets/preview_content.dart#L38-47) |
| 3.3 | AppBar 显示当前文档标题 + 修改状态（`•`） | - |
| 3.4 | WebView 预热机制（App 启动后并行加载，不阻塞首屏） | - |
| 3.5 | 公式 / Mermaid 渲染缓存策略改造（不退出清空） | - |
| 3.6 | 代码块语法高亮 | highlight.js / flutter_highlight |
| 3.7 | 大纲 / TOC 侧滑面板，点击跳转标题 | - |
| 3.8 | 文件树侧滑（替代文件管理独立屏幕） | - |
| 3.9 | 多套主题（GitHub / Night / Sepia / Newsprint） | - |
| 3.10 | 字号可缩放（Ctrl +/- / 双指缩放） | - |
| 3.11 | 焦点模式 / 打字机模式 | - |
| 3.12 | 实时字数统计（底部状态栏） | - |
| 3.13 | 撤销 / 重做按钮接入 UI（`HistoryManager` 已实现） | - |
| 3.14 | 自动配对（`$` / `(` / `[` / `*` 等） | - |
| 3.15 | 表格可视化编辑（点击 cell 直接编辑） | - |
| 3.16 | 快捷键支持（Android 物理键盘 + Web） | - |
| 3.17 | 导出进度反馈（百分比 + 当前公式计数） | - |

### 退出条件

- [ ] 用户不再需要切换"编辑/预览"模式
- [ ] WebView 冷启动时间 < 500ms 或预热完成后才显示编辑器
- [ ] 21 项 Typora 核心特性对齐度 ≥ 80%

---

## Phase 4：多平台与高级功能

**目标**：扩展到桌面 / Web，并加入协同等高级功能。

### 任务（暂不细化）

- 4.1 桌面端适配（macOS / Windows / Linux）：键盘快捷键、多窗口
- 4.2 Web 端 PWA 优化
- 4.3 iCloud / Dropbox 同步
- 4.4 文档加密（生物识别解锁）
- 4.5 自定义 CSS 主题
- 4.6 插件系统

---

## 风险与依赖

| 风险 | 影响范围 | 缓解措施 |
|------|---------|---------|
| `flutter_app/android/` 目录缺失 | build-android job | ~~CI 中 `flutter create --platforms=android .` 动态生成~~ ✅ 已补齐（AGP 8.7.3 + compileSdk 36） |
| 依赖版本兼容性（inappwebview / file_picker / pdf） | Phase 0 阻塞 | ~~逐个 pin 版本或 dependency_overrides~~ ✅ 已解决（0.7） |
| 范式重构失败 | Phase 2 延期 | 渐进式、feature flag |
| 数据迁移丢用户文档 | Phase 1.2 | 备份 + 回滚脚本 |
| WebView 性能瓶颈 | Phase 3 | 预热 + 缓存 + 异步渲染 |
| 测试覆盖不足 | 全程 | Phase 1.8 补齐 |
| UI 在 Phase 1-2 退化 | 用户体验 | Phase 0 UI Prototype Freeze 明确预期 |

---

## 节奏

- **不预测时间**：每个任务完成后才进入下一个，不强行按时间表
- **不跳阶段**：Phase 0 不完成不进 Phase 1
- **不混阶段**：底层重构不与 UI 实现混在同一 PR
- **Phase 1-2 UI 退化可接受**：这是"UI Prototype Freeze"策略的核心——底层重构优先，UI 在 Phase 3 重建

---

**当前阶段**：Phase 1（底层重构，进度 7/8，待 1.8 严格测试通过后退出）  
**最近更新**：2026-07-18  
**维护人**：首席架构工程师