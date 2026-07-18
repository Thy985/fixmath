# FormulaFix

> 移动端 Typora 类 Markdown 写作工具，以公式 / 图表 / 学术写作为特色。
> 目标：让手机端也能拥有 Typora 级别的所见即所得（WYSIWYG）写作体验。

[![CI](https://github.com/Thy985/fixmath/actions/workflows/ci.yml/badge.svg)](https://github.com/Thy985/fixmath/actions/workflows/ci.yml)
[![Phase](https://img.shields.io/badge/phase-0%20工程化-blue)](docs/ROADMAP.md)
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

**Phase 0：工程化基础建设**

已完成工程基础设施（文档体系、CI、规范），尚未启动业务代码重构。详见 [docs/ROADMAP.md](docs/ROADMAP.md)。

下一阶段（Phase 1 / R1）将启动 P0 地基修复：存储统一、Provider 合并、解析器补齐 7 类 Markdown 元素。

## 文档导航

| 文档 | 用途 |
|------|------|
| [AGENTS.md](AGENTS.md) | **AI 协作规范**（架构原则 / 编码规范 / 禁止事项）— 协作者必读 |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | 架构总览（当前 + 目标 + 问题 + 风险） |
| [docs/ROADMAP.md](docs/ROADMAP.md) | 路线图（Phase 0-4 分阶段） |
| [docs/REFACTOR_DESIGN.md](docs/REFACTOR_DESIGN.md) | FormulaFix 2.0 重构方案 |
| [docs/CRITICAL_REVIEW.md](docs/CRITICAL_REVIEW.md) | 现状严厉批判报告 |
| [docs/CODING_RULES.md](docs/CODING_RULES.md) | 详细编码规范 |
| [docs/GIT_WORKFLOW.md](docs/GIT_WORKFLOW.md) | Git 流程 + PR 检查清单 |
| [docs/ADR/](docs/ADR/) | 架构决策记录（6 份） |

### ADR 索引

| ADR | 主题 | 状态 |
|-----|------|------|
| [0001](docs/ADR/0001-project-naming-and-structure.md) | 项目命名与目录结构 | Accepted |
| [0002](docs/ADR/0002-state-management-riverpod.md) | 状态管理选 Riverpod | Accepted |
| [0003](docs/ADR/0003-storage-single-source-md-files.md) | 存储统一为 .md 单一真相 | Proposed |
| [0004](docs/ADR/0004-markdown-parser-extension-strategy.md) | 解析器扩展而非重写 | Proposed |
| [0005](docs/ADR/0005-exporter-facade-dependency-injection.md) | 导出器 facade + DI | Accepted |
| [0006](docs/ADR/0006-ci-github-actions.md) | CI 选 GitHub Actions | Accepted |

## 项目结构

```
math/
├── AGENTS.md                    # AI 协作规范（强制阅读）
├── README.md                    # 本文件
├── LICENSE                      # MIT 协议
├── .gitignore
├── .github/workflows/ci.yml     # GitHub Actions CI
├── docs/                        # 工程文档
│   ├── ARCHITECTURE.md
│   ├── ROADMAP.md
│   ├── REFACTOR_DESIGN.md
│   ├── CRITICAL_REVIEW.md
│   ├── CODING_RULES.md
│   ├── GIT_WORKFLOW.md
│   └── ADR/
└── flutter_app/                 # Flutter 工程目录
    ├── lib/                     # 源代码（6 层架构）
    ├── test/                    # 测试
    ├── web/                     # PWA 资产
    └── README.md                # Flutter 工程细节
```

详细的 `lib/` 内部结构见 [flutter_app/README.md](flutter_app/README.md) 与 [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)。

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
- **公式渲染**：flutter_inappwebview + MathJax（tex-svg.js）
- **图表渲染**：mermaid.min.js
- **PDF 导出**：pdf 包 + 自研 SVG AST
- **Word 导出**：archive 包打 OOXML
- **存储**：.md 文件（单一真相源，[ADR-0003](docs/ADR/0003-storage-single-source-md-files.md)）
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
3. **禁止事项**：见 [AGENTS.md §6](AGENTS.md)，特别是当前 Phase 0 的特别禁令

### Git 工作流

- `main`：受保护，只接受 PR 合入
- `feat/<scope>-<short-desc>`：功能分支
- `fix/<scope>-<short-desc>`：修复分支
- `chore/<short-desc>`：工程化任务
- `docs/<short-desc>`：文档变更

Commit message 遵循 [Conventional Commits](docs/GIT_WORKFLOW.md#2-commit-message-规范)。

## 当前已知问题

完整清单见 [docs/CRITICAL_REVIEW.md](docs/CRITICAL_REVIEW.md)。摘要：

**P0 阻塞**：
- 编辑/预览分离模式（与 Typora WYSIWYG 哲学对立）
- 三套存储互不同步（SharedPreferences / JSON / .md）
- 解析器缺 7 类 Markdown 元素（斜体 / 行内代码 / 链接 / 图片 / 删除线 / 任务列表 / 引用链接）
- 工具栏与解析器自相矛盾
- `DocumentListScreen` 死代码
- Provider 重复定义

**P3 工程化**：
- 缺 `flutter_app/android/` 目录（build-android job 已临时禁用）
- 测试覆盖不足

这些问题已记入 [ROADMAP.md](docs/ROADMAP.md)，按 Phase 修复。新增代码不得延续以上问题。

## 路线图概览

| Stage | 目标 | 状态 |
|-------|------|------|
| Phase 0 / R0 | 工程化基础（文档 / CI / 规范） | ✅ 基本完成 |
| Phase 1 / R1 | 地基重构（存储 + Provider） | ⏳ 待启动 |
| R2 | 完整 AST + 解析器 | ⏳ |
| R3 | 渲染系统统一 | ⏳ |
| R4 | Block-based WYSIWYG | ⏳（高风险） |
| R5 | 体验完善，对齐 Typora | ⏳ |

详见 [docs/ROADMAP.md](docs/ROADMAP.md) 与 [docs/REFACTOR_DESIGN.md](docs/REFACTOR_DESIGN.md)。

## License

本项目基于 [MIT 协议](LICENSE) 开源。

Copyright (c) 2026 [Thy985](https://github.com/Thy985)

---

**维护人**：首席架构工程师
**最近更新**：2026-07-18
**文档版本**：v0.1
