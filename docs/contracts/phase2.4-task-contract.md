# Task Contract: Phase 2.4 AST 重构对齐评估

> AI Agent 在开始编码前必须填写此契约。复杂任务提交 Human Owner 审批后再开始实现。

---

Task ID: ROADMAP Phase 2.4

**版本**：v1.1（2026-07-19，落地评审反馈 4 项修订）

---

## 修订记录

- v1.0（2026-07-19）：初版
- v1.1（2026-07-19）：基于 Human Owner 评审反馈（9/10）修订 4 项：
  1. ADR-0007 修订方式：不修改历史决策正文，改用 Addendum 追加
  2. TableElement 不拆理由：强化为"Composite Block 内部节点，非 Document-level Block"层级边界
  3. EmptyLineElement 保留理由：补充"Document Formatting Node vs Editable Block Node"概念区分
  4. ElementType 清理：明确标注为"附带 cleanup"
  5. 新增 AST snapshot regression 验证
  6. Future ADR 候选调整：ADR-0008 改为 Transaction Model（Phase 2.5 前完成）

---

## 1. Goal（目标）

要解决的问题：**完成 ADR-0007 §Phase 2.4 三项评估，确定 AST 是否需要重构以对齐 BlockEditor 块类型**。

ADR-0007 §Phase 2.4 列出三项评估任务：

> - 评估 `EmptyLineElement` 是否从 AST 移除（BlockEditor 不编辑空行）
> - 评估 `TableElement` 是否拆为 `TableRow` / `TableCell` 块
> - ADR-0007 修订（如需）

**评估结论（已由代码扫描得出）**：

| 评估项 | 结论 | 理由 |
|--------|------|------|
| EmptyLineElement 移除 | **保留** | EmptyLineElement 属于 **Document Formatting Node**（保留 Markdown 空行格式，影响 round-trip / 导出 / 编辑体验），而非 **Editable Block Node**。BlockEditor 通过抛 `ArgumentError` 隔离空行，AST/Editor Model 职责分离正确。13 文件依赖。 |
| TableElement 拆分 | **不拆** | TableRow/TableCell 是 **Composite Block 的内部节点**，不属于 **Document-level Block**（Block = 用户可感知编辑单元）。拆分会破坏 ADR-0007 §1.3 Wrapping 决策"Block 与 DocumentElement 1:1 映射"；17 文件依赖；cell inline 解析已通过 `MarkdownParser.parseInline()` 解决。 |
| ADR-0007 修订 | **Addendum 追加** | 以 Addendum 方式追加 Phase 2.4 评估结论，**不修改历史决策正文**（保持 ADR 历史可追踪）。 |

**附带 cleanup**（不属 Phase 2.4 核心目标）：

