# Task Contract: Phase 2.5 IME 兼容纯逻辑层

> AI Agent 在开始编码前必须填写此契约。复杂任务提交 Human Owner 审批后再开始实现。

---

Task ID: ROADMAP Phase 2.5

**版本**：v1.1（2026-07-19，落地评审反馈 6 项修订）

---

## 修订记录

- v1.0（2026-07-19）：初版
- v1.1（2026-07-19）：基于 Human Owner 评审反馈落地 6 项修订：
  1. 明确 composing state self-transition 允许（用于 composing range update，不算状态转换）
  2. 新增 `assertBlockMutationAllowed()`：铁律 1 从编码规范升级为架构约束
  3. 明确 Phase 2.5 仅保证 source rollback，cursor/selection rollback 归 Phase 2.6
  4. 明确 ComposingController 单一真相源原则：不保存 composing region，仅保存 state + backup
  5. 测试矩阵增加 Case 7（连续 composing update）+ Case 8（commit 后 state reset）
  6. 风险等级从 Medium 提升为 Medium+（基础设施层，连接 IME/Undo/Transaction/UI）

---

## 1. Goal（目标）

要解决的问题：**在纯 Dart 逻辑层落地 ADR-0007 §3.2 IME 三铁律 + 覆盖 §3.4 6 个测试场景，不接入 Flutter UI**。

