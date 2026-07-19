# TEST_SKIP_REGISTRY — 测试跳过清单

> **目的**：登记所有 `skip: true` / `skip: 'reason'` 的测试，避免"半年后没人知道为什么跳过"。
>
> **维护规则**：
> - 新增 skip 必须同步登记到本文件
> - 每 Phase 退出前回顾，已解封的从 Registry 删除并归档到对应 Phase 的 Verification Report
> - 字段：测试路径 / 跳过原因 / 解封 Phase / 跟踪链接

**当前总数**：9 个 skip（截至 2026-07-19，Phase 1 Close Candidate 时点）

---

## 1. 架构守门历史遗留（6 个）

均位于 [test/architecture/provider_uniqueness_test.dart](file:///d:/Projects/Active/math/flutter_app/test/architecture/provider_uniqueness_test.dart)，对应 AGENTS.md §10「当前阻塞项与例外说明」中的「Provider 重复定义」。

| # | 测试 | Skip 原因 | 解封 Phase | 跟踪 |
|---|------|----------|-----------|------|
| 1 | `sharedPreferencesProvider 唯一` | `providers/providers.dart` 与 `editor_providers.dart` 重复定义 | Phase 1 1.1（Provider 重构） | ROADMAP 1.1 |
| 2 | `darkModeProvider 唯一` | 两文件均定义 `DarkModeNotifier` | Phase 1 1.1 | ROADMAP 1.1 |
| 3 | `documentsProvider 唯一` | `providers/providers.dart` 与 `domain/providers/document_provider.dart` 重复 | Phase 1 1.1 | ROADMAP 1.1 |
| 4 | `editorProvider 唯一` | 两文件重复定义 | Phase 1 1.1 | ROADMAP 1.1 |
| 5 | `currentDocumentProvider 唯一` | 两文件重复定义 | Phase 1 1.1 | ROADMAP 1.1 |
| 6 | `isPreviewMode 唯一` | 两文件重复定义 | Phase 1 1.1 | ROADMAP 1.1 |

**冻结策略**：6 个 skip 数量在 Phase 1 期间不允许新增；解封时必须成组（一次性解封全部 6 个），避免分批合并引入回归。

---

## 2. Phase 0 UI 冻结阻塞（1 个）

| # | 测试 | Skip 原因 | 解封 Phase | 跟踪 |
|---|------|----------|-----------|------|
| 7 | [test/golden/file_manager_test.dart](file:///d:/Projects/Active/math/flutter_app/test/golden/file_manager_test.dart) `有文件状态：显示文件列表` | `FileManagerScreen._loadFiles` 在 `initState` 中调用 `await file.readAsBytes()` 真实磁盘 I/O，与 Flutter test fake async zone 冲突，setState 永不触发。Phase 0 UI Prototype Freeze 禁止修改 `FileManagerScreen` 行为。 | Phase 3 UI 重构（引入 Provider 解耦文件 I/O 后） | ROADMAP Phase 3 |

**临时覆盖**：空状态 Golden 已通过（`file_manager_empty.png` 基线已生成），覆盖 AppBar + Scaffold + 空状态布局结构回归。

---

## 3. 平台 mock 未补齐（2 个）

| # | 测试 | Skip 原因 | 解封 Phase | 跟踪 |
|---|------|----------|-----------|------|
| 8 | [test/storage/migration_test.dart](file:///d:/Projects/Active/math/flutter_app/test/storage/migration_test.dart) 第 37 行 `migrateIfNeeded 在无 JSON 时跳过并标记 marker` | 需 path_provider mock 注入临时目录（`_MockPathProvider` 已在 [storage_repository_test.dart](file:///d:/Projects/Active/math/flutter_app/test/storage_repository_test.dart) 实现但未抽到共享 helper） | Phase 2 测试基础设施 | - |
| 9 | [test/storage/migration_test.dart](file:///d:/Projects/Active/math/flutter_app/test/storage/migration_test.dart) 第 58 行 `migrateIfNeeded 在 marker 已存在时幂等跳过` | 同上，需 path_provider mock | Phase 2 测试基础设施 | - |

**临时覆盖**：[storage_repository_test.dart](file:///d:/Projects/Active/math/flutter_app/test/storage_repository_test.dart) 已覆盖 `StorageMigration.migrateIfNeeded` 的幂等性 + 无 JSON 路径 + 篡改后不还原，回归保护已建立，本 2 个 skip 不构成关键缺口。

---

## 4. 已知 parser 限制（非 skip，但作为已知偏差登记）

下列 parser 行为**未跳过测试**，而是通过放松断言 + 注释说明的方式记录：

| 现象 | 测试 | 处理方式 | 修复 Phase |
|------|------|---------|-----------|
| `_italicStarRe = RegExp(r'\*([^*\n]+?)\*')` 误匹配 `**bold *italic ~text` 中的 `*bold *` 为 ItalicElement | [test/parser/edge_case_test.dart](file:///d:/Projects/Active/math/flutter_app/test/parser/edge_case_test.dart) `连续未闭合标记不导致崩溃` | 仅断言"无 BoldElement"，不断言"无 ItalicElement" | Phase 3（Parser 重写） |
| `MarkdownParser.parse('   \n   \n   ')` 返回 3 个 EmptyLineElement（非空列表） | [test/parser/edge_case_test.dart](file:///d:/Projects/Active/math/flutter_app/test/parser/edge_case_test.dart) `只有空白字符不产生 ParagraphElement` | 断言 `whereType<ParagraphElement>().isEmpty` 而非 `elements.isEmpty` | Phase 3 |

---

## 5. 审计规则

- **频率**：每 Phase 退出前回顾一次
- **解封流程**：
  1. 修复根因（如 Provider 重构、UI Provider 解耦）
  2. 删除测试中的 `skip: ...`
  3. 跑全量 `flutter test` 确认通过
  4. 从本 Registry 删除对应条目
  5. 在对应 Phase 的 Verification Report 中归档"已解封 skip 列表"
- **新增规则**：Phase 1 期间不允许新增 skip，除非由 Human Owner 审批
- **越界检查**：每 Phase 退出时 `grep -rn "skip:" flutter_app/test/ | wc -l` 必须等于本 Registry 当前条目数

---

**本文档由 AI Agent 维护，版本 v1.0，生效日期 2026-07-19。**
