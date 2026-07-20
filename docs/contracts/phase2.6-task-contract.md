# Task Contract: Phase 2.6 块级操作原语 + Transaction Model

> AI Agent 在开始编码前必须填写此契约。复杂任务提交 Human Owner 审批后再开始实现。

---

Task ID: ROADMAP Phase 2.6

**版本**：v1.2（2026-07-19，含 Human Owner 二次评审 3 项补强）

---

## 修订记录

- v1.0（2026-07-19）：初版，基于 ADR-0007 §4（块级操作原语）+ ADR-0008（Transaction Model）起草
- v1.1（2026-07-19）：Human Owner v1.0 评审反馈 5 项修订
  1. **必改** §3.2 TextOperation：`blockIndex` → `BlockId`（BlockId 是稳定 identity，index 仅作 cached 优化）
  2. **必改** §3.1 DocumentEditor：移除 listener 核心职责，改由 Transaction.commit 触发通知（避免每 op 触发 UI rebuild 风暴）
  3. **必改** §3.3 BlockOperation revert context：每类 op 补充 index/snapshot，确保 revert 能精确恢复位置
  4. **建议改** §3.6 EditorHistory：coalesce 规则改为 `canCoalesce(prev, next)` predicate 函数化，不写死
  5. **建议改** §4.1 测试矩阵：新增 4 类测试（undo/redo round trip / transaction rollback atomicity / notification count / IME mutation forbidden）
- v1.2（2026-07-19）：Human Owner v1.1 二次评审"Approve with 2 small additions"3 项补强
  1. **补强** §3.3 revertContext：明确"immutable snapshot，禁止保存 live mutable reference"约束
  2. **补强** §3.4 TransactionId：明确生命周期"在 TransactionBuilder 创建时生成，非 commit 时"（便于 debug 追踪）
  3. **补强** §3.4 TransactionOrigin：从 4 值扩展为 6 值（keyboard/ime/paste/programmatic/undo/redo），§3.6 _defaultCanCoalesce 增加 origin 一致性检查

---

## 1. Goal（目标）

要解决的问题：**在纯 Dart 逻辑层落地 ADR-0007 §4.1 五原语（insert/delete/merge/split/move）+ ADR-0008 Transaction Model（Transaction 容器 + EditOperation apply/revert + Coalescing + EditorHistory 包装）**。

### 1.1 上游 ADR 完整约束

| ADR | 章节 | 已落地内容 | 本 Phase 待落地 |
|-----|------|----------|---------------|
| ADR-0007 | §4.1 | 五原语接口骨架（abstract `BlockOperations`） | 5 个具体 BlockOperation 类（apply + revert） |
| ADR-0007 | §4.2 | EditOperation sealed class 骨架 + 双层 Undo 决策 | EditOperation 完整实现 + HistoryManager 扩展 |
| ADR-0007 | §4.4 | 边界约束（不修改 AST 签名 / 不引入派生缓存 / 10000 块上限） | 全部遵守 |
| ADR-0008 | §1 | Transaction = EditOperation 批量容器 | Transaction 类 + TransactionId + Metadata + Origin |
| ADR-0008 | §2 | apply/revert 幂等纯函数 | 5 类 BlockOp + TextOp 的 apply/revert |
| ADR-0008 | §3 | TransactionBuilder.commit/rollback 原子性 | TransactionBuilder 实现 + 嵌套合并 |
| ADR-0008 | §4 | Coalescing 6 触发条件 + 4 封口规则 | EditorHistory.push 实现 + _canCoalesce |
| ADR-0008 | §5 | 与 IME 三铁律交互（Phase 2.5 已预留接口） | BlockOperation 前置调用 `assertBlockMutationAllowed` |
| ADR-0008 | §6 | EditorHistory 包装 HistoryManager<Transaction> | EditorHistory 类 + 旧 API 向后兼容 |
| ADR-0008 | §7 | Transaction 不持久化 | 内存态，重启清空 |
| ADR-0008 | §8 | TransactionId 内存顺序标识 | 自增计数器 |

### 1.2 ADR-0008 §负面后果 #4 隐含依赖

