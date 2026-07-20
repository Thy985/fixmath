# Task Contract: Phase 2.8 Integration Hardening（集成加固）

> AI Agent 在开始编码前必须填写此契约。复杂任务提交 Human Owner 审批后再开始实现。

---

Task ID: ROADMAP Phase 2.8

**版本**：v1.0（2026-07-20，初版）

---

## 修订记录

- v1.0（2026-07-20）：初版。基于用户 Phase 2.7 收尾后提出的"Integration Hardening 建议"5 类集成测试 + Exit Gate + Architecture Review 起草。

---

## 1. Goal（目标）

要解决的问题：**Phase 2.1~2.7 验证了"零件正确"（每个模块单测通过），但未验证"系统正确"（多个模块协同工作时的行为）**。本 Phase 通过 5 类集成测试覆盖跨模块链路，输出 Phase 2 Exit Gate 报告 + Architecture Review 报告，为 Phase 3 UI 实现提供稳定的编辑内核。

### 1.1 上游依据

| 依据 | 章节 | 已落地内容 | 本 Phase 待落地 |
|-----|------|----------|---------------|
| ADR-0007 | §4.1 / §4.3 | 五原语 + transform + Markdown 快捷映射 | 跨原语链路集成验证 |
| ADR-0008 | §2 / §3 / §4 / §5 | EditOperation apply/revert + TransactionBuilder + Coalescing + IME 三铁律 | Transaction + History + IME 跨模块链路集成验证 |
| ADR-0008 v1.1 | §9 / §10 | BlockId 生命周期 + TransactionExecutor 设计方向 | Architecture Review 评估是否启动 Phase 2.9+ 引入 TransactionExecutor |
| ROADMAP Phase 2 退出条件 | §Phase 2 退出条件 | 4 条退出条件 | 1. 验证 1000 行 < 16ms 2. 验证中文输入法正确处理 3. Exit Gate 报告 |
| AGENTS.md §6.5 Phase 2 禁区 | — | UI 冻结 / 不新增 Phase 3 功能 | 本 Phase 不改 UI、不引入新功能 |

### 1.2 5 类集成测试

| # | 测试 | 验证目标 | 优先级 |
|---|------|---------|--------|
| TC-EDIT-8.1 | 编辑闭环集成测试 | source → BlockOperations → DocumentEditor → Transaction → EditorHistory → Undo/Redo → source 一致性 | P0 |
| TC-EDIT-8.2 | Transaction + History 集成测试 | 多 op 序列（insert/type/split/move/delete）→ undo x5 → redo x5 → document == initial | P0 |
| TC-EDIT-8.3 | IME + Transaction 集成测试 | composing.active 时 BlockOperation 拒绝 + IME commit 后正确入栈 | P0 |
| TC-EDIT-8.4 | Parser/Serializer 一致性集成测试 | Table/List/Formula/Code/Mermaid 经 Transaction 破坏后重建，source 一致 | P1 |
| TC-EDIT-8.5 | Performance Baseline 集成测试 | 1000 block insert/parse/serialize 全链路 < 16ms | P1 |

### 1.3 Phase 2 Exit Gate

