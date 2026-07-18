# AGENTS.md — AI 协作开发规范

> 本文件是 FormulaFix 项目对所有 AI 协作开发者（含 TRAE Agent / Claude Code / Cursor / 人工协作者）的强制规范。
> 所有 PR 必须通过本文档的检查项才能合并。

---

## 0. 项目愿景与定位

**FormulaFix** 的目标是演进为 **移动端 Typora 类产品**：

- 不是"带预览的 Markdown 编辑器"，而是 **所见即所得（WYSIWYG）** 编辑器
- 不是"桌面端 Typora 的功能搬运"，而是 **手机优先（mobile-first）** 的重新设计
- 不是"通用笔记 App"，而是 **以公式 / 图表 / 学术写作为特色** 的专业写作工具
- 不是"像 Obsidian 那样只能在自家 Vault 内查看"，而是 **任意来源 .md 文件即开即看** 的便携查看器

**当前阶段定位**：Phase 0：工程化 + UI Prototype Freeze。UI 冻结为重构基线，Phase 1-2 期间 UI 退化不视为 bug。  
**当前阶段禁区**：不修改业务代码，不新增功能，不修改 UI 行为。

---

## 1. 项目架构原则

### 1.1 六层分层架构（严格自上而下依赖）

```
presentation/    UI 组件、屏幕、主题
      ↓
providers/       全局 Riverpod Provider
      ↓
domain/          业务领域（导出服务、业务 Provider）
      ↓
data/            数据模型（Document / Template）
      ↓
core/            基础设施（parser / renderers / services / router / utils）
      ↓
main.dart        App 入口
```

**强制规则**：
- `core` 不允许反向 import `presentation` / `domain` / `providers`
- `data` 不允许 import `core` 之外的业务代码
- `presentation` 不允许跨过 `domain` / `providers` 直接调用 `core` 的服务（除路由、常量等纯工具）
- 循环依赖零容忍

### 1.2 单一职责

一个 `.dart` 文件 = 一个 class / 一个主题 / 一个 Provider 簇。  
文件超过 **400 行** 必须拆分。

### 1.3 显式依赖

