# FormulaFix

> 移动端 Typora 类 Markdown 写作工具，以公式 / 图表 / 学术写作为特色。
> 目标：让手机端也能拥有 Typora 级别的所见即所得（WYSIWYG）写作体验。

[![CI](https://github.com/Thy985/fixmath/actions/workflows/ci.yml/badge.svg)](https://github.com/Thy985/fixmath/actions/workflows/ci.yml)
[![Phase](https://img.shields.io/badge/phase-3.8%20ADI%20Accepted-blue)](docs/ROADMAP.md)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

---

## 项目定位

FormulaFix 不是"带预览的 Markdown 编辑器"，而是 **移动端 Typora 类产品**：

- ✅ **所见即所得**：块级 WYSIWYG 编辑，无"编辑/预览"模式切换
- ✅ **手机优先**：为触屏 + 单手握持重新设计的交互范式
- ✅ **学术写作特色**：原生支持 LaTeX 公式、Mermaid 图表、代码高亮
- ✅ **便携查看器**：任意来源 .md 文件即开即看，无需导入到 Vault
- ✅ **离线可用**：100% 本地渲染，无云端依赖
- ✅ **多平台**：Android / Windows / Web

## 当前阶段

**Phase 3.7：Editor Observability System 已完成**（2026-08-03）  
**Phase 3.8：Agent Diagnostic Interface（ADI）已 Accepted**（2026-08-10，ADR-0024 签字，实施未开始）

Phase 0-3.7 全部完成，Phase 3.8 ADI 已 Accepted 待实施，编辑器已具备完整工程链路：

| 维度 | 完成度 | 说明 |
|------|--------|------|
| **Engineering Foundation（工程地基）** | **~95%** | 编辑内核 / 块运行时 / 持久化 / 自动保存 / 文件树 / TOC / 导出进度 / 图片全链路 / 可观测系统 / Core+Extended E2E 均已落地并通过；ADI（Phase 3.8）已 Accepted 待实施 |
| **Visual / Product Identity（视觉与产品识别）** | **~60%** | Design System 对齐（主色 `#1E3A5F` / 衬线字体 / 暖纸背景 / 公式块）已落地；UI 修复 P0-P1 完成，P2-P3 进行中 |

下一阶段为 **Phase 3.8：Agent Diagnostic Interface**（ADI v0.1 Core — 4 个核心命令 + Extract replay_engine，[ADR-0024](docs/ADR/0024-agent-diagnostic-interface.md)）。其后为 Phase 4：多平台与高级功能。详见 [docs/ROADMAP.md](docs/ROADMAP.md)。

## 文档导航

| 文档 | 用途 |
|------|------|
| [AGENTS.md](AGENTS.md) | **AI 协作规范**（架构原则 / 编码规范 / 禁止事项 / CI 失败手册）— 协作者必读 |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | 架构总览（当前 + 目标 + 问题 + 风险） |
| [docs/ROADMAP.md](docs/ROADMAP.md) | 路线图（Phase 0-4 分阶段，含 3.0-3.8 子阶段） |
| [docs/archive/REFACTOR_DESIGN.md](docs/archive/REFACTOR_DESIGN.md) | FormulaFix 2.0 重构方案 |
| [docs/CRITICAL_REVIEW.md](docs/CRITICAL_REVIEW.md) | 现状严厉批判报告 |
| [docs/CODING_RULES.md](docs/CODING_RULES.md) | 详细编码规范 |
| [docs/GIT_WORKFLOW.md](docs/GIT_WORKFLOW.md) | Git 流程 + PR 检查清单 |
| [docs/UI-ARCHITECTURE.md](docs/UI-ARCHITECTURE.md) | UI 架构心智模型 + 状态模型（Phase 2.9 产出） |
| [docs/Interaction-Model.md](docs/Interaction-Model.md) | 交互事件模型（Phase 2.9 产出） |
| [docs/Component-Tree.md](docs/Component-Tree.md) | 组件树与核心接口冻结（Phase 2.9 产出） |
| [docs/UI_SPEC.md](docs/UI_SPEC.md) | UI 设计规范（权威裁定源） |
| [docs/E2E_TEST_PLAN.md](docs/E2E_TEST_PLAN.md) | E2E 测试计划（Core + Extended + Patrol） |
| [docs/design/adi-design-v1.md](docs/design/adi-design-v1.md) | ADI 设计文档（实现细节，[ADR-0024](docs/ADR/0024-agent-diagnostic-interface.md) 配套） |
| [docs/releases/](docs/releases/) | 各 Phase Verification Report |
| [docs/contracts/](docs/contracts/) | 各 Phase Task Contract |
| [docs/ADR/](docs/ADR/) | 架构决策记录（24 份） |

### ADR 索引

| ADR | 主题 | 状态 |
|-----|------|------|
| [0001](docs/ADR/0001-project-naming-and-structure.md) | 项目命名与目录结构 | Accepted |
| [0002](docs/ADR/0002-state-management-riverpod.md) | 状态管理选 Riverpod | Accepted |
| [0003](docs/ADR/0003-storage-single-source-md-files.md) | 存储统一为 .md 单一真相 | Implemented |
| [0004](docs/ADR/0004-markdown-parser-extension-strategy.md) | 解析器扩展而非重写 | Accepted |
| [0005](docs/ADR/0005-exporter-facade-dependency-injection.md) | 导出器 facade + DI | Accepted |
| [0006](docs/ADR/0006-ci-github-actions.md) | CI 选 GitHub Actions | Accepted |
| [0007](docs/ADR/0007-blockeditor-abstraction-design.md) | BlockEditor 抽象设计 | Accepted |
| [0008](docs/ADR/0008-editor-transaction-model.md) | 编辑器 Transaction 模型 | Accepted |
| [0009](docs/ADR/0009-ui-architecture-design.md) | UI 架构设计 | Accepted |
| 0010 | （已跳过，编号不复用） | Skipped |
| [0011](docs/ADR/0011-phase3.3-architecture-decisions.md) | Phase 3.3 架构决策 | Accepted |
| [0012](docs/ADR/0012-live-editing-state.md) | 实时编辑状态 | Accepted |
| [0013](docs/ADR/0013-autosave-architecture.md) | 自动保存架构 | Accepted |
| [0014](docs/ADR/0014-document-asset-management.md) | 文档资产管理 | Accepted |
| [0015](docs/ADR/0015-theme-architecture-migration.md) | 主题架构迁移 | Accepted |
| [0016](docs/ADR/0016-document-repository-boundary.md) | DocumentRepository 边界 | Accepted |
| [0017](docs/ADR/0017-design-system-alignment.md) | Design System Token & Typography | Accepted |
| [0018](docs/ADR/0018-app-shell-navigation.md) | App Shell 导航 | Accepted |
| [0019](docs/ADR/0019-editor-interaction-layer.md) | 编辑器交互层 | Accepted |
| [0020](docs/ADR/0020-block-model.md) | Block 模型 | Accepted |
| [0021](docs/ADR/0021-repository-integrity-strategy.md) | 仓库完整性策略 | Accepted |
| [0022](docs/ADR/0022-renderer-failure-policy.md) | Renderer 失败策略 | Accepted |
| [0023](docs/ADR/0023-editor-observability-system.md) | 编辑器可观测系统 | Accepted |
| [0024](docs/ADR/0024-agent-diagnostic-interface.md) | Agent 诊断接口（ADI） | Accepted |

## 项目结构

```
math/
├── AGENTS.md                    # AI 协作规范（强制阅读）
├── README.md                    # 本文件
├── LICENSE                      # MIT 协议
├── .gitignore
├── .github/workflows/ci.yml     # GitHub Actions CI
├── .agent/                      # AI 工程治理层（安全层 / 规则 / 模板）
├── .adi/                        # ADI 运行时产物（不入库，ADR-0024）
├── docs/                        # 工程文档（含 ADR / contracts / releases / design）
├── tools/adi/                   # ADI CLI 入口（dart run tools/adi/adi.dart，ADR-0024）
└── flutter_app/                 # Flutter 工程目录
    ├── lib/                     # 源代码（6 层架构）
    │   ├── core/                # 基础设施（parser / renderers / services / observability / replay / utils）
    │   │   ├── observability/   # 可观测系统（ADR-0023）+ ADI Adapter（ADR-0024）
    │   │   └── replay/          # 重放引擎（从 CommandReplayer Extract，ADR-0024）
    │   ├── data/                # 数据模型（Document / Template）
    │   ├── domain/              # 业务领域（导出服务 / 业务 Provider）
    │   ├── providers/           # 全局 Riverpod Provider
    │   ├── presentation/        # UI 层（13 子目录）
    │   │   ├── editor/          # EditorShell / EditorCoordinator / EditorPage
    │   │   ├── blocks/          # 8 种 BlockType（paragraph/heading/code/quote/table/mermaid/formula/input）+ shared/
    │   │   ├── chrome/          # AppBar / StatusBar / Toolbar（IDE 惯例分离）
    │   │   ├── panels/          # TOC / 文件树
    │   │   ├── commands/        # EditorCommand（sealed）+ CommandHandler
    │   │   ├── states/          # BlockViewState / CoordinatorState
    │   │   ├── theme/           # EditorTokens（ThemeExtension）
    │   │   ├── themes/          # AppTheme（light / dark / sepia）
    │   │   ├── observability/   # 可观测性 UI（诊断导出 + CommandReplayer 委托 core/replay）
    │   │   ├── components/      # 通用组件
    │   │   ├── widgets/         # 基础 Widget
    │   │   ├── prototype/       # Phase 2.9 Prototype Demo（4 个）
    │   │   └── screens/         # 顶层 Screen
    │   └── main.dart            # App 入口
    ├── test/                    # 测试（architecture 守门 / editing / golden / observability / integration / presentation）
    ├── integration_test/        # E2E 测试（Core + Extended + Patrol）
    ├── android/                 # Android 平台（AGP 8.7.3）
    ├── ios/                     # iOS 平台
    ├── web/                     # PWA 资产
    └── pubspec.yaml             # 依赖配置
```

详细的 `lib/` 内部结构见 [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) 与 [docs/Component-Tree.md](docs/Component-Tree.md)。

## 快速开始

```bash
cd flutter_app
flutter pub get
flutter run
```

测试与构建：

```bash
cd flutter_app
flutter test
flutter build apk --debug
flutter build web
```

CI 会在每个 PR 自动运行上述全部步骤，详见 [.github/workflows/ci.yml](.github/workflows/ci.yml)。

## 技术栈

- **框架**：Flutter + Dart 3（sealed class / records / 模式匹配）
- **状态管理**：flutter_riverpod
- **路由**：go_router
- **公式渲染**：flutter_inappwebview + MathJax（tex-svg.js）+ flutter_math_fork（兜底）
- **图表渲染**：mermaid.min.js
- **代码高亮**：flutter_highlight（githubTheme）
- **PDF 导出**：pdf 包 + 自研 SVG AST
- **Word 导出**：archive 包打 OOXML
- **存储**：.md 文件（单一真相源，[ADR-0003](docs/ADR/0003-storage-single-source-md-files.md)）
- **可观测性**：自研五层架构（TraceContext / CommandTracer / TransactionTracer / InvariantChecker / ObservabilityService，[ADR-0023](docs/ADR/0023-editor-observability-system.md)）
- **Agent 诊断接口（ADI）**：复用 3.7 采集能力，标准化暴露诊断协议给 AI Agent（`.adi/` 存储 + CLI `dart run tools/adi/adi.dart`，[ADR-0024](docs/ADR/0024-agent-diagnostic-interface.md)）
- **E2E 测试**：patrol（真机 / 模拟器）+ integration_test
- **Golden 测试**：golden_toolkit
- **CI/CD**：GitHub Actions（[ADR-0006](docs/ADR/0006-ci-github-actions.md)）

## 协作

### 给开发者

1. **必读**：[AGENTS.md](AGENTS.md) 第 6 章禁止事项
2. **认领任务前**：读 [docs/ROADMAP.md](docs/ROADMAP.md) 确认当前 Phase 范围
3. **架构决策**：查 [docs/ADR/](docs/ADR/)，新增决策按 ADR 模板补 ADR
4. **提 PR 前**：对照 [docs/GIT_WORKFLOW.md §3.2](docs/GIT_WORKFLOW.md) 检查清单自检

### 给 AI 协作者（TRAE / Claude / Cursor）

1. **接到任务的标准流程**：见 [AGENTS.md §9.1](AGENTS.md)
2. **不确定时**：按 [AGENTS.md §9.2](AGENTS.md) 升级路径处理
3. **禁止事项**：见 [AGENTS.md §6](AGENTS.md)
4. **ADI 诊断工作流**：见 [AGENTS.md §9.5](AGENTS.md)（Agent 调试 FormulaFix 时 MUST 遵守 ADR-0024 §1.4 Agent Interaction Contract）
5. **CI 失败手册**：见 [AGENTS.md §11](AGENTS.md)（unused_import / SDK API 误用 / 架构守门 / widget 测试注入等高频模式）

### Git 工作流

- `main`：受保护，只接受 PR 合入
- `feat/<scope>-<short-desc>`：功能分支
- `fix/<scope>-<short-desc>`：修复分支
- `chore/<short-desc>`：工程化任务
- `docs/<short-desc>`：文档变更

Commit message 遵循 [Conventional Commits](docs/GIT_WORKFLOW.md#2-commit-message-规范)。

## 当前已知问题

完整清单见 [docs/CRITICAL_REVIEW.md](docs/CRITICAL_REVIEW.md)。摘要：

**Phase 1 已修复项**（2026-07-19，PR #23 合并后正式关闭）：

| 问题 | 修复 commit / PR |
|------|----------------|
| Provider 重复定义 | `ec76f06`（1.1） |
| 三套存储并存 | `b43e5c1`（1.2） |
| 解析器缺 7 类元素 | `da4ab00`（1.5） |
| DocumentListScreen 死代码 | `b36d930`（1.3） |
| 错误 detail 透传 UI | `f6a73af`（1.7） |

**仍存在项**（按 Phase 修复）：

| 问题 | 修复 Phase | 跟踪 |
|------|----------|------|
| MathBlock 双态切换 | Phase 3.5+ | [ROADMAP §3.5](docs/ROADMAP.md) |
| 选区格式化菜单（Overlay 浮动菜单） | Phase 3.4 §3.4.10 | [ROADMAP §3.4.10](docs/ROADMAP.md) |
| 21 项 Typora 核心特性对齐度 < 80% | Phase 3.3+ 体验增强 | [ROADMAP §3.1+ 退出条件](docs/ROADMAP.md) |
| 桌面快捷键 / 打字机模式 | Phase 4 Desktop Enhancement | [ROADMAP §3.4.5/3.4.6](docs/ROADMAP.md) |
| 静态状态污染测试 | Phase 2 | [CRITICAL_REVIEW §8.5](docs/CRITICAL_REVIEW.md) |

新增代码不得延续以上问题，必须按目标架构编写。

## 路线图概览

| Stage | 目标 | 状态 |
|-------|------|------|
| Phase 0 | 工程化基础（文档 / CI / 规范） | ✅ 已完成 |
| Phase 1 | 地基重构（存储 + Provider + 解析器） | ✅ 已完成（2026-07-19，PR #23） |
| Phase 2 | 编辑模型（BlockEditor / AST / IME / Transaction） | ✅ 已完成（含 2.8 Integration Hardening + 2.9 UI Architecture Prototype） |
| Phase 3.0 | Editor Shell Architecture & Presentation Foundation | ✅ 已完成 |
| Phase 3.1 | WYSIWYG Migration（移除预览/编辑双模式） | ✅ 已完成 |
| Phase 3.2 | Block Runtime Expansion（8 种 BlockType） | ⚠️ Conditionally Complete（MathBlock 延期 3.5） |
| Phase 3.3 | Mobile Markdown Editing Experience（9 任务） | ✅ 已完成（PR #58-#67） |
| Phase 3.4+ | Advanced Capabilities（TOC / 文件树 / 主题 / 导出 / 自动保存 / 图片） | ✅ 主体完成（3.4.10 选区菜单未实现） |
| Phase 3.4.5 | Design System Alignment（主色 / 字体 / 暖纸 / 公式块） | ✅ 已完成 |
| Phase 3.5 | Formula Rendering System + Block 交互三件套 | ✅ 已完成 |
| Phase 3.6 | Editor Reliability & Behavioral Verification（E2E） | ✅ 已完成（Core + Extended + Patrol） |
| Phase 3.7 | Editor Observability System（可观测 + 诊断导出 + Command Replay） | ✅ 已完成 |
| Phase 3.8 | Agent Diagnostic Interface（ADI · Agent 诊断协议 + `.adi/` 存储 + CLI） | 🔶 Accepted 待实施（ADR-0024） |
| Phase 4 | 多平台与高级功能（桌面 / Web PWA / 云同步 / 加密 / 插件） | ⏳ 未启动 |

详见 [docs/ROADMAP.md](docs/ROADMAP.md)。

## License

本项目基于 [MIT 协议](LICENSE) 开源。

Copyright (c) 2026 [Thy985](https://github.com/Thy985)

---

**维护人**：首席架构工程师
**最近更新**：2026-08-10
**文档版本**：v0.2
