# Task Contract: Phase 2.1 设计 BlockEditor 抽象

> AI Agent 在开始编码前必须填写此契约。复杂任务提交 Human Owner 审批后再开始实现。

---

Task ID: ROADMAP Phase 2.1

---

## 1. Goal（目标）

要解决的问题：**为 Phase 2 编辑模型阶段定义 BlockEditor 抽象设计基线**。

Phase 1 已稳定 AST（10 类 block + 8 类 inline），但当前编辑范式仍是"编辑/预览分离"（[CRITICAL_REVIEW §1.1](file:///d:/Projects/Active/math/docs/CRITICAL_REVIEW.md)）。Phase 2 必须先定义 BlockEditor 抽象的 4 个子系统（抽象结构 / 光标模型 / IME 兼容 / 块级操作原语），才能进入 2.2~2.7 的实现。Phase 2.1 是**设计任务**，不写代码（[AGENTS.md §6.5](file:///d:/Projects/Active/math/AGENTS.md) 禁止在抽象稳定前实现 2.2~2.7）。

---

## 2. Scope（范围）

### 修改

| 文件 | 变更类型 | 说明 |
|------|---------|------|
| [docs/ADR/0007-blockeditor-abstraction-design.md](file:///d:/Projects/Active/math/docs/ADR/0007-blockeditor-abstraction-design.md) | 新增 | ADR-0007《BlockEditor 抽象设计》，覆盖 4 子系统，状态 Proposed |
| [docs/contracts/phase2.1-task-contract.md](file:///d:/Projects/Active/math/docs/contracts/phase2.1-task-contract.md) | 新增 | 本 Task Contract 文件 |

### 不修改

- `lib/` 下任何业务代码（Phase 2.1 是设计任务，§6.5 禁止在 BlockEditor 抽象稳定前实现 2.2~2.7）
- `lib/data/models/document.dart`（AST 保持不变，ADR-0007 §1.3 决定 wrapping 而非 flattening）
- `lib/core/parser/markdown_parser.dart`（ADR-0004 保留，不重写）
- `lib/presentation/` 下任何 UI 代码（Phase 2 仍属 UI Prototype Freeze 期）
- `test/` 下任何测试文件（Phase 2.1 不写测试，2.2 才开始）
- 其他 ADR（ADR-0001 ~ 0006 不动）
- AGENTS.md / ROADMAP.md（Phase 2.1 不动顶层规范）

---

## 3. Expected Behavior（预期行为）

### Before（当前行为）

- Phase 2 在 ROADMAP 中只有任务列表（2.1~2.7），无设计文档
- 编辑范式仍是"编辑/预览分离"（[editor_screen.dart:300-321](file:///d:/Projects/Active/math/flutter_app/lib/presentation/screens/editor_screen.dart#L300-321)）
- 没有块编辑内核抽象，Phase 2.2 无起点
- ADR 体系中无 BlockEditor 相关决策

### After（目标行为）

- ADR-0007《BlockEditor 抽象设计》已落地，状态 Proposed（待 Human Owner Accept）
- BlockEditor 抽象的 4 子系统（抽象结构 / 光标模型 / IME 兼容 / 块级操作原语）有清晰决策
- 关键决策有替代方案评估与动机说明
- 风险与缓解已识别
- Phase 2.2~2.7 实施计划清晰
- Task Contract 明确 Phase 2.1 不写代码、不破坏 AST、不引入新存储

### 修订记录（v1.1，2026-07-19，基于 Human Owner 评审反馈）

- ADR-0007 §1 新增 §1.5「编辑态显示策略：显示 Markdown source，不实现 syntax hiding」
- ADR-0007 §1 新增 §1.6「error 态处理（逆解析失败）」+ 状态机扩展 error 态
- ADR-0007 §2.1 新增「offset 语义」明确 UTF-16 code unit 对齐 Flutter TextEditingValue
- ADR-0007 §4.2 重写为「双层 Undo（BlockOperation + TextOperation 共存）」，否决纯块级 Undo
- ADR-0007 §动机 / §后果 / §风险 / §Phase 2.6 同步更新

---

## 4. Validation Plan（验证计划）

### Unit Test

| 测试文件 | 验证点 | 预期结果 |
|----------|--------|---------|
| - | Phase 2.1 不写代码，无单元测试 | - |

### Integration Test

| 测试文件 | 验证流程 | 预期结果 |
|----------|---------|---------|
| - | Phase 2.1 不写代码，无集成测试 | - |

### Manual Verification

1. ADR-0007 包含 §背景 / §决策 / §动机 / §后果 / §替代方案 / §实施计划 / §参考 7 大节，符合 AGENTS.md §7 ADR 编写规则
2. ADR-0007 覆盖用户授权的 4 个子系统：抽象结构 / 光标模型 / IME 兼容 / 块级操作原语
3. ADR-0007 决策与 [ADR-0003](file:///d:/Projects/Active/math/docs/ADR/0003-storage-single-source-md-files.md) / [ADR-0004](file:///d:/Projects/Active/math/docs/ADR/0004-markdown-parser-extension-strategy.md) / [AGENTS.md §6.5](file:///d:/Projects/Active/math/AGENTS.md) 不冲突
4. Task Contract §2 Scope 明确 Phase 2.1 不写代码、不修改 AST、不引入新存储
5. Task Contract §8 Risk Assessment 标注 Risk Level = High（架构变更）
6. Task Contract §9 Approval 待 Human Owner 审批

### Architecture Validation

| 检查项 | 验证方式 | 预期结果 |
|--------|---------|---------|
| ADR 编号唯一 | docs/ADR/ 目录无同名 | 0007 未被占用 |
| ADR 状态合法 | 文件顶部 Status 字段 | Proposed |
| ADR 与现有 ADR 不冲突 | 交叉引用 ADR-0003 / ADR-0004 | 引用一致 |
| Phase 2.1 不引入代码 | git diff --stat | 仅 .md 文件变更 |

---

## 5. Success Criteria（完成标准）

任务完成必须满足：

- [ ] ADR-0007 文件已创建，状态 Proposed
- [ ] ADR-0007 覆盖 4 个子系统（抽象结构 / 光标模型 / IME 兼容 / 块级操作原语）
- [ ] ADR-0007 包含背景 / 决策 / 动机 / 后果 / 替代方案 / 实施计划 / 参考
- [ ] Task Contract 已填写完整
- [ ] Risk Level = High 已标注
- [ ] PR 已创建，等待 Human Owner 审批
- [ ] **未修改任何 `lib/` / `test/` 代码**
- [ ] **未引入新依赖**（pubspec.yaml 不变）
- [ ] **未修改 AGENTS.md / ROADMAP.md 等顶层架构文档**
- [ ] CI 通过（flutter analyze + flutter test + flutter build，预期全绿，本 PR 仅文档）

---

## 6. Rollback Plan（回滚方案）

如果出现问题：

回滚方式：

1. **Human Owner 拒绝审批**：直接 close PR，ADR-0007 留在分支不入 main。Phase 2.1 重启需重新设计或修订 ADR。
2. **审批后发现设计缺陷**：在分支上修订 ADR-0007（仍 Proposed 状态），重新提交 PR review。
3. **Phase 2.2 实现时发现 ADR-0007 不可行**：发起 ADR-0007 修订（Proposed → 修订），或起 ADR-0008 替代（ADR-0007 标记 Superseded）。

回滚不影响 Phase 1 已稳定的代码与测试，因为 Phase 2.1 不写代码。

---

## 7. Feedback Signals（反馈信号）

### 成功信号

- ✅ Human Owner 在 PR review 中明确 Approve ADR-0007 设计
- ✅ ADR-0007 状态从 Proposed → Accepted
- ✅ Phase 2.2 启动时，开发者（AI 或 Human）能直接按 ADR-0007 §实施计划 Phase 2.2 落地 BlockEditor 接口骨架
- ✅ ADR-0007 的关键决策（wrapping / 双态切换 / 块级 Undo）在 Phase 2.2~2.7 实现中无需推翻

### 失败信号

- ❌ Human Owner 在 PR review 中 Request Changes，指出 4 子系统设计有重大缺陷
- ❌ ADR-0007 与 ADR-0003 / ADR-0004 冲突（如引入了派生缓存 / 重写了 parser）
- ❌ Phase 2.2 实现时发现 BlockEditor 抽象无法对齐现有 AST（如某些 DocumentElement 子类无对应 BlockType）
- ❌ Phase 2.5 IME 测试矩阵无法覆盖（如 composing region 抽象不兼容 TextEditingController）

---

## 8. Risk Assessment（风险评估）

| 风险 | 概率 | 影响 | 缓解措施 |
|------|------|------|---------|
| ADR-0007 设计在 Phase 2.2 实现时不可行 | 中 | 高 | ADR-0007 §实施计划明确 2.2~2.7 分步实施，每步可独立验证；若发现不可行，及时修订 ADR |
| 4 子系统设计耦合度过高，无法独立实现 | 中 | 中 | ADR-0007 §实施计划明确 2.2（抽象结构）→ 2.3（增量解析）→ 2.5（IME）→ 2.6（操作原语）→ 2.7（快捷映射），每步只改一个子系统 |
| 逆解析（DocumentElement → source）工作量被低估 | 高 | 中 | ADR-0007 §风险与缓解 已标注，Phase 2.3 必须有 round-trip 测试覆盖 10 类 block |
| IME 铁律在 UI 接入时被绕过 | 中 | 高 | ADR-0007 §3.2 三条铁律 + §风险与缓解 architecture test 守门；Phase 2.5 必须有 6 类场景测试 |
| 块级 Undo 与现有字符级 HistoryManager 不兼容 | 中 | 中 | ADR-0007 §4.2 决定扩展而非重写，Phase 2.6 引入 BlockOperation 类型 |
| BlockType 1:1 映射 DocumentElement 后期需扩展（如 TableRow / TableCell） | 中 | 低 | ADR-0007 §Phase 2.4 评估点已预留，AST 修改需新 ADR |
| ADR-0007 状态长期停留 Proposed（Human Owner 不审批） | 低 | 高 | PR review 主动跟进，必要时发起 ADR 评审会议 |

Risk Level: **High**

理由：本任务是架构变更级设计决策，定义 Phase 2~3 的实现基线。设计错误会传导到 2.2~2.7 所有实现任务，回滚成本高。

---

## 9. Approval（审批）

复杂任务（Risk High / 涉及架构变更）需 Human Owner 审批。

- [ ] 无需审批（风险低，AI 可自主执行）
- [x] 待审批（Human Owner 确认后开始 Phase 2.2）

Human Owner: 

- [ ] Approve ADR-0007（状态 Proposed → Accepted，授权进入 Phase 2.2）
- [ ] Approve Task Contract（授权按本契约执行）
- [ ] Request Changes（指出需修订点）
- [ ] Reject（设计方向错误，需重新设计或起 ADR-0008）

---

## 10. AI Self Review

| 检查项 | 状态 | 说明 |
|-------|------|------|
| ADR 合规 | ✅ | ADR-0007 编写符合 AGENTS.md §7 规则，文件名 `NNNN-kebab-case`，状态 Proposed |
| 范围漂移 | ✅ | Phase 2.1 仅设计，不写代码（§2 Scope 明确） |
| 技术债务 | ✅ | 未引入新依赖 / 新存储 / 新静态状态 |
| 测试覆盖 | ✅ | Phase 2.1 无测试任务（§4 已说明） |
| §6.4 禁区授权 | ✅ | Human Owner 在 AskUserQuestion 中明确授权"ADR + Task Contract（推荐）"模式 |
| §6.5 当前阶段禁区 | ✅ | Phase 2.1 不实现 2.2~2.7 细节，仅定义抽象 |
| 与 ADR-0003 兼容 | ✅ | ADR-0007 §4.4 明确不引入派生缓存 |
| 与 ADR-0004 兼容 | ✅ | ADR-0007 §1.3 决定 wrapping 而非 flattening，保留自研 parser |
| Task Contract 完整性 | ✅ | 9 节齐全，Risk Level = High |
| AI commit message | ✅ | 将包含 `Task scope: ROADMAP Phase 2.1` |

---

**Agent**：TRAE (GLM-5.2)  
**日期**：2026-07-19  
**版本**：v1.0
