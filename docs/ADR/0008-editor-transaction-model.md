# ADR-0008：Editor Transaction Model

**状态**：Proposed
**日期**：2026-07-19
**决策者**：AI Agent（GLM-5.2）起草，Human Owner 审批

---

## 背景

### 当前状态

Phase 2.4 已完成（PR #30 合并，commit `2f718dd`），AST 在 Phase 2 保持稳定。
即将进入 Phase 2.5（IME 兼容）与 Phase 2.6（块级操作原语）。

### 待决问题

[ADR-0007 §4.2](file:///d:/Projects/Active/math/docs/ADR/0007-blockeditor-abstraction-design.md)
已定义 `EditOperation` sealed class 联合类型骨架（`BlockOperation` + `TextOperation`），
但只描述了 **数据结构形状**，未落地以下关键问题：

1. **原子性边界**：`split` 后立即 `insert`（如 `\n\n` 创建空段落）算 1 个 Undo
   单元，但 `beginBatch() / endBatch()` 的语义、嵌套、错误回滚未定义
2. **应用方向**：操作日志（operation log）需要反向应用，但反向应用的状态来源
   与副作用边界未明确（如何避免反向应用时再次触发 `setState` 风暴）
3. **与 IME 的交互**：Phase 2.5 ComposingRegion 三条铁律下，commit 阶段如何
   批量封口 TextOperation、cancel 阶段如何回滚未封口操作，未定义
4. **与 HistoryManager 的关系**：现有 [history_manager.dart](file:///d:/Projects/Active/math/flutter_app/lib/core/utils/history_manager.dart)
   是泛型 `<T>` 状态快照栈（`maxHistorySize=50`），Phase 2.6 需要"扩展为支持
   `EditOperation` 联合类型"。扩展是 **重写还是包装**？状态快照与操作日志如何共存？
5. **序列化与持久化**：Transaction 是否需要跨 session 持久化？`.md` 文件作为
   单一真相源（ADR-0003）下，Transaction 是否仅内存态？
6. **复合操作语义**：`split` + `insert` + `update source` 这种复合操作的事务边界
   是显式 `beginBatch/endBatch`，还是隐式时间窗（如 500ms）？

### 现有约束

- [ADR-0007 §4.2](file:///d:/Projects/Active/math/docs/ADR/0007-blockeditor-abstraction-design.md)
  已定义 `EditOperation` sealed class 骨架（不可推翻，本 ADR 仅扩展细节）
- [ADR-0003](file:///d:/Projects/Active/math/docs/ADR/0003-storage-single-source-md-files.md)
  `.md` 文件作为单一真相源，Transaction 不得引入第五套持久化存储
- [AGENTS.md §6.5](file:///d:/Projects/Active/math/AGENTS.md) Phase 2 禁区：
  UI 行为冻结，Transaction Model 必须能脱离 UI 独立运行（纯 Dart 逻辑）
- [history_manager.dart](file:///d:/Projects/Active/math/flutter_app/lib/core/utils/history_manager.dart)
  现有 50 上限泛型栈，5 处引用（editor_screen / document_provider 等）

### 触发本 ADR 的事件

Phase 2.4 Task Contract §11 评审反馈记录：

> ADR-0008（候选，Phase 2.5 前完成）：Transaction Model
> BlockOperation + TextOperation 双层 Undo 的统一接口
> Phase 2.6 会遇到 Text Change 与 Block Operation 必须统一的需求，
> 建议 Phase 2.5 前完成 ADR。

Human Owner 于 2026-07-19 明确授权："先开 ADR-0008 Transaction Model"。

---

## 决策

### 1. Transaction = EditOperation 的批量容器

**采用"显式 Transaction + 隐式时间窗"混合模型**：

```dart
/// 编辑事务。一个 Transaction = 一组原子可逆的 EditOperation。
///
/// 对应 ADR-0007 §4.2 的 `beginBatch() / endBatch()`，本 ADR 落地语义：
/// - 原子性：Transaction 内所有 op 要么全部应用，要么全部回滚
/// - 可逆性：Transaction 是 Undo/Redo 的最小单元（1 Transaction = 1 Ctrl+Z）
/// - 嵌套：内层 Transaction 合并到最近外层（不独立成 Undo 单元）
@immutable
class Transaction {
  final TransactionId id;          // 顺序自增，用于调试
  final List<EditOperation> ops;   // 顺序敏感
  final TransactionMetadata metadata;
  final TransactionOrigin origin;  // user / system / ime / undo-redo
}

/// 操作来源。决定是否入栈、是否触发 listener、是否可被 coalesce。
enum TransactionOrigin {
  user,        // 用户输入 / 快捷键
  system,      // 程序修改（如格式化）
  ime,         // IME commit（Phase 2.5 接入）
  undoRedo,    // undo/redo 自身（不入栈，避免无限递归）
}

@immutable
class TransactionMetadata {
  final DateTime timestamp;
  final String? label;  // 用户可读标签，如 "输入 'hello'" / "拆分块"
}
```

**Undo 单元 = Transaction**，不再是单条 `EditOperation`。

### 2. 应用模型：前向应用 + 反向应用

**决策**：操作日志（Operation Log）模式，每条 `EditOperation` 实现两个方法：

```dart
sealed class EditOperation {
  /// 前向应用：修改 Document 状态，返回是否成功。
  bool apply(DocumentEditor editor);

  /// 反向应用：恢复到 apply 前的状态。
  void revert(DocumentEditor editor);
}

class BlockOperation extends EditOperation {
  final BlockOpType opType;    // insert / delete / merge / split / move
  final BlockId targetId;
  final BlockPosition cursorBefore;
  final BlockPosition cursorAfter;
  final Map<String, Object?> context;  // 反向应用所需的上下文（如 deleted block 的 source）

  @override
  bool apply(DocumentEditor editor) { /* 前向修改 editor */ }

  @override
  void revert(DocumentEditor editor) { /* 用 context 反向恢复 */ }
}

class TextOperation extends EditOperation {
  final BlockId blockId;
  final int offset;
  final String deleted;   // 被删除文本（revert 时恢复）
  final String inserted;  // 插入文本（revert 时删除）

  @override
  bool apply(DocumentEditor editor) { /* 前向修改 */ }

  @override
  void revert(DocumentEditor editor) { /* 反向：先删 inserted，再插 deleted */ }
}
```

**关键约束**：

- `apply` / `revert` 必须是**幂等纯函数**（不依赖外部可变状态）
- 所有状态修改必须通过 `DocumentEditor` 接口，不直接操作 AST
- 副作用（如通知 UI / 写文件）由 `DocumentEditor` 统一发出，避免反向应用时再次触发 `setState` 风暴

### 3. 原子性：Transaction 级 commit / rollback

**决策**：Transaction 用 `commit()` / `rollback()` 显式控制：

```dart
class TransactionBuilder {
  final List<EditOperation> _ops = [];
  final TransactionOrigin _origin;
  final String? _label;

  /// 添加操作（不入栈，仅暂存）。
  void add(EditOperation op) => _ops.add(op);

  /// 提交：apply 所有 op，全部成功则入栈；任一失败则 rollback。
  ///
  /// 返回 true = commit 成功；false = 已 rollback，editor 状态未变。
  bool commit(DocumentEditor editor, HistoryManager history) {
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
    history.pushTransaction(Transaction(
      id: TransactionId.next(),
      ops: _ops,
      metadata: TransactionMetadata(
        timestamp: DateTime.now(),
        label: _label,
      ),
      origin: _origin,
    ));
    return true;
  }
}
```

**嵌套语义**：

- 内层 `TransactionBuilder.commit()` 不入栈，把 ops 合并到外层
- 外层 `commit()` 入栈
- 用 `TransactionScope.current` 检测是否在嵌套上下文中

### 4. 隐式时间窗：Coalescing

**决策**：用户连续字符输入用 **coalescing**（合并）而非 batch，避免显式 `beginBatch` 污染调用方。

```dart
class HistoryManager {
  Duration coalesceWindow = const Duration(milliseconds: 500);

  /// push 操作时检查：若上一 Transaction 满足 coalesce 条件，则合并到上一 Transaction。
  void push(EditOperation op) {
    final last = _undoStack.lastOrNull;
    if (last != null && _canCoalesce(last, op)) {
      last.ops.add(op);  // 合并到上一 Transaction
    } else {
      _undoStack.add(Transaction(ops: [op], ...));
    }
  }

  bool _canCoalesce(Transaction last, EditOperation op) {
    if (op is! TextOperation) return false;
    if (last.origin != TransactionOrigin.user) return false;
    if (last.ops.last is! TextOperation) return false;
    final lastText = last.ops.last as TextOperation;
    if (lastText.blockId != op.blockId) return false;
    if (op.offset != lastText.offset + lastText.inserted.length) return false;
    if (DateTime.now().difference(last.metadata.timestamp) > coalesceWindow) {
      return false;
    }
    return true;
  }
}
```

**Coalesce 触发条件**（全部满足才合并）：

1. 当前 op 是 `TextOperation`
2. 上一 Transaction origin = `user`
3. 上一 Transaction 最后一条 op 是 `TextOperation`
4. 同一 blockId
5. offset 连续（前一条 inserted 尾部 = 当前 offset）
6. 时间间隔 < 500ms

**Coalesce 封口**（强制开新 Transaction）：

- 切焦点 / 切块 / IME commit / 选区替换
- 任意 `BlockOperation` 插入
- `origin != user` 的 op

### 5. 与 IME 三铁律的交互（Phase 2.5 预留接口）

[ADR-0007 §3.2](file:///d:/Projects/Active/math/docs/ADR/0007-blockeditor-abstraction-design.md)
IME 三铁律：

1. 组合态中间不切块
2. commit 时不丢字
3. cancel 时回滚

**本 ADR 落地**：

- **铁律 1（不切块）**：composing.isActive 时禁止 `BlockOperation.split`。
  `TransactionBuilder.add(BlockOperation.split)` 在 composing 态抛 `StateError`
- **铁律 2（commit 不丢字）**：IME commit 触发 `origin=ime` 的 Transaction，
  包含 1 个 `TextOperation`（替换 composing region）。`coalesceWindow` 对
  `origin=ime` 不生效（IME commit 必须独立成单元）
- **铁律 3（cancel 回滚）**：IME cancel 不入栈（未 commit 的 composing 不入历史）。
  composing region 本身是 ephemeral 状态，commit 时才转 Transaction

### 6. HistoryManager 扩展策略：包装而非重写

**决策**：新建 `EditorHistory` 包装现有 `HistoryManager<Transaction>`，保留旧 API 用于
向后兼容（[history_manager.dart](file:///d:/Projects/Active/math/flutter_app/lib/core/utils/history_manager.dart)
5 处引用不破坏）。

```dart
/// Phase 2.6+ 编辑历史。包装 HistoryManager<Transaction>，提供 Transaction 级 API。
class EditorHistory {
  final HistoryManager<Transaction> _delegate = HistoryManager<Transaction>(
    maxHistorySize: 100,  // Phase 2.6 调优：从 50 提升到 100
  );

  Duration coalesceWindow = const Duration(milliseconds: 500);

  bool get canUndo => _delegate.canUndo;
  bool get canRedo => _delegate.canRedo;

  void push(EditOperation op) { /* §4 coalescing 逻辑 */ }

  void pushTransaction(Transaction tx) => _delegate.push(tx);

  Transaction? undo() {
    final last = _delegate.undo(null);  // currentState 不需要，op log 模式
    return last;
  }

  Transaction? redo() => _delegate.redo(null);

  void apply(Transaction tx, DocumentEditor editor) {
    for (final op in tx.ops) {
      op.apply(editor);
    }
  }

  void revert(Transaction tx, DocumentEditor editor) {
    for (var i = tx.ops.length - 1; i >= 0; i--) {
      tx.ops[i].revert(editor);
    }
  }
}
```

**理由**：

- 现有 `HistoryManager<T>` 是泛型状态快照栈，Transaction 也是 `<T>` 的一种
- 包装而非重写：保留现有 5 处引用，避免 Phase 2.6 改动外溢到 editor_screen 等
- `maxHistorySize` 从 50 提升到 100：Transaction 比"每次保存整个状态"省内存，可多存

### 7. 序列化与持久化：仅内存态

**决策**：Transaction **不持久化**到磁盘。

**理由**：

- [ADR-0003](file:///d:/Projects/Active/math/docs/ADR/0003-storage-single-source-md-files.md)
  `.md` 文件是单一真相源，Transaction 持久化等于引入第五套存储
- 编辑器关闭重启后 Undo/Redo 历史清空是用户预期行为（VSCode / Typora 都这么做）
- 跨 session Undo 不是 Phase 2 目标

**例外**：若未来 Phase 4+ 需要"崩溃恢复"，应作为单独 ADR 评估，本 ADR 不预留接口。

### 8. TransactionId：内存顺序标识

```dart
class TransactionId {
  static int _counter = 0;
  final int value;
  TransactionId._(this.value);

  factory TransactionId.next() => TransactionId._(_counter++);
}
```

**非持久化**：进程重启后从 0 开始，仅用于调试与日志。

---

## 动机

### 为什么需要 Transaction Model？

**问题 1：原子性**

ADR-0007 §4.2 说"`split` 后立即 `insert` 算 1 个 Undo 单元"，但未定义：

- 如果 `split` 成功但 `insert` 失败，editor 处于半应用状态，如何恢复？
- `beginBatch / endBatch` 的嵌套语义？（内层 endBatch 是否立即入栈？）

**本 ADR 解答**：Transaction 级 commit/rollback，嵌套合并到外层。

**问题 2：Coalescing vs Batch**

ADR-0007 §4.2 说"连续字符输入（< 500ms）合并为 1 个 TextOperation"，
但用户输入是逐字符触发的，调用方无法显式 `beginBatch`。

**本 ADR 解答**：HistoryManager.push 时隐式 coalescing，调用方无需感知。

**问题 3：IME 交互**

Phase 2.5 IME commit 时，composing region 整体替换为 commit 后的文本。
这个"替换"是 1 个 TextOperation 还是 2 个（delete + insert）？

**本 ADR 解答**：1 个 TextOperation（deleted=composing原文，inserted=commit文本），
origin=ime，不参与 coalescing。

**问题 4：扩展 HistoryManager**

现有 `HistoryManager<T>` 是泛型栈。Transaction 如何接入？

**本 ADR 解答**：包装为 `EditorHistory`，旧 API 保留向后兼容。

### 设计原则

1. **显式优于隐式**：Transaction 用 `commit()` 显式控制原子性，避免隐式状态
2. **幂等纯函数**：apply/revert 不依赖外部可变状态，便于测试与回滚
3. **单一入口**：所有状态修改通过 `DocumentEditor` 接口，避免反向应用触发副作用
4. **包装而非重写**：保留 `HistoryManager<T>` 向后兼容，外层包 `EditorHistory`
5. **不持久化**：与 ADR-0003 单一真相源对齐

---

## 后果

### 正面后果

1. **原子性保证**：Transaction 级 commit/rollback，半应用状态可恢复
2. **Undo 粒度可控**：用户连续输入 coalesce 为 1 个 Undo 单元，符合直觉
3. **IME 兼容**：Phase 2.5 可基于 Transaction 接口实现 commit/cancel
4. **测试性**：apply/revert 幂等纯函数，可独立单测
5. **向后兼容**：`HistoryManager<T>` 5 处引用不破坏

### 负面后果

1. **复杂度增加**：Transaction + EditOperation 两层抽象，Phase 2.6 学习曲线陡
2. **内存占用**：Transaction 比"每次保存整个状态"省内存，但 100 Transaction 仍有成本
3. **Coalescing 调优**：500ms 默认值需在真实用户输入数据上调优
4. **DocumentEditor 接口未定义**：本 ADR 引用 `DocumentEditor`，但其接口需
   Phase 2.6 在 [block_editor.dart](file:///d:/Projects/Active/math/flutter_app/lib/core/editing/block_editor.dart)
   中落地，是隐含依赖

### 风险与缓解

| 风险 | 概率 | 影响 | 缓解 |
|------|------|------|------|
| Transaction 嵌套语义复杂，开发者误用 | 中 | 中 | 提供 `runInTransaction()` helper，自动 begin/end |
| Coalescing 500ms 默认值在低端机不适配 | 低 | 低 | 暴露为配置项，UI 层可调 |
| DocumentEditor 接口未定义导致 Phase 2.6 阻塞 | 中 | 高 | Phase 2.6 第一个任务就是定义 DocumentEditor |
| apply/revert 非幂等导致 rollback 失败 | 中 | 高 | 单测覆盖所有 op 类型的 apply-revert 幂等性 |
| 与 IME commit 时序冲突 | 中 | 高 | Phase 2.5 ADR-0009 IME Lifecycle Model 单独定义时序 |

---

## 替代方案

### 方案 A：纯状态快照（每次保存整个 Document 状态）

**否决理由**：

- 1000 块 Document 单次快照可能几十 KB，50 次 = 几 MB 内存
- 无法实现"用户输入 hello = 1 个 Undo 单元"（必须 coalesce 状态快照，复杂）
- 与 ADR-0007 §4.2 双层 Undo 决策冲突

### 方案 B：纯操作日志（无 Transaction 容器）

**否决理由**：

- 每条 op 独立 Undo，用户输入 5 字符需 Ctrl+Z 5 次才能全部删除
- 违反 ADR-0007 §4.2 "连续字符输入合并为 1 个 TextOperation"决策
- 无法表达 `split + insert` 复合操作的原子性

### 方案 C：ProseMirror 风格的 Transaction（每步自动入栈）

**否决理由**：

- ProseMirror Transaction 是不可变快照序列，每次 apply 产生新 state
- 与现有 `HistoryManager<T>` 模型冲突（需要完全重写）
- Dart 生态无成熟实现，学习成本高

### 方案 D：Command Pattern（每类操作一个 Command 类）

**否决理由**：

- 5 类 BlockOperation × N 种参数组合 = 类爆炸
- 缺乏 coalescing 支持，需要额外机制
- 与 ADR-0007 §4.2 sealed class 联合类型决策冲突

### 方案 E（采用）：显式 Transaction + 隐式 Coalescing 混合

**采纳理由**：

- 与 ADR-0007 §4.2 EditOperation sealed class 兼容（仅扩展容器）
- 显式 Transaction 满足原子性，隐式 coalescing 满足用户直觉
- 包装 HistoryManager 保留向后兼容
- 与 ADR-0007 §4.2 `beginBatch / endBatch` 决策对齐

---

## 实施计划

### Phase 2.5（IME 兼容）预备

本 ADR 落地**仅文档**，无代码实现。Phase 2.5 实现 IME 时需引用本 ADR：

- IME commit 触发 `origin=ime` 的 Transaction
- IME cancel 不入栈

### Phase 2.6（块级操作）落地

Phase 2.6 实施步骤（参考本 ADR）：

1. 定义 `DocumentEditor` 接口（apply/revert 的副作用边界）
2. 实现 `EditOperation.apply / revert`（5 类 BlockOp + TextOp）
3. 实现 `Transaction` + `TransactionBuilder`
4. 实现 `EditorHistory` 包装 `HistoryManager<Transaction>`
5. 实现 coalescing 逻辑
6. 单测：apply-revert 幂等性 + coalescing 规则 + 嵌套 Transaction

### 与现有 ADR 的关系

- **扩展** [ADR-0007 §4.2](file:///d:/Projects/Active/math/docs/ADR/0007-blockeditor-abstraction-design.md)
  的 `EditOperation` 骨架（不推翻，仅补充 Transaction 容器）
- **遵守** [ADR-0003](file:///d:/Projects/Active/math/docs/ADR/0003-storage-single-source-md-files.md)
  不持久化 Transaction
- **预留** [ADR-0009](file:///d:/Projects/Active/math/docs/ADR/) IME Lifecycle Model
  的接口（origin=ime）

---

## 参考

- [ADR-0007 §4.2](file:///d:/Projects/Active/math/docs/ADR/0007-blockeditor-abstraction-design.md) EditOperation 骨架
- [ADR-0003](file:///d:/Projects/Active/math/docs/ADR/0003-storage-single-source-md-files.md) 存储单一真相源
- [ROADMAP Phase 2.6](file:///d:/Projects/Active/math/docs/ROADMAP.md) 块级操作
- [history_manager.dart](file:///d:/Projects/Active/math/flutter_app/lib/core/utils/history_manager.dart) 现有泛型栈
- [block_editor.dart](file:///d:/Projects/Active/math/flutter_app/lib/core/editing/block_editor.dart) BlockEditor 抽象
- ProseMirror Transaction 设计（参考架构，未采用其不可变快照模型）
- VSCode / Typora 的 Undo 粒度（参考产品行为）

---

**维护人**：AI Agent（GLM-5.2）
**生效日期**：2026-07-19（Proposed，待 Human Owner 审批后 Accepted）
