# FormulaFix Roadmap

> 从"Markdown + 公式预览原型"演进为"移动端 Typora 类产品"的分阶段路线图。  
> 每个 Phase 内的任务尽量独立，可并行 / 可独立 PR。

---

## Phase 0：工程化基础（当前阶段）

**目标**：建立工程基础设施，让项目可构建、可测试、可协作。

**禁止**：修改业务代码、新增功能。

### 任务

| # | 任务 | 责任人 | 状态 |
|---|------|--------|------|
| 0.1 | 补齐 `pubspec.yaml`（含依赖最小集 + assets 声明） | 架构师 | ⏳ 待启动 |
| 0.2 | 创建 `AGENTS.md`（AI 协作规范） | 架构师 | ✅ 已完成 |
| 0.3 | 建立 `docs/` 文档体系（ARCHITECTURE / ROADMAP / CODING_RULES / GIT_WORKFLOW / ADR） | 架构师 | ✅ 已完成 |
| 0.4 | 配置 GitHub Actions CI（pub get / analyze / test / build） | 架构师 | ✅ 已完成 |
| 0.5 | 清理工程残留（`export_service_tail.txt` / `manifest.json` 默认描述） | 工程师 | ⏳ 待启动 |
| 0.6 | 添加 `.gitignore`（忽略 `build/` `.dart_tool/` 等） | 工程师 | ⏳ 待启动 |

### 退出条件

- [ ] `flutter pub get` 在干净环境成功
- [ ] `flutter analyze` 无 error
- [ ] `flutter test` 全部通过
- [ ] `flutter build apk --debug` + `flutter build web` 成功
- [ ] CI 在 PR 上自动运行上述全部步骤

---

## Phase 1：P0 地基修复

**目标**：解决阻塞性架构问题，让代码"配得上"Typora 端侧版的称呼。

**前置条件**：Phase 0 全部退出。

### 任务

| # | 任务 | 优先级 | 关联 ADR |
|---|------|--------|---------|
| 1.1 | 合并重复 Provider（`sharedPreferencesProvider` / `darkModeProvider`） | P0 | ADR-0002 |
| 1.2 | 存储统一为 .md 文件单一真相；废弃 `formula_fix_documents.json` 与 `pref_last_content` | P0 | ADR-0003 |
| 1.3 | 处理 `DocumentListScreen`：合并到 `FileManagerScreen` 或注册路由 | P0 | - |
| 1.4 | 修正路由初始位置为文件列表，而非空白编辑器 | P0 | - |
| 1.5 | 补齐解析器：行内代码 / 链接 / 图片 / 斜体 / 删除线 / 任务列表 / 引用链接 | P0 | ADR-0004 |
| 1.6 | 修复工具栏与解析器矛盾（移除不支持的按钮，或同步实现） | P0 | ADR-0004 |
| 1.7 | 修复错误消息透传 `detail`（[editor_screen.dart:221-253](file:///d:/Projects/Active/math/flutter_app/lib/presentation/screens/editor_screen.dart#L221-253)） | P1 | - |
| 1.8 | 补齐 UI / 路由 / Provider 集成测试 | P1 | - |

### 退出条件

- [ ] 单一存储源，无数据丢失风险
- [ ] 解析器与工具栏一致，无自相矛盾
- [ ] 所有 Provider 定义唯一
- [ ] 路由无死代码
- [ ] 错误消息对用户友好

---

## Phase 2：WYSIWYG 范式重构

**目标**：从"编辑/预览分离"切换为"块级所见即所得"。

**前置条件**：Phase 1 全部退出。

### 任务

| # | 任务 | 备注 |
|---|------|------|
| 2.1 | 设计 `BlockEditor` 抽象：聚焦态 / 非聚焦态切换 | 参考 Notion / Typora 块编辑 |
| 2.2 | 实现"光标所在块渲染为 TextField，离开光标渲染为最终样式" | 核心机制 |
| 2.3 | 移除 `previewModeProvider` 与"编辑/预览"切换按钮 | 范式完成的标志 |
| 2.4 | 移除预览卡片包裹（[preview_content.dart:38-47](file:///d:/Projects/Active/math/flutter_app/lib/presentation/widgets/preview_content.dart#L38-47)），改为沉浸式全屏编辑 | - |
| 2.5 | AppBar 显示当前文档标题 + 修改状态（`•`） | - |
| 2.6 | 增量解析：只重解析光标所在块 | 性能优化 |
| 2.7 | WebView 预热机制（App 启动后并行加载，不阻塞首屏） | - |
| 2.8 | 公式 / Mermaid 渲染缓存策略改造（不退出清空） | - |

### 退出条件

- [ ] 用户不再需要切换"编辑/预览"模式
- [ ] 1000 行文档输入流畅（每按键 < 16ms）
- [ ] WebView 冷启动时间 < 500ms 或预热完成后才显示编辑器

---

## Phase 3：体验完善

**目标**：对齐 Typora 的专业写作体验。

### 任务（按价值排序）

| # | 任务 |
|---|------|
| 3.1 | 代码块语法高亮（highlight.js / flutter_highlight） |
| 3.2 | 大纲 / TOC 侧滑面板，点击跳转标题 |
| 3.3 | 文件树侧滑（替代文件管理独立屏幕） |
| 3.4 | 多套主题（GitHub / Night / Sepia / Newsprint） |
| 3.5 | 字号可缩放（Ctrl +/- / 双指缩放） |
| 3.6 | 焦点模式 / 打字机模式 |
| 3.7 | 实时字数统计（底部状态栏） |
| 3.8 | 撤销 / 重做按钮接入 UI（`HistoryManager` 已实现） |
| 3.9 | 自动配对（`$` / `(` / `[` / `*` 等） |
| 3.10 | 表格可视化编辑（点击 cell 直接编辑） |
| 3.11 | 快捷键支持（Android 物理键盘 + Web） |
| 3.12 | 导出进度反馈（百分比 + 当前公式计数） |

### 退出条件

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
| pubspec.yaml 缺失 | Phase 0 阻塞 | 0.1 优先解决 |
| 范式重构失败 | Phase 2 延期 | 渐进式、feature flag |
| 数据迁移丢用户文档 | Phase 1.2 | 备份 + 回滚脚本 |
| WebView 性能瓶颈 | Phase 2 | 预热 + 缓存 + 异步渲染 |
| 测试覆盖不足 | 全程 | Phase 1.8 补齐 |

---

## 节奏

- **不预测时间**：每个任务完成后才进入下一个，不强行按时间表
- **不跳阶段**：Phase 0 不完成不进 Phase 1
- **不混阶段**：Phase 1 P0 修复不与 Phase 3 体验功能混在同一 PR

---

**当前阶段**：Phase 0  
**最近更新**：2026-07-18  
**维护人**：首席架构工程师