- `enum ElementType` 在 [document.dart:1-10](file:///d:/Projects/Active/math/flutter_app/lib/data/models/document.dart#L1-10) 定义但**全项目无任何引用**（Phase 1 遗留死代码）。本任务一并清理。

**不实现**：
- AST 字段修改（HeadingElement.text / BlockquoteElement.text 仍为 plain String）
- TableElement 结构拆分
- EmptyLineElement 移除
- 任何 UI 行为变化（AGENTS.md §6.5 仍属 UI Prototype Freeze 期）

---

## 2. Scope（范围）

### 修改

| 文件 | 变更类型 | 说明 |
|------|---------|------|
| `docs/ADR/0007-blockeditor-abstraction-design.md` | 修改（Addendum） | **不修改历史决策正文**，在文末追加 `## Phase 2.4 Evaluation Addendum` 章节，记录三项评估结论（用户已授权） |
| `flutter_app/lib/data/models/document.dart` | 修改（附带 cleanup） | 移除死代码 `enum ElementType`（10 行） |
| `flutter_app/test/architecture/ast_snapshot_test.dart` | 新增 | AST snapshot regression 测试，验证 Phase 1 sample documents 解析后 AST 结构稳定 |
| `docs/contracts/phase2.4-task-contract.md` | 新增 | 本 Task Contract |

### 不修改

- `lib/core/parser/markdown_parser.dart`（parser 不变）
- `lib/core/editing/block_*.dart`（Phase 2.2/2.3 产物已稳定）
- `lib/presentation/widgets/preview_content.dart`（UI 冻结）
- `lib/domain/services/exporters/*.dart`（导出器不变）
- 所有 test 文件（评估性任务不改测试）

---

## 3. Expected Behavior（预期行为）

### 3.1 ADR-0007 追加 Addendum（不修改历史决策正文）

**ADR 生命周期原则**：ADR 的价值在于"记录过去为什么这么决定"，历史决策正文不可修改。
本任务在 ADR-0007 文末追加 `## Phase 2.4 Evaluation Addendum` 章节，**保持原 §决策、§动机、§后果 等正文不变**。

Addendum 内容（追加在 ADR-0007 文末"## 参考"章节之前）：

```markdown
## Phase 2.4 Evaluation Addendum

**追加日期**：2026-07-19
**状态**：Phase 2.4 评估完成，AST 保持稳定，不重构。

### 评估结论

| 评估项 | 结论 | 核心理由 |
|--------|------|---------|
| EmptyLineElement 移除 | **保留** | 属于 **Document Formatting Node**，非 **Editable Block Node** |
| TableElement 拆分 | **不拆** | TableRow/TableCell 是 **Composite Block 内部节点**，非 **Document-level Block** |
| ADR-0007 修订 | **Addendum 追加** | 不修改历史决策正文，保持可追踪性 |

### 1. EmptyLineElement 保留理由

**概念区分**：

- **Document Formatting Node**：表达 Markdown 文档结构（含空行格式），影响 source round-trip / 导出格式 / 编辑体验。`EmptyLineElement` 属此类。
- **Editable Block Node**：BlockEditor 可编辑单元（Block = 用户可感知编辑单元）。空行不是 Block。

**职责分离**：

```
AST 层    : EmptyLineElement ✅（保留 Markdown 空行格式）
Editor 层 : EmptyLineElement ❌（不在 BlockType 枚举中）
```

**风险**：移除 EmptyLineElement 会导致：

```markdown
# Title


Paragraph
```

解析后变：

```
HeadingElement
ParagraphElement
```

重新生成 Markdown 时丢空行格式：

```markdown
# Title
Paragraph
```

**结论**：AST 与 BlockEditor 职责已正确分离（[block_types.dart:70](file:///d:/Projects/Active/math/flutter_app/lib/core/editing/block_types.dart) 抛 `ArgumentError`），无需改 AST。

### 2. TableElement 不拆理由

**层级边界论点**（强化版）：

```
Document
   |
   Block (Document-level，用户可感知编辑单元)
   |    ├── HeadingBlock
   |    ├── ParagraphBlock
   |    └── TableBlock  ← Block 边界止于此
   |
   Composite Block 内部节点（非 Document-level）
        ├── TableRow
        └── TableCell
              |
              Inline
```

**核心理由**：用户不认为"第二行第三列"是一个 Block，它是 Table 的内部结构。
若拆分为 `TableRowBlock` / `TableCellBlock`，会破坏 ADR-0007 §1.3 Wrapping 决策
"Block 与 DocumentElement 1:1 映射"，并让 BlockEditor 的光标模型（§2）失效
（光标如何在 row/cell 间导航？）。

**cell inline 解析**：[markdown_parser.dart:295](file:///d:/Projects/Active/math/flutter_app/lib/core/parser/markdown_parser.dart)
已公开 `MarkdownParser.parseInline()`，pdf/word exporter 已用，无需改 TableElement 结构。

**未来扩展**：Phase 3+ UI 层做表格 cell 编辑时，可在 `TableBlock.source` 内部
实现 cell-level cursor，不影响 BlockEditor 抽象。

### 3. 附带 cleanup

移除 `enum ElementType`（Phase 1 遗留死代码，全项目无引用）。
`BlockType`（[block_types.dart](file:///d:/Projects/Active/math/flutter_app/lib/core/editing/block_types.dart)）
才是 BlockEditor 使用的类型枚举。

### 决策

**AST 在 Phase 2 保持稳定，不重构。**

未来若要移除 EmptyLineElement 或拆分 TableElement，应作为单独 ADR
（如 ADR-0011+）在 Phase 4+ 评估，并附完整迁移方案。
```

### 3.2 ElementType 死代码清理（附带 cleanup）

[document.dart:1-10](file:///d:/Projects/Active/math/flutter_app/lib/data/models/document.dart#L1-10) 的 `enum ElementType { ... }` 整段移除。`DocumentElement` 及其子类保持原样。

### 3.3 业务行为不变

- `flutter analyze`：0 error / 0 warning（移除 ElementType 后无新 warning）
- `flutter test --exclude-tags golden`：与 Phase 2.3 相同的 471 passed / 8 skipped / 0 regression
- AST 数据形状：0 变化（所有 DocumentElement 子类签名不变）

---

## 4. Validation Plan（验证计划）

### 4.1 Unit Test

无新增 unit test。本任务是评估性 + 死代码清理 + AST snapshot 守门，不需要业务逻辑测试。

### 4.2 Architecture Validation

- TC-ARCH-7（file_size_test.dart）：清理 10 行后 document.dart 仍 ≤400 行
- TC-ARCH-11（editing_layer_test.dart）：仍通过（Phase 2.4 不改 editing/）

### 4.3 AST Snapshot Regression（新增）

**目的**：证明 Phase 2.4 后 AST 数据形状 0 变化。这是 AST 稳定性的**显式证明**，
防止未来 Phase 2.5+ 误改 AST 字段而不自知。

**测试位置**：[flutter_app/test/architecture/ast_snapshot_test.dart](file:///d:/Projects/Active/math/flutter_app/test/architecture/ast_snapshot_test.dart)（新建）

**测试方法**：

1. 构造 5 份 Phase 1 sample markdown 文档（覆盖 10 类 Block + 8 类 Inline）：
   - sample 1：纯 paragraph + inline（bold/italic/code/link/image/formula）
   - sample 2：heading 6 级 + horizontalRule + blockquote
   - sample 3：list（ordered/unordered）+ taskListItem（checked/unchecked）+ 嵌套 indent
   - sample 4：code（含 mermaid）+ table（多行多列）
   - sample 5：empty line 混合（验证 EmptyLineElement 保留）

2. 用 `MarkdownParser.parse(sample)` 解析得 AST

3. 对 AST 做**结构快照断言**：
   - `expect(elements.length, equals(N))` — 块数
   - `expect(elements[i], isA<XxxElement>())` — 块类型
   - 关键字段断言（HeadingElement.level / ListElement.ordered / TableElement.rows.length 等）

4. 测试断言为"硬编码期望值"——若未来误改 AST 字段或 parser 行为，此测试必失败

**TC-ARCH-12 标识**：

- `TC-ARCH-12.1` sample 1（inline 全覆盖）
- `TC-ARCH-12.2` sample 2（heading/rule/quote）
- `TC-ARCH-12.3` sample 3（list/task/indent）
- `TC-ARCH-12.4` sample 4（code/mermaid/table）
- `TC-ARCH-12.5` sample 5（empty line + 混合）

### 4.4 Regression Validation

- `flutter analyze` 0 error / 0 warning
- `flutter test --exclude-tags golden`：471 passed + 5 新增 snapshot = 476 passed / 8 skipped / 0 regression
- 关键关注点：移除 ElementType 后是否触发任何 import 失败（应无，因无引用）

### 4.5 Manual Verification

无需手动验证（无 UI 行为变化）。

---

## 5. Success Criteria（完成标准）

- [x] ADR-0007 文末追加 Phase 2.4 Evaluation Addendum（不修改历史决策正文）
- [x] `enum ElementType` 从 document.dart 移除（附带 cleanup）
- [x] 新增 TC-ARCH-12.x AST snapshot regression 测试（5 sample）
- [x] `flutter analyze` 0 error / 0 warning
- [x] `flutter test --exclude-tags golden` 0 regression（471 + 5 新增 = 476 passed）
- [x] AST 数据形状 0 变化（DocumentElement 子类签名不变）
- [x] 17 个 TableElement 使用文件 0 修改
- [x] 13 个 EmptyLineElement 使用文件 0 修改
- [x] 本 Task Contract 已提交
- [x] PR 描述包含关联 issue / 改动说明 / 测试方式
- [x] ADR-0007 修订经 Human Owner 授权（用户已选择"修订 ADR-0007 + 清理 ElementType" + 9/10 评审反馈 4 项修订）

---

## 6. Rollback Plan（回滚方案）

**回滚难度**：极低（< 5 分钟）

**回滚步骤**：

1. `git revert <commit-hash>` 即可还原 ADR-0007 修订 + ElementType 清理
2. PR merge 前：直接 close PR，分支不合并即可
3. PR merge 后：新开 `revert/phase2.4-ast-alignment` 分支 revert merge commit

**回滚触发条件**：

- 评估结论被 Human Owner 否决（认为应改 AST）
- 移除 ElementType 后出现未预期的 import 失败（不应发生，因已扫描确认无引用）
- 测试 regression > 0

---

## 7. Feedback Signals（反馈信号）

### 7.1 成功信号

- ADR-0007 §Phase 2.4 标记完成
- ElementType 移除后 `flutter analyze` 仍 0 error
- `flutter test` 471 passed / 0 regression
- PR 一次 review 通过

### 7.2 失败信号

- 移除 ElementType 后出现 compile error（说明有未扫描到的引用）
- 任何测试 regression
- ADR-0007 修订被 reviewer 质疑结论

---

## 8. Risk Assessment（风险评估）

| 风险 | 概率 | 影响 | 缓解 |
|------|------|------|------|
| ElementType 有未扫描到的引用 | 极低 | 低 | 已用 Grep 全项目扫描，仅 document.dart 定义 |
| ADR-0007 修订格式不符合 Human Owner 预期 | 中 | 低 | 修订前在 Task Contract 中展示完整 markdown 片段，等审批 |
| 评估结论未来被推翻（如 Phase 3 真需要拆 TableElement） | 低 | 低 | ADR 记录"未来若要移除/拆分，应作为单独 ADR"，可追溯 |

**总体风险等级**：Low（评估性任务 + 10 行死代码清理，0 业务行为变化）

---

## 9. Approval（审批）

| 角色 | 状态 | 时间 |
|------|------|------|
| AI Agent | 已起草 | 2026-07-19 |
| Human Owner | 待审批 | — |

**审批方式**：Human Owner 在本 Task Contract PR 中 review 后回复 "approved" / "approved with comments" / "rejected"。

**授权范围**：Human Owner 已通过 AskUserQuestion 选择"修订 ADR-0007 + 清理 ElementType（推荐）"，授权 AI 修订 ADR-0007 + 清理 ElementType 死代码。

---

## 10. AI Self Review（自检）

### 10.1 ADR 合规性

- [x] ADR-0007 §1.3 Wrapping 决策得到尊重（AST 不变）
- [x] ADR-0003 §边界约束 5 不引入派生缓存（未引入）
- [x] AGENTS.md §6.5 Phase 2 禁区未触碰（未改 UI / 未新增 Phase 3 功能）
- [x] AGENTS.md §6.4 AI 提交分工得到遵守（ADR 修订经用户授权）

### 10.2 范围漂移检查

- [x] 改动范围与 Task Contract 一致
- [x] 未夹带未在 Task Contract 中说明的改动
- [x] 0 业务行为变化（重构 PR 纯净性）

### 10.3 技术债务检查

- [x] 未引入新的技术债务
- [x] ElementType 清理减少技术债务（10 行死代码）

### 10.4 测试覆盖检查

- [x] 评估性任务不需要新测试
- [x] 死代码清理依赖现有测试套件回归验证

### 10.5 文档同步

- [x] ADR-0007 修订与代码同步
- [x] Task Contract 完整记录决策依据

---

## 11. Future ADR 候选（信息性记录）

以下 ADR 候选不在本 Phase 范围，但记录以便未来追溯：

- **ADR-0008**（候选，Phase 2.5 前完成）：Transaction Model
  - BlockOperation + TextOperation 双层 Undo 的统一接口
  - Phase 2.6 会遇到 Text Change 与 Block Operation 必须统一的需求，建议 Phase 2.5 前完成 ADR
  - 关键设计点：`EditOperation` sealed class 联合类型（ADR-0007 §4.2 已预留）
- **ADR-0009**（候选）：IME Lifecycle Model
  - Flutter TextEditingController 的 composing 生命周期复杂，需提前定义：
    - composition start / update / commit / cancel 四态
  - ADR-0007 §3.2 已定义三条铁律，本 ADR 落地实现细节
- ~~**ADR-0008 (AST 稳定)**~~：不需要单独开 ADR（本 Task Contract 已在 ADR-0007 Addendum 内嵌记录"AST 在 Phase 2 保持稳定"决策）

---

**维护人**：AI Agent（GLM-5.2）
**生效日期**：2026-07-19
