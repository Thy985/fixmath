# ADR-0001: 项目命名与目录结构

- **状态**：Accepted
- **生效日期**：2026-07-18
- **决策者**：首席架构工程师

## 背景

FormulaFix 是一个基于 Flutter 的 Markdown 数学文档编辑器，目标是演进为移动端 Typora 类产品。

代码分析发现：

1. **现有目录** 已按 6 层分层结构组织，证据：
   - `lib/core/`（parser / renderers / services / router / utils / constants）
   - `lib/data/models/`（document / template）
   - `lib/domain/`（providers / services）
   - `lib/presentation/`（screens / widgets / components / theme）
   - `lib/providers/`（与 `domain/providers` 职责重叠）

2. **产品命名** 已分散落地：
   - [web/manifest.json](file:///d:/Projects/Active/math/flutter_app/web/manifest.json): `"name": "formula_fix"`
   - [main.dart:26](file:///d:/Projects/Active/math/flutter_app/lib/main.dart#L26): `title: 'FormulaFix'`
   - 文档存储文件名 `formula_fix_documents.json`（[document_service.dart:10](file:///d:/Projects/Active/math/flutter_app/lib/core/services/document_service.dart#L10)）
   - 自动保存文件名 `formulafix_<timestamp>.md`（[file_service.dart:76](file:///d:/Projects/Active/math/flutter_app/lib/core/services/file_service.dart#L76)）

3. **现有问题**：
   - `lib/providers/` 与 `lib/domain/providers/` 职责重叠，是 P0 阻塞问题（见 [CRITICAL_REVIEW.md §2.4](file:///d:/Projects/Active/math/docs/CRITICAL_REVIEW.md)）
   - 项目根目录无 `pubspec.yaml`，无法构建

## 决策

### 1. 项目命名

- **应用名**：FormulaFix（PascalCase）
- **包名**：`formulafix`（lowercase，用于 `pubspec.yaml`）
- **manifest name**：`FormulaFix`（修正 web/manifest.json 的默认值）
- **文件名前缀**：`formula_fix_`（snake_case，用于持久化文件）

### 2. 目录结构

保留现有 6 层分层架构：

```
flutter_app/
├── lib/
│   ├── core/         基础设施
│   ├── data/         数据模型
│   ├── domain/       业务领域
│   ├── presentation/ UI
│   ├── providers/    全局 Provider（统一）
│   └── main.dart
├── test/             测试（镜像 lib/ 结构）
├── web/              PWA 资产
├── assets/           字体 / JS / HTML
└── pubspec.yaml      （待补齐）
```

### 3. Provider 归属规则

- `lib/providers/`：**全局唯一**的全局 Provider 位置
- `lib/domain/providers/`：**业务级** Provider（与特定业务域绑定，如导出、文档管理）

合并规则（Phase 1 P0 #1 执行）：
- 删除 [lib/providers/editor_providers.dart](file:///d:/Projects/Active/math/flutter_app/lib/providers/editor_providers.dart) 中重复的 `sharedPreferencesProvider` / `darkModeProvider`
- 编辑器特定 Provider（如 `editorContentProvider`）保留在 `lib/providers/editor_providers.dart`
- 业务 Provider 留在 `lib/domain/providers/`

### 4. `flutter_app/` 作为唯一 Flutter 工程目录

- 项目根 `d:/Projects/Active/math/` 持有 `docs/` / `AGENTS.md` / `.github/` 等工程治理文件
- `d:/Projects/Active/math/flutter_app/` 是 Flutter 工程目录，持有 `pubspec.yaml` / `lib/` / `test/` / `web/`

## 动机

1. **保留现有架构**：6 层分层已是 Flutter 社区主流模式（参考 Clean Architecture），无需推倒重来
2. **明确职责边界**：`core` 不依赖业务，`data` 不依赖 UI，便于测试与重构
3. **解决 Provider 重复**：当前 P0 问题必须在不破坏 import 兼容性的前提下解决
4. **包名一致性**：避免 `formula_fix` / `formulafix` / `FormulaFix` 三种命名混用

## 后果

### 正面

- 现有代码 import 路径基本不变
- 测试目录镜像 `lib/`，无歧义
- 工程治理文件与代码分离清晰

### 负面

- Phase 1 P0 #1 需要修改多个文件的 import 路径
- `flutter_app/` 子目录结构让 CI 配置需要 `working-directory`（见 ADR-0006）

## 替代方案

### 方案 A：单一根目录结构（无 `flutter_app/` 子目录）

把 Flutter 工程放项目根目录。

**否决理由**：会让 `docs/` / `AGENTS.md` / `.github/` 与 Flutter 工程文件混在一起，职责不清。

### 方案 B：拆分为 monorepo（packages/core + packages/app）

**否决理由**：当前规模不需要 monorepo，增加构建复杂度。

### 方案 C：Feature-first 结构（`features/editor/` / `features/export/`）

**否决理由**：与现有 6 层结构差异太大，重构成本过高。可在 Phase 4 重新评估。

## 参考

- [CRITICAL_REVIEW.md](file:///d:/Projects/Active/math/docs/CRITICAL_REVIEW.md) §2.4
- [AGENTS.md §1](file:///d:/Projects/Active/math/AGENTS.md) 项目架构原则