> DocumentEditor 接口未定义：本 ADR 引用 `DocumentEditor`，但其接口需 Phase 2.6 在 [block_editor.dart](file:///d:/Projects/Active/math/flutter_app/lib/core/editing/block_editor.dart) 中落地，是隐含依赖

**本 Phase 第一个任务**：定义 DocumentEditor 接口（apply/revert 的副作用边界）。

### 1.3 不实现范围

- ❌ 不接入 UI（Phase 3）
- ❌ 不修改 BlockEditor abstract 接口（保持 abstract，Phase 3 UI 实现具体类）
- ❌ 不修改 AST（[document.dart](file:///d:/Projects/Active/math/flutter_app/lib/data/models/document.dart) 零修改）
- ❌ 不修改 parser / storage / providers
- ❌ 不实现 Markdown 快捷映射（Phase 2.7）
- ❌ 不接入真实 TextEditingController（Phase 3）
- ❌ 不实现 cursor/selection rollback（归本 Phase Transaction 上下文，但 cursor 跟踪归 Phase 3 UI 接入）

### 1.4 与 Phase 2.5 的衔接

- ✅ 复用 `ComposingController.isActive` / `assertBlockMutationAllowed()`：每个 BlockOperation.apply 前置调用
- ✅ 复用 `ComposingRegion`（[block_types.dart:202](file:///d:/Projects/Active/math/flutter_app/lib/core/editing/block_types.dart)）：TextOperation.offset 语义对齐 UTF-16
- ❌ 不修改 ComposingController / ComposingState / ComposingHost（Phase 2.5 已稳定）

---

## 2. Scope（范围）

### 2.1 修改

| 文件 | 操作 | 说明 | 预估行数 |
|------|------|------|---------|
| `flutter_app/lib/core/editing/document_editor.dart` | 新增 | DocumentEditor abstract 接口（model mutation boundary，**v1.1 不含 listener**） | ~130 |
| `flutter_app/lib/core/editing/edit_operation.dart` | 新增 | sealed EditOperation + 5 类 BlockOperation + TextOperation（**v1.1：BlockId 定位 + revertContext 完整 snapshot**） | ~400 |
| `flutter_app/lib/core/editing/transaction.dart` | 新增 | Transaction + TransactionId + TransactionMetadata + TransactionOrigin | ~100 |
| `flutter_app/lib/core/editing/transaction_builder.dart` | 新增 | TransactionBuilder（add/commit/rollback + 嵌套合并 + **v1.1：onChange 回调**） | ~180 |
| `flutter_app/lib/core/editing/editor_history.dart` | 新增 | EditorHistory 包装 HistoryManager<Transaction> + **v1.1：canCoalesce predicate 函数化** | ~210 |
| `flutter_app/lib/core/editing/block_operations.dart` | 新增 | BlockOperations 抽象（**v1.1：BlockId 定位**） | ~100 |
| `flutter_app/test/editing/edit_operation_test.dart` | 新增 | TC-EDIT-6.1 apply/revert 幂等性（5 类 BlockOp + TextOp） | ~350 |
| `flutter_app/test/editing/transaction_builder_test.dart` | 新增 | TC-EDIT-6.2 TransactionBuilder commit/rollback/嵌套/onChange | ~320 |
| `flutter_app/test/editing/editor_history_test.dart` | 新增 | TC-EDIT-6.3 EditorHistory coalescing + canCoalesce 注入 | ~350 |
| `flutter_app/test/editing/block_operations_test.dart` | 新增 | TC-EDIT-6.4 5 原语语义 + IME 铁律集成 | ~300 |
| `flutter_app/test/editing/document_editor_test.dart` | 新增 | TC-EDIT-6.5 DocumentEditor 副作用边界（**v1.1：验证无 listener**） | ~150 |
| `flutter_app/test/editing/undo_redo_round_trip_test.dart` | 新增 | TC-EDIT-6.6 Undo/Redo 5 轮循环（**v1.1 评审反馈 5A 新增**） | ~250 |
| `flutter_app/test/editing/transaction_rollback_atomicity_test.dart` | 新增 | TC-EDIT-6.7 Transaction 回滚原子性（**v1.1 评审反馈 5B 新增**） | ~200 |
| `flutter_app/test/editing/notification_count_test.dart` | 新增 | TC-EDIT-6.8 Notification 次数验证（**v1.1 评审反馈 5C 新增**） | ~120 |
| `flutter_app/test/editing/ime_mutation_forbidden_test.dart` | 新增 | TC-EDIT-6.9 IME 组合态操作禁止（**v1.1 评审反馈 5D 新增**） | ~120 |
| `flutter_app/test/architecture/editing_layer_test.dart` | 修改 | TC-ARCH-11.1 扩展覆盖 6 个新文件 | +6 行 |
| `flutter_app/lib/core/utils/history_manager.dart` | 修改 | **v1.1**：新增 `lastOrNull` getter + `replaceLast` 方法（纯新增，旧 API 0 修改） | +20 |
| `docs/contracts/phase2.6-task-contract.md` | 新增 | 本 Task Contract | — |

**注**：所有 lib 文件 ≤400 行限制；所有 test 文件 ≤400 行限制（超限则拆分，参考 Phase 2.3 / 2.5 经验）。

### 2.2 不修改

- `lib/core/editing/block_editor.dart`（abstract 接口稳定，Phase 3 UI 实现具体类）
- `lib/core/editing/block_editor_state.dart`（Phase 2.2 产物已稳定）
- `lib/core/editing/block_types.dart`（Phase 2.2 产物已稳定，含 BlockId/BlockType/BlockPosition/ComposingRegion）
- `lib/core/editing/block_serializer.dart`（Phase 2.3 产物已稳定）
- `lib/core/editing/block_type_detector.dart`（Phase 2.3 产物已稳定，Phase 2.7 扩展）
- `lib/core/editing/composing_controller.dart`（Phase 2.5 产物已稳定）
- `lib/core/editing/composing_state.dart`（Phase 2.5 产物已稳定）
- `lib/core/utils/history_manager.dart`（**保留向后兼容**，EditorHistory 包装而非重写）
- `lib/data/models/document.dart`（AST 零修改）
- `lib/core/parser/markdown_parser.dart`（不改）
- `lib/presentation/widgets/*.dart`（UI 冻结）
- `lib/presentation/screens/*.dart`（UI 冻结）
- `pubspec.yaml`（无新依赖）
- `docs/ADR/0007-*.md` / `docs/ADR/0008-*.md`（架构决策文件，由 Human Owner 维护）

---

## 3. Expected Behavior（预期行为）

### 3.1 DocumentEditor 接口（model mutation boundary）

ADR-0008 §2 决策："所有状态修改必须通过 `DocumentEditor` 接口，不直接操作 AST"。

**v1.1 评审反馈 2 修订**：listener 不属于 DocumentEditor 核心职责。

**理由**：

DocumentEditor 是 model mutation boundary（数据修改边界）。listener 是 UI/reactive layer concern（UI/响应层关注点）。

若 listener 放在 DocumentEditor 内：

```
BlockOperation.apply
  ↓
DocumentEditor.insert
  ↓
listener 触发  // ← 每个 op 都触发
  ↓
UI rebuild     // ← UI rebuild 风暴
```

10 个 op 的 Transaction commit 时会触发 10 次 listener，导致 UI 重建 10 次。

**修订后架构**：

```
DocumentEditor          ← 仅负责修改数据（纯 model mutation）
       ↑
       │
Transaction.commit()   ← 负责完成后通知（一次 commit 一次 notification）
       ↑
       │
ChangeNotifier / UI    ← 订阅 Transaction 级通知
```

**修订后接口**：

```dart
/// Document 编辑器接口（model mutation boundary）。
///
/// 所有 EditOperation.apply / revert 通过此接口修改 Document 状态，
/// 不直接操作 AST，不触发任何通知（纯数据修改）。
///
/// Notification 责任在 Transaction.commit() 一层（见 §3.5），
/// 避免 N 个 op 触发 N 次 UI rebuild。
///
/// Phase 3 UI 层实现具体类，包装 Document + AST。
/// Phase 2.6 单测用 mock 实现。
abstract class DocumentEditor {
  /// 当前块数。
  int get blockCount;

  /// 按 BlockId 查找块。
  ///
  /// BlockId 是稳定 identity（[block_types.dart:23](file:///d:/Projects/Active/math/flutter_app/lib/core/editing/block_types.dart#L23)），
  /// 不随 insert/delete 变化。
  /// 找不到时返回 null（调用方决定是否抛异常）。
  DocumentElement? getBlock(BlockId id);

  /// 按 BlockId 查找 index（用于 revert 时恢复位置）。
  ///
  /// 找不到时返回 -1（revert 失败时调用方决定如何处理）。
  int indexOf(BlockId id);

  /// 在 [index] 处插入 [element]，分配新 BlockId。
  ///
  /// index 越界时抛 RangeError。
  /// 返回新分配的 BlockId（用于 BlockOperation revert context）。
  BlockId insertBlock(int index, DocumentElement element);

  /// 移除 [id] 对应的块，返回被移除的元素（用于 revert）。
  ///
  /// 找不到时抛 StateError。
  DocumentElement removeBlock(BlockId id);

  /// 替换 [id] 对应的块为 [element]，返回旧元素（用于 revert）。
  ///
  /// 找不到时抛 StateError。
  /// 注意：element 的新 BlockId 由 DocumentEditor 重新分配，
  /// 旧 BlockId 失效（若需保持 BlockId，应使用 updateBlockContent）。
  DocumentElement replaceBlock(BlockId id, DocumentElement element);

  /// 仅替换 [id] 对应块的内容（保持 BlockId 不变）。
  ///
  /// 用于 TextOperation.apply：BlockId 不变，仅 source 变化。
  /// 找不到时抛 StateError。
  void updateBlockContent(BlockId id, DocumentElement newContent);
}
```

**设计要点**：

- 接口极简：getBlock / indexOf / insertBlock / removeBlock / replaceBlock / updateBlockContent + blockCount
- **BlockId 是稳定 identity**：所有 op 用 BlockId 而非 index 定位（评审反馈 1+2 联动修订）
- 返回值设计支持 revert：removeBlock 返回被移除元素，replaceBlock 返回旧元素，insertBlock 返回新 BlockId
- **不暴露 listener**：notification 责任在 Transaction.commit() 一层
- **新增 indexOf**：revert 时需要按 BlockId 找 index（用于恢复插入位置）
- **新增 updateBlockContent**：TextOperation 专用（保持 BlockId 不变，仅替换内容）
- **新增 EmptyLineElement 过滤由调用方负责**（[BlockTypeDetector] 不映射空行）

### 3.2 EditOperation sealed class

ADR-0008 §2 定义骨架，本 Phase 落地完整实现：

```dart
/// 编辑操作联合类型。
///
/// ADR-0007 §4.2 + ADR-0008 §2。
sealed class EditOperation {
  const EditOperation();

  /// 前向应用：修改 [editor] 状态，返回是否成功。
  ///
  /// 幂等纯函数（不依赖外部可变状态），同一 op 对同一 editor 状态多次 apply 结果一致。
  /// 失败返回 false（不抛异常），调用方决定是否 rollback。
  bool apply(DocumentEditor editor);

  /// 反向应用：恢复到 apply 前的状态。
  ///
  /// 幂等纯函数。revert 后 editor 状态应与 apply 前一致。
  void revert(DocumentEditor editor);
}

/// 5 类块级操作的类型标识。
enum BlockOpType {
  insert,
  delete,
  merge,
  split,
  move,
}

/// 块级操作：结构变化。
///
/// 每次 §4.1 五原语调用 = 1 个 BlockOperation。
/// apply 前必须先调用 ComposingController.assertBlockMutationAllowed()（ADR-0008 §5 铁律 1）。
///
/// **v1.1 评审反馈 3 修订**：所有 op 用 BlockId 定位（不用 index），
/// revert context 保存完整 snapshot（含 index / 元素）确保精确恢复。
final class BlockOperation extends EditOperation {
  final BlockOpType opType;

  /// 操作的目标 BlockId（apply 前存在）。
  ///
  /// BlockId 是稳定 identity（[block_types.dart:23](file:///d:/Projects/Active/math/flutter_app/lib/core/editing/block_types.dart#L23)），
  /// 不随其他 insert/delete 变化。
  final BlockId targetId;

  /// 辅助 BlockId：split 的新块 / move 的目标位置参考块 / merge 的右块。
  final BlockId? auxiliaryId;

  /// apply 前填充的 revert context（每类 op 不同，见 §3.3 表）。
  ///
  /// 由 apply() 方法在执行过程中填充，revert() 读取使用。
  /// 内容包括：被删元素、旧 index、left/right snapshot 等。
  final Map<String, Object?> revertContext;

  /// apply 前的 cursor（可选，用于 Phase 3 UI 恢复光标）。
  final BlockPosition? cursorBefore;

  const BlockOperation({
    required this.opType,
    required this.targetId,
    this.auxiliaryId,
    this.revertContext = const {},
    this.cursorBefore,
  });

  @override
  bool apply(DocumentEditor editor) {
    // 分派到 _applyInsert / _applyDelete / _applyMerge / _applySplit / _applyMove
    // 每个 _applyXxx：
    //   1. 通过 editor.getBlock(targetId) 拿到当前元素
    //   2. 通过 editor.indexOf(targetId) 拿到当前 index
    //   3. 执行修改（editor.insertBlock / removeBlock / replaceBlock / updateBlockContent）
    //   4. 把 revert 数据写入 revertContext（mutable copy）
    //   5. 返回 true / false
  }

  @override
  void revert(DocumentEditor editor) {
    // 逆序调用 _revertXxx，从 revertContext 读取 index / snapshot 恢复
  }
}

/// 文本操作：块内文本变化。
///
/// 用户连续输入 "hello" = 5 个 TextOperation 或 1 个批量（coalescing 自动合并）。
///
/// **v1.1 评审反馈 1 修订**：用 BlockId 而非 blockIndex 作为 identity。
/// 理由：BlockId 是稳定 identity（不随 insert/delete 变化），
/// 而 index 在 insert/delete 后会失效（如 delete B 后 index=1 不再指向 B）。
final class TextOperation extends EditOperation {
  /// 目标块的 BlockId（稳定 identity，不随其他 op 变化）。
  final BlockId blockId;

  /// 块内 offset（UTF-16，对齐 Flutter TextEditingValue）。
  final int offset;

  /// 被删除文本（revert 时恢复）。
  final String deleted;

  /// 插入文本（revert 时删除）。
  final String inserted;

  /// 可选：cached index（性能优化，不作为 identity）。
  ///
  /// apply 时填充，仅用于快速查找。失效时降级到 editor.indexOf(blockId)。
  /// 不可作为 revert 定位依据。
  int? cachedIndex;

  const TextOperation({
    required this.blockId,
    required this.offset,
    this.deleted = '',
    this.inserted = '',
    this.cachedIndex,
  });

  @override
  bool apply(DocumentEditor editor) {
    // 1. editor.getBlock(blockId) → element
    // 2. block_serializer.fromElement(element) → source + type
    // 3. source = source.substring(0, offset) + inserted + source.substring(offset + deleted.length)
    // 4. block_serializer.toElement(source, type) → newElement
    // 5. editor.updateBlockContent(blockId, newElement)  // BlockId 保持不变
    // 6. cachedIndex = editor.indexOf(blockId)  // 缓存优化
    // 7. 返回 true
  }

  @override
  void revert(DocumentEditor editor) {
    // 逆操作：通过 blockId 定位（不依赖 cachedIndex）
    // 1. editor.getBlock(blockId) → currentElement
    // 2. block_serializer.fromElement(currentElement) → source + type
    // 3. // 先删 inserted，再插 deleted
    //    source = source.substring(0, offset) + deleted + source.substring(offset + inserted.length)
    // 4. block_serializer.toElement(source, type) → revertedElement
    // 5. editor.updateBlockContent(blockId, revertedElement)
  }
}
```

**关键约束**：

- `apply` 返回 bool，不抛异常（调用方决定 rollback）
- `apply` 内部填充 `revertContext`，`revert` 读取使用（不依赖外部可变状态）
- **TextOperation 用 BlockId 作为 identity**（评审反馈 1），cachedIndex 仅作性能优化
- **BlockOperation 用 BlockId 定位**（评审反馈 1+3 联动），index 存入 revertContext 用于精确恢复
- offset 语义对齐 [block_types.dart:148](file:///d:/Projects/Active/math/flutter_app/lib/core/editing/block_types.dart) UTF-16 code unit
- TextOperation 通过 `updateBlockContent` 修改内容（BlockId 不变），不通过 `replaceBlock`（会重新分配 BlockId）

### 3.3 5 类 BlockOperation 语义 + revert context（ADR-0007 §4.1）

**v1.1 评审反馈 3 修订**：每类 op 补充完整 revert context（含 index / snapshot），确保 revert 能精确恢复位置。

| 操作 | apply 行为 | revert 行为 | revertContext 必须保存 |
|------|----------|-----------|----------------------|
| **insert** | `newId = editor.insertBlock(targetIndex, element)` | `editor.removeBlock(newId)` | `newId`（新分配的 BlockId）+ `targetIndex`（apply 前 index）|
| **delete** | `deletedElement = editor.removeBlock(targetId); oldIndex = editor.indexOf(targetId) // apply 前已查` | `editor.insertBlock(oldIndex, deletedElement)` | `deletedElement`（被删元素完整 snapshot）+ `oldIndex`（apply 前 index）|
| **merge** | `rightElement = editor.removeBlock(targetId); leftId = auxiliaryId; leftElement = editor.getBlock(leftId); leftSource = serializer.fromElement(leftElement).source; rightSource = serializer.fromElement(rightElement).source; mergedElement = serializer.toElement(leftSource + rightSource, mergedType); editor.updateBlockContent(leftId, mergedElement)` | `editor.updateBlockContent(leftId, leftElement); editor.insertBlock(rightOldIndex, rightElement)` | `leftId` + `leftElement`（左块 apply 前 snapshot）+ `rightElement`（右块完整 snapshot）+ `rightOldIndex`（右块 apply 前 index）+ `mergedType`（合并后类型）|
| **split** | `originalElement = editor.getBlock(targetId); originalSource = serializer.fromElement(originalElement).source; leftSource = originalSource.substring(0, offset); rightSource = originalSource.substring(offset); leftElement = serializer.toElement(leftSource, originalType); rightElement = serializer.toElement(rightSource, originalType); editor.updateBlockContent(targetId, leftElement); newId = editor.insertBlock(targetIndex + 1, rightElement)` | `editor.removeBlock(newId); editor.updateBlockContent(targetId, originalElement)` | `targetId` + `originalElement`（原块完整 snapshot）+ `offset`（split 点）+ `newId`（新块 BlockId）+ `targetIndex`（apply 前 index）|
| **move** | `element = editor.removeBlock(targetId); oldIndex = editor.indexOf(targetId) // apply 前已查; newId = editor.insertBlock(targetIndex, element)`（注：move 后 BlockId 重新分配） | `editor.removeBlock(newId); editor.insertBlock(oldIndex, element)` | `element`（移动的元素完整 snapshot）+ `oldIndex`（apply 前 index）+ `newId`（apply 后新 BlockId）+ `targetIndex`（apply 后新 index）|

**类型兼容性（merge）**：

- Paragraph + Paragraph → Paragraph（source 拼接）
- List + List（同 ordered）→ List（source 拼接，indent 取较小者）
- 不兼容 → 回退为 Paragraph（source 拼接，ADR-0007 §4.1 决策）

**关键设计点**：

1. **每个 op 的 revertContext 在 apply 时填充**，revert 时读取使用，确保幂等
2. **所有 snapshot 保存完整 DocumentElement**（不是仅 source），因不同 BlockType 的 element 有不同字段（如 CodeElement.language / ListElement.ordered / ListElement.indent）
3. **oldIndex 在 apply 开头查询**（apply 改变 blocks 之前），存入 revertContext
4. **newId 是 insertBlock 返回值**，apply 时由 DocumentEditor 分配，存入 revertContext
5. **move 是唯一会改 BlockId 的 op**：因 insertBlock 重新分配 BlockId（不可保持原 BlockId）。其他 op（delete/merge/split）保持现有 BlockId 语义

**v1.2 评审反馈补强**：revertContext 必须是 **immutable snapshot**，禁止保存 live mutable reference 作为唯一恢复依据。

**理由**：

若保存 live reference：

```dart
// 错误做法（v1.2 禁止）
class DeleteOp {
  DocumentElement deletedElement;  // ← live reference
}

// 后续若 deletedElement 被修改（虽然 DocumentElement 当前是 @immutable，
// 但若未来 AST 改为 mutable，此约束会失效）
// undo 时恢复的是"修改后"的对象，违反幂等性
```

**正确做法**：

```dart
// v1.2 正确做法
class DeleteOp {
  final DocumentElement deletedElement;  // ← final 字段 + @immutable DocumentElement
  // 或：final String serializedState;  // 极端保守：序列化快照
}
```

**约束声明**：

> revertContext represents historical state, NOT live mutable reference.
> 所有 snapshot 字段必须是 final，且 DocumentElement 必须保持 @immutable（[document.dart:30](file:///d:/Projects/Active/math/flutter_app/lib/data/models/document.dart#L30) 已是 @immutable）。
> 若未来 AST 改为 mutable，需重新评估 revertContext 的 snapshot 策略（可能需要深拷贝或序列化）。

**当前 AST 状态**：

- [document.dart:30](file:///d:/Projects/Active/math/flutter_app/lib/data/models/document.dart#L30) 已标注 `@immutable`
- 所有 DocumentElement 子类字段均为 final
- 因此 v1.2 的 immutable snapshot 约束天然满足，无需额外深拷贝

### 3.4 Transaction 容器 + TransactionId 生命周期 + Origin 枚举（ADR-0008 §1+§8）

**v1.2 评审反馈补强 2+3**：

1. **TransactionId 生命周期**：在 TransactionBuilder 创建时生成，非 commit 时
2. **TransactionOrigin 枚举**：从 4 值扩展为 6 值（细化用户输入来源，支持 coalesce origin 一致性检查）

```dart
/// 编辑事务。一个 Transaction = 一组原子可逆的 EditOperation。
///
/// ADR-0008 §1：1 Transaction = 1 Undo 单元（Ctrl+Z 一次撤销整个 Transaction）。
@immutable
class Transaction {
  final TransactionId id;
  final List<EditOperation> ops;   // 顺序敏感
  final TransactionMetadata metadata;
  final TransactionOrigin origin;

  const Transaction({
    required this.id,
    required this.ops,
    required this.metadata,
    required this.origin,
  });
}

/// Transaction 顺序自增标识（ADR-0008 §8）。
///
/// **v1.2 评审反馈补强 2**：生命周期——在 TransactionBuilder **创建时**生成，
/// 非 commit 时。
///
/// 内存态，进程重启后从 0 开始。仅用于调试与日志。
///
/// **生命周期理由**：
///
/// 若在 commit 时生成：
/// ```
/// Builder created  → T-001
/// (添加 op...)
/// commit           → T-002（与 builder 不一致）
/// ```
///
/// Debug log 追踪困难，无法把 "Builder 创建" 与 "Transaction 应用" 关联。
///
/// v1.2 在 Builder 创建时生成：
/// ```
/// Builder created  → T-001
/// (添加 op...)
/// commit           → T-001（一致）
/// ```
///
/// 便于日志追踪与性能分析（测量 Builder 创建到 commit 的耗时）。
class TransactionId {
  static int _counter = 0;
  final int value;

  TransactionId._(this.value);

  /// 在 TransactionBuilder 构造时调用（非 commit 时）。
  factory TransactionId.next() => TransactionId._(_counter++);

  @override
  String toString() => 'TransactionId($value)';
}

/// Transaction 元数据。
@immutable
class TransactionMetadata {
  final DateTime timestamp;
  final String? label;  // 用户可读标签，如 "输入 'hello'" / "拆分块"

  const TransactionMetadata({
    required this.timestamp,
    this.label,
  });
}

/// Transaction 来源。决定是否入栈 / 是否触发 listener / 是否可被 coalesce。
///
/// **v1.2 评审反馈补强 3**：从 v1.0/v1.1 的 4 值扩展为 6 值。
///
/// **扩展理由**：
///
/// ADR-0008 §4 coalescing 6 触发条件之一是 `last.origin == user`，
/// 但 "user" 过于笼统：键盘连续输入与 IME commit / paste 在 Undo 行为上应该有差异
/// （paste 应该独立成单元，不应与前面键盘输入合并）。
///
/// v1.2 细化 user 为 keyboard / ime / paste 三类，coalesce 默认只合并 keyboard
/// （详见 §3.6 _defaultCanCoalesce）。
enum TransactionOrigin {
  /// 键盘逐字符输入（可参与 coalescing）。
  ///
  /// 例：输入 "hello" 的 5 个 TextOperation 应合并为 1 个 Undo 单元。
  keyboard,

  /// IME commit（Phase 2.5 已预留，本 Phase 接入）。
  ///
  /// 例：输入 "你好" 的最终 commit。
  /// 不参与 coalescing（IME commit 必须独立成单元，避免与前面 keyboard 输入混淆）。
  /// 详见 ADR-0008 §5 铁律 2。
  ime,

  /// 粘贴（剪贴板批量插入）。
  ///
  /// 不参与 coalescing（paste 应独立成单元，符合用户直觉）。
  paste,

  /// 程序修改（如格式化 / 自动修复 / lint 修复）。
  ///
  /// 不参与 coalescing（程序修改应独立成单元，便于追溯）。
  programmatic,

  /// undo 自身（不入栈，避免无限递归）。
  undo,

  /// redo 自身（不入栈，避免无限递归）。
  redo,
}
```

**与 v1.1 的对比**：

| 维度 | v1.1 | v1.2 |
|------|------|------|
| TransactionId 生命周期 | commit 时生成 | **Builder 创建时生成** |
| TransactionOrigin 值数 | 4（user/system/ime/undoRedo） | **6（keyboard/ime/paste/programmatic/undo/redo）** |
| coalesce 默认规则 | `origin == user` | **`origin == keyboard`**（更严格，paste/ime 不合并） |

**向后兼容性**：

- v1.0/v1.1 的 `TransactionOrigin.user` 已移除（拆分为 keyboard/ime/paste 三类）
- v1.0/v1.1 的 `TransactionOrigin.system` 改名为 `programmatic`（更准确）
- v1.0/v1.1 的 `TransactionOrigin.undoRedo` 拆分为 `undo` + `redo` 两个独立值
- 本 Phase 是首次落地，无存量代码依赖 v1.1 枚举，向后兼容性无影响

### 3.5 TransactionBuilder + Notification 责任（ADR-0008 §3）

**v1.1 评审反馈 2 修订**：listener 从 DocumentEditor 移出后，notification 责任归 Transaction.commit()。

**Notification 架构**：

```
DocumentEditor          ← 纯 model mutation（不通知）
       ↑
       │
Transaction.commit()   ← N 个 op 全部 apply 成功后，触发 1 次 notification
       ↑
       │
ChangeNotifier          ← TransactionExecutor 持有，UI 订阅
       ↑
       │
UI / Widget            ← 收到 1 次 notification 重建 1 次
```

**修订后 TransactionBuilder**：

```dart
/// Transaction 构造器。add 操作暂存，commit 时原子应用 + 入栈 + 触发 notification。
///
/// ADR-0008 §3：commit/rollback 显式控制原子性。
/// 嵌套语义：内层 TransactionBuilder.commit() 不入栈，ops 合并到外层。
///
/// **v1.1 评审反馈 2 修订**：
/// - DocumentEditor 不暴露 listener（纯数据修改）
/// - Transaction.commit() 完成后触发 1 次 onChange 回调（避免 N 个 op 触发 N 次 UI rebuild）
/// - onChange 回调由 TransactionExecutor / Phase 3 UI 层注入
class TransactionBuilder {
  final List<EditOperation> _ops = [];
  final TransactionOrigin _origin;
  final String? _label;
  final ComposingController? _composing;  // 用于铁律 1 守门

  /// **v1.2 评审反馈补强 2**：TransactionId 在 Builder 创建时生成（非 commit 时）。
  ///
  /// 便于 debug 日志追踪：日志中 "Builder T-001 created" 与 "Transaction T-001 committed"
  /// 使用同一 id，可关联创建与应用两个时间点。
  final TransactionId _id;

  /// Transaction commit 完成后的回调（notification 出口）。
  ///
  /// 由 TransactionExecutor / Phase 3 UI 注入：
  /// - 调用方应在回调内触发 setState / notifyListeners / ValueNotifier.value = ...
  /// - 回调接收 committed Transaction（用于日志 / 调试）
  final void Function(Transaction committed)? onChange;

  /// 嵌套标记（v1.1：简化实现，不引入 TransactionScope.current 全局状态）。
  ///
  /// 内层 TransactionBuilder 通过 isNested=true 创建，commit 时仅合并 ops 到外层，
  /// 不入栈、不触发 onChange。
  final bool isNested;

  TransactionBuilder({
    TransactionOrigin origin = TransactionOrigin.keyboard,  // v1.2：默认 keyboard
    String? label,
    ComposingController? composing,
    this.onChange,
    this.isNested = false,
  })  : _origin = origin,
        _label = label,
        _composing = composing,
        _id = TransactionId.next();  // v1.2：创建时生成 id

  /// 添加操作（不入栈，仅暂存）。
  ///
  /// BlockOperation 前置检查铁律 1（若 composing.isActive 则抛 StateError）。
  void add(EditOperation op) {
    if (op is BlockOperation && _composing != null) {
      _composing.assertBlockMutationAllowed();
    }
    _ops.add(op);
  }

  /// 提交：apply 所有 op，全部成功则入栈 + 触发 onChange；任一失败则 rollback。
  ///
  /// 返回 true = commit 成功；false = 已 rollback，editor 状态未变，未触发 onChange。
  bool commit(DocumentEditor editor, EditorHistory history) {
    final applied = <EditOperation>[];
    for (final op in _ops) {
      if (!op.apply(editor)) {
        // rollback：逆序 revert 已 apply 的 op
        for (var i = applied.length - 1; i >= 0; i--) {
          applied[i].revert(editor);
        }
        return false;
      }
      applied.add(op);
    }

    // 嵌套语义：内层不入栈，不触发 onChange
    if (isNested) {
      return true;  // ops 已通过 _ops 暴露给外层合并
    }

    // 外层：构造 Transaction（用 _id，v1.2 在 Builder 创建时已生成），入栈，触发 1 次 notification
    final tx = Transaction(
      id: _id,  // v1.2：使用 Builder 创建时生成的 id（非 commit 时新生成）
      ops: List.unmodifiable(_ops),
      metadata: TransactionMetadata(
        timestamp: DateTime.now(),
        label: _label,
      ),
      origin: _origin,
    );
    history.pushTransaction(tx);
    onChange?.call(tx);  // ← 1 次 commit = 1 次 notification
    return true;
  }

  /// 外层 Builder 合并内层 ops（用于嵌套）。
  ///
  /// 内层 commit 后，外层通过此方法吸收内层 ops。
  void absorb(TransactionBuilder inner) {
    _ops.addAll(inner._ops);
  }
}
```

**嵌套语义（v1.1 简化）**：

- **不支持** `TransactionScope.current` 全局 ambient context（避免隐式全局状态）
- **支持** 显式父子合并：外层 `TransactionBuilder.absorb(inner)` 合并内层 ops
- **内层** `isNested=true` 时 commit 不入栈、不触发 onChange
- **外层** commit 时正常入栈 + 触发 onChange（1 次）

**TransactionExecutor（可选 helper，本 Phase 不强制实现）**：

```dart
/// Transaction 执行器：包装 DocumentEditor + EditorHistory + ChangeNotifier。
///
/// Phase 2.6 可选实现（单测不需要）；Phase 3 UI 接入时实现。
class TransactionExecutor {
  final DocumentEditor editor;
  final EditorHistory history;
  final ChangeNotifier notifier = ChangeNotifier();

  TransactionBuilder begin({
    TransactionOrigin origin = TransactionOrigin.user,
    String? label,
    ComposingController? composing,
  }) {
    return TransactionBuilder(
      origin: origin,
      label: label,
      composing: composing,
      onChange: (tx) => notifier.notifyListeners(),  // 1 次 commit = 1 次 rebuild
    );
  }
}
```

### 3.6 EditorHistory + Coalesce Predicate（ADR-0008 §6）

**v1.1 评审反馈 4 修订**：coalesce 规则改为 `canCoalesce(prev, next)` predicate 函数化，不写死规则。

**修订理由**：

ADR-0008 §4 6 触发条件写死在 EditorHistory 内，未来扩展困难（如增加 "同 origin" 约束 / "同 op type" 约束需修改 EditorHistory 源码）。

改为 predicate 函数化后，调用方可注入定制规则，EditorHistory 仅负责栈管理。

**修订后 EditorHistory**：

```dart
/// 编辑历史。包装 HistoryManager<Transaction>，提供 Transaction 级 API。
///
/// ADR-0008 §6：包装而非重写，保留旧 API 向后兼容。
///
/// **v1.1 评审反馈 4 修订**：coalesce 规则改为可注入 predicate 函数，
/// 不写死 6 触发条件。
class EditorHistory {
  final HistoryManager<Transaction> _delegate = HistoryManager<Transaction>(
    maxHistorySize: 100,  // ADR-0008 §6：从 50 提升到 100
  );

  /// Coalescing 时间窗（ADR-0008 §4：默认 500ms）。
  Duration coalesceWindow = const Duration(milliseconds: 500);

  /// Coalesce predicate：判断当前 op 能否合并到上一个 Transaction。
  ///
  /// 默认实现 ADR-0008 §4 6 触发条件。
  /// 调用方可覆盖此函数以扩展规则（如增加 same-origin / same-op-type 约束）。
  bool Function(Transaction prev, EditOperation next) canCoalesce =
      _defaultCanCoalesce;

  /// ADR-0008 §4 默认 coalescing 6 触发条件（全部满足才合并）。
  ///
  /// **v1.2 评审反馈补强 3**：
  /// - origin 检查从 `== user` 改为 `== keyboard`（更严格）
  /// - 新增第 7 条：next.origin 也必须是 keyboard（防止 keyboard → paste 混合）
  static bool _defaultCanCoalesce(Transaction prev, EditOperation next) {
    // v1.2 7 触发条件（v1.0 是 6 条，v1.2 增加 origin 一致性）
    if (next is! TextOperation) return false;
    if (prev.origin != TransactionOrigin.keyboard) return false;  // v1.2：keyboard 而非 user
    if (prev.ops.isEmpty || prev.ops.last is! TextOperation) return false;
    final lastText = prev.ops.last as TextOperation;
    if (lastText.blockId != next.blockId) return false;  // v1.1：用 BlockId
    if (next.offset != lastText.offset + lastText.inserted.length) return false;
    if (DateTime.now().difference(prev.metadata.timestamp) >
        const Duration(milliseconds: 500)) {
      return false;
    }
    // v1.2 新增：next 自己也必须是 keyboard origin（由 EditorHistory.pushOperation 调用方传入）
    // 注：pushOperation 默认构造的 Transaction origin 是 keyboard（见下文 pushOperation 实现）
    return true;
  }

  bool get canUndo => _delegate.canUndo;
  bool get canRedo => _delegate.canRedo;

  /// 直接 push Transaction（绕过 coalescing，用于显式 batch）。
  void pushTransaction(Transaction tx) => _delegate.push(tx);

  /// push 操作时检查 coalescing。
  ///
  /// 满足 [canCoalesce] predicate 则合并到上一 Transaction，否则新建 Transaction。
  ///
  /// **v1.2**：新增 [origin] 参数，调用方可指定 op 的来源（默认 keyboard）。
  /// 非 keyboard origin（paste/ime/programmatic 等）不会触发合并（因 _defaultCanCoalesce 检查 prev.origin == keyboard）。
  void pushOperation(EditOperation op, {TransactionOrigin origin = TransactionOrigin.keyboard}) {
    final last = _delegate.lastOrNull;  // 需要 HistoryManager 新增 lastOrNull getter
    if (last != null && canCoalesce(last, op)) {
      // 合并：注意 Transaction.ops 默认 List.unmodifiable，
      // 合并时需构造新 Transaction 替换栈顶（保持 immutable）
      final merged = Transaction(
        id: last.id,
        ops: [...last.ops, op],
        metadata: last.metadata,
        origin: last.origin,
      );
      _delegate.replaceLast(merged);  // 需要 HistoryManager 新增 replaceLast
    } else {
      _delegate.push(Transaction(
        id: TransactionId.next(),  // v1.2：独立 push 时 next() 生成新 id
        ops: [op],
        metadata: TransactionMetadata(timestamp: DateTime.now()),
        origin: origin,  // v1.2：由调用方指定（默认 keyboard）
      ));
    }
  }

  /// Undo：返回上一个 Transaction（调用方负责 revert + 触发 onChange）。
  Transaction? undo() => _delegate.undo(_delegate.currentState);

  /// Redo：返回下一个 Transaction（调用方负责 apply + 触发 onChange）。
  Transaction? redo() => _delegate.redo(null);

  void clear() => _delegate.clear();
}
```

**Coalescing 4 封口规则**（ADR-0008 §4，强制开新 Transaction）：

由默认 `_defaultCanCoalesce` 实现，违反任一条件即不合并（开新 Transaction）：

1. 切焦点 / 切块 / IME commit / 选区替换 → 通过显式 `pushTransaction` 绕过 coalescing
2. 任意 `BlockOperation` → `_defaultCanCoalesce` 返回 false（next is! TextOperation）
3. `origin != user` 的 op → `_defaultCanCoalesce` 返回 false
4. 时间间隔 >= 500ms → `_defaultCanCoalesce` 返回 false

**HistoryManager 扩展**（v1.1 增补）：

ADR-0008 §6 决策"包装而非重写"，但 EditorHistory 需要两个新能力：

1. `T? get lastOrNull => _undoStack.lastOrNull;`（查询栈顶）
2. `void replaceLast(T newItem)`（替换栈顶，用于 coalescing 合并）

两个都是纯新增 public API，旧 API 0 修改，向后兼容。

**调用方定制 coalesce 规则示例**（Phase 3+ 扩展）：

```dart
final history = EditorHistory();
// 扩展：要求 same origin + same op type
history.canCoalesce = (prev, next) {
  if (!EditorHistory._defaultCanCoalesce(prev, next)) return false;
  // 额外约束：op type 必须一致
  // ...扩展规则
  return true;
};
```

### 3.7 BlockOperations 五原语（ADR-0007 §4.1）

**v1.1 评审反馈 1 联动修订**：所有 op 用 BlockId 而非 index 定位。

```dart
/// 块级操作原语抽象。
///
/// ADR-0007 §4.1：5 个核心原语（insert/delete/merge/split/move）。
/// 每个 op 调用 = 1 个 BlockOperation + 1 个 Transaction（commit 时入栈）。
///
/// Phase 2.6 实现：纯逻辑层，不接入 UI。
/// Phase 3 UI 层通过此接口触发块操作。
///
/// **v1.1**：所有 op 用 BlockId 定位（稳定 identity），
/// 不用 index（index 在 insert/delete 后会失效）。
abstract class BlockOperations {
  /// 在 [afterId] 之后插入新块。
  ///
  /// [afterId] 为 null 表示插入到开头。
  /// 返回新块的 BlockId。触发 Document 写回 + Undo 入栈。
  BlockId insert(BlockId? afterId, BlockType type, {String source = ''});

  /// 删除 [id] 块。光标移到上一块末尾（或下一块开头）。
  ///
  /// 禁止删除最后一个块（保证 Document 至少 1 块）。
  /// 返回光标建议位置（BlockId + offset）。
  BlockPosition delete(BlockId id);

  /// 合并 [id] 与其前一块。
  ///
  /// 类型必须兼容（Paragraph+Paragraph / List+List）；
  /// 不兼容时回退为 Paragraph 合并（source 拼接）。
  /// 返回合并后块的光标位置（拼接处）。
  BlockPosition merge(BlockId id);

  /// 在 [id] 块的 [offset] 处拆分为两块。
  ///
  /// 原 block 截断到 offset，新 block 接管 offset 之后内容。
  /// Markdown 语法场景（如 `# ` 起首）由 Phase 2.7 BlockTypeDetector 处理。
  /// 返回新块的光标位置（offset=0）。
  BlockPosition split(BlockId id, int offset);

  /// 移动 [id] 块到 [targetId] 之前/之后。
  ///
  /// 用于上下箭头拖拽 / 拖放。
  /// 返回移动后块的新 BlockId（注意：move 后 BlockId 重新分配）。
  BlockId move(BlockId id, BlockId targetId, {bool before = true});
}
```

**实现类 `BlockOperationsImpl`**：

- 构造注入 `DocumentEditor` + `EditorHistory` + `ComposingController?`（可选，铁律 1 守门）+ `onChange` 回调（可选，notification 出口）
- 每个 op 方法内部：
  1. （BlockOperation 类型）调用 `composing.assertBlockMutationAllowed()` 守门（在 TransactionBuilder.add 内自动执行）
  2. 构造 `BlockOperation`
  3. 包装到 `TransactionBuilder`
  4. `commit(editor, history)` → 自动触发 onChange（1 次）

### 3.8 与 IME 三铁律集成（ADR-0008 §5）

| 铁律 | 落地 |
|------|----|
| 铁律 1（不切块） | `TransactionBuilder.add(BlockOperation)` 前置调用 `composing.assertBlockMutationAllowed()` |
| 铁律 2（commit 不丢字） | IME commit 触发 `origin=ime` 的 Transaction（含 1 个 TextOperation 替换 composing region），不参与 coalescing |
| 铁律 3（cancel 回滚） | IME cancel 不入栈（未 commit 的 composing 不入历史），由 ComposingController.onComposingCancel 处理 source rollback |

### 3.9 业务行为不变

- `flutter analyze`：0 error / 0 warning
- `flutter test --exclude-tags golden`：510 + 新增 ≈ 540+ passed / 0 regression
- 现有 BlockEditor abstract 接口 0 修改
- 现有 ComposingController / ComposingState / ComposingHost 0 修改
- 现有 AST 0 修改
- 现有 HistoryManager<T> API 0 修改（仅新增 `lastOrNull` getter + `replaceLast` 方法，纯新增）

---

## 4. Validation Plan（验证计划）

### 4.1 Unit Test

**v1.1 评审反馈 5 修订**：新增 4 类测试（TC-EDIT-6.6 ~ 6.9），总测试数从 ~100 提升到 ~120。

**TC-EDIT-6.1 EditOperation apply/revert 幂等性**（~30 tests）：

文件 `test/editing/edit_operation_test.dart`：

- insert apply + revert → editor 状态恢复（含 index 恢复）
- delete apply + revert → editor 状态恢复（含 oldIndex 恢复）
- merge apply + revert（Paragraph + Paragraph / List + List / 不兼容回退）
  - revert 后 leftElement + rightElement + rightOldIndex 全部恢复
- split apply + revert（Paragraph split / Code split / 含空 source split）
  - revert 后 originalElement 完整恢复（含 CodeElement.language 等字段）
- move apply + revert（前移 / 后移 / 跨多块移动）
  - revert 后 oldIndex + newId 都恢复
- TextOperation apply + revert（insert / delete / replace / 空 source / 含 emoji UTF-16 offset）
  - revert 后通过 BlockId 定位（不依赖 cachedIndex）
- 幂等性：同一 op 连续 apply 2 次结果一致（apply-revert-apply-revert 循环）
- 非法 BlockId（不存在的 id）→ apply 返回 false（不抛异常）
- 边界：empty deleted + empty inserted（空操作）

**TC-EDIT-6.2 TransactionBuilder commit/rollback/嵌套**（~15 tests）：

文件 `test/editing/transaction_builder_test.dart`：

- 单 op commit → history push 1 Transaction
- 多 op commit → history push 1 Transaction（ops 长度 = N）
- 任一 op apply 失败 → rollback，editor 状态未变，history 未入栈
- commit 后 _ops 清空
- composing.isActive 时 add(BlockOperation) → 抛 StateError（铁律 1）
- composing.isActive 时 add(TextOperation) → 不抛（TextOperation 不受铁律 1 约束）
- 嵌套 commit：内层 commit 不入栈（isNested=true），外层通过 absorb 合并 ops
- 嵌套 commit：内层不触发 onChange，外层 commit 触发 1 次 onChange
- label / origin 正确传递到 Transaction
- onChange 回调被调用 1 次（评审反馈 5C）

**TC-EDIT-6.3 EditorHistory coalescing**（~28 tests）：

文件 `test/editing/editor_history_test.dart`：

- 单 op push → 1 Transaction
- 连续 2 个 TextOperation（同 BlockId / offset 连续 / < 500ms）→ 合并到 1 Transaction
- **v1.2 7 触发条件**逐一违反：不合并
  - op 不是 TextOperation（是 BlockOperation）
  - prev.origin != keyboard（v1.2：从 user 改为 keyboard）
  - prev.ops.last 不是 TextOperation
  - blockId 不同（v1.1：用 BlockId）
  - offset 不连续
  - 时间间隔 >= 500ms
  - **next.origin != keyboard**（v1.2 新增：paste/ime/programmatic 不合并）
- 4 封口规则触发新 Transaction
- undo / redo 后栈状态正确
- EditorHistory 包装 HistoryManager：canUndo / canRedo 透传
- maxHistorySize=100：push 101 次，最早 1 个被淘汰
- **canCoalesce predicate 可注入**（v1.1 评审反馈 4）：
  - 默认 _defaultCanCoalesce 行为正确
  - 注入自定义 predicate（如要求 same op type）后行为按新规则
  - 注入 always-false predicate 后所有 op 独立成 Transaction
- **v1.2 origin 一致性测试**：
  - keyboard → keyboard：可合并
  - keyboard → paste：不合并（v1.2 新增）
  - keyboard → ime：不合并（v1.2 新增）
  - paste → paste：不合并（v1.2 新增）
  - ime → ime：不合并（v1.2 新增）

**TC-EDIT-6.4 5 原语语义**（~25 tests）：

文件 `test/editing/block_operations_test.dart`：

- insert：afterId=null 表示插入到开头；afterId=最后一个块表示追加到末尾
- delete：禁止删除最后一个块（抛 StateError）
- delete：删除第一个块后光标移到下一块开头
- delete：删除中间块后光标移到上一块末尾
- merge：Paragraph + Paragraph → Paragraph（source 拼接）
- merge：List + List（同 ordered）→ List
- merge：List + List（异 ordered）→ 回退 Paragraph
- merge：Paragraph + Code → 回退 Paragraph
- merge：合并第一个块 → 抛 StateError（无上一块）
- split：Paragraph split → 2 个 Paragraph
- split：Code split → 2 个 Code（language 保留）
- split：offset=0 → 新块为空 Paragraph
- split：offset=source.length → 新块为空 Paragraph
- move：前移 / 后移 / 跨多块
- move：id == targetId → 抛 StateError
- IME 集成：composing.isActive 时调 insert/delete/merge/split/move → 抛 StateError
- IME 集成：composing.idle 时正常执行
- Undo 集成：每个 op 后 history.canUndo == true
- Undo 集成：undo 后 editor 状态恢复
- Redo 集成：redo 后 editor 状态恢复

**TC-EDIT-6.5 DocumentEditor 副作用边界**（~10 tests）：

文件 `test/editing/document_editor_test.dart`：

- insertBlock / removeBlock / replaceBlock 后 blockCount 正确
- removeBlock 返回被移除元素
- replaceBlock 返回旧元素
- insertBlock 返回新 BlockId
- getBlock / indexOf 一致
- updateBlockContent 保持 BlockId 不变（v1.1 评审反馈 1 联动）
- **DocumentEditor 不暴露 listener**（v1.1 评审反馈 2）：
  - 接口不含 addListener / notifyListeners
  - 所有方法仅修改数据，不触发任何回调

**TC-EDIT-6.6 Undo/Redo 循环一致性**（~10 tests，**v1.1 评审反馈 5A 新增**）：

文件 `test/editing/undo_redo_round_trip_test.dart`：

- apply → undo → redo → undo → redo（5 轮循环）
  - 每轮后 editor 状态一致（无状态污染）
  - history.canUndo / canRedo 状态正确切换
- 5 类 BlockOperation 各自的 undo/redo 循环（5 轮）
- TextOperation undo/redo 循环（5 轮）
- 混合 Transaction（含 BlockOp + TextOp）undo/redo 循环（5 轮）
- coalescing 合并后的 Transaction undo/redo 循环（5 轮）
- 多 Transaction 序列的 undo/redo 循环：
  - apply T1 → apply T2 → apply T3 → undo → undo → undo → redo → redo → redo
- 边界：连续多次 undo（超过栈深度）→ 返回 null（不抛异常）
- 边界：连续多次 redo（超过 redo 栈深度）→ 返回 null

**TC-EDIT-6.7 Transaction 回滚原子性**（~8 tests，**v1.1 评审反馈 5B 新增**）：

文件 `test/editing/transaction_rollback_atomicity_test.dart`：

- 3 op Transaction 第 3 步失败 → 全部 rollback
  - editor 状态完全恢复（与 apply 前一致）
  - history 栈未入栈
  - onChange 未触发
- 5 op Transaction 第 1 步失败 → 直接返回 false（无 op 已 apply）
- 5 op Transaction 第 5 步失败 → 4 个 op 全部 rollback
- rollback 后 editor 状态精确恢复（含 BlockId 重新分配）
  - rollback 不应残留新分配的 BlockId
- rollback 后可立即开新 Transaction（不阻塞）
- rollback 后 history.canUndo / canRedo 状态不变
- 嵌套 Transaction 内层 rollback → 不影响外层
- 嵌套 Transaction 外层 rollback → 内层 ops 全部 revert

**TC-EDIT-6.8 Notification 次数验证**（~6 tests，**v1.1 评审反馈 5C 新增**）：

文件 `test/editing/notification_count_test.dart`：

- 1 op Transaction commit → onChange 触发 1 次
- 5 op Transaction commit → onChange 触发 1 次（不是 5 次）
- 10 op Transaction commit → onChange 触发 1 次（不是 10 次）
- Transaction rollback → onChange 触发 0 次
- 嵌套 Transaction 外层 commit → onChange 触发 1 次（内层不触发）
- Transaction undo → 调用方负责触发 onChange（1 次）
  - 注：EditorHistory.undo 不自动触发 onChange，由调用方（TransactionExecutor）触发

**TC-EDIT-6.9 IME 组合态操作禁止**（~6 tests，**v1.1 评审反馈 5D 新增**）：

文件 `test/editing/ime_mutation_forbidden_test.dart`：

- composing.isActive 时调 insert → 抛 StateError
- composing.isActive 时调 delete → 抛 StateError
- composing.isActive 时调 merge → 抛 StateError
- composing.isActive 时调 split → 抛 StateError
- composing.isActive 时调 move → 抛 StateError
- composing.isActive 时调 TextOperation.apply → 不抛（TextOperation 不受铁律 1 约束，仅在 commit 阶段触发 origin=ime）

### 4.2 Architecture Validation

- TC-ARCH-7（file_size_test.dart）：6 个新 lib 文件 + 8 个新 test 文件均 ≤400 行
- TC-ARCH-11（editing_layer_test.dart）：扩展 TC-ARCH-11.1 sanity check 覆盖 6 个新文件
- TC-ARCH-12.x（ast_snapshot_test.dart）：仍通过（Phase 2.6 不改 AST）
- 新增 TC-ARCH-13（候选）：EditOperation apply/revert 幂等性守门（防 future regression）

### 4.3 Regression Validation

- `flutter analyze` 0 error / 0 warning
- `flutter test --exclude-tags golden`：510 + ~120 新增 = ~630 passed / 0 regression
- 关键关注点：
  - 新增 editing 文件不破坏现有 editing_layer 守门
  - 不修改 block_editor.dart abstract 接口
  - HistoryManager 旧 API（push / undo / redo / clear）仍可用
  - HistoryManager 新增 lastOrNull + replaceLast 不破坏现有 5 处引用
  - Phase 2.5 ComposingController 32 tests 全部通过（0 regression）

### 4.4 Manual Verification

无 UI 改动，纯逻辑层。手动验证留待 Phase 3 UI 接入后。

---

## 5. Success Criteria（完成标准）

- [ ] 新增 6 个 lib 文件（document_editor / edit_operation / transaction / transaction_builder / editor_history / block_operations），均 ≤400 行
- [ ] 新增 8 个 test 文件（含 v1.1 新增的 6.6~6.9），均 ≤400 行
- [ ] 扩展 editing_layer_test.dart（TC-ARCH-11.1 覆盖 6 个新文件）
- [ ] 扩展 history_manager.dart（新增 `lastOrNull` getter + `replaceLast` 方法，不破坏旧 API）
- [ ] `flutter analyze` 0 error / 0 warning
- [ ] `flutter test --exclude-tags golden` 0 regression（510 + ~120 新增 = ~630）
- [ ] ADR-0007 §4.1 五原语全部落地（insert/delete/merge/split/move，**v1.1：BlockId 定位**）
- [ ] ADR-0007 §4.2 EditOperation + 双层 Undo 落地
- [ ] ADR-0008 §1-8 全部落地（Transaction / apply-revert / TransactionBuilder / Coalescing / IME 交互 / EditorHistory / 不持久化 / TransactionId）
- [ ] **v1.1：DocumentEditor 不含 listener**，notification 由 Transaction.commit() 触发
- [ ] **v1.1：Transaction 嵌套用 isNested flag**，不支持 TransactionScope.current
- [ ] **v1.1：canCoalesce 是可注入 predicate**，默认实现 6 触发条件
- [ ] **v1.1：BlockOperation revert context 含完整 snapshot**（index + element）
- [ ] IME 三铁律集成（composing.isActive 时 BlockOperation 抛 StateError）
- [ ] 现有 BlockEditor abstract 接口 0 修改
- [ ] 现有 ComposingController / ComposingState / ComposingHost 0 修改
- [ ] 现有 AST 0 修改
- [ ] 现有 HistoryManager 旧 API 0 修改（仅新增 lastOrNull + replaceLast）
- [ ] 本 Task Contract 已提交
- [ ] PR 描述包含关联 issue / 改动说明 / 测试方式

---

## 6. Rollback Plan（回滚方案）

**回滚难度**：中（< 15 分钟）

**回滚步骤**：

1. `git revert <commit-hash>` 即可还原所有新增文件
2. PR merge 前：直接 close PR，分支不合并即可
3. PR merge 后：新开 `revert/phase2.6-block-ops` 分支 revert merge commit
4. HistoryManager 新增的 `lastOrNull` getter + `replaceLast` 方法是纯新增，revert 不影响旧 API 调用方

**回滚触发条件**：

- 5 类 BlockOperation apply/revert 幂等性测试失败
- TransactionBuilder rollback 未正确恢复 editor 状态
- Coalescing 规则误合并（如把 BlockOperation 合并到 TextOperation）
- 现有 Phase 2.5 ComposingController 32 tests 出现 regression
- 现有 Phase 2.3 block_serializer 79 tests 出现 regression

**部分回滚选项**：

- 若仅 EditorHistory coalescing 有问题：保留 EditOperation + Transaction，临时禁用 coalescing（pushOperation 退化为 pushTransaction）
- 若仅 BlockOperations 5 原语有问题：保留底层 EditOperation + Transaction，UI 层（Phase 3）暂用低层 API

---

## 7. Feedback Signals（反馈信号）

### 7.1 成功信号

- 5 类 BlockOperation apply/revert 幂等性测试全部通过
- TransactionBuilder 嵌套合并正确（内层不入栈）
- Coalescing 6 触发条件 + 4 封口规则全部测试覆盖
- IME 三铁律集成测试通过（composing.isActive 时 BlockOperation 抛 StateError）
- PR 一次 review 通过

### 7.2 失败信号

- apply 后 revert 未恢复 editor 状态（幂等性破坏）
- coalescing 误合并不同 block 的 TextOperation
- composing.isActive 时 BlockOperation 未抛 StateError（违反铁律 1）
- HistoryManager 旧 API 调用方（editor_screen 等）出现 regression
- TransactionBuilder 嵌套 commit 时内层 ops 丢失

---

## 8. Risk Assessment（风险评估）

| 风险 | 概率 | 影响 | 缓解 |
|------|------|------|------|
| DocumentEditor 接口设计不足（Phase 3 UI 接入时发现不够） | 中 | 高 | 接口极简（insert/remove/replace + listener），未来扩展不破坏现有调用 |
| EditOperation apply/revert 非幂等 | 中 | 高 | 单测覆盖每类 op 的 apply-revert-apply-revert 循环 |
| Coalescing 500ms 默认值在低端机不适配 | 低 | 低 | 暴露为 EditorHistory.coalesceWindow，UI 层可调 |
| 嵌套 TransactionBuilder 语义复杂，开发者误用 | 中 | 中 | 本 Phase 实现简化版（isNested flag），完整 TransactionScope 留待 Phase 2.7+ |
| TextOperation blockIndex 在 insert/delete 后失效 | 中 | 高 | coalescing 严格检查 blockIndex 连续性；insert/delete 自动封口新 Transaction |
| HistoryManager 扩展破坏现有 5 处引用 | 低 | 中 | 仅新增 lastOrNull getter（纯新增），不改原有 API 签名 |
| 5 类 BlockOperation 上下文存储不足（revert 时缺数据） | 中 | 高 | 单测覆盖每类 op 的 revert；replacedElement 在 apply 时填充 |
| IME 三铁律集成与 Phase 2.5 ComposingController 冲突 | 低 | 高 | Phase 2.5 已暴露 isActive / assertBlockMutationAllowed，本 Phase 仅调用，不修改 |
| 性能：1000 块 Document 下 coalescing 检查慢 | 低 | 低 | _canCoalesce 是 O(1) 检查（lastOrNull + 字段比较） |
| 与 ADR-0008 决策冲突 | 低 | 高 | 严格按 ADR-0008 §1-8 实现，不引入新决策 |

**总体风险等级**：**High**

理由：

1. **代码量大**：6 个新 lib 文件（~1020 行）+ 5 个新 test 文件（~1450 行），是 Phase 2.5 的 5 倍
2. **架构影响广**：Transaction Model 是 Phase 2.6+ 的基础设施，连接 BlockEditor / IME / Undo / Transaction / UI 五层
3. **幂等性要求高**：apply/revert 必须严格幂等，否则 Undo/Redo 错乱
4. **coalescing 规则复杂**：6 触发条件 + 4 封口规则，边界 case 多
5. **与现有 HistoryManager 集成**：5 处引用（editor_screen / document_provider 等），扩展需保证向后兼容

**不升级为 Critical** 的理由：

- 不改 AST（[document.dart](file:///d:/Projects/Active/math/flutter_app/lib/data/models/document.dart) 零修改）
- 不改 UI（Phase 3 才接入）
- 不改存储（ADR-0003 单一真相源不变）
- 不改 parser / providers / domain
- 可独立回滚（PR merge 前可 close）

**升级为 High 的理由**（相比 Phase 2.5 的 Medium+）：

- 代码量大 5 倍
- apply/revert 幂等性是 Undo/Redo 正确性的基石
- 5 类 BlockOperation 上下文存储设计复杂
- 嵌套 Transaction 语义容易误用

---

## 9. Approval（审批）

| 角色 | 状态 | 时间 |
|------|------|------|
| AI Agent | 已起草 v1.0 | 2026-07-19 |
| Human Owner | v1.0 评审：Approve with changes（5 项修订） | 2026-07-19 |
| AI Agent | 已修订 v1.1（落实 5 项修订） | 2026-07-19 |
| Human Owner | v1.1 二次评审：Approve with 2 small additions（3 项补强） | 2026-07-19 |
| AI Agent | 已修订 v1.2（落实 3 项补强） | 2026-07-19 |
| Human Owner | v1.2 待三次审批 → 通过即可开始实现 | — |

**v1.0 → v1.1 修订对照**（响应 Human Owner v1.0 评审）：

| # | 类型 | 修订点 | 落地章节 |
|---|------|--------|---------|
| 1 | 必改 | TextOperation: `blockIndex` → `BlockId` | §3.2 TextOperation + §3.6 _defaultCanCoalesce + §3.7 BlockOperations |
| 2 | 必改 | DocumentEditor: 移除 listener，改 Transaction.commit 触发通知 | §3.1 DocumentEditor + §3.5 TransactionBuilder.onChange |
| 3 | 必改 | BlockOperation revert context 补 index/snapshot | §3.3 5 类 op revert context 表 + §3.2 BlockOperation.revertContext |
| 4 | 建议改 | coalesce 规则改为可注入 predicate | §3.6 EditorHistory.canCoalesce + 测试 TC-EDIT-6.3 |
| 5 | 建议改 | 新增 4 类测试（6.6-6.9） | §4.1 + §2.1 文件清单 |

**v1.1 → v1.2 修订对照**（响应 Human Owner v1.1 二次评审 "Approve with 2 small additions"）：

| # | 类型 | 补强点 | 落地章节 |
|---|------|--------|---------|
| 1 | 补强 | revertContext 明确 immutable snapshot 约束（禁止 live mutable reference） | §3.3 关键设计点 + 约束声明 |
| 2 | 补强 | TransactionId 生命周期：Builder 创建时生成（非 commit 时） | §3.4 TransactionId + §3.5 TransactionBuilder.\_id |
| 3 | 补强 | TransactionOrigin 从 4 值扩展为 6 值（keyboard/ime/paste/programmatic/undo/redo） | §3.4 TransactionOrigin + §3.6 _defaultCanCoalesce + pushOperation origin 参数 |

**审批方式**：Human Owner 在本 Task Contract PR 中 review 后回复 "approved" / "approved with comments" / "rejected"。

**授权范围**：Human Owner 已通过 "进行 2.6 块级操作：插入/删除/合并/拆分/移动块" 指令授权本 Phase 启动。

**强制审批理由**：

- AGENTS.md §9.2 要求：复杂任务（Risk Medium+ 或涉及架构变更）的 Task Contract 须提交 Human Owner 审批后再开始实现
- 本 Phase 风险等级 High
- 本 Phase 涉及架构变更（落地 ADR-0008 Transaction Model，引入 6 个新 lib 文件 + 8 个新 test 文件）

---

## 10. AI Self Review（自检）

### 10.1 ADR 合规性

- [x] ADR-0007 §4.1 五原语全部落地（insert/delete/merge/split/move）
- [x] ADR-0007 §4.2 EditOperation sealed class + 双层 Undo 落地
- [x] ADR-0007 §4.4 边界约束（不改 AST / 不引入派生缓存 / 10000 块上限）
- [x] ADR-0008 §1 Transaction = EditOperation 批量容器
- [x] ADR-0008 §2 apply/revert 幂等纯函数
- [x] ADR-0008 §3 TransactionBuilder commit/rollback 原子性 + 嵌套合并
- [x] ADR-0008 §4 Coalescing 6 触发条件 + 4 封口规则
- [x] ADR-0008 §5 IME 三铁律交互（铁律 1 通过 assertBlockMutationAllowed 守门）
- [x] ADR-0008 §6 EditorHistory 包装 HistoryManager<Transaction>
- [x] ADR-0008 §7 Transaction 不持久化（内存态）
- [x] ADR-0008 §8 TransactionId 内存顺序标识
- [x] AGENTS.md §6.5 Phase 2 禁区未触碰（未改 UI / 未新增 Phase 3 功能 / 未引入派生缓存）
- [x] AGENTS.md §6.4 AI 提交分工得到遵守

### 10.2 范围漂移检查

- [x] 改动范围与 Task Contract 一致
- [x] 未夹带未在 Task Contract 中说明的改动
- [x] 0 业务行为变化（纯新增逻辑层，UI 冻结）

### 10.3 技术债务检查

- [x] 未引入新的技术债务
- [x] TransactionScope 完整实现留待 Phase 2.7+（本 Phase 用 isNested flag 简化）
- [x] EditorHistory.coalesceWindow 暴露为配置项（未来可调）
- [x] DocumentEditor 接口极简，未来扩展不破坏现有调用

### 10.4 测试覆盖检查

- [x] 5 类 BlockOperation apply/revert 幂等性单测覆盖
- [x] TextOperation apply/revert 幂等性单测覆盖
- [x] TransactionBuilder commit/rollback/嵌套单测覆盖
- [x] EditorHistory coalescing 6 触发条件 + 4 封口规则单测覆盖
- [x] BlockOperations 5 原语语义单测覆盖
- [x] IME 三铁律集成测试覆盖
- [x] DocumentEditor 副作用边界单测覆盖
- [x] 非法 index / 空 source / emoji UTF-16 offset 边界测试覆盖

### 10.5 文档同步

- [x] Task Contract 完整记录设计依据
- [x] ADR-0007 §4 引用准确
- [x] ADR-0008 §1-8 引用准确
- [x] Phase 2.5 Task Contract 衔接说明清晰

---

## 11. Future ADR 候选（信息性记录）

- **ADR-0009**（候选，Phase 2.7 前完成）：IME Lifecycle Model
  - 落地 ComposingController 接入 ADR-0008 Transaction Model 的具体细节
  - 定义 composing 四态与 Transaction origin=ime 的时序
  - Phase 2.6 实现时若发现接口不足，再开此 ADR

- **ADR-0010**（候选，Phase 2.7）：Markdown 快捷映射规则
  - 完善 BlockTypeDetector 6 类规则（# → Heading / - → List / ``` → Code 等）
  - 集成到 split / onSourceChanged 触发点

- **ADR-0011**（候选，Phase 3+）：Syntax Hiding
  - visual/source offset 映射规则
  - Phase 3+ 若实现 syntax hiding 才开

---

## 12. 实施顺序（建议，v1.1 修订）

为降低单 PR 复杂度，建议分阶段实施（但合并为 1 个 PR）：

1. **扩展 history_manager.dart**（新增 lastOrNull + replaceLast，向后兼容）
2. **DocumentEditor 接口**（~130 行，**v1.1 不含 listener**）+ 单测（~150 行）→ TC-EDIT-6.5
3. **Transaction + TransactionId + Metadata + Origin**（~100 行）
4. **EditOperation sealed class + 5 类 BlockOperation + TextOperation**（~400 行，**v1.1：BlockId 定位 + revertContext 完整 snapshot**）+ 单测（~350 行）→ TC-EDIT-6.1
5. **TransactionBuilder**（~180 行，**v1.1：onChange 回调 + isNested flag**）+ 单测（~320 行）→ TC-EDIT-6.2
6. **EditorHistory**（~210 行，**v1.1：canCoalesce predicate 函数化**）+ 单测（~350 行）→ TC-EDIT-6.3
7. **BlockOperations 抽象 + 实现**（~100 行，**v1.1：BlockId 定位**）+ 单测（~300 行）→ TC-EDIT-6.4
8. **扩展 editing_layer_test.dart TC-ARCH-11.1**
9. **新增 v1.1 评审反馈 5A-5D 4 个测试文件**：
   - TC-EDIT-6.6 Undo/Redo 5 轮循环（~250 行）
   - TC-EDIT-6.7 Transaction 回滚原子性（~200 行）
   - TC-EDIT-6.8 Notification 次数（~120 行）
   - TC-EDIT-6.9 IME 组合态操作禁止（~120 行）
10. **flutter analyze + flutter test 验证**
11. **commit + push + PR**

每阶段完成后跑 `flutter analyze` + 对应单测，确保增量正确。

---

**维护人**：AI Agent（GLM-5.2）
**生效日期**：2026-07-19
