# ADR-0007: BlockEditor 抽象设计

- **状态**：Accepted（Human Owner 于 2026-07-19 授权进入 Phase 2.2 实现）
- **生效日期**：2026-07-19
- **决策者**：首席架构工程师
- **关联**：[ROADMAP Phase 2.1](file:///d:/Projects/Active/math/docs/ROADMAP.md) / [ADR-0004](file:///d:/Projects/Active/math/docs/ADR/0004-markdown-parser-extension-strategy.md) / [CRITICAL_REVIEW §1.1](file:///d:/Projects/Active/math/docs/CRITICAL_REVIEW.md)

---

## 背景

Phase 1（底层重构）已关闭（PR #23，2026-07-19）。当前 AST 稳定：

- **Block 层**：`HeadingElement` / `ParagraphElement` / `ListElement` / `CodeElement` / `TableElement` / `BlockquoteElement` / `MermaidElement` / `EmptyLineElement` / `TaskListItemElement` / `HorizontalRuleElement`（共 10 类）
- **Inline 层**：`TextElement` / `FormulaElement` / `BoldElement` / `ItalicElement` / `StrikethroughElement` / `InlineCodeElement` / `LinkElement` / `ImageElement`（共 8 类）

但当前编辑范式仍是 **编辑/预览分离**（[editor_screen.dart:300-321](file:///d:/Projects/Active/math/flutter_app/lib/presentation/screens/editor_screen.dart#L300-321)），与 Typora 的 **WYSIWYG** 哲学对立（详见 [CRITICAL_REVIEW §1.1](file:///d:/Projects/Active/math/docs/CRITICAL_REVIEW.md)）。

Phase 2 的核心目标是：**设计并实现块级编辑内核**，让光标所在块渲染为可编辑组件、离开光标渲染为最终样式。这是 Phase 3 UI 重写的基石。

### 待决问题

1. **抽象结构**：BlockEditor 接口如何定义？聚焦态/非聚焦态如何切换？与现有 `DocumentElement` 是 wrapping 还是 flattening 关系？
2. **光标模型**：光标位置如何表示？块内 offset 与块间 navigation 如何统一？是否支持选区与多光标？
3. **IME 兼容**：中文输入组合态（composing region）如何在块编辑中正确处理？避免组合态中间断块、避免 commit 时丢字。
4. **块级操作原语**：insert / delete / merge / split / move 的语义、签名、与 Undo/Redo 栈的关系？

### 现有约束

- [ADR-0003](file:///d:/Projects/Active/math/docs/ADR/0003-storage-single-source-md-files.md) 已落地：`.md` 文件作为单一真相源，BlockEditor 抽象**不得引入第四套存储**
- [AGENTS.md §6.5](file:///d:/Projects/Active/math/AGENTS.md) Phase 2 禁区：UI 行为仍冻结，BlockEditor 抽象必须能 **脱离 UI 独立运行**（纯 Dart 逻辑）
- [ROADMAP Phase 2 退出条件](file:///d:/Projects/Active/math/docs/ROADMAP.md)：块编辑内核可脱离 UI 独立运行 + 1000 行增量解析 < 16ms + IME 组合态正确处理

---

## 决策

### 1. 抽象结构

#### 1.1 BlockEditor 接口定义

**采用"渲染态 + 编辑态"双态切换，由 Block 接口统一描述。**

```dart
/// 块编辑器抽象。一个 Block = 一段可独立编辑的内容（段落 / 标题 / 代码 / ...）。
///
/// Phase 2.1 仅定义抽象；Phase 2.2 实现聚焦态切换；
/// Phase 2.6 实现块级操作原语；Phase 2.7 实现 Markdown 快捷映射。
abstract class BlockEditor {
  /// 唯一标识。同一 Document 内稳定（用于光标定位、Undo/Redo）。
  BlockId get id;

  /// 块类型（对应 DocumentElement 子类）。
  BlockType get type;

  /// 当前是否处于聚焦编辑态（true=TextField / false=渲染样式）。
  bool get isFocused;

  /// 块内可编辑内容（Markdown 源文本，与 .md 单一真相源对齐）。
  ///
  /// 对于 CodeElement 是代码本身；对于 ParagraphElement 是一行 Markdown 文本；
  /// 对于 TableElement 是表格源（GFM 语法）。
  String get source;

  /// 编辑态切换回调。Phase 2.2 接入 UI 后，由 FocusNode 驱动。
  void onFocus();
  void onBlur();

  /// 源文本变更回调。Phase 2.3 接入增量解析后，仅触发当前块的重解析。
  void onSourceChanged(String newSource);
}
```

#### 1.2 BlockType 枚举

**对齐现有 AST，1:1 映射 DocumentElement 子类，避免引入第二套类型系统。**

```dart
enum BlockType {
  heading,
  paragraph,
  listItem,        // 合并 ListElement.ordered 与 unordered
  taskListItem,
  code,
  table,
  blockquote,
  mermaid,
  horizontalRule,
  // 注：emptyLine 不在 BlockEditor 范围（空行是块间分隔符，不编辑）
}
```

#### 1.3 与 DocumentElement 的关系：**Wrapping 而非 Flattening**

```
DocumentElement (AST)        BlockEditor (编辑模型)
─────────────────────        ─────────────────────
HeadingElement       <---->  HeadingBlock
ParagraphElement     <---->  ParagraphBlock
CodeElement          <---->  CodeBlock
...
```

- **AST 不变**：`DocumentElement` 子类签名零修改（保护 PDF/Word/TXT 导出器与所有 renderer）
- **Block 是 AST 的编辑态视图**：`BlockEditor.source` ↔ `DocumentElement` 字段双向映射
- **映射函数**：`BlockEditor.fromElement(DocumentElement)` + `BlockEditor.toElement()`
- **不引入"扁平 inline 编辑"**：inline 元素（Bold/Italic/...）仍是 `List<InlineElement>`，块内编辑时整段重解析 inline（Phase 2.3 增量解析）

**否决 Flattening 方案的理由**：将 inline 元素铺平为 token 流会破坏 AST 与导出器的耦合，且需要重写 [markdown_parser.dart](file:///d:/Projects/Active/math/flutter_app/lib/core/parser/markdown_parser.dart) 的 inline 解析，违反 [ADR-0004 §决策 4](file:///d:/Projects/Active/math/docs/ADR/0004-markdown-parser-extension-strategy.md)（保留自研解析器）。

#### 1.4 聚焦态/非聚焦态切换机制

```
非聚焦态（渲染样式）           聚焦态（可编辑）
─────────────────           ──────────────
Block renders via              Block renders via
*Renderer Widget              TextField + MarkdownInputField
(Phase 3 实现)                (Phase 2.2 接入)

  ↑ onBlur()                    ↑ onFocus()
  └─────────────┐  ┌───────────┘
                ↓  ↓
            BlockEditor.isFocused
```

- **切换触发**：Phase 2.2 由 `FocusNode` 驱动；Phase 2.1 仅定义接口与状态机
- **状态机**：`blurred → focusing → focused → blurring → blurred`（中间态用于过渡动画与 IME 提交处理）
- **切换时副作用**：
  - `onFocus()`：从 `DocumentElement` 重建 `source`（逆解析）
  - `onBlur()`：把 `source` 解析回 `DocumentElement`，写回 Document，触发增量解析

### 2. 光标模型

#### 2.1 位置表示：`BlockPosition`

```dart
/// 光标位置。块间 + 块内双层定位。
@immutable
class BlockPosition {
  final BlockId blockId;       // 哪个块
  final int offset;            // 块内字符 offset（0..source.length）
  final BlockSelection? selection; // 选区（null=单光标点）
}

@immutable
class BlockSelection {
  final int start;             // 选区起点 offset
  final int end;               // 选区终点 offset（end >= start）
  final TextAffinity affinity; // 文本方向（中文混排）
}
```

#### 2.2 块间 navigation

```dart
abstract class BlockCursorController {
  BlockPosition? get current;
  BlockPosition? moveNext();     // → 下一块
  BlockPosition? movePrevious(); // ← 上一块
  BlockPosition? moveTo(BlockId id, {int offset = 0});
  BlockPosition? moveEdge(bool toEnd); // 块首 / 块尾
}
```

#### 2.3 多光标决策：**Phase 2 不支持**

- **理由 1**：移动端无 Ctrl+Click 触发多光标的需求
- **理由 2**：多光标会指数级增加 Undo/Redo 复杂度
- **理由 3**：Typora 移动版本身不支持多光标
- **保留扩展点**：`BlockPosition.selection` 已预留，未来 Phase 4+ 可扩展

#### 2.4 选区支持：**仅块内选区**

- 跨块选区 = 多块操作（移动 / 删除），由块级操作原语处理（§4）
- 块内选区 = `TextField` 原生选区，BlockEditor 不重新发明

### 3. IME 兼容

#### 3.1 composing region 抽象

```dart
/// IME 组合态。中文 / 日文输入未 commit 时，[composingStart, composingEnd) 区间不可分割。
@immutable
class ComposingRegion {
  final int start;
  final int end;
  bool get isActive => start >= 0 && end > start;
}
```

#### 3.2 三条铁律

1. **组合态中间不切块**：`composing.isActive` 时，禁止 `onBlur()` / `split()` / `merge()` 触发；UI 切换需先 commit 或 cancel
2. **commit 时不丢字**：`onSourceChanged` 在 commit 阶段触发，BlockEditor 必须用新值替换 composing region，而不是覆盖整个 source
3. **cancel 时回滚**：`onComposingCancelled()` 回调，恢复 commit 前 source

#### 3.3 与 TextEditingController 的关系

- **不重新发明 TextEditingController**：Phase 2.2 直接复用 Flutter 的 `TextEditingController` + `composingRange`
- **BlockEditor 适配层**：监听 `composingRange` 变化，拦截 §3.2 铁律
- **测试隔离**：BlockEditor 抽象本身不依赖 `TextEditingController`，可通过 `ComposingRegion` 接口 mock

#### 3.4 中文输入法组合态测试矩阵

| 场景 | 预期行为 |
|------|---------|
| 输入 "你好" 中途切到下一块 | 先 commit "你好" 到当前块，再切换 |
| 输入 "你好" 中途点工具栏加粗按钮 | 先 commit，再包裹 `**` |
| 输入 "ni hao" 选第 2 候选"拟好" | commit 时替换整个 composing region |
| 输入到块末尾继续输入 | 块内 offset 推进，不自动 split |
| 输入到块末尾按 Enter | split 当前块（Paragraph → Paragraph） |
| composing 中按 Backspace | 取消 composing，不删除已 commit 字符 |

### 4. 块级操作原语

#### 4.1 五个核心原语

```dart
abstract class BlockOperations {
  /// 在 [afterId] 之后插入新块。
  /// 返回新块 id。触发 Document 写回 + Undo 入栈。
  BlockId insert(BlockId? afterId, BlockType type, {String source = ''});

  /// 删除 [id] 块。光标移到上一块末尾（或下一块开头）。
  /// 禁止删除最后一个块（保证 Document 至少 1 块）。
  BlockPosition delete(BlockId id);

  /// 合并 [id] 与 [id-1] 块。
  /// 类型必须兼容（Paragraph+Paragraph / List+List）；
  /// 不兼容时回退为 Paragraph 合并（source 拼接）。
  BlockPosition merge(BlockId id);

  /// 在 [id] 块的 [offset] 处拆分为两块。
  /// 原 block 截断到 offset，新 block 接管 offset 之后内容。
  /// Markdown 语法场景（如 `# ` 起首）由 §4.3 重类型化处理。
  BlockPosition split(BlockId id, int offset);

  /// 移动 [id] 块到 [targetId] 之前/之后。
  /// 用于上下箭头拖拽 / 拖放。
  BlockPosition move(BlockId id, BlockId targetId, {bool before = true});
}
```

#### 4.2 与 Undo/Redo 栈的关系

- **每个原语 = 一个 Undo 单元**：不是字符级，是块级
- **复合操作**：`split` 后立刻 `insert`（如输入 `\n\n` 创建空段落）算 1 个 Undo 单元，需 `beginBatch() / endBatch()` 包裹
- **复用 `HistoryManager`**：[core/utils/history_manager.dart](file:///d:/Projects/Active/math/flutter_app/lib/core/utils/history_manager.dart) 已实现，扩展为支持 `BlockOperation` 类型
- **状态快照 vs 操作日志**：采用操作日志（更省内存），undo 时反向应用

#### 4.3 Markdown 快捷映射（Phase 2.7）

`split` / `onSourceChanged` 时检测块首语法，触发**重类型化**：

| 源文本变化 | 重类型化动作 |
|-----------|------------|
| `# Title\n` | Paragraph → Heading(level=1) |
| `- item\n` | Paragraph → ListItem(ordered=false) |
| `- [ ] task\n` | Paragraph → TaskListItem(checked=false) |
| ``` ```lang\n | Paragraph → Code(language=lang) |
| `> quote\n` | Paragraph → Blockquote |
| `---\n` | Paragraph → HorizontalRule |

**实现位置**：`BlockTypeDetector` 工具类，纯函数，无副作用。

#### 4.4 边界约束

- **不修改 DocumentElement 子类签名**：保护导出器
- **不引入派生缓存**（[ADR-0003 §边界约束 5](file:///d:/Projects/Active/math/docs/ADR/0003-storage-single-source-md-files.md)）：Block 列表 = .md 解析结果，无 SQLite / FileIndex
- **块数上限**：10000 块（移动端单 Document 容量上限，超出报错而非崩）

---

## 动机

### 为什么采用"渲染态 + 编辑态"双态切换？

**对齐 Typora 范式**：Typora 的核心是「光标所在块渲染为编辑态，离开光标渲染为最终样式」。双态切换是最直接的实现。

**否决方案 A（始终渲染 TextField）**：1000 块的 TextField 会内存爆炸 + 性能崩溃。

**否决方案 B（始终渲染样式，弹出 modal 编辑）**：丢失 WYSIWYG 的"就地编辑"体验。

### 为什么 BlockType 1:1 映射 DocumentElement？

**保护现有投资**：Phase 1 已稳定 10 类 block + 8 类 inline AST，PDF/Word/TXT 导出器全部基于此。引入第二套类型系统会让导出器重写。

**否决方案 C（Notion 风格的 generic Block）**：Notion 的 Block 是无类型 dict，渲染时按 property 分发。这种范式适合数据库驱动笔记，不适合 Markdown WYSIWYG（Markdown 语法本质是 typed）。

### 为什么多光标不支持？

**移动端无需求**：触屏无法触发 Ctrl+Click。
**复杂度爆炸**：多光标的 Undo/Redo 需要分组，IME 组合态需多 region 协调，超出 Phase 2 范围。

### 为什么操作粒度是块级而非字符级？

**移动端习惯**：手机用户更倾向"块感"操作（长按拖拽整段、上下箭头移动段落）。
**性能**：字符级 Undo 在 1000 块 Document 上会内存爆炸。块级 Undo 是工程折中。

---

## 后果

### 正面

1. **Phase 3 UI 重写有清晰契约**：UI 层只需实现 `BlockEditor` 接口的渲染，不碰编辑逻辑
2. **AST 不破坏**：[ADR-0004](file:///d:/Projects/Active/math/docs/ADR/0004-markdown-parser-extension-strategy.md) 的扩展策略继续生效
3. **可独立测试**：BlockEditor 抽象是纯 Dart 逻辑，不依赖 Flutter UI（满足 ROADMAP Phase 2 退出条件）
4. **IME 隔离**：通过 `ComposingRegion` 抽象，未来可适配不同 IME（搜狗 / Gboard / 系统输入法）

### 负面

1. **抽象层增加**：BlockEditor ↔ DocumentElement 双向映射有性能开销（每次 onFocus/onBlur 都要转换）
2. **不兼容多光标**：未来若要支持需重构 `BlockPosition` 数据结构
3. **逆解析复杂**：从 `DocumentElement` 重建 `source`（Markdown 文本）需实现 10 类块的逆解析，工作量集中
4. **IME 测试矩阵大**：§3.4 的 6 类场景必须全覆盖

### 风险与缓解

| 风险 | 概率 | 影响 | 缓解 |
|------|------|------|------|
| 抽象漏抽象（BlockEditor 暴露 DocumentElement 细节） | 中 | 中 | 严格 mapping 函数边界，单元测试覆盖 |
| 逆解析与解析不对称（Markdown round-trip 丢字） | 高 | 高 | 每 type 必须有 round-trip 测试（source → element → source 一致） |
| IME 铁律在 UI 接入时被绕过 | 中 | 高 | architecture test 守门：BlockEditor 切换必须经 ComposingRegion 检查 |
| 块级 Undo 与现有字符级 HistoryManager 不兼容 | 中 | 中 | Phase 2.6 引入 `BlockOperation` 类型，扩展而非重写 |
| 1000 块 Document 性能不达标 | 中 | 中 | Phase 2.3 增量解析只重解析当前块，性能瓶颈在 inline 解析而非块管理 |

---

## 实施计划

### Phase 2.1（本 ADR 对应任务，本 PR）

**产物**：
- 本 ADR-0007 设计文档
- Phase 2.1 Task Contract
- **不写代码**（Phase 2.1 是设计任务，§6.5 禁止在抽象稳定前实现 2.2~2.7）

**审批**：Human Owner 审批 ADR + Task Contract，Accept 后进入 Phase 2.2。

### Phase 2.2（聚焦态切换）

- 实现 `BlockEditor` 接口骨架（无 UI 接入）
- 实现 `BlockId` / `BlockType` / `BlockPosition` 数据类
- 单元测试：状态机 blurred → focusing → focused → blurring → blurred

### Phase 2.3（增量解析）

- 实现 `BlockEditor.toElement()` / `fromElement()` 双向映射
- 实现 `BlockTypeDetector`（Markdown 快捷映射）
- 性能测试：1000 块 Document 增量解析 < 16ms（ROADMAP 退出条件）

### Phase 2.4（AST 重构对齐）

- 评估 `EmptyLineElement` 是否从 AST 移除（BlockEditor 不编辑空行）
- 评估 `TableElement` 是否拆为 `TableRow` / `TableCell` 块
- ADR-0007 修订（如需）

### Phase 2.5（IME 兼容）

- 实现 `ComposingRegion` 抽象
- 接入 `TextEditingController.composingRange`
- §3.4 测试矩阵全覆盖

### Phase 2.6（块级操作原语）

- 实现 `BlockOperations` 五原语
- 扩展 `HistoryManager` 支持 `BlockOperation`
- `beginBatch() / endBatch()` 复合操作

### Phase 2.7（Markdown 快捷映射）

- 完善 `BlockTypeDetector` 全部 6 类规则
- 集成到 `split` / `onSourceChanged` 触发点

---

## 替代方案再次评估

### 方案 X：ProseMirror 风格的 Schema + Transaction

**否决理由**：
- ProseMirror 是 JS 生态，Dart 无成熟实现
- Schema 系统过重，Phase 2 不需要 plugin
- 学习曲线陡，不利于 AI 协作

### 方案 Y：直接用 Flutter 的 `EditableText` + 自定义 InputFormatter

**否决理由**：
- `EditableText` 是单块文本，不支持块级切换
- InputFormatter 是字符级 hook，无法表达块级语义

### 方案 Z：Notion 风格 generic Block + property

**否决理由**：见 §动机 - 否决方案 C

---

## 参考

- [ROADMAP.md Phase 2](file:///d:/Projects/Active/math/docs/ROADMAP.md)
- [ADR-0003](file:///d:/Projects/Active/math/docs/ADR/0003-storage-single-source-md-files.md) 存储单一真相源
- [ADR-0004](file:///d:/Projects/Active/math/docs/ADR/0004-markdown-parser-extension-strategy.md) Parser 扩展策略
- [CRITICAL_REVIEW §1.1](file:///d:/Projects/Active/math/docs/CRITICAL_REVIEW.md) 编辑/预览分离问题
- [data/models/document.dart](file:///d:/Projects/Active/math/flutter_app/lib/data/models/document.dart) 现有 AST
- [core/utils/history_manager.dart](file:///d:/Projects/Active/math/flutter_app/lib/core/utils/history_manager.dart) Undo/Redo 栈
- [presentation/widgets/preview_content.dart](file:///d:/Projects/Active/math/flutter_app/lib/presentation/widgets/preview_content.dart) 当前渲染分发
- Typora 块级编辑体验（参考产品）
- ProseMirror Schema 设计（参考架构，未采用）
