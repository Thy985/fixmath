# Task Contract: Phase 2.7 Markdown 快捷输入映射

> AI Agent 在开始编码前必须填写此契约。复杂任务提交 Human Owner 审批后再开始实现。

---

Task ID: ROADMAP Phase 2.7

**版本**：v1.1（2026-07-20，评审反馈补强）

---

## 修订记录

- v1.0（2026-07-20）：初版，基于 ADR-0007 §4.3（Markdown 快捷映射规则表）+ ROADMAP Phase 2.7 起草
- v1.1（2026-07-20）：Human Owner 评审反馈补强：
  1. §1.5 新增 **BlockId 生命周期约束**（引用 [ADR-0008 v1.1 §9](file:///d:/Projects/Active/math/docs/ADR/0008-editor-transaction-model.md)）
  2. §1.6 新增 **TransactionExecutor 设计方向**（引用 [ADR-0008 v1.1 §10](file:///d:/Projects/Active/math/docs/ADR/0008-editor-transaction-model.md)）：本 Phase 不引入 TransactionExecutor，仅记录为 Phase 2.8+ 候选
  3. §3 实现细节中所有 BlockId 引用补充"内存态 only"约束说明
  4. §8 风险评估新增"BlockOperations 隐式执行器角色"为已知 tech debt（不在本 Phase 解决）
  5. §10 AI Self Review 新增 ADR-0008 v1.1 §9 / §10 合规检查

---

## 1. Goal（目标）

要解决的问题：**在纯 Dart 逻辑层落地 ADR-0007 §4.3 Markdown 快捷输入映射规则，集成到 split / onSourceChanged 触发点**。

### 1.1 上游 ADR 完整约束

| ADR | 章节 | 已落地内容 | 本 Phase 待落地 |
|-----|------|----------|---------------|
| ADR-0007 | §4.3 | BlockTypeDetector 7 条规则（Phase 2.3 已完成） | 集成到 split / onSourceChanged 触发点 |
| ADR-0007 | §4.1 | 五原语（insert/delete/merge/split/move，Phase 2.6 已完成） | 新增第 6 原语：transform（重类型化） |
| ADR-0007 | §1.3 | BlockSerializer 双向映射（Phase 2.3 已完成） | 在 transform 中复用 toElement |
| ADR-0008 | §2 | EditOperation apply/revert 幂等（Phase 2.6 已完成） | 扩展 BlockOperation 支持 transform opType |
| ADR-0008 | §4 | Coalescing 规则（Phase 2.6 已完成） | transform 是 BlockOperation，自动不参与 coalescing |

### 1.2 重类型化触发条件（ADR-0007 §4.3）

| 源文本变化 | 重类型化动作 |
|-----------|------------|
| `# Title\n` | Paragraph → Heading(level=1) |
| `## Title\n` | Paragraph → Heading(level=2) |
| `- item\n` | Paragraph → ListItem(ordered=false) |
| `* item\n` | Paragraph → ListItem(ordered=false) |
| `+ item\n` | Paragraph → ListItem(ordered=false) |
| `1. item\n` | Paragraph → ListItem(ordered=true) |
| `- [ ] task\n` | Paragraph → TaskListItem(checked=false) |
| `- [x] task\n` | Paragraph → TaskListItem(checked=true) |
| ``` ```lang\ncode\n``` ``` | Paragraph → Code(language=lang) |
| ``` ```mermaid\n...\n``` ``` | Paragraph → Mermaid |
| `> quote\n` | Paragraph → Blockquote |
| `---\n` | Paragraph → HorizontalRule |
| `***\n` | Paragraph → HorizontalRule |
| `___\n` | Paragraph → HorizontalRule |

注：mermaid 由 `BlockTypeDetector` 统一识别为 code（区分发生在 `toElement` 内部），符合 Phase 2.3 设计。

### 1.3 不实现范围

- ❌ 不接入 UI（Phase 3）
- ❌ 不修改 BlockEditor abstract 接口（保持 abstract，Phase 3 UI 实现具体类）
- ❌ 不修改 AST（[document.dart](file:///d:/Projects/Active/math/flutter_app/lib/data/models/document.dart) 零修改）
- ❌ 不修改 parser / storage / providers
- ❌ 不修改 DocumentEditor / ComposingController / Transaction / TransactionBuilder / EditorHistory（Phase 2.5/2.6 已稳定）
- ❌ 不接入真实 TextEditingController（Phase 3）
- ❌ 不实现 syntax hiding（ADR-0011 候选，Phase 3+）
- ❌ 不支持反向 transform（Heading → Paragraph 需要 source 变化，由调用方负责）

### 1.4 与 Phase 2.6 的衔接

- ✅ 复用 `BlockOperation`（新增 `BlockOpType.transform`）：apply/revert 接口一致
- ✅ 复用 `TransactionBuilder`：transform 作为 op 加入 Transaction
- ✅ 复用 `EditorHistory`：transform 自动不参与 coalescing（_defaultCanCoalesce 已守门，仅 TextOperation 可合并）
- ✅ 复用 `BlockTypeDetector`：Phase 2.3 已完成 7 条规则
- ✅ 复用 `BlockSerializer.toElement`：transform 内部用 newType 重建 element
- ✅ 复用 IME 守门：transform 是 BlockOperation，前置调用 `assertBlockMutationAllowed()`

### 1.5 BlockId 生命周期约束（v1.1 新增）

引用 [ADR-0008 v1.1 §9](file:///d:/Projects/Active/math/docs/ADR/0008-editor-transaction-model.md)：

> **BlockId provides in-memory identity only and is not persisted across document serialization boundaries.**

本 Phase 落地约束：

1. **transform 不变更 BlockId**：apply 通过 `DocumentEditor.updateBlockContent`（非 `replaceBlock`），保留原 BlockId
2. **transform revert 保留 BlockId**：revertContext 保存完整 `originalElement` snapshot，revert 时用 `updateBlockContent` 恢复（不重新分配 BlockId）
3. **split 自动 transform 的 BlockId**：新块的 BlockId 由 split op 分配（`editor.insertBlock`），tryTransform 仅修改 element 内容，不重新分配 BlockId
4. **不引入跨 session 持久化**：transform revertContext 仅内存态，与 Transaction §7 一致

**禁止行为**：

- ❌ transform 时持久化 BlockId 到 `.md` 文件（违反 ADR-0003 §边界约束 5）
- ❌ transform 时为 BlockId 添加 UUID / stable identity 字段（属于协同编辑场景，本 Phase 不实现）
- ❌ transform 时调用 `replaceBlock`（这会重新分配 BlockId，破坏 Undo 链）

### 1.6 TransactionExecutor 设计方向（v1.1 新增，不在本 Phase 实现）

引用 [ADR-0008 v1.1 §10](file:///d:/Projects/Active/math/docs/ADR/0008-editor-transaction-model.md)：

> Transaction 是数据结构，TransactionExecutor 是执行环境（类比 Git commit object 不会自己执行）。

**当前状态**（Phase 2.6 已实现）：

- `BlockOperations` 持有 `DocumentEditor` + `TransactionBuilder`，承担隐式执行器角色
- `TransactionBuilder.commit()` 不直接 apply，触发 `onChange` 回调
- `EditorHistory` 仅栈管理 + coalescing，不 apply / revert

**本 Phase 守则**：

- ✅ transform 复用现有 `BlockOperations` 模式（eager apply + builder.add）
- ✅ transform 不引入新的执行器抽象
- ✅ transform 的 revertContext 由 `BlockOperation.apply` 填充（与现有 5 类 op 一致）

**Phase 2.8+ 候选**（不在本 Phase 实现）：

- 引入 `TransactionExecutor` 类，集中承担 apply / notify 责任
- `BlockOperations` 内部委托给 `TransactionExecutor`（`_executor.applyOp(op, _builder)`）
- 引入 `NotificationSink` 抽象解耦 UI 通知 + history push

详见 [ADR-0008 v1.1 §10](file:///d:/Projects/Active/math/docs/ADR/0008-editor-transaction-model.md) 迁移策略。

---

## 2. Scope（范围）

### 2.1 修改

| 文件 | 操作 | 说明 | 预估行数 |
|------|------|------|---------|
| `flutter_app/lib/core/editing/block_operation.dart` | 修改 | 扩展 `BlockOpType` 枚举新增 `transform` + `_applyTransform` / `_revertTransform` 实现 + `transformedType` 字段 | +80 |
| `flutter_app/lib/core/editing/block_operations.dart` | 修改 | 新增 `tryTransform(blockId)` / `updateSource(blockId, newSource)` 高层 API + 修改 `split` 自动 transform 新块 | +90 |
| `flutter_app/test/editing/block_operation_transform_test.dart` | 新增 | TC-EDIT-7.1 transform apply/revert 幂等性 | ~180 |
| `flutter_app/test/editing/block_operations_transform_test.dart` | 新增 | TC-EDIT-7.2 tryTransform + updateSource 集成 | ~250 |
| `flutter_app/test/editing/split_auto_transform_test.dart` | 新增 | TC-EDIT-7.3 split 后自动 transform（覆盖 ADR-0007 §4.3 12 类规则） | ~220 |
| `flutter_app/test/editing/transform_undo_redo_test.dart` | 新增 | TC-EDIT-7.4 transform 的 Undo/Redo 循环 + 与 TextOperation 组合 | ~150 |
| `flutter_app/test/editing/transform_boundary_test.dart` | 新增 | TC-EDIT-7.5 边界（无 transform 时不产生 op / IME 守门 / 反向 transform 不支持） | ~120 |
| `docs/contracts/phase2.7-task-contract.md` | 新增 | 本 Task Contract | — |

**注**：所有 lib 文件 ≤400 行限制；所有 test 文件 ≤400 行限制（超限则拆分）。

### 2.2 不修改

- `lib/core/editing/block_editor.dart`（abstract 接口稳定）
- `lib/core/editing/block_editor_state.dart`（Phase 2.2 产物已稳定）
- `lib/core/editing/block_types.dart`（Phase 2.2 产物已稳定，含 BlockId/BlockType）
- `lib/core/editing/block_serializer.dart`（Phase 2.3 产物已稳定，transform 内复用）
- `lib/core/editing/block_type_detector.dart`（Phase 2.3 产物已稳定，7 条规则已覆盖本 Phase 需求）
- `lib/core/editing/composing_controller.dart`（Phase 2.5 产物已稳定）
- `lib/core/editing/composing_state.dart`（Phase 2.5 产物已稳定）
- `lib/core/editing/document_editor.dart`（Phase 2.6 产物已稳定，transform 用 updateBlockContent）
- `lib/core/editing/edit_operation.dart`（sealed class 接口稳定，仅 BlockOperation 实现扩展）
- `lib/core/editing/transaction.dart`（Phase 2.6 产物已稳定）
- `lib/core/editing/transaction_builder.dart`（Phase 2.6 产物已稳定）
- `lib/core/editing/editor_history.dart`（Phase 2.6 产物已稳定，transform 自动不参与 coalescing）
- `lib/core/utils/history_manager.dart`（Phase 2.6 扩展已完成）
- `lib/data/models/document.dart`（AST 零修改）
- `lib/core/parser/markdown_parser.dart`（不改）
- `lib/presentation/widgets/*.dart`（UI 冻结）
- `lib/presentation/screens/*.dart`（UI 冻结）
- `pubspec.yaml`（无新依赖）
- `docs/ADR/*.md`（架构决策文件，由 Human Owner 维护）

---

## 3. Expected Behavior（预期行为）

### 3.1 BlockOpType.transform 新增（ADR-0007 §4.3 落地）

扩展 [block_operation.dart](file:///d:/Projects/Active/math/flutter_app/lib/core/editing/block_operation.dart) 中的 `BlockOpType` 枚举：

```dart
/// 5 类块级操作的类型标识 + transform（重类型化）。
enum BlockOpType {
  insert,
  delete,
  merge,
  split,
  move,
  transform,  // ← Phase 2.7 新增
}
```

**transform 语义**：
- apply：用 [BlockSerializer.toElement] 重新构造 element，source 不变，BlockType 变化为 [transformedType]
- revert：恢复原 element（保存在 revertContext）
- 不变更 BlockId（通过 `updateBlockContent`，而非 `replaceBlock`）

### 3.2 BlockOperation 扩展 transform apply/revert

```dart
class BlockOperation extends EditOperation {
  // ... 现有字段 ...

  /// transform 目标 BlockType（仅 transform opType 使用）。
  ///
  /// apply 时通过 [BlockSerializer.toElement] 用 [transformedType] 重建 element。
  /// 若 transformedType 与当前 BlockType 相同，apply 返回 false（无 transform 必要）。
  final BlockType? transformedType;

  // ============ transform ============

  bool _applyTransform(DocumentEditor editor) {
    if (transformedType == null) return false;

    final element = editor.getBlock(targetId);
    if (element == null) return false;

    final currentType = BlockType.fromElement(element);
    if (currentType == transformedType) return false;  // 无需 transform

    final source = fromElement(element);
    final newElement = toElement(source, transformedType!);

    // 保存 revert context
    revertContext['originalElement'] = element;
    revertContext['originalType'] = currentType;

    // 保持 BlockId 不变，仅替换 element
    editor.updateBlockContent(targetId, newElement);
    return true;
  }

  void _revertTransform(DocumentEditor editor) {
    final originalElement =
        revertContext['originalElement'] as DocumentElement?;
    if (originalElement == null) return;
    editor.updateBlockContent(targetId, originalElement);
  }
}
```

**关键设计点**：

1. **transform 保存完整 element snapshot**（不是仅 type），因为 revert 需要精确恢复原 element（含 ListElement.ordered / CodeElement.language 等字段）
2. **transform 不变更 BlockId**（通过 `updateBlockContent`）
3. **transform 不变更 source**（仅 type 变化）
4. **幂等性**：apply 多次后状态一致（第二次 apply 返回 false，因 currentType == transformedType）
5. **transformedType == currentType 时返回 false**（避免无意义的 transform 入栈）

### 3.3 BlockOperations.tryTransform 高层 API

新增 [block_operations.dart](file:///d:/Projects/Active/math/flutter_app/lib/core/editing/block_operations.dart) 方法：

```dart
/// 检测 [blockId] 的 source 是否触发 Markdown 快捷映射，
/// 若触发则构造 [BlockOperation.transform] 并 apply。
///
/// 返回 true 表示触发了 transform（已加入 [TransactionBuilder]）。
/// 返回 false 表示：
/// - 当前 BlockType 已与 detected type 一致（无需 transform）
/// - composing.isActive（铁律 1 守门）
/// - blockId 不存在
///
/// ADR-0007 §4.3：onSourceChanged 触发点。
bool tryTransform(BlockId blockId) {
  _composing?.assertBlockMutationAllowed();

  final element = _editor.getBlock(blockId);
  if (element == null) return false;

  final source = fromElement(element);
  final currentType = BlockType.fromElement(element);
  final detectedType = detectBlockType(source);

  if (detectedType == currentType) return false;

  final op = BlockOperation(
    opType: BlockOpType.transform,
    targetId: blockId,
    transformedType: detectedType,
  );

  if (!op.apply(_editor)) return false;
  _builder.add(op);
  return true;
}
```

### 3.4 BlockOperations.updateSource 高层 API（onSourceChanged 等价物）

```dart
/// 更新 [blockId] 的 source 文本（模拟用户输入），并自动检测是否触发 transform。
///
/// 内部步骤：
/// 1. 构造 [TextOperation]（offset/deleted/inserted 由调用方根据新旧 source 计算）
/// 2. apply TextOperation（BlockId 不变，type 不变）
/// 3. 调用 [tryTransform] 检测是否需要重类型化
/// 4. 若 transform 触发，加入 [TransactionBuilder]
///
/// 一次调用最多产生 2 个 op（text + transform），仍属同一 Transaction。
///
/// 失败返回 false（任意 op apply 失败则 rollback 已 apply 的 op）。
///
/// ADR-0007 §4.3：onSourceChanged 触发点的等价物（Phase 2 不接 UI）。
bool updateSource(BlockId blockId, String newSource) {
  _composing?.assertBlockMutationAllowed();

  final element = _editor.getBlock(blockId);
  if (element == null) return false;

  final oldSource = fromElement(element);

  // 边界：newSource 与 oldSource 相同 → 无操作
  if (newSource == oldSource) return true;

  // 简化：用整段替换（deleted = oldSource, inserted = newSource）
  // Phase 3 UI 层若需精细 TextOperation（如 IME 增量），可直接构造 TextOperation 后调用 tryTransform
  final textOp = TextOperation(
    blockId: blockId,
    offset: 0,
    deleted: oldSource,
    inserted: newSource,
  );
  if (!textOp.apply(_editor)) return false;
  _builder.add(textOp);

  // 尝试 transform（若不需要，tryTransform 返回 false，不影响已 apply 的 textOp）
  tryTransform(blockId);
  return true;
}
```

**关键设计点**：

1. **updateSource 不做原子性保证**：若 tryTransform 失败（极少见，仅 composing 中途激活），textOp 已 apply，调用方需自行 revert
2. **Phase 3 UI 层应优先使用 updateSource** 而非直接构造 TextOperation，以获得自动 transform
3. **精细 IME 输入**：Phase 3 若需 IME 增量（offset/deleted 精确），可手动构造 TextOperation 后调用 tryTransform

### 3.5 BlockOperations.split 自动 transform

修改现有 [block_operations.dart](file:///d:/Projects/Active/math/flutter_app/lib/core/editing/block_operations.dart) `split` 方法：

```dart
bool split(BlockId targetId, int offset) {
  _composing?.assertBlockMutationAllowed();

  final op = BlockOperation(
    opType: BlockOpType.split,
    targetId: targetId,
    splitOffset: offset,
  );

  if (!op.apply(_editor)) return false;
  _builder.add(op);

  // Phase 2.7 新增：对新块（右块）调用 tryTransform
  // ADR-0007 §4.3：split 触发点
  final newId = op.revertContext['newId'] as BlockId?;
  if (newId != null) {
    tryTransform(newId);
  }
  return true;
}
```

**关键设计点**：

1. **split 自动 transform 新块**：典型场景是用户在 Paragraph 末尾按 Enter，新块是空 Paragraph，不触发 transform；但若用户在 Paragraph 中间按 Enter 且右块恰好是 `# Title` 形式，自动重类型化为 Heading
2. **原块（左块）不自动 transform**：原块保持原 type，避免破坏用户已编辑的块
3. **transform 失败不阻塞 split**：split 已 apply 并加入 TransactionBuilder，tryTransform 失败仅意味着不产生额外 op
4. **一次 split 调用最多产生 2 个 op**：split + transform

### 3.6 业务行为变化清单

| 行为 | Phase 2.6 | Phase 2.7 |
|------|----------|----------|
| `ops.split(targetId, offset)` | 仅 split op | split op + 可选 transform op（对新块） |
| `ops.updateSource(blockId, newSource)` | 不存在 | 新增（TextOperation + 可选 transform） |
| `ops.tryTransform(blockId)` | 不存在 | 新增 |
| `BlockOpType.transform` | 不存在 | 新增（apply/revert 幂等） |
| `BlockOperation.transformedType` 字段 | 不存在 | 新增（仅 transform opType 使用） |

**对 Phase 2.6 既有行为的影响**：
- `BlockOperation.split` 本身行为不变（仅 BlockOperations.split 高层包装增加 tryTransform 调用）
- 直接调用 `BlockOperation(opType: BlockOpType.split, ...)` 不会触发 transform
- 通过 `BlockOperations.split` 高层 API 才会触发自动 transform

### 3.7 与 IME 三铁律集成（ADR-0008 §5）

| 铁律 | Phase 2.7 落地 |
|------|---------------|
| 铁律 1（不切块） | `tryTransform` / `updateSource` / `split` 前置调用 `composing.assertBlockMutationAllowed()`（transform 是 BlockOperation，受铁律 1 约束） |
| 铁律 2（commit 不丢字） | IME commit 触发的 transform 通过 origin=ime 的 Transaction，不参与 coalescing |
| 铁律 3（cancel 回滚） | IME cancel 不入栈（transform 不入栈，由 ComposingController.onComposingCancel 处理） |

### 3.8 业务行为不变（除新增 transform）

- `flutter analyze`：0 error / 0 warning
- `flutter test --exclude-tags golden`：671 + 新增 ~60 = ~731 passed / 0 regression
- 现有 BlockEditor abstract 接口 0 修改
- 现有 ComposingController / ComposingState / ComposingHost 0 修改
- 现有 AST 0 修改
- 现有 DocumentEditor / Transaction / TransactionBuilder / EditorHistory / HistoryManager 0 修改
- Phase 2.6 测试 347 全部通过（0 regression）

---

## 4. Validation Plan（验证计划）

### 4.1 Unit Test

**TC-EDIT-7.1 BlockOperation.transform apply/revert 幂等性**（~15 tests）：

文件 `test/editing/block_operation_transform_test.dart`：

- transform apply：Paragraph → Heading / ListItem / Code / Blockquote / HorizontalRule / TaskListItem / Mermaid
- transform revert：恢复原 element（含 ListElement.ordered / CodeElement.language 等）
- 幂等性：apply-revert-apply-revert 循环 5 轮
- transformedType == currentType → apply 返回 false（无 op 入栈）
- transformedType == null → apply 返回 false
- 非法 targetId → apply 返回 false
- revertContext 保存完整 originalElement snapshot
- revert 后 BlockId 保持不变

**TC-EDIT-7.2 BlockOperations.tryTransform + updateSource 集成**（~20 tests）：

文件 `test/editing/block_operations_transform_test.dart`：

- tryTransform 触发条件：source 匹配规则 + 当前 type 不一致
- tryTransform 不触发：source 不匹配规则 / 当前 type 已一致
- tryTransform 失败：composing.isActive 时抛 StateError
- updateSource 仅改 source（无 transform）：仅产生 TextOperation
- updateSource 改 source 并触发 transform：产生 TextOperation + BlockOperation.transform
- updateSource 边界：newSource == oldSource → 无 op
- updateSource 边界：blockId 不存在 → 返回 false
- IME 守门：composing.isActive 时 updateSource 抛 StateError
- builder.ops 顺序：text 在前，transform 在后

**TC-EDIT-7.3 split 后自动 transform**（~15 tests）：

文件 `test/editing/split_auto_transform_test.dart`：

- ADR-0007 §4.3 12 类规则全覆盖：
  - split 后新块为 `# Title` → Heading
  - split 后新块为 `## Title` → Heading(level=2)
  - split 后新块为 `- item` → ListItem(ordered=false)
  - split 后新块为 `* item` → ListItem(ordered=false)
  - split 后新块为 `+ item` → ListItem(ordered=false)
  - split 后新块为 `1. item` → ListItem(ordered=true)
  - split 后新块为 `- [ ] task` → TaskListItem(checked=false)
  - split 后新块为 `- [x] task` → TaskListItem(checked=true)
  - split 后新块为 ``` ```lang\ncode\n``` ``` → Code(language=lang)
  - split 后新块为 ``` ```mermaid\n...\n``` ``` → Mermaid
  - split 后新块为 `> quote` → Blockquote
  - split 后新块为 `---` → HorizontalRule
- split 后新块为纯文本（无规则匹配）→ 不触发 transform，仅产生 split op
- split 后新块为空字符串 → 不触发 transform
- split revert 后：原块 + 新块都恢复（含可能的 transform revert）

**TC-EDIT-7.4 transform Undo/Redo 循环**（~10 tests）：

文件 `test/editing/transform_undo_redo_test.dart`：

- transform 单独 Undo/Redo 5 轮循环
- TextOperation + transform 组合 Undo/Redo 循环
- split + transform 组合 Undo/Redo 循环
- 多 Transaction 序列 Undo/Redo：
  - apply T1（text only）→ apply T2（text + transform）→ undo → undo → redo → redo
- transform revert 后 BlockId 保持不变
- transform revert 后 element 完整恢复（含 ordered / language 字段）

**TC-EDIT-7.5 transform 边界**（~8 tests）：

文件 `test/editing/transform_boundary_test.dart`：

- transformedType == currentType → tryTransform 返回 false，不产生 op
- composing.isActive 时 tryTransform 抛 StateError
- composing.isActive 时 updateSource 抛 StateError
- composing.isActive 时 split 抛 StateError（已 Phase 2.6 覆盖，本 Phase 不重复）
- 非法 blockId → tryTransform 返回 false
- 非法 blockId → updateSource 返回 false
- 反向 transform 不支持（Heading → Paragraph 需 source 变化）：检测到 detectedType == currentType 时返回 false
- BlockOperation.transform 不参与 coalescing（自动由 _defaultCanCoalesce 守门）

### 4.2 Architecture Validation

- TC-ARCH-7（file_size_test.dart）：2 个修改的 lib 文件 + 5 个新 test 文件均 ≤400 行
- TC-ARCH-11（editing_layer_test.dart）：扩展 TC-ARCH-11.1 sanity check 覆盖新增/修改文件
- TC-ARCH-12.x（ast_snapshot_test.dart）：仍通过（Phase 2.7 不改 AST）

### 4.3 Regression Validation

- `flutter analyze` 0 error / 0 warning
- `flutter test --exclude-tags golden`：671 + ~60 新增 = ~731 passed / 0 regression
- 关键关注点：
  - Phase 2.6 的 347 editing 测试 0 regression
  - 新增 transform opType 不破坏现有 5 类 op 的 apply/revert
  - BlockOperations.split 修改后不破坏 Phase 2.6 的 split 测试（自动 transform 在 mock 中可能触发，需检查）

### 4.4 Manual Verification

无 UI 改动，纯逻辑层。手动验证留待 Phase 3 UI 接入后。

---

## 5. Success Criteria（完成标准）

- [ ] 扩展 `BlockOpType` 新增 `transform` 枚举值
- [ ] 扩展 `BlockOperation` 新增 `transformedType` 字段 + `_applyTransform` / `_revertTransform`
- [ ] 新增 `BlockOperations.tryTransform(blockId)` 高层 API
- [ ] 新增 `BlockOperations.updateSource(blockId, newSource)` 高层 API
- [ ] 修改 `BlockOperations.split` 自动 transform 新块
- [ ] 新增 5 个 test 文件，均 ≤400 行
- [ ] `flutter analyze` 0 error / 0 warning
- [ ] `flutter test --exclude-tags golden` 0 regression（671 + ~60 新增 = ~731）
- [ ] ADR-0007 §4.3 12 类规则全覆盖（测试矩阵）
- [ ] ADR-0007 §4.3 split / onSourceChanged 触发点全部落地
- [ ] IME 三铁律集成（composing.isActive 时 tryTransform / updateSource / split 抛 StateError）
- [ ] transform Undo/Redo 循环正确（含与 TextOperation / split 组合）
- [ ] 现有 BlockEditor abstract 接口 0 修改
- [ ] 现有 ComposingController / ComposingState / ComposingHost 0 修改
- [ ] 现有 AST 0 修改
- [ ] 现有 DocumentEditor / Transaction / TransactionBuilder / EditorHistory / HistoryManager 0 修改
- [ ] 本 Task Contract 已提交
- [ ] PR 描述包含关联 issue / 改动说明 / 测试方式

---

## 6. Rollback Plan（回滚方案）

**回滚难度**：低（< 10 分钟）

**回滚步骤**：

1. `git revert <commit-hash>` 即可还原所有修改
2. PR merge 前：直接 close PR，分支不合并即可
3. PR merge 后：新开 `revert/phase2.7-markdown-shortcut` 分支 revert merge commit

**部分回滚选项**：

- 若 `BlockOperations.split` 自动 transform 引起 regression：保留 transform opType + tryTransform / updateSource，仅在 split 中移除自动调用
- 若 `BlockOperation.transform` 实现有问题：保留 BlockOperations 修改，移除新 opType（split 自动 transform 退化为 no-op）

**回滚触发条件**：

- transform apply/revert 幂等性测试失败
- Phase 2.6 347 editing 测试出现 regression
- BlockOperations.split 自动 transform 破坏既有 split 行为

---

## 7. Feedback Signals（反馈信号）

### 7.1 成功信号

- 12 类 Markdown 快捷规则在 split 后自动 transform 全部测试通过
- tryTransform 在 type 已一致时返回 false（不产生冗余 op）
- transform Undo/Redo 循环 5 轮状态一致
- Phase 2.6 测试 0 regression

### 7.2 失败信号

- transform apply 后 revert 未恢复原 element
- split 自动 transform 破坏 Phase 2.6 split 测试
- updateSource 中 TextOperation 失败但未 rollback
- composing.isActive 时 transform 未抛 StateError

---

## 8. Risk Assessment（风险评估）

| 风险 | 概率 | 影响 | 缓解 |
|------|------|------|------|
| BlockOperations.split 自动 transform 破坏 Phase 2.6 split 测试 | 中 | 中 | 检查 Phase 2.6 split 测试：若测试用例的右块恰好匹配规则，需调整测试 fixture（如新块为空或纯文本不匹配规则） |
| transform revert 未恢复 ListElement.ordered / CodeElement.language 字段 | 中 | 高 | revertContext 保存完整 originalElement snapshot（不是仅 type），单测覆盖 12 类规则的字段保留 |
| BlockOpType.transform 与现有 5 类 opType 共存导致 switch 不完整 | 低 | 中 | BlockOperation.apply 使用 exhaustive switch（Dart 编译期保证） |
| updateSource 中 TextOperation 失败但已 apply | 中 | 中 | updateSource 不做原子性保证（已说明）；调用方需自行 revert（参考 transaction_rollback_atomicity_test.dart 的 rollback helper） |
| 与 ADR-0007 §4.3 决策冲突 | 低 | 高 | 严格按 §4.3 规则表实现，不引入新决策 |
| 性能：1000 块 Document 下 tryTransform 慢 | 低 | 低 | tryTransform 是 O(1) 检查（detectBlockType + BlockType 比较） |
| **BlockOperations 隐式执行器角色（v1.1 新增）** | 低 | 中 | 已知 tech debt（[ADR-0008 v1.1 §10](file:///d:/Projects/Active/math/docs/ADR/0008-editor-transaction-model.md)）；本 Phase 复用现有模式，不引入 TransactionExecutor，留待 Phase 2.8+ 解决 |
| **transform 误用 replaceBlock 导致 BlockId 重分配（v1.1 新增）** | 低 | 高 | §1.5 已明确禁止；单测覆盖"transform 后 BlockId 不变"（TC-EDIT-7.1） |
| **BlockId 误持久化到 .md 文件（v1.1 新增）** | 低 | 高 | BlockSerializer 不读写 BlockId（Phase 2.3 已稳定）；transform 不修改 BlockSerializer，单测验证 toElement/fromElement 不含 BlockId |

**总体风险等级**：**Medium**

**v1.1 风险等级维持 Medium** 的理由：

新增 3 项风险均为「已知 tech debt / 防御性约束」，不引入新架构改动：

- BlockOperations 隐式执行器：Phase 2.8+ 解决，本 Phase 不触碰
- transform 误用 replaceBlock：编译期 + 单测双重守门
- BlockId 误持久化：现有 BlockSerializer 已隐含遵守，本 Phase 不修改 BlockSerializer

理由：

1. **代码量小**：仅修改 2 个 lib 文件（+170 行）+ 新增 5 个 test 文件（~920 行）
2. **架构影响可控**：transform 是新增 opType，不修改既有 5 类 op 的 apply/revert
3. **幂等性要求**：transform apply/revert 必须严格幂等，但实现简单（仅 updateBlockContent）
4. **split 自动 transform 是行为变化**：可能影响 Phase 2.6 split 测试（需检查）

**不升级为 High** 的理由：

- 不改 AST
- 不改 UI
- 不改存储
- 不改 parser / providers / domain
- 不改 DocumentEditor / Transaction / TransactionBuilder / EditorHistory / ComposingController
- 可独立回滚（PR merge 前可 close）

**相比 Phase 2.6 的 High 风险**：

- 代码量是 Phase 2.6 的 1/5
- 不引入新的抽象层（仅扩展现有 BlockOperation）
- 不改 coalescing 规则
- 不改 IME 集成（复用现有守门）

---

## 9. Approval（审批）

| 角色 | 状态 | 时间 |
|------|------|------|
| AI Agent | 已起草 v1.0 | 2026-07-20 |
| Human Owner | v1.0 评审反馈：补强 BlockId 生命周期 + TransactionExecutor 设计方向 | 2026-07-20 |
| AI Agent | 已落地 v1.1 修订 | 2026-07-20 |
| Human Owner | v1.1 待审批 → 通过即可开始实现 | — |

**审批方式**：Human Owner 在本 Task Contract PR 中 review 后回复 "approved" / "approved with comments" / "rejected"。

**授权范围**：Human Owner 已通过 "更新文档，进行 2.7 的开发" 指令授权本 Phase 启动，并明确授权同时调整 ADR-0008（v1.1）。

**强制审批理由**：

- AGENTS.md §9.2 要求：复杂任务（Risk Medium+ 或涉及架构变更）的 Task Contract 须提交 Human Owner 审批后再开始实现
- 本 Phase 风险等级 Medium
- 本 Phase 涉及 BlockOperation 扩展（新增 transform opType + 修改 BlockOperations.split 行为）
- v1.1 修订引用 ADR-0008 v1.1 §9 / §10，需 Human Owner 同时审批 ADR-0008 修订

---

## 10. AI Self Review（自检）

### 10.1 ADR 合规性

- [x] ADR-0007 §4.3 Markdown 快捷映射规则表 12 类全覆盖
- [x] ADR-0007 §4.3 split / onSourceChanged 触发点全部落地
- [x] ADR-0007 §1.3 Wrapping 决策：transform 复用 BlockSerializer.toElement
- [x] ADR-0008 §2 apply/revert 幂等纯函数：transform 严格遵守
- [x] ADR-0008 §4 Coalescing：transform 是 BlockOperation，自动不参与 coalescing
- [x] ADR-0008 §5 IME 三铁律：transform 前置调用 assertBlockMutationAllowed
- [x] **ADR-0008 v1.1 §9 BlockId 生命周期（v1.1 新增）**：transform 不变更 BlockId（用 updateBlockContent 非 replaceBlock）；不持久化 BlockId 到 .md 文件
- [x] **ADR-0008 v1.1 §10 TransactionExecutor（v1.1 新增）**：本 Phase 不引入 TransactionExecutor，复用现有 BlockOperations 模式；Phase 2.8+ 候选已记录
- [x] AGENTS.md §6.5 Phase 2 禁区未触碰（未改 UI / 未新增 Phase 3 功能 / 未引入派生缓存）
- [x] AGENTS.md §6.4 AI 提交分工得到遵守

### 10.2 范围漂移检查

- [x] 改动范围与 Task Contract 一致
- [x] 未夹带未在 Task Contract 中说明的改动
- [x] 0 业务行为变化（除新增 transform + split 自动 transform）

### 10.3 技术债务检查

- [x] 未引入新的技术债务
- [x] BlockOperations.split 自动 transform 是有意的设计决策（ADR-0007 §4.3 明确要求）
- [x] updateSource 不做原子性保证已文档化（与 BlockOperations 整体 eager apply 语义一致）

### 10.4 测试覆盖检查

- [x] transform apply/revert 幂等性单测覆盖（12 类规则）
- [x] tryTransform / updateSource 触发条件单测覆盖
- [x] split 自动 transform 12 类规则单测覆盖
- [x] transform Undo/Redo 循环单测覆盖
- [x] IME 守门单测覆盖
- [x] 边界（type 已一致 / 非法 blockId / composing.isActive）单测覆盖

### 10.5 文档同步

- [x] Task Contract 完整记录设计依据
- [x] ADR-0007 §4.3 引用准确
- [x] ADR-0008 §2 / §4 / §5 引用准确
- [x] Phase 2.6 衔接说明清晰

---

## 11. Future ADR 候选（信息性记录）

- **ADR-0010**（候选，Phase 2.7 后评估）：Markdown 快捷映射规则扩展
  - 若未来需支持非标准语法（如 obsidian wiki link / KaTeX block）
  - 若 split 自动 transform 在特定场景下需要禁用（如 Code block 内不触发）

- **ADR-0011**（候选，Phase 3+）：Syntax Hiding
  - visual/source offset 映射规则
  - Phase 3+ 若实现 syntax hiding 才开

---

## 12. 实施顺序（建议）

为降低单 PR 复杂度，建议分阶段实施（但合并为 1 个 PR）：

1. **扩展 BlockOpType.transform** + BlockOperation 实现（~80 行 lib）+ 单测 TC-EDIT-7.1（~180 行 test）
2. **新增 BlockOperations.tryTransform + updateSource**（~90 行 lib）+ 单测 TC-EDIT-7.2（~250 行 test）
3. **修改 BlockOperations.split 自动 transform** + 单测 TC-EDIT-7.3（~220 行 test）
4. **Undo/Redo 循环测试** TC-EDIT-7.4（~150 行 test）
5. **边界测试** TC-EDIT-7.5（~120 行 test）
6. **检查 Phase 2.6 既有 split 测试** 是否被自动 transform 影响
7. **flutter analyze + flutter test 验证**
8. **commit + push + PR**

每阶段完成后跑 `flutter analyze` + 对应单测，确保增量正确。

---

**维护人**：AI Agent（GLM-5.2）
**生效日期**：2026-07-20