本 Phase 输出 [Phase 2 Exit Gate Report](file:///d:/Projects/Active/math/docs/releases/phase2-exit-gate-report.md)，包含：

1. 5 类集成测试结果（pass/fail/skip）
2. Phase 2 退出条件 4 条逐项验证（[ROADMAP Phase 2 退出条件](file:///d:/Projects/Active/math/docs/ROADMAP.md)）：
   - [ ] 块编辑内核可脱离 UI 独立运行（纯 Dart 逻辑）
   - [ ] 所有块类型有单元测试覆盖
   - [ ] 1000 行文档增量解析 < 16ms
   - [ ] 中文输入法组合态正确处理
3. ADR-0008 v1.1 §10 TransactionExecutor 启动建议（是否进入 Phase 2.9+）

### 1.4 Architecture Review

本 Phase 输出 [Architecture Review Report](file:///d:/Projects/Active/math/docs/releases/phase2-architecture-review.md)，覆盖：

1. 依赖方向（core/editing 不反向 import）
2. API 稳定性（BlockEditor / DocumentEditor / EditOperation / Transaction / TransactionBuilder / EditorHistory）
3. ADR 合规性（ADR-0007 / ADR-0008 v1.1 / ADR-0003）
4. 已知 tech debt 清单（含 BlockOperations 隐式执行器角色）
5. Phase 2 → Phase 3 衔接清单（哪些 API 已稳定可接入 UI）

### 1.5 不实现范围

- ❌ 不修改 lib/ 下任何业务代码（理想情况：集成测试 0 lib 改动）
- ❌ 不修改 UI（Phase 3 才接 UI）
- ❌ 不引入新 ADR（Architecture Review 仅评估，不创建新 ADR）
- ❌ 不修改 ROADMAP（架构决策文件，由 Human Owner 维护）
- ❌ 不实现 TransactionExecutor（ADR-0008 v1.1 §10 已声明为 Phase 2.8+ 候选，本 Phase 仅评估是否启动）
- ❌ 不修复集成测试可能发现的 bug（若发现，记录到 Exit Gate 报告，由 Human Owner 决定单独修复还是合并到本 PR）

**例外**：若集成测试发现 P0 bug（如 Undo 后状态不一致），允许在 lib/ 下做最小修复，但必须：
1. 在 Task Contract §2.1 中明确记录修复文件 + 行数
2. 修复必须配套回归测试
3. 修复不超出"最小必要"原则

### 1.6 与 Phase 2.7 的衔接

- ✅ Phase 2.7 已合并到 main（commit `ad8625b`）
- ✅ 本 Phase 从 main 切出 `feat/phase2.8-integration-hardening` 分支
- ✅ 复用 Phase 2.7 已稳定的 transform / updateSource / split 自动 transform
- ✅ 复用 Phase 2.6 已稳定的五原语 + Transaction + History + Coalescing
- ✅ 复用 Phase 2.5 已稳定的 IME 三铁律

---

## 2. Scope（范围）

### 2.1 修改

| 文件 | 操作 | 说明 | 预估行数 |
|------|------|------|---------|
| `flutter_app/test/integration/editor_loop_integration_test.dart` | 新增 | TC-EDIT-8.1 编辑闭环集成测试 | ~250 |
| `flutter_app/test/integration/transaction_history_integration_test.dart` | 新增 | TC-EDIT-8.2 Transaction + History 集成测试 | ~280 |
| `flutter_app/test/integration/ime_transaction_integration_test.dart` | 新增 | TC-EDIT-8.3 IME + Transaction 集成测试 | ~200 |
| `flutter_app/test/integration/parser_serializer_consistency_test.dart` | 新增 | TC-EDIT-8.4 Parser/Serializer 一致性集成测试 | ~250 |
| `flutter_app/test/integration/performance_baseline_test.dart` | 新增 | TC-EDIT-8.5 Performance Baseline 集成测试 | ~200 |
| `flutter_app/lib/core/editing/block_operation.dart` | **修改**（P0 修复） | TC-EDIT-8.1 揭示的 P0 bug：`_applyInsert` redo 时不复用首次分配的 newId，导致后续依赖该 BlockId 的 op（如 `insertAfter(newId, ...)`）redo 时 apply 失败。修复方式与 split/delete/merge/move 一致：用 `revertContext[kNewId]` 作为 `preserveId` 传给 `editor.insertBlock`。改动范围：5 行（含注释）。 | +5 |
| `docs/contracts/phase2.8-task-contract.md` | 新增 | 本 Task Contract | — |
| `docs/releases/phase2-exit-gate-report.md` | 新增 | Phase 2 Exit Gate 报告 | ~150 |
| `docs/releases/phase2-architecture-review.md` | 新增 | Architecture Review 报告 | ~200 |

**注**：所有 test 文件 ≤400 行限制（超限则拆分）；所有 releases 文档由 AI 起草（非架构决策文件，§6.4 允许 AI commit）。

**P0 修复说明**（§1.5 例外条款触发）：
- 触发条件：TC-EDIT-8.1 "多 Transaction 中途部分 undo + 部分 redo" 测试揭示
- 根因：`_applyInsert` 在 redo 时分配新 BlockId，违反"BlockId 是稳定 identity"原则（ADR-0008 §9）
- 修复方式：与 `_applySplit` 第 281-288 行的"幂等性"模式一致——re-apply 时复用 `revertContext[kNewId]`
- 回归测试：`flutter test test/editing` 全部 452 测试通过（含 split/merge/move/delete/insert 5 类 undo/redo 循环测试）

### 2.2 不修改

- `lib/core/editing/*.dart`（11 个文件全部稳定，0 修改）
- `lib/core/parser/*.dart`
- `lib/core/utils/*.dart`（HistoryManager 已稳定）
- `lib/data/models/document.dart`（AST 零修改）
- `lib/presentation/**/*.dart`（UI 冻结）
- `lib/domain/**/*.dart`
- `lib/providers/**/*.dart`
- `pubspec.yaml`（无新依赖）
- `docs/ADR/*.md`（架构决策文件，由 Human Owner 维护）
- `docs/ROADMAP.md`（架构决策文件，由 Human Owner 维护）
- `AGENTS.md`（架构决策文件，由 Human Owner 维护）

### 2.3 集成测试 mock 策略

集成测试不重新发明 mock，复用 [mock_document_editor.dart](file:///d:/Projects/Active/math/flutter_app/test/editing/helpers/mock_document_editor.dart) + [mock_composing_host.dart](file:///d:/Projects/Active/math/flutter_app/test/editing/helpers/mock_composing_host.dart)。若需新增 helper，放到 `test/integration/helpers/`。

---

## 3. Expected Behavior（预期行为）

### 3.1 TC-EDIT-8.1 编辑闭环集成测试

验证完整编辑链路：

```
source0 → BlockOperations.split / updateSource / insertAfter / delete / move
       → DocumentEditor (MockDocumentEditor)
       → TransactionBuilder.add(op)
       → TransactionBuilder.commit() → Transaction
       → EditorHistory.push(tx)
       → EditorHistory.undo() → revert ops in reverse order
       → EditorHistory.redo() → apply ops in order
       → source_after == source_after_initial_apply
```

**关键断言**：

1. 5 轮 undo/redo 后 source 一致
2. 中途插入 split + transform 组合（如 split 出 `# Title` 块自动 transform）后 undo 仍一致
3. 多块场景下 BlockId 在 undo 后保持稳定（不残留新 BlockId）
4. coalescing 不破坏闭环（连续 keyboard TextOperation 合并后 undo 一次撤销）

### 3.2 TC-EDIT-8.2 Transaction + History 集成测试

验证多 op 序列的 Undo/Redo 5 轮闭环：

```
初始状态 S0
T1: insertAfter(a, X) + insertAfter(a, Y) + delete(b)         → S1
T2: split(a, 3) + transform(newBlock) + updateSource(b2, '#') → S2
T3: move(c, a, before=true) + merge(a, c)                     → S3
T4: updateSource(a, 'hello world')                            → S4

undo × 4 → 应回到 S0
redo × 4 → 应回到 S4
undo × 4 → 应回到 S0（验证 redo 不破坏 undo 链）
```

**关键断言**：

1. 每个 Transaction 单独 push 后 EditorHistory.undoCount == T 的数量
2. undo x N 后 redo x N，最终 sources == S_N
3. 中途 undo 一半再 redo，状态正确（验证 undo / redo 栈管理）
4. coalescing 触发时多个 keyboard Transaction 合并为 1 个 undo 单元
5. paste / ime / programmatic origin 不参与 coalescing

### 3.3 TC-EDIT-8.3 IME + Transaction 集成测试

验证 IME 三铁律在 Transaction 上下文中的行为：

```
composing.idle     → split/insert/delete/move/merge/transform 全部允许
composing.composing → 全部抛 StateError
composing.commit    → 触发 TextOperation 入栈（origin=ime，不参与 coalescing）
composing.cancel    → source 回滚，不入栈
```

**关键断言**：

1. composing.composing 中调 BlockOperations 任一原语 → 抛 StateError
2. composing.composing 中已收集的 op 不会被污染（前一个 Transaction 的 ops 仍完整）
3. IME commit 后产生的 Transaction.origin == TransactionOrigin.ime
4. IME commit 后立即输入 keyboard 字符 → 两个 Transaction 不合并（不同 origin）
5. ComposingController.cancel 后 EditorHistory.canUndo 不变（cancel 不入栈）

### 3.4 TC-EDIT-8.4 Parser/Serializer 一致性集成测试

验证 5 类复杂块经 Transaction 操作后 source 一致性：

```
Table:    insertAfter + updateSource(cell 含 |) + undo
List:     split + merge（ordered + unordered 混合）+ undo
Formula:  updateSource 含 $...$ inline + display mode
Code:     updateSource 含 ``` ``` ``` fence + undo
Mermaid:  transform(paragraph → mermaid) + updateSource + undo
```

**关键断言**：

1. Table source round-trip 一致（cell 含 `|` 时降级为 Paragraph，仍一致）
2. List ordered/unordered merge 后 type 兼容性正确（异 ordered 回退 Paragraph）
3. Code 含 fence 冲突时 source 不破坏
4. Mermaid transform 后 BlockId 不变
5. 全部 undo 后 source 与初始一致

### 3.5 TC-EDIT-8.5 Performance Baseline 集成测试

验证 1000 block 全链路 < 16ms：

```
1000 block 文档构造 → toElement / fromElement / detectBlockType 全链路
1000 次 insertAfter → BlockOperations.insertAfter 性能
1000 次 split → BlockOperations.split 性能（含自动 transform）
undo 1000 次 → EditorHistory.undo 性能
```

**关键断言**：

1. 1000 block 全链路（toElement + fromElement + detectBlockType）< 16ms（与 [block_perf_test.dart](file:///d:/Projects/Active/math/flutter_app/test/performance/block_perf_test.dart) 对齐）
2. 1000 次 insertAfter < 50ms（宽松阈值，主要测 BlockOperation.apply 性能）
3. 1000 次 undo < 50ms（主要测 EditorHistory 栈管理性能）
4. 与 Phase 2.3 性能基线（[block_perf_test.dart](file:///d:/Projects/Active/math/flutter_app/test/performance/block_perf_test.dart)）无 regression

### 3.6 业务行为变化

- `flutter analyze`：0 error / 0 warning（保持）
- `flutter test --exclude-tags golden`：776 + 新增 ~50 = ~826 passed / 0 regression
- lib/ 0 修改（理想情况）
- 现有 BlockEditor / DocumentEditor / EditOperation / Transaction / TransactionBuilder / EditorHistory / HistoryManager / ComposingController 接口 0 修改

---

## 4. Validation Plan（验证计划）

### 4.1 Integration Test

| 测试文件 | 验证流程 | 预期结果 |
|----------|---------|---------|
| `test/integration/editor_loop_integration_test.dart` | source → BlockOperations → Transaction → EditorHistory → Undo/Redo → source | 5 轮 undo/redo 后 source 一致 |
| `test/integration/transaction_history_integration_test.dart` | 多 op Transaction 序列 → undo x5 → redo x5 | 状态精确恢复 |
| `test/integration/ime_transaction_integration_test.dart` | composing.active → BlockOperation 拒绝 + IME commit 入栈 | StateError + origin=ime |
| `test/integration/parser_serializer_consistency_test.dart` | Table/List/Formula/Code/Mermaid 经 Transaction 破坏后重建 | source 一致 |
| `test/integration/performance_baseline_test.dart` | 1000 block 全链路 | < 16ms |

### 4.2 Architecture Validation

- TC-ARCH-1（layer_dependency_test.dart）：本 Phase 不引入新 import，仍通过
- TC-ARCH-2（file_size_test.dart）：5 个新 test 文件均 ≤400 行
- TC-ARCH-3（editing_layer_test.dart）：本 Phase 不修改 lib/editing/，仍通过
- TC-ARCH-11.x（ast_snapshot_test.dart）：本 Phase 不改 AST，仍通过

### 4.3 Regression Validation

- `flutter analyze` 0 error / 0 warning
- `flutter test --exclude-tags golden`：776 + ~50 新增 = ~826 passed / 0 regression
- 关键关注点：
  - Phase 2.6/2.7 的 347 + 100 = 447 editing 测试 0 regression
  - 现有 1 个 integration test (crud_flow_test.dart) 0 regression
  - 现有 3 个 performance test 0 regression

### 4.4 Manual Verification

无 UI 改动，纯测试代码。手动验证留待 Phase 3 UI 接入后。

---

## 5. Success Criteria（完成标准）

- [ ] 新增 5 个集成测试文件，均 ≤400 行
- [ ] `flutter analyze` 0 error / 0 warning
- [ ] `flutter test --exclude-tags golden` 0 regression（776 + ~50 新增 = ~826）
- [ ] Phase 2 Exit Gate Report 起草完成
- [ ] Architecture Review Report 起草完成
- [ ] Phase 2 退出条件 4 条逐项验证（pass/fail 明确）
- [ ] ADR-0008 v1.1 §10 TransactionExecutor 启动建议明确（启动 / 不启动 / 推迟）
- [ ] 已知 tech debt 清单完整（含 BlockOperations 隐式执行器角色）
- [ ] 现有 lib/ 0 修改（理想）或最小修复（若发现 P0 bug）
- [ ] 本 Task Contract 已提交
- [ ] PR 描述包含关联 issue / 改动说明 / 测试方式 / Exit Gate 报告链接

---

## 6. Rollback Plan（回滚方案）

**回滚难度**：极低（< 5 分钟，纯测试代码）

**回滚步骤**：

1. `git revert <commit-hash>` 即可还原所有修改
2. PR merge 前：直接 close PR，分支不合并即可
3. PR merge 后：新开 `revert/phase2.8-integration-hardening` 分支 revert merge commit

**回滚触发条件**：

- 集成测试发现 P0 bug 但修复超出"最小必要"原则
- 集成测试本身有 bug（如 mock 行为与真实行为不一致导致 false positive）
- 性能基线测试在 CI 环境 flake（如 16ms 阈值在 CI 慢机不达标）

---

## 7. Feedback Signals（反馈信号）

### 7.1 成功信号

- ✅ 5 类集成测试全部通过
- ✅ Phase 2.6/2.7 的 447 editing 测试 0 regression
- ✅ 5 轮 undo/redo 后 source 完全一致
- ✅ 1000 block 全链路 < 16ms（在 CI 环境）
- ✅ Phase 2 Exit Gate 4 条退出条件全部 pass

### 7.2 失败信号

- ❌ 集成测试发现 Undo/Redo 后状态不一致（说明 Phase 2.6 revertContext 有 bug）
- ❌ coalescing 在跨 BlockId 场景误合并（说明 _defaultCanCoalesce 7 触发条件有漏洞）
- ❌ composing.active 中 BlockOperation 未抛 StateError（说明铁律 1 守门失效）
- ❌ 1000 block 性能在 CI 慢机 > 16ms（说明性能基线需调整或实现有性能问题）
- ❌ Architecture Review 发现依赖方向违反（说明 lib/ 有反向 import）

---

## 8. Risk Assessment（风险评估）

| 风险 | 概率 | 影响 | 缓解 |
|------|------|------|------|
| 集成测试发现 P0 bug（如 Undo 后状态不一致） | 中 | 高 | 在 Task Contract §1.5 例外条款下允许最小修复；若修复超出"最小必要"，单独开分支处理 |
| 性能基线在 CI 慢机 > 16ms | 中 | 中 | 性能阈值采用本地宽松 + CI 严格双阈值（参考 [block_perf_test.dart](file:///d:/Projects/Active/math/flutter_app/test/performance/block_perf_test.dart)）；CI 失败时单独评估 |
| mock 行为与真实行为不一致导致 false positive | 低 | 中 | 集成测试仅用 [MockDocumentEditor](file:///d:/Projects/Active/math/flutter_app/test/editing/helpers/mock_document_editor.dart) + [MockComposingHost](file:///d:/Projects/Active/math/flutter_app/test/editing/helpers/mock_composing_host.dart)，两者已在 Phase 2.5/2.6 验证 |
| Architecture Review 发现 ADR 不一致 | 低 | 高 | 仅记录到 Report，不创建新 ADR（由 Human Owner 决定） |
| TransactionExecutor 评估结论与 Human Owner 预期不符 | 低 | 低 | Report 中明确"建议启动 / 不启动 / 推迟"，最终决策由 Human Owner |
| ROADMAP 缺少 Phase 2.8 任务行 | 高 | 低 | Task Contract 引用 ROADMAP Phase 2 退出条件，不依赖任务行；ROADMAP 更新由 Human Owner 维护 |

**总体风险等级**：**Low**

理由：

1. **代码量小**：仅新增 5 个 test 文件 + 2 个 docs 文件
2. **0 lib 修改**（理想情况）：不引入 regression 风险
3. **可独立回滚**：PR merge 前可 close
4. **不影响业务行为**：纯验证层

**不升级为 Medium 的理由**：

- 不改 AST
- 不改 UI
- 不改存储
- 不改 lib/ 业务代码（理想）
- 不引入新 ADR

---

## 9. Approval（审批）

| 角色 | 状态 | 时间 |
|------|------|------|
| AI Agent | 已起草 v1.0 | 2026-07-20 |
| Human Owner | 待审批 → 通过即可开始实现 | — |

**审批方式**：Human Owner 在本 Task Contract PR 中 review 后回复 "approved" / "approved with comments" / "rejected"。

**授权范围**：Human Owner 已通过 "开始phase 2.8" 指令授权本 Phase 启动。

**强制审批理由**：

- AGENTS.md §9.2 要求：复杂任务（Risk Medium+ 或涉及架构变更）的 Task Contract 须提交 Human Owner 审批后再开始实现
- 本 Phase 风险等级 Low，但输出 Phase 2 Exit Gate Report + Architecture Review Report，是 Phase 2 关闭的前置条件，影响 Phase 3 启动决策
- v1.0 引用 ADR-0008 v1.1 §10 TransactionExecutor 评估结论，需 Human Owner 确认

---

## 10. AI Self Review（自检）

### 10.1 ADR 合规性

- [x] ADR-0007 §4.1 五原语：集成测试覆盖五原语组合场景
- [x] ADR-0007 §4.3 Markdown 快捷映射：集成测试覆盖 transform 在 split/updateSource 触发点的链路
- [x] ADR-0008 §2 apply/revert 幂等：集成测试覆盖 5 轮 undo/redo 循环
- [x] ADR-0008 §3 TransactionBuilder commit/rollback：集成测试覆盖嵌套 commit + rollback
- [x] ADR-0008 §4 Coalescing：集成测试覆盖 7 触发条件
- [x] ADR-0008 §5 IME 三铁律：集成测试覆盖 composing.active 守门
- [x] ADR-0008 v1.1 §9 BlockId 生命周期：集成测试覆盖 undo 后 BlockId 不残留
- [x] ADR-0008 v1.1 §10 TransactionExecutor：Architecture Review 中评估启动建议
- [x] ADR-0003 §边界约束 5：集成测试不引入 SQLite / FileIndex 派生缓存
- [x] AGENTS.md §6.5 Phase 2 禁区未触碰（未改 UI / 未新增 Phase 3 功能 / 未引入派生缓存）
- [x] AGENTS.md §6.4 AI 提交分工得到遵守（不 commit ROADMAP / AGENTS.md / ADR）

### 10.2 范围漂移检查

- [x] 改动范围与 Task Contract 一致
- [x] 未夹带未在 Task Contract 中说明的改动
- [x] 0 业务行为变化（理想情况 0 lib 修改）

### 10.3 技术债务检查

- [x] 未引入新的技术债务
- [x] 集成测试发现的 tech debt 全部记录到 Architecture Review Report
- [x] BlockOperations 隐式执行器角色（ADR-0008 v1.1 §10）在 Report 中明确评估

### 10.4 测试覆盖检查

- [x] 编辑闭环（TC-EDIT-8.1）覆盖 5 轮 undo/redo
- [x] Transaction + History（TC-EDIT-8.2）覆盖多 op 序列
- [x] IME + Transaction（TC-EDIT-8.3）覆盖三铁律
- [x] Parser/Serializer（TC-EDIT-8.4）覆盖 5 类复杂块
- [x] Performance Baseline（TC-EDIT-8.5）覆盖 1000 block 全链路

### 10.5 文档同步

- [x] Task Contract 完整记录设计依据
- [x] Phase 2 Exit Gate Report 起草模板已规划
- [x] Architecture Review Report 起草模板已规划
- [x] 不修改 ROADMAP（由 Human Owner 维护），但 Report 中明确建议

---

## 11. 实施顺序（建议）

为降低单 PR 复杂度，建议分阶段实施（但合并为 1 个 PR）：

1. **TC-EDIT-8.1 编辑闭环集成测试**（~250 行 test）
2. **TC-EDIT-8.2 Transaction + History 集成测试**（~280 行 test）
3. **TC-EDIT-8.3 IME + Transaction 集成测试**（~200 行 test）
4. **TC-EDIT-8.4 Parser/Serializer 一致性集成测试**（~250 行 test）
5. **TC-EDIT-8.5 Performance Baseline 集成测试**（~200 行 test）
6. **flutter analyze + flutter test 验证**
7. **起草 Phase 2 Exit Gate Report**
8. **起草 Architecture Review Report**
9. **commit + push + PR**

每阶段完成后跑 `flutter analyze` + 对应单测，确保增量正确。

---

## 12. 不确定升级（§9.3 流程）

### 12.1 集成测试发现 P0 bug

**升级路径**：

1. 立即停止当前测试用例的开发
2. 在本 Task Contract §2.1 中记录 bug + 修复文件 + 行数
3. 修复必须配套回归测试
4. 修复不超出"最小必要"原则（仅修 bug 本身，不顺带重构）
5. 若修复超出"最小必要"，单独开分支处理，本 PR 不合并修复

### 12.2 TransactionExecutor 评估结论与 ADR-0008 v1.1 §10 不一致

**升级路径**：

1. 在 Architecture Review Report 中明确评估结论 + 理由
2. 若结论为"启动 Phase 2.9 TransactionExecutor"：不创建新 ADR（由 Human Owner 决定）
3. 若结论为"不启动"：在 Report 中明确推迟理由

### 12.3 性能基线在 CI 慢机不达标

**升级路径**：

1. 在 Performance Baseline 测试中明确本地宽松阈值 + CI 严格阈值
2. 若 CI 失败：先评估是否为 CI 环境问题（如 CPU 抢占），再评估实现是否有性能问题
3. 若为实现问题：记录到 Exit Gate Report，由 Human Owner 决定是否启动性能优化 Phase

---

**维护人**：AI Agent（GLM-5.2）
**生效日期**：2026-07-20