- 服务类构造函数注入，不写 `class.service()` 风格的全局静态方法
- 例外：现有 `MarkdownExporter` / `PdfExporter` / `WordExporter` 已是 facade 静态，重写前不动
- 测试时通过 `MarkdownExporter.register({...})` 注入 fake（见 [export_service.dart:67-83](file:///d:/Projects/Active/math/flutter_app/lib/domain/services/export_service.dart#L67-83)）

---

## 2. Flutter 编码规范

### 2.1 命名

| 类型 | 规则 | 示例 |
|------|------|------|
| 类 / 枚举 / typedef | UpperCamelCase | `DocumentElement`、`ExportFailure` |
| 文件名 | snake_case.dart | `markdown_parser.dart` |
| 方法 / 变量 | lowerCamelCase | `parseInline`、`isDarkMode` |
| 常量 | lowerCamelCase 或 UPPER_SNAKE_CASE（限 static const） | `maxHistorySize`、`_kHtml` |
| 私有 | 前缀 `_` | `_PendingLatex`、`_dispatchWaiting` |
| Provider | `xxxProvider` 后缀 | `documentsProvider`、`darkModeProvider` |

### 2.2 现代 Dart 特性使用（鼓励）

- sealed class 用于 AST / 状态联合（已在 [document.dart](file:///d:/Projects/Active/math/flutter_app/lib/data/models/document.dart) 落地）
- 模式匹配 `switch` 替代 if-else 链（已在 [preview_content.dart:80-102](file:///d:/Projects/Active/math/flutter_app/lib/presentation/widgets/preview_content.dart#L80-102) 落地）
- records 用于多值返回（已在 `ExportFailureInfo` 落地）
- 空安全：禁止 `!` 强制解包，除非同一行内已 null 检查

### 2.3 注释

- **dartdoc** `///` 用于 public API（公开给其他模块调用的方法）
- **普通** `//` 用于实现细节
- **TODO 格式**：`// TODO(<name>): <desc> —— 见 <ticket/url>`
- 禁止无意义注释（如 `// constructor`）
- 中文注释允许，但 public API 的 dartdoc 优先英文（便于跨团队协作）

### 2.4 文件头

每个 `.dart` 文件必须有 1-3 行 `///` 顶部文档，说明该文件职责。  
参考 [export_service.dart:1-19](file:///d:/Projects/Active/math/flutter_app/lib/domain/services/export_service.dart#L1-19) 的写法。

### 2.5 import 顺序

```dart
// 1. Dart SDK
import 'dart:async';
import 'dart:io';

// 2. Flutter / 第三方
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// 3. 项目内（按相对路径，不混用 package:）
import '../../core/constants/app_constants.dart';
import '../../data/models/document.dart';
```

---

## 3. 状态管理规范（Riverpod）

### 3.1 Provider 选择决策树

```
需要异步数据？
  └ 是 → FutureProvider / AsyncNotifierProvider
  └ 否 → 需要修改状态？
          └ 是 → StateNotifierProvider（业务状态）/ StateProvider（UI 状态）
          └ 否 → Provider（依赖注入）
```

### 3.2 命名与归属

- 业务级 Provider 放 `domain/providers/`
- UI 全局状态放 `providers/`
- **禁止在多个文件定义同名 Provider**（当前 [providers/providers.dart](file:///d:/Projects/Active/math/flutter_app/lib/providers/providers.dart) 与 [providers/editor_providers.dart](file:///d:/Projects/Active/math/flutter_app/lib/providers/editor_providers.dart) 重复定义 `sharedPreferencesProvider` / `darkModeProvider`，是 bug，待 P0 重构修复）

### 3.3 状态不可变性

- `StateNotifier<S>` 的 `S` 必须是不可变类型
- 集合修改用 `copyWith` 或新对象，禁止 `state.list.add(...)`
- 已有范本：[data/models/document.dart:108-122](file:///d:/Projects/Active/math/flutter_app/lib/data/models/document.dart#L108-122) 的 `copyWith`

### 3.4 Provider dispose

- 资源持有型 Provider（WebView、Stream、Timer）必须实现 `autoDispose` 或显式清理
- 当前 [editor_screen.dart:51-65](file:///d:/Projects/Active/math/flutter_app/lib/presentation/screens/editor_screen.dart#L51-65) 在 `dispose` 中清空静态缓存是 hack，待 WYSIWYG 重构后移除

---

## 4. 数据访问规范

### 4.1 单一真相源（目标状态，当前未达成）

**目标**：`.md` 文件作为文档唯一存储，废弃 `formula_fix_documents.json` 与 `SharedPreferences['pref_last_content']`。

**理由**：见 [docs/ADR/0003-storage-single-source-md-files.md](file:///d:/Projects/Active/math/docs/ADR/0003-storage-single-source-md-files.md)。

**过渡期规则**：在 ADR-0003 执行前，**禁止新增第四套存储**。

### 4.2 服务层访问

- UI 不直接调 `DocumentService`，必须通过 `domain/providers/document_provider.dart` 的 Provider
- 例外：`EditorScreen` 当前直接调 `FileService` 是历史遗留，重构时下沉到 Provider

### 4.3 编码兜底

- 所有从外部读取的字节流必须走 [file_service.dart:13-41](file:///d:/Projects/Active/math/flutter_app/lib/core/services/file_service.dart#L13-41) `decodeBytesAuto`
- 禁止直接 `utf8.decode(bytes)` —— 中国用户的 .md 常含 GBK 字节

### 4.4 错误传播

- 服务层抛业务异常（`ExportException` / `FileImportException` 等），不抛 raw `Exception`
- UI 层通过 [export_service.dart:261-348](file:///d:/Projects/Active/math/flutter_app/lib/domain/services/export_service.dart#L261-348) `classifyError` 映射到 `ExportFailure` 枚举
- **禁止把 `detail`（含 source/offset/stack）直接显示给用户** —— 当前 [editor_screen.dart:230-253](file:///d:/Projects/Active/math/flutter_app/lib/presentation/screens/editor_screen.dart#L230-253) 违反此规则，待 P1 修复

---

## 5. Git 提交规范

详见 [docs/GIT_WORKFLOW.md](file:///d:/Projects/Active/math/docs/GIT_WORKFLOW.md)。要点：

### 5.0 AI / Human 提交分工（核心规则）

| 行为 | AI | Human Owner |
|------|----|-------------|
| 创建独立 branch | ✅ 必须 | ✅ |
| 创建 commit | ✅ 可以 | ✅ |
| Commit message 含任务范围 | ✅ 必须 | — |
| 创建 PR | ✅ 必须 | ✅ |
| 直接 push 到 `main` | ❌ 禁止 | ✅ |
| Merge PR | ❌ 禁止 | ✅ 专属权限 |
| 架构决策类文件 commit | ❌ 禁止（除非明确授权） | ✅ 专属权限 |

详见 [§6.4](#64-ai--human-提交分工)。

### 5.1 Commit Message 格式（Conventional Commits）

```
<type>(<scope>): <subject>

<body>

<footer>
```

**type**：`feat` / `fix` / `refactor` / `docs` / `chore` / `test` / `perf` / `style` / `ci` / `build`

**scope**：模块名（如 `parser` / `exporter` / `ui` / `ci` / `docs`）

**AI commit 强制要求**：body 必须包含任务范围，格式：
```
Task scope: <ROADMAP phase.task 或 issue 编号>
```

**示例（AI commit）**：
```
feat(parser): 支持 Markdown 行内代码与链接语法

补齐 _parseBoldAndItalic 中缺失的 `code` 与 [text](url) 解析分支

Task scope: ROADMAP 1.5
Closes #12
```

**示例（Human commit，架构决策）**：
```
docs(adr): 新增 ADR-0007 StorageMigration 设计

按重构方案 R1 要求，补充存储迁移的幂等性、备份、回滚策略。
```

### 5.2 Branch 策略

- `main`：受保护，只接受 PR 合入
- `develop`：日常集成分支（Phase 1 启用）
- `feat/<scope>-<short-desc>`：功能分支，如 `feat/parser-inline-code`
- `fix/<scope>-<short-desc>`：bug 修复分支
- `chore/<short-desc>`：工程化任务
- `docs/<short-desc>`：文档变更

### 5.3 PR 检查清单

PR 描述必须包含：

- [ ] 关联 issue 编号
- [ ] 改动说明（what + why）
- [ ] 测试方式（手动 / 自动）
- [ ] 是否影响公共 API
- [ ] 是否更新文档
- [ ] 自测：`flutter analyze` 无 error
- [ ] 自测：`flutter test` 全部通过
- [ ] 自测：`flutter build apk --debug` / `flutter build web` 成功

---

## 6. 禁止事项（Hard Rules）

### 6.1 业务代码禁区

1. ❌ **禁止** 在 `core/` 内 import `presentation/` 或 `domain/`
2. ❌ **禁止** 在多个文件定义同名 Provider
3. ❌ **禁止** 在 UI 层直接展示异常 `detail` / `stack`
4. ❌ **禁止** 使用 `print()`，必须用 `debugPrint()`
5. ❌ **禁止** 在 `main()` 中写业务逻辑，只允许 runApp + 初始化
6. ❌ **禁止** 在 `setState` 之外的同步代码里修改 Provider state
7. ❌ **禁止** 引入新的全局静态状态（已有 `MermaidService._cache` 等是历史遗留，重构时清理）

### 6.2 工程禁区

1. ❌ **禁止** 提交 `build/` 目录
2. ❌ **禁止** 提交 `.dart_tool/` 目录
3. ❌ **禁止** 提交 `pubspec.lock`（如果是 App 项目；库项目需要提交）
4. ❌ **禁止** 提交含密钥的文件（`.env` / `google-services.json` 等）
5. ❌ **禁止** 跳过 CI 直接 push `main`

### 6.3 AI 协作禁区

1. ❌ **禁止凭空设计**：所有架构决策必须有代码依据，并落地为 ADR
2. ❌ **禁止跨阶段实现**：当前阶段为 Phase 0 工程化，禁止在未完成 P0 修复前实现新业务功能
3. ❌ **禁止大规模重构与功能改动混在同一 PR**：重构 PR 必须 0 业务行为变化
4. ❌ **禁止删除测试以通过 CI**：测试失败必须修代码，不修测试（除非测试本身有 bug）

### 6.4 AI / Human 提交分工

| 行为 | AI | Human Owner |
|------|----|-------------|
| 创建 branch | ✅ 必须（独立分支） | ✅ |
| 创建 commit | ✅ 可以 | ✅ |
| Commit 必须包含任务范围 | ✅ 必须 | — |
| 创建 PR | ✅ 必须 | ✅ |
| 直接 push 到 `main` | ❌ 禁止 | ✅ |
| Merge PR | ❌ 禁止 | ✅ 专属权限 |
| 架构决策类文件 commit | ❌ 禁止 | ✅ 专属权限 |

**架构决策类文件**指：
- `docs/ADR/*.md`（架构决策记录）
- `AGENTS.md`（协作规范本身）
- `docs/ARCHITECTURE.md` / `docs/ROADMAP.md` / `docs/REFACTOR_DESIGN.md` 等顶层架构文档
- `docs/CRITICAL_REVIEW.md`（架构评审）

**例外**：当 Human Owner 明确授权时（如在任务说明里写明"请你同时更新 ADR-XXXX"），AI 可以 commit 架构决策类文件，但仍必须走 PR 流程。

### 6.5 当前阶段特别禁止

在 Phase 0 工程化 + UI Prototype Freeze 阶段，额外禁止：

1. ❌ 修改 `lib/` 下任何业务逻辑代码
2. ❌ 新增业务功能（主题、TOC、图片等）—— 等到 P0 修复完
3. ❌ 重写 `MarkdownParser` —— 等到 Phase 1 P0 #5 任务启动
4. ❌ 合并 `SharedPreferences` 与 JSON 存储 —— 等到 ADR-0003 执行

---

## 7. 文档体系

```
.agent/                        AI 工程治理层
├── AI_POLICY.md               Agent 身份、权限、行为协议
├── context/
│   └── loading-rules.md       分级上下文加载规则
└── templates/
    └── task-contract.md        任务契约模板

docs/
├── ARCHITECTURE.md          架构总览（当前 + 目标 + 问题 + 风险）
├── ROADMAP.md                路线图（Phase 0-4）
├── CODING_RULES.md           详细编码规范
├── GIT_WORKFLOW.md           Git 详细流程
├── WORKFLOW.md                开发流程与 CI/CD
├── CRITICAL_REVIEW.md        现状严厉批判报告
└── ADR/                      架构决策记录（每条决策一份）
    ├── 0001-project-naming-and-structure.md
    ├── 0002-state-management-riverpod.md
    ├── 0003-storage-single-source-md-files.md
    ├── 0004-markdown-parser-extension-strategy.md
    ├── 0005-exporter-facade-dependency-injection.md
    └── 0006-ci-github-actions.md
```

### ADR 编写规则

- 文件名：`NNNN-<kebab-case-title>.md`，NNNN 从 0001 递增，不复用
- 状态：`Proposed` → `Accepted` → `Superseded by ADR-NNNN` / `Deprecated`
- 内容必须包含：背景、决策、动机、后果、替代方案

---

## 8. CI 与质量门禁

详见 [.github/workflows/ci.yml](file:///d:/Projects/Active/math/.github/workflows/ci.yml)。

**PR 合并必须满足**：

1. `flutter pub get` 成功
2. `flutter analyze` 无 error（warning 允许，但应尽量消除）
3. `flutter test` 全部通过
4. `flutter build` 成功（apk + web 两平台）

**当前状态**：全部 4 项门禁通过。

---

## 9. AI 协作工作流（TRAE / Claude / Cursor 等）

### 9.1 接到任务时的标准流程

1. **先读文档**：本文件 + 相关 ADR + ROADMAP 当前 Phase
2. **再读代码**：相关模块的实际实现，不依赖文档描述
3. **判断阶段**：当前任务是否在允许的阶段范围内
4. **写 todo**：复杂任务（>3 步）必须用 TodoWrite
5. **最小改动**：能改一行不改两行
6. **写测试**：新功能必须有测试；bug 修复必须有回归测试
7. **写文档**：架构决策必须落 ADR
8. **自检**：参照本文档禁止事项逐条确认

### 9.2 编码前必须回答的四个问题

AI Agent 在开始编码前，必须填写 [Task Contract](file:///d:/Projects/Active/math/.agent/templates/task-contract.md)，明确回答：

1. **What changes?** — 修改哪些文件？为什么？
2. **How to verify?** — 测试在哪里？如何证明正确？
3. **What feedback signals exist?** — 成功指标是什么？失败指标是什么？
4. **What is done?** — 什么条件满足才算完成？

复杂任务（Risk Medium+ 或涉及架构变更）的 Task Contract 须提交 Human Owner 审批后再开始实现。

### 9.3 不确定时的升级路径

- 业务范围不清 → 看 ROADMAP / 问用户
- 架构选型不清 → 看 ADR / 提新 ADR
- API 兼容性疑问 → 看相关模块 dartdoc
- 测试策略疑问 → 看 CODING_RULES.md 第 6 章

### 9.4 PR 提交前的自检清单

- [ ] 读了 AGENTS.md 相关章节
- [ ] 没有违反任何 Hard Rules
- [ ] 改动范围与 PR 描述一致
- [ ] 没有夹带未在 PR 描述中说明的改动
- [ ] 测试覆盖完整
- [ ] 文档已同步

---

## 10. 当前阻塞项与例外说明

以下是已知问题，已记入 [CRITICAL_REVIEW.md](file:///d:/Projects/Active/math/docs/CRITICAL_REVIEW.md)，**不视为违反本规范**，但应在对应 Phase 修复：

| 问题 | 修复 Phase |
|------|----------|
| Provider 重复定义 | Phase 1 1.1 |
| 三套存储并存 | Phase 1 1.2 |
| 解析器缺 7 类元素 | Phase 1 1.5 |
| 编辑/预览分离模式 | Phase 3 UI Implementation |
| DocumentListScreen 死代码 | Phase 1 1.3 |
| 错误 detail 透传 UI | Phase 1 1.7 |
| 静态状态污染测试 | Phase 2 |

新增代码不得延续以上问题，必须按目标架构编写。

---

**本文档由首席架构工程师维护，版本 v0.1，生效日期 2026-07-18。**
