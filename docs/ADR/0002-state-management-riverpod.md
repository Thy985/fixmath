# ADR-0002: 状态管理选型 Riverpod

- **状态**：Accepted
- **生效日期**：2026-07-18
- **决策者**：首席架构工程师

## 背景

代码分析显示项目已使用 `flutter_riverpod` 作为状态管理方案。证据：

1. [main.dart:2](file:///d:/Projects/Active/math/flutter_app/lib/main.dart#L2) `import 'package:flutter_riverpod/flutter_riverpod.dart';`
2. [main.dart:11-15](file:///d:/Projects/Active/math/flutter_app/lib/main.dart#L11-15) 用 `ProviderScope` 包裹根 Widget
3. [providers/providers.dart](file:///d:/Projects/Active/math/flutter_app/lib/providers/providers.dart) 全文用 `Provider` / `StateNotifierProvider` / `StateProvider` / `FutureProvider`
4. [providers/providers.dart:39-75](file:///d:/Projects/Active/math/flutter_app/lib/providers/providers.dart#L39-75) `DocumentsNotifier extends StateNotifier<AsyncValue<List<Document>>>`
5. 所有 screens 用 `ConsumerStatefulWidget` / `ConsumerWidget`（如 [editor_screen.dart:18](file:///d:/Projects/Active/math/flutter_app/lib/presentation/screens/editor_screen.dart#L18)）

现有 Provider 类型分布：

| 类型 | 用途 | 例子 |
|------|------|------|
| `FutureProvider` | 异步初始化 | `sharedPreferencesProvider` |
| `Provider` | 依赖注入 | `documentServiceProvider` / `clipboardServiceProvider` |
| `StateNotifierProvider` | 业务状态 | `darkModeProvider` / `documentsProvider` / `editorContentProvider` |
| `StateProvider` | UI 简单状态 | `previewModeProvider` / `isExportingProvider` / `searchQueryProvider` |
| 衍生 Provider | 派生数据 | `filteredDocumentsProvider` |

## 决策

**继续使用 `flutter_riverpod` 作为唯一状态管理方案。**

### 规则

1. **禁止** 引入其他状态管理库（`bloc` / `provider`（旧版） / `getx` / `mobx`）
2. **禁止** 用 `StatefulWidget` + `InheritedWidget` 模拟全局状态
3. **Provider 类型选择** 严格按 [CODING_RULES.md §5.1](file:///d:/Projects/Active/math/docs/CODING_RULES.md#51-provider-选择决策树) 决策树
4. **状态不可变**：所有 `StateNotifier<S>` 的 `S` 必须不可变
5. **Provider 归属** 严格按 [CODING_RULES.md §5.3](file:///d:/Projects/Active/math/docs/CODING_RULES.md#53-归属)

### 现有违规（Phase 1 P0 #1 修复）

- `sharedPreferencesProvider` 在 [providers/providers.dart:8-10](file:///d:/Projects/Active/math/flutter_app/lib/providers/providers.dart#L8-10) 与 [providers/editor_providers.dart:4-6](file:///d:/Projects/Active/math/flutter_app/lib/providers/editor_providers.dart#L4-6) 各定义一次
- `darkModeProvider` 在 [providers/providers.dart:20-35](file:///d:/Projects/Active/math/flutter_app/lib/providers/providers.dart#L20-35) 与 [providers/editor_providers.dart:8-23](file:///d:/Projects/Active/math/flutter_app/lib/providers/editor_providers.dart#L8-23) 各定义一次

两个文件定义同名 Provider 在 Riverpod 中是**两个独立实例**，状态不同步。

## 动机

### 选择 Riverpod 的理由

1. **已落地**：现有代码全部用 Riverpod，切换成本远高于保留
2. **编译期安全**：相比 `provider` 旧版，Riverpod 的 `Provider` 不依赖 `BuildContext`，可在 `initState` 中安全读取
3. **类型推导强**：`StateNotifierProvider<DocumentsNotifier, AsyncValue<List<Document>>>` 完整类型签名
4. **测试友好**：可注入 override，无需 mock BuildContext
5. **Dart 3 适配好**：records / sealed class 与 Riverpod 2.x 配合良好

### 否决其他方案的理由

- **`bloc`**：样板代码过多，事件 / 状态分离对中小型 App 过度设计
- **`getx`**：依赖 `GetxController` 全局单例，反 DI 原则；与本项目"显式依赖"原则冲突
- **`mobx`**：Observable / Action / Reaction 概念与 Flutter 响应式模型不完全契合
- **`provider` 旧版**：被官方废弃，Riverpod 是其继任者

## 后果

### 正面

- 状态变更可追踪（`StateNotifier` 单向数据流）
- 测试可注入 override（`ProviderScope(overrides: [...])`）
- 与现有代码完全兼容

### 负面

- 学习曲线：新人需理解 `Provider` / `StateNotifierProvider` / `autoDispose` 等概念
- 跨文件同名 Provider 陷阱（如本次 P0 问题）

## 替代方案

### 方案 A：迁移到 Bloc

**否决理由**：
- 现有代码量已不小，迁移成本高
- Bloc 对本项目规模过度设计
- 现有 Riverpod 用法没有明显瓶颈

### 方案 B：保留 Riverpod 但全部用 `Notifier`（Riverpod 2.x 新 API）

**否决理由**：现有 `StateNotifier` 已可用，2.x 新 API 主要是语法糖，迁移可放在 Phase 4。

## 实施

- Phase 1 P0 #1：合并重复 Provider，统一到 `lib/providers/`（业务级留在 `lib/domain/providers/`）
- Phase 2：评估是否升级到 Riverpod 2.x `Notifier` API
- Phase 4：评估是否拆分 `autoDispose` 与非 autoDispose Provider

## 参考

- [AGENTS.md §3](file:///d:/Projects/Active/math/AGENTS.md) 状态管理规范
- [CODING_RULES.md §5](file:///d:/Projects/Active/math/docs/CODING_RULES.md) Riverpod 详细规则
- [CRITICAL_REVIEW.md §2.4](file:///d:/Projects/Active/math/docs/CRITICAL_REVIEW.md) Provider 重复定义问题
