# Task Contract: Phase 2.2 BlockEditor 接口骨架与状态机

> AI Agent 在开始编码前必须填写此契约。复杂任务提交 Human Owner 审批后再开始实现。

---

Task ID: ROADMAP Phase 2.2

---

## 1. Goal（目标）

要解决的问题：**为 Phase 2 编辑模型阶段定义 BlockEditor 抽象的代码骨架 + 状态机 + 单元测试基线**。

ADR-0007（[docs/ADR/0007-blockeditor-abstraction-design.md](file:///d:/Projects/Active/math/docs/ADR/0007-blockeditor-abstraction-design.md)）已被 Human Owner Accept（2026-07-19 授权进入 Phase 2.2）。本任务落地 ADR-0007 §实施计划 Phase 2.2：

> - 实现 `BlockEditor` 接口骨架（无 UI 接入）
> - 实现 `BlockId` / `BlockType` / `BlockPosition` 数据类
> - 单元测试：状态机 blurred → focusing → focused → blurring → blurred

**不实现**：BlockEditor.fromElement / toElement（Phase 2.3）、BlockOperations 五原语（Phase 2.6）、ComposingRegion 接入 UI（Phase 2.5）。

---

## 2. Scope（范围）

### 修改

| 文件 | 变更类型 | 说明 |
|------|---------|------|
| `flutter_app/lib/core/editing/block_types.dart` | 新增 | BlockId / BlockType / BlockPosition / BlockSelection / ComposingRegion 数据类 |
| `flutter_app/lib/core/editing/block_editor_state.dart` | 新增 | BlockEditorState enum + 状态转换函数（纯函数） |
| `flutter_app/lib/core/editing/block_editor.dart` | 新增 | BlockEditor abstract class（接口骨架，无实现） |
| `flutter_app/test/editing/block_types_test.dart` | 新增 | 数据类不变性 / equality / 边界值测试 |
| `flutter_app/test/editing/block_editor_state_test.dart` | 新增 | 状态机单元测试（含 error 态） |
| `flutter_app/test/architecture/editing_layer_test.dart` | 新增 | 守门：core/editing/ 不反向 import presentation / domain |
| [docs/ADR/0007-blockeditor-abstraction-design.md](file:///d:/Projects/Active/math/docs/ADR/0007-blockeditor-abstraction-design.md) | 修改 | 状态 Proposed → Accepted |
| [docs/contracts/phase2.2-task-contract.md](file:///d:/Projects/Active/math/docs/contracts/phase2.2-task-contract.md) | 新增 | 本 Task Contract |

### 不修改

- `lib/data/models/document.dart`（AST 保持不变，ADR-0007 §1.3 决定 wrapping）
- `lib/core/parser/markdown_parser.dart`（Phase 2.3 才接入）
- `lib/core/utils/history_manager.dart`（Phase 2.6 才扩展）
- `lib/presentation/` 下任何 UI 代码（[AGENTS.md §6.5](file:///d:/Projects/Active/math/AGENTS.md) Phase 2 仍属 UI Prototype Freeze 期）
- 其他 ADR（ADR-0001 ~ 0006 不动）
- AGENTS.md / ROADMAP.md（Phase 2.2 不动顶层规范）
- pubspec.yaml（不引入新依赖，纯 Dart 数据类与抽象）

---

## 3. Expected Behavior（预期行为）

### Before（当前行为）

- `lib/core/editing/` 目录不存在
- 无 BlockEditor 抽象，无块编辑内核数据类型
- Phase 2.3 ~ 2.7 无起点

### After（目标行为）

- `lib/core/editing/` 目录已建立，含 3 个文件（block_types.dart / block_editor_state.dart / block_editor.dart）
- BlockId / BlockType / BlockPosition / BlockSelection / ComposingRegion 数据类已定义
- BlockEditorState 状态机含 5 态（blurred / focusing / focused / blurring / error）+ 合法转换规则
- BlockEditor abstract class 定义接口（isFocused / source / onFocus / onBlur / onSourceChanged）
- 状态机单元测试覆盖所有合法 / 非法转换路径
- 数据类测试覆盖 equality / 不变性 / 边界值
- 守门测试防止 core/editing 反向 import
- ADR-0007 状态 Accepted
- 全部测试通过，flutter analyze 无 error

---

## 4. Validation Plan（验证计划）

### Unit Test

| 测试文件 | 验证点 | 预期结果 |
|----------|--------|---------|
| `test/editing/block_types_test.dart` | BlockId equality（同值相等，不同值不等） | ✅ |
| `test/editing/block_types_test.dart` | BlockType 1:1 映射 DocumentElement 子类（switch 完整性） | ✅ |
| `test/editing/block_types_test.dart` | BlockPosition immutability（copyWith 不变原对象） | ✅ |
| `test/editing/block_types_test.dart` | BlockSelection 边界（start <= end，负值非法） | ✅ |
| `test/editing/block_types_test.dart` | ComposingRegion.isActive 逻辑（start<0 / end<=start 时 false） | ✅ |
| `test/editing/block_editor_state_test.dart` | blurred → focusing → focused → blurring → blurred 合法路径 | ✅ |
| `test/editing/block_editor_state_test.dart` | focused → blurring → error（parse fail）→ focused 回滚 | ✅ |
| `test/editing/block_editor_state_test.dart` | 非法转换被拒绝（如 blurred → focused 直接跳过 focusing） | ✅ throws StateError |

### Integration Test

| 测试文件 | 验证流程 | 预期结果 |
|----------|---------|---------|
| - | Phase 2.2 无集成测试（无 UI 接入） | - |

### Manual Verification

1. `flutter analyze` 无 error
2. `flutter test` 全部通过
3. 状态机 5 态覆盖完整（blurred / focusing / focused / blurring / error）
4. 守门测试通过（core/editing 不反向 import）
5. 文件均 < 400 行（[AGENTS.md §1.2](file:///d:/Projects/Active/math/AGENTS.md)）
6. 每个文件有 1-3 行 `///` 顶部文档（[AGENTS.md §2.4](file:///d:/Projects/Active/math/AGENTS.md)）

### Architecture Validation

| 检查项 | 验证方式 | 预期结果 |
|--------|---------|---------|
| 分层依赖方向 | [test/architecture/editing_layer_test.dart](file:///d:/Projects/Active/math/flutter_app/test/architecture/editing_layer_test.dart) | core/editing/ 不 import presentation / domain / providers |
| AST 不修改 | git diff lib/data/models/document.dart | 无变更 |
| Parser 不修改 | git diff lib/core/parser/ | 无变更 |
| HistoryManager 不修改 | git diff lib/core/utils/history_manager.dart | 无变更 |
| 不引入新依赖 | git diff pubspec.yaml | 无变更 |
| 文件大小 | wc -l flutter_app/lib/core/editing/*.dart | 每个 < 400 行 |

---

## 5. Success Criteria（完成标准）

任务完成必须满足：

- [ ] `flutter_app/lib/core/editing/` 目录已建立
- [ ] 3 个 .dart 文件（block_types / block_editor_state / block_editor）已创建
- [ ] BlockId / BlockType / BlockPosition / BlockSelection / ComposingRegion 已定义
- [ ] BlockEditorState enum 含 5 态（blurred / focusing / focused / blurring / error）
- [ ] 状态机转换函数已实现（纯函数，无副作用）
- [ ] BlockEditor abstract class 接口已定义
- [ ] 单元测试覆盖数据类 equality / 不变性 / 边界值
- [ ] 单元测试覆盖状态机所有合法转换路径
- [ ] 单元测试覆盖状态机非法转换被拒绝
- [ ] 守门测试通过（core/editing 不反向 import）
- [ ] ADR-0007 状态更新为 Accepted
- [ ] Task Contract 已填写完整
- [ ] `flutter analyze` 无 error
- [ ] `flutter test` 全部通过（314 + 新增 N 个测试，0 regression）
- [ ] **未修改** AST / parser / history_manager / UI 代码
- [ ] **未引入** 新依赖
- [ ] PR 已创建

---

## 6. Rollback Plan（回滚方案）

如果出现问题：

回滚方式：

1. **Task Contract 未通过 Human Owner 审批**：直接 close PR，分支保留。重新修订 Task Contract 后再提交。
2. **状态机设计缺陷**：在分支上修订 `block_editor_state.dart`，重新提交 PR review。
3. **数据类 API 需调整**：Phase 2.2 阶段 BlockEditor 抽象尚未被任何业务代码使用，可直接修改 API 不影响其他模块。
4. **整体回滚**：执行 `git revert <commit>` 或删除 `lib/core/editing/` 目录，对 Phase 1 已稳定代码零副作用（独立目录 + 0 业务接入）。

回滚不影响 Phase 1 已稳定的代码与测试，因为 Phase 2.2 新建独立目录，不改业务代码。

---

## 7. Feedback Signals（反馈信号）

### 成功信号

- ✅ Human Owner 在 PR review 中明确 Approve Task Contract + 代码
- ✅ `flutter analyze` 无 error
- ✅ `flutter test` 全部通过，0 regression
- ✅ Phase 2.3 启动时，开发者能直接基于 `BlockEditor` abstract class 实现 `fromElement / toElement`
- ✅ 状态机 5 态覆盖完整，无遗漏

### 失败信号

- ❌ Human Owner 在 PR review 中 Request Changes，指出接口设计有重大缺陷
- ❌ `flutter analyze` 报 error（如类型不匹配、未使用 import）
- ❌ `flutter test` 出现 regression（Phase 1 的 314 测试有失败）
- ❌ 守门测试失败（core/editing 反向 import 了 presentation / domain）
- ❌ 状态机单元测试无法覆盖 ADR-0007 §1.4 + §1.6 描述的所有场景

---

## 8. Risk Assessment（风险评估）

| 风险 | 概率 | 影响 | 缓解措施 |
|------|------|------|---------|
| 数据类 API 设计不当，Phase 2.3 需返工 | 中 | 中 | Phase 2.2 仅定义最小 API（BlockEditor 接口 + 5 数据类），2.3 接入时再扩展 |
| 状态机转换规则与 ADR-0007 §1.4 + §1.6 不一致 | 中 | 中 | 单元测试逐条对照 ADR 描述，每条转换路径必须有测试 |
| 守门测试规则与现有 layer_dependency_test.dart 重复或冲突 | 低 | 低 | 独立 editing_layer_test.dart，不修改现有 layer_dependency_test.dart |
| BlockType 1:1 映射遗漏 DocumentElement 子类 | 中 | 中 | 用 switch 表达式 + `exhaustive` 检查，编译期保证完整性 |
| 文件超 400 行 | 低 | 低 | 拆分为 3 个文件（types / state / editor），每文件预计 < 200 行 |

Risk Level: **Medium**

理由：本任务定义新抽象（BlockEditor 接口），但不修改业务代码、不接入 UI、不引入新依赖。Phase 2.3 才开始使用这些抽象，回滚成本可控。

---

## 9. Approval（审批）

复杂任务（Risk Medium+ / 涉及架构变更）需 Human Owner 审批。

- [ ] 无需审批（风险低，AI 可自主执行）
- [x] 待审批（Human Owner 确认后开始 Phase 2.3）

Human Owner:

- [ ] Approve Task Contract（授权按本契约执行 Phase 2.2 实现）
- [ ] Approve 代码实现（PR merge 后进入 Phase 2.3）
- [ ] Request Changes（指出需修订点）
- [ ] Reject（设计方向错误，需重新设计或修订 ADR-0007）

**Human Owner 已于 2026-07-19 通过"授权进入 Phase 2.2 实现"指令预授权本任务**。Task Contract 与代码一同 PR 提交，Human Owner 在 PR review 时正式 Approve。

---

## 10. AI Self Review

| 检查项 | 状态 | 说明 |
|-------|------|------|
| ADR 合规 | ✅ | 实现严格遵循 ADR-0007 §1（抽象结构）+ §2（光标模型）+ §1.4（状态机）+ §1.6（error 态） |
| 范围漂移 | ✅ | Phase 2.2 仅实现接口骨架 + 数据类 + 状态机 + 测试，不接入 UI / parser / history |
| 技术债务 | ✅ | 未引入新依赖 / 新存储 / 新静态状态；纯 Dart 抽象，可独立测试 |
| 测试覆盖 | ✅ | 数据类 + 状态机 + 守门测试三层覆盖 |
| §6.4 禁区授权 | ✅ | Human Owner 已"授权进入 Phase 2.2 实现"；ADR-0007 状态更新属本次授权范围 |
| §6.5 当前阶段禁区 | ✅ | Phase 2.2 不修改 UI 行为、不新增 Phase 3 功能、不在 BlockEditor 抽象稳定前实现 2.3~2.7 细节 |
| 与 ADR-0003 兼容 | ✅ | 不引入派生缓存，BlockId 是内存标识而非持久化存储 |
| 与 ADR-0004 兼容 | ✅ | 不修改 parser，BlockType 仅枚举定义 |
| Task Contract 完整性 | ✅ | 9 节齐全，Risk Level = Medium |
| AI commit message | ✅ | 将包含 `Task scope: ROADMAP Phase 2.2` |

---

**Agent**：TRAE (GLM-5.2)  
**日期**：2026-07-19  
**版本**：v1.0