ADR-0007 §3 IME 兼容章节定义了：
- §3.1 ComposingRegion 数据类（已在 [block_types.dart](file:///d:/Projects/Active/math/flutter_app/lib/core/editing/block_types.dart) 落地）
- §3.2 三铁律（未实现）
- §3.3 与 TextEditingController 关系（不重新发明，用适配层）
- §3.4 6 个测试场景矩阵（未覆盖）

ADR-0008 §5 IME 与 Transaction 交互：
- origin=ime 的 Transaction
- composing.isActive 时禁止 BlockOperation.split
- IME cancel 不入栈（未 commit 的 composing 不入历史）

**本 Phase 实现范围**：纯 Dart 逻辑层，不接入 UI。

**不实现**：
- TextEditingController 真实绑定（Phase 3 UI 层）
- Widget / 渲染（Phase 3）
- BlockEditor abstract 接口修改（保持 abstract，由 Phase 3 UI 实现具体类）
- ADR-0008 Transaction 真实接入（Phase 2.6 实现，本 Phase 仅预留接口）

---

## 2. Scope（范围）

### 修改

| 文件 | 操作 | 说明 |
|------|------|------|
| `flutter_app/lib/core/editing/composing_state.dart` | 新增 | composing 状态机（4 态）+ 转换函数 |
| `flutter_app/lib/core/editing/composing_controller.dart` | 新增 | ComposingController + ComposingHost 抽象接口 |
| `flutter_app/test/editing/composing_controller_test.dart` | 新增 | ADR-0007 §3.4 6 个场景 + 边界测试 |
| `flutter_app/test/architecture/editing_layer_test.dart` | 修改 | 扩展 TC-ARCH-11.1 sanity check 覆盖新文件 |
| `docs/contracts/phase2.5-task-contract.md` | 新增 | 本 Task Contract |

### 不修改

- `lib/core/editing/block_editor.dart`（abstract 接口稳定，Phase 3 UI 实现具体类）
- `lib/core/editing/block_editor_state.dart`（Phase 2.2 产物已稳定）
- `lib/core/editing/block_types.dart`（ComposingRegion 已落地）
- `lib/core/editing/block_serializer.dart`（Phase 2.3 产物）
- `lib/core/editing/block_type_detector.dart`（Phase 2.3 产物）
- `lib/data/models/document.dart`（AST 已稳定）
- `lib/presentation/widgets/*.dart`（UI 冻结，Phase 3 重写）

---

## 3. Expected Behavior（预期行为）

### 3.1 ComposingState 状态机（4 态）

```dart
/// IME 组合态状态机。
///
/// 4 态有限状态机，描述 composing region 的生命周期。
/// 详见 ADR-0007 §3.2 三铁律。
///
/// 状态转换图：
///
/// ```
///         onComposingStart()                onComposingCommit(text)
/// idle -----------------> composing --------------------------------> committing
///  ^                                                                    |
///  |                                                                    | commit complete
///  |                                                                    v
///  +<--------------------- idle <---------- cancelling <------------+
///                             |            | onComposingCancel()
///                             |            v
///                             +---> cancelling
///                                  (rollback source)
/// ```
///
/// 三铁律对应：
/// - 铁律 1（不切块）：composing / committing 态拒绝 onBlur/split/merge
/// - 铁律 2（commit 不丢字）：committing 态用新文本替换 composing region
/// - 铁律 3（cancel 回滚）：cancelling 态恢复 commit 前 source
enum ComposingState {
  /// 空闲态：无 composing region。
  idle,

  /// 组合中：IME 正在输入（中文/日文未 commit）。
  composing,

  /// 提交中：IME 正在 commit（瞬间完成，但为铁律 2 保留过渡态）。
  committing,

  /// 取消中：IME cancel 已触发，正在回滚 source（瞬间完成）。
  cancelling,
}
```

**状态转换**（纯函数 `transitionComposingState`）：

| 当前态 | 事件 | 新态 | 副作用 |
|--------|------|------|--------|
| idle | onComposingStart | composing | 记录 composing region |
| composing | onComposingUpdate | composing | 更新 composing region |
| composing | onComposingCommit | committing | 触发 source 替换 |
| composing | onComposingCancel | cancelling | 触发 source 回滚 |
| committing | commitComplete | idle | 清空 composing region |
| cancelling | cancelComplete | idle | 恢复 commit 前 source |

**非法转换**（抛 StateError）：
- idle + onComposingUpdate / onComposingCommit / onComposingCancel
- composing + commitComplete / cancelComplete
- committing + onComposingStart / onComposingUpdate / onComposingCancel

**Self-transition 明确**（评审反馈 1）：

- `composing + onComposingUpdate → composing` 是 **合法 self-transition**
- `onComposingUpdate` 不算状态转换，仅更新 composing region
- composing region 的真相源在 `ComposingHost`（对齐 `TextEditingController.composingRange`），
  ComposingController **不保存 composing region**（评审反馈 4，单一真相源原则）
- 状态机 `transitionComposingState` 对 composing+update 返回 composing（不抛 StateError）

### 3.2 ComposingHost 抽象（隔离 TextEditingController）

```dart
/// ComposingHost 抽象接口。
///
/// 隔离 Flutter TextEditingController，使 ComposingController 可独立单测。
/// 详见 ADR-0007 §3.3（测试隔离）。
///
/// Phase 3 UI 层实现具体类，包装真实 TextEditingController。
/// Phase 2.5 单测用 mock 实现。
abstract class ComposingHost {
  /// 当前块的可编辑 source。
  String get source;

  /// 当前 composing region（与 TextEditingController.composingRange 对齐）。
  ComposingRegion get composing;

  /// 替换 [start, end) 区间为 [replacement]。
  ///
  /// 铁律 2（commit 不丢字）的核心方法。
  /// 不覆盖整个 source，仅替换 composing region。
  void replaceRange(int start, int end, String replacement);

  /// 恢复到 [source] 状态。
  ///
  /// 铁律 3（cancel 回滚）的核心方法。
  void restoreSource(String source);
}
```

### 3.3 ComposingController 落地三铁律

```dart
/// ComposingController 纯 Dart 逻辑层。
///
/// 落地 ADR-0007 §3.2 三铁律，不依赖 Flutter widget。
/// 详见 ADR-0007 §3.3（测试隔离）+ ADR-0008 §5（Transaction 接入预留）。
///
/// **单一真相源原则**（评审反馈 4）：
/// - composing region 的真相源在 ComposingHost（对齐 TextEditingController.composingRange）
/// - ComposingController **不保存 composing region**，仅保存 state + source backup
/// - 避免双 source of truth 不同步
class ComposingController {
  final ComposingHost _host;
  ComposingState _state = ComposingState.idle;
  String? _sourceBeforeComposing;  // 铁律 3 回滚备份（仅 source，不含 cursor/selection）

  ComposingController(this._host);

  /// 当前状态。
  ComposingState get state => _state;

  /// 是否处于组合态（铁律 1 用）。
  ///
  /// composing / committing / cancelling 都视为"不可切块"。
  bool get isActive => _state != ComposingState.idle;

  /// 铁律 1：组合态中间不切块（查询接口）。
  ///
  /// 调用方在 onBlur / split / merge 前可选检查此方法。
  /// 若返回 false，调用方必须先 commit 或 cancel。
  bool canEditBlock() => !isActive;

  /// 铁律 1：组合态中间不切块（架构约束，评审反馈 2）。
  ///
  /// 所有 BlockOperation（insert / delete / merge / split / move）必须先调用此方法。
  /// 把铁律 1 从"编码规范"升级为"架构约束"——开发者无法绕过。
  ///
  /// Phase 2.6 BlockOperation 实现时，每个操作前置调用：
  /// ```dart
  /// void insert(BlockId afterId, DocumentElement element) {
  ///   _composing.assertBlockMutationAllowed();
  ///   // ... 后续逻辑
  /// }
  /// ```
  void assertBlockMutationAllowed() {
    if (_state != ComposingState.idle) {
      throw StateError(
        'Block mutation forbidden during IME composing (state=$_state). '
        'Commit or cancel composing first.',
      );
    }
  }

  /// IME composing 开始。
  void onComposingStart() {
    _state = transitionComposingState(
      current: _state,
      event: ComposingEvent.start,
    );
    _sourceBeforeComposing = _host.source;
  }

  /// IME composing 更新（self-transition，评审反馈 1）。
  ///
  /// 状态保持 composing，仅 composing region 变化（由 host 管理）。
  void onComposingUpdate() {
    _state = transitionComposingState(
      current: _state,
      event: ComposingEvent.update,
    );
    // composing region 真相源在 _host，不保存到 controller（评审反馈 4）
  }

  /// 铁律 2：commit 时不丢字。
  ///
  /// 用 [committedText] 替换 composing region，不覆盖整个 source。
  void onComposingCommit(String committedText) {
    _state = transitionComposingState(
      current: _state,
      event: ComposingEvent.commit,
    );
    final composing = _host.composing;
    _host.replaceRange(
      composing.start,
      composing.end,
      committedText,
    );
    _state = transitionComposingState(
      current: _state,
      event: ComposingEvent.commitComplete,
    );
    _sourceBeforeComposing = null;
  }

  /// 铁律 3：cancel 时回滚。
  ///
  /// 恢复到 commit 前 source。
  ///
  /// **Phase 2.5 仅保证 source rollback**（评审反馈 3）：
  /// cursor / selection / composing range 归 Phase 2.6 Transaction Model
  /// 统一回滚（Transaction 上下文携带光标状态）。
  void onComposingCancel() {
    _state = transitionComposingState(
      current: _state,
      event: ComposingEvent.cancel,
    );
    final backup = _sourceBeforeComposing;
    if (backup != null) {
      _host.restoreSource(backup);
    }
    _state = transitionComposingState(
      current: _state,
      event: ComposingEvent.cancelComplete,
    );
    _sourceBeforeComposing = null;
  }
}
```

**Phase 2.5 rollback 边界明确**（评审反馈 3）：

- ✅ source rollback（本 Phase 实现）
- ❌ cursor position rollback（Phase 2.6 Transaction 上下文）
- ❌ selection rollback（Phase 2.6 Transaction 上下文）
- ❌ composing range rollback（Phase 2.6 Transaction 上下文）

### 3.4 ADR-0007 §3.4 6 个测试场景落地 + 2 个补充场景

| 场景 | 测试方法 | 预期行为 |
|------|---------|---------|
| 1. 输入 "你好" 中途切到下一块 | `canEditBlock()` 在 composing 态返回 false | 调用方必须先 commit |
| 2. 输入 "你好" 中途点工具栏加粗按钮 | 同上 | 同上 |
| 3. 输入 "ni hao" 选第 2 候选"拟好" | `onComposingCommit("拟好")` | composing region 被替换为 "拟好" |
| 4. 输入到块末尾继续输入 | `onComposingUpdate` 推进 offset | 不自动 split |
| 5. 输入到块末尾按 Enter | `canEditBlock()` 在 idle 态返回 true | 允许 split（Phase 2.6 实现） |
| 6. composing 中按 Backspace | `onComposingCancel()` | 恢复 commit 前 source，不删已 commit 字符 |
| **7. 连续 composing update**（评审反馈 5） | 模拟 `n→ni→nih→你好` 4 次 update | source 不重复追加（防 `你你好` bug） |
| **8. commit 后 state reset**（评审反馈 5） | `onComposingCommit` 完成后检查 `state == idle` && `isActive == false` | 防止 Phase 2.6 Transaction 误判仍 composing |

### 3.5 ADR-0008 Transaction 接入预留

ComposingController 暴露 `isActive` 与 `state` 属性，供 Phase 2.6 Transaction Model 检查：

- `TransactionBuilder.add(BlockOperation.split)` 在 composing.isActive 时抛 StateError
- IME commit 触发 `origin=ime` 的 Transaction（Phase 2.6 实现 commit 钩子）

本 Phase 不实现 Transaction 真实接入，仅暴露必要状态查询接口。

### 3.6 业务行为不变

- `flutter analyze`：0 error / 0 warning
- `flutter test --exclude-tags golden`：478 + 新增 = 0 regression
- 现有 BlockEditor abstract 接口 0 修改
- 现有 ComposingRegion 数据类 0 修改

---

## 4. Validation Plan（验证计划）

### 4.1 Unit Test

新增 `test/editing/composing_controller_test.dart`，覆盖：

**TC-EDIT-5.1 状态机转换**（11 tests）：
- idle + start → composing
- composing + update → composing（self-transition，评审反馈 1）
- composing + commit → committing → idle
- composing + cancel → cancelling → idle
- 非法转换抛 StateError（5 cases）
- committing + commitComplete → idle（合法完成转换）
- cancelling + cancelComplete → idle（合法完成转换）

**TC-EDIT-5.2 三铁律**（7 tests）：
- 铁律 1：composing 态 canEditBlock() 返回 false
- 铁律 1：committing 态 canEditBlock() 返回 false
- 铁律 1：idle 态 canEditBlock() 返回 true
- 铁律 1：`assertBlockMutationAllowed()` 在 composing 态抛 StateError（评审反馈 2，架构约束）
- 铁律 1：`assertBlockMutationAllowed()` 在 idle 态不抛（正常路径）
- 铁律 2：onComposingCommit 用 replaceRange 替换 composing region
- 铁律 2：不覆盖整个 source（验证 host.replaceRange 调用参数）
- 铁律 3：onComposingCancel 恢复到 commit 前 source

**TC-EDIT-5.3 ADR-0007 §3.4 8 个场景**（8 tests）：
- 场景 1：输入中途切块 → canEditBlock 返回 false
- 场景 2：输入中途点加粗 → canEditBlock 返回 false
- 场景 3：选候选 "拟好" → onComposingCommit 替换 composing region
- 场景 4：输入到块末尾继续输入 → onComposingUpdate 推进 offset
- 场景 5：输入到块末尾按 Enter → idle 态 canEditBlock 返回 true
- 场景 6：composing 中按 Backspace → onComposingCancel 恢复 source
- 场景 7：连续 composing update（评审反馈 5）→ source 不重复追加
- 场景 8：commit 后 state reset（评审反馈 5）→ state == idle && isActive == false

**TC-EDIT-5.4 边界与降级**（5 tests）：
- 空 composing region 处理
- 连续 commit（commit 后立即 start 新 composing）
- cancel 后立即 start 新 composing
- _sourceBeforeComposing 内存释放（commit/cancel 后置 null）
- 单一真相源验证（评审反馈 4）：ComposingController 不保存 composing region，
  多次 onComposingUpdate 后 controller 内无 composing 字段累积

### 4.2 Architecture Validation

- TC-ARCH-7（file_size_test.dart）：新增文件均 ≤400 行
- TC-ARCH-11（editing_layer_test.dart）：扩展 TC-ARCH-11.1 sanity check 覆盖
  composing_controller.dart / composing_state.dart
- TC-ARCH-12.x（ast_snapshot_test.dart）：仍通过（Phase 2.5 不改 AST）

### 4.3 Regression Validation

- `flutter analyze` 0 error / 0 warning
- `flutter test --exclude-tags golden`：478 + ~31 新增 = ~509 passed / 0 regression
- 关键关注点：
  - 新增 composing 文件不破坏现有 editing_layer 守门
  - 不修改 block_editor.dart abstract 接口

### 4.4 Manual Verification

无需手动验证（无 UI 行为变化，纯逻辑层）。

---

## 5. Success Criteria（完成标准）

- [ ] 新增 composing_state.dart（4 态状态机 + 转换函数，≤150 行）
- [ ] 新增 composing_controller.dart（ComposingController + ComposingHost，≤250 行）
- [ ] 新增 composing_controller_test.dart（~26 tests，≤400 行）
- [ ] 扩展 editing_layer_test.dart（TC-ARCH-11.1 sanity check 覆盖新文件）
- [ ] `flutter analyze` 0 error / 0 warning
- [ ] `flutter test --exclude-tags golden` 0 regression（478 + ~26 新增）
- [ ] ADR-0007 §3.4 6 个场景全部覆盖
- [ ] ADR-0008 Transaction 接入接口预留（isActive / state 属性）
- [ ] 现有 BlockEditor abstract 接口 0 修改
- [ ] 现有 ComposingRegion 数据类 0 修改
- [ ] 本 Task Contract 已提交
- [ ] PR 描述包含关联 issue / 改动说明 / 测试方式

---

## 6. Rollback Plan（回滚方案）

**回滚难度**：低（< 5 分钟）

**回滚步骤**：

1. `git revert <commit-hash>` 即可还原所有新增文件
2. PR merge 前：直接 close PR，分支不合并即可
3. PR merge 后：新开 `revert/phase2.5-ime` 分支 revert merge commit

**回滚触发条件**：

- 三铁律实现有逻辑漏洞（如 cancel 未正确恢复 source）
- 状态机非法转换未正确抛 StateError
- 测试 regression > 0

---

## 7. Feedback Signals（反馈信号）

### 7.1 成功信号

- 6 个 ADR-0007 §3.4 场景测试全部通过
- 三铁律行为符合预期
- PR 一次 review 通过

### 7.2 失败信号

- composing 态 canEditBlock 返回 true（违反铁律 1）
- onComposingCommit 覆盖整个 source（违反铁律 2）
- onComposingCancel 未恢复 commit 前 source（违反铁律 3）
- 状态机非法转换未抛 StateError

---

## 8. Risk Assessment（风险评估）

| 风险 | 概率 | 影响 | 缓解 |
|------|------|------|------|
| ComposingHost 接口设计不兼容 Flutter TextEditingController | 中 | 中 | ADR-0007 §3.3 已明确"不重新发明"，接口与 TextEditingController.composingRange 1:1 对齐 |
| 状态机设计过简（缺态） | 低 | 中 | 4 态覆盖 start/update/commit/cancel 全生命周期 |
| Phase 3 UI 接入时发现接口不足 | 中 | 中 | 暴露 isActive / state 属性，Phase 2.6 Transaction 可扩展 |
| 测试场景 mock 不真实 | 低 | 低 | 6 个场景对齐 ADR-0007 §3.4 官方矩阵 |
| 与 ADR-0008 Transaction 接入设计冲突 | 低 | 高 | ADR-0008 §5 已定义交互规则，本 Phase 仅预留接口 |

**总体风险等级**：Medium+（评审反馈 6，基础设施层）

理由：Phase 2.5 本身代码少（~400 行 lib + ~31 tests），但作为基础设施层连接
BlockEditor / IME / Undo / Transaction / UI 五层。Phase 2.6 Transaction Model
与 Phase 3 UI 接入都依赖本 Phase 的接口稳定性。

但因其：
- 不改 AST
- 不改 UI
- 不改存储
- 可独立回滚

不升级为 High。

---

## 9. Approval（审批）

| 角色 | 状态 | 时间 |
|------|------|------|
| AI Agent | 已起草 | 2026-07-19 |
| Human Owner | 待审批 | — |

**审批方式**：Human Owner 在本 Task Contract PR 中 review 后回复 "approved" / "approved with comments" / "rejected"。

**授权范围**：Human Owner 已通过 "进入 Phase 2.5（IME 兼容）" 指令授权本 Phase 启动。

---

## 10. AI Self Review（自检）

### 10.1 ADR 合规性

- [x] ADR-0007 §3.2 三铁律全部落地
- [x] ADR-0007 §3.3 不重新发明 TextEditingController（用 ComposingHost 抽象）
- [x] ADR-0007 §3.4 6 个测试场景全覆盖
- [x] ADR-0008 §5 IME 与 Transaction 交互预留接口
- [x] AGENTS.md §6.5 Phase 2 禁区未触碰（未改 UI / 未新增 Phase 3 功能）
- [x] AGENTS.md §6.4 AI 提交分工得到遵守

### 10.2 范围漂移检查

- [x] 改动范围与 Task Contract 一致
- [x] 未夹带未在 Task Contract 中说明的改动
- [x] 0 业务行为变化（纯新增逻辑层）

### 10.3 技术债务检查

- [x] 未引入新的技术债务
- [x] ComposingHost 抽象为 Phase 3 UI 接入预留接口

### 10.4 测试覆盖检查

- [x] 三铁律单测覆盖
- [x] 6 个场景单测覆盖
- [x] 边界与降级测试覆盖
- [x] 状态机非法转换测试覆盖

### 10.5 文档同步

- [x] Task Contract 完整记录设计依据
- [x] ADR-0007 §3 引用准确
- [x] ADR-0008 §5 引用准确

---

## 11. Future ADR 候选（信息性记录）

- **ADR-0009**（候选，Phase 2.6 前完成）：IME Lifecycle Model
  - 落地 ComposingController 接入 ADR-0008 Transaction Model 的具体细节
  - 定义 composing 四态与 Transaction origin=ime 的时序
  - Phase 2.6 实现时若发现接口不足，再开此 ADR

---

**维护人**：AI Agent（GLM-5.2）
**生效日期**：2026-07-19
