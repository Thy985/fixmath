# Phase 3.3 PR #3 Task Contract: 自动配对 + 自动续列表

> **版本**：v1.1（落地 Human Owner v1.0 审批 6 项修改：4 P0 + 2 P1）
> **起草日期**：2026-07-24
> **起草人**：AI Agent（GLM-5.2）
> **状态**：Accepted（v1.0 Human Owner 审批 "Approved with changes",v1.1 落地 6 项修改后启动实施）
> **关联文档**：
> - [Phase 3.3 Task Contract v1.4](./phase3.3-task-contract.md) §3.3.6 + §3.3.8 + §9.2
> - [ADR-0008](../ADR/0008-editor-transaction-model.md) sealed class 约束
> - [ADR-0011](../ADR/0011-phase3.3-architecture-decisions.md) §3 + §5
> - [PR #2 Task Contract v2.1](./phase3.3-pr2-task-contract.md) Command Layer 路径

---

## 0. v1.1 修订记录

### v1.0 → v1.1 修订（落地 Human Owner 审批 6 项修改）

| # | 修改点 | 优先级 | 来源 | 章节 |
|---|--------|--------|------|------|
| 1 | onChanged 改为基于 `TextEditingValue`,增加 composing region 检查 Hard Rule | P0 | Human v1.0 review #1 | §2.1.1 + §2.4 |
| 2 | `PairInsertCommand` 增加 `insertOffset` 字段,不通过 selection 推断 cursor | P0 | Human v1.0 review #2 | §3.1 |
| 3 | `InsertNewLineWithPrefixCommand` 删除 `currentSource`（Command 不携带 State） | P0 | Human v1.0 review #4 | §3.2 |
| 4 | `AutoContinueRules` 修复 checkbox regex + 列表规则优先级（checkbox 优先匹配） | P0 + P1 | Human v1.0 review #4 + #5 | §4.3 |
| 5 | `BaseBlockState` 增加 input handler 边界,新增 `blocks/input/` 目录 | P1 | Human v1.0 review #6 | §2.6 + §4.1 |
| 6 | Undo 不合并方案记录为 Phase 3.4 技术债（ADR 待补） | — | Human v1.0 review #3 | §2.2 |

### Human Owner 决策审批（v1.0 §8）

| 决策项 | v1.0 推荐 | v1.1 审批结果 | 备注 |
|--------|----------|--------------|------|
| §8.1 IME 兼容性方案 | onChanged 统一路径 | ✅ Approved + composing 检查 | §2.1.1 Hard Rule |
| §8.2 CommandOrigin 与 Coalescing | ime + 不合并 | ✅ Approved | Phase 3.4 Coalescing 技术债 |
| §8.3 PR 拆分策略 | 单 PR #3 | ✅ Approved + 小 commit | §9 commit 划分 |

---

## 1. 目标与范围

### 1.1 总目标

落地 Phase 3.3 Task Contract §3.3.6（自动配对）+ §3.3.8（自动续列表）。

**核心价值**：移动端 Markdown 输入辅助。用户输入 `(` 自动补 `)`，输入 `- item` 回车自动续 `- `。降低移动端 Markdown 输入摩擦力（Obsidian Mobile / Typora 标配）。

### 1.2 PR 范围

| 项目 | 包含 | 不包含 |
|------|------|--------|
| 自动配对 | 4 种配对符（`(` / `[` / `{` / `` ` ``） | `*` / `$` / `#` / `-` / `>`（v1.3 缩减,留 Phase 3.4+） |
| 自动续列表 | 5 种前缀（`- ` / `* ` / `1. ` / `> ` / `- [ ] `） | 嵌套列表 / 混合前缀 / 编号验证（Phase 3.4+） |
| Command | PairInsertCommand + InsertNewLineWithPrefixCommand | — |
| UI 改动 | BaseBlockState buildEditField 新增 onChanged | 无新 UI 组件 |

### 1.3 不在范围（Out of Scope）

- ❌ Markdown 语义字符自动配对（`*` / `$` / `#` / `-` / `>`）—— 需 AST 上下文判断,留 Phase 3.4+
- ❌ 嵌套列表续行（缩进追踪）—— Phase 3.4+
- ❌ 编号列表起始编号验证 —— Phase 3.4+
- ❌ 混合前缀识别（`- ` → `1. ` 切换）—— Phase 3.4+
- ❌ 字号缩放 / 焦点模式（PR #4 P1）

### 1.4 前置依赖

- ✅ PR #1 chrome 接线（已合并）
- ✅ PR #2A Command Infrastructure（已合并,InsertTextCommand / WrapSelectionCommand 范式可复用）
- ✅ PR #2B Toolbar UI + Selection sync（已合并,BaseBlockState selection 同步机制可复用）
- ✅ PR #2C Template Menu（已推送,待合并）
- ✅ ADR-0008 sealed class 约束
- ✅ ADR-0011 §5 Toolbar 状态来源（Command Layer 强制）

---

## 2. 架构决策（v1.1 Human Owner 已审批）

### 2.1 IME 兼容性方案：onChanged 统一路径（Approved v1.1）

**决策**：自动配对 + 自动续列表统一通过 `onChanged` 拦截,不使用 `onSubmitted`。

**理由**：

| 方案 | 优点 | 缺点 | 评估 |
|------|------|------|------|
| onSubmitted | 实现简单 | Gboard 中文输入法可能不触发（§3.8 R4 风险） | ❌ 移动端不可靠 |
| onChanged + `\n` 检测 | IME 友好,与自动配对共用路径 | 需手动管理光标位置 | ✅ Approved |
| 双路径（onSubmitted + onChanged 兜底） | 最可靠 | 逻辑复杂,可能双重触发 | ❌ 过度工程 |

**统一路径优势**：
- 自动配对已确定用 onChanged（§9.2 R4 确认）
- 自动续列表改用 onChanged + `\n` 检测,与自动配对共用 `onChanged` 回调
- 避免维护两套输入拦截逻辑

### 2.1.1 Hard Rule：composing region 检查（v1.1 P0-1 新增）

**背景**：Flutter TextField 输入事件核心不是 `String` 变化,而是 `TextEditingValue` 变化（含 `text` / `selection` / `composing`）。中文 IME 组合输入期间 `composing.isValid == true`,此时**禁止触发任何自动行为**,否则会导致状态错乱：

```
用户输入 'nihao' 拼 '你好'
  ↓
IME composing 状态
  ↓
若误触发自动配对（如检测到某个配对符）
  ↓
IME commit
  ↓
状态错乱
```

**Hard Rule**：

```dart
// 必须基于 TextEditingValue 而非 String
void _onTextChanged(String text) {
  final value = textController.value;  // 取完整 TextEditingValue
  // Hard Rule：composing region 非 collapsed 时禁止自动行为
  if (value.composing != TextRange.empty) return;
  // ... 后续自动配对 / 续列表逻辑 ...
}
```

**约束**：
- ❌ 禁止仅基于 `String text` 判断是否触发自动行为
- ✅ 必须读取 `TextEditingController.value` 获取 `composing` 字段
- ✅ `composing != TextRange.empty`（即 `composing.isValid`）时跳过所有自动行为

**自动续列表 onChanged 时序**：
```
1. 用户按回车
2. IME 提交 '\n' 到 controller（composing 已 collapsed）
3. controller.text 变为 "line1\n"
4. onChanged(text) 触发
5. 检查 textController.value.composing == TextRange.empty ✅
6. 检测 text.endsWith('\n')
7. 分析倒数第二行前缀（"line1" 的前缀）
8. 若为列表前缀 → 构造 InsertNewLineWithPrefixCommand
9. Coordinator.handle(command)
10. controller.text 更新为 "line1\n- "（续行前缀已追加）
11. 光标移到新行末尾
```

### 2.2 CommandOrigin 与 Coalescing 策略（Approved v1.1）

**决策**：`CommandOrigin.ime` + 不合并（两个独立 undo 步骤）。

**理由**：
- 自动配对是 IME 输入的"副作用",语义上属于 `ime` origin
- 不合并（两个 undo 步骤）更安全：用户 undo 一次撤销配对符 `)`,再 undo 一次撤销原始输入 `(`
- 合并方案需要 Coalescing 逻辑（检测相邻 ime origin Transaction 合并）,Phase 3.3 不实现 Coalescing

**Phase 3.4 技术债（v1.1 记录）**：

| 技术债 | 当前方案（Phase 3.3） | 目标方案（Phase 3.4+） | 跟踪 |
|--------|---------------------|----------------------|------|
| IME Transaction Coalescing | 自动配对产生独立 undo 步骤（undo 2 次撤销 `()`） | 合并相邻 ime origin Transaction（undo 1 次撤销 `()`） | 待 ADR 记录 |

**用户体验说明**：当前 undo 2 次的行为与 VS Code 等主流编辑器（undo 1 次）不一致,属于已知限制。Phase 3.3 不视为 bug,Phase 3.4 Coalescing 实现后自动修复。

### 2.3 PairInsertCommand 设计：不修改原始输入

**关键约束**（§9.2 R4）：PairInsertCommand **不修改原始用户输入,只追加配对符右半部分**。

**时序**：
```
1. 用户输入 '('
2. IME 已提交 '(' → controller.text = "...("  ← 原始输入已在 controller 中
3. onChanged(text) 触发
4. 检测到 '(' 在光标位置且需要配对
5. 构造 PairInsertCommand(
     blockId,
     insertOffset: 光标位置（'(' 之后）,
     pairChar: ')',
     mode: PairInsertMode.appendAfterCursor,  // 只追加 ')',不修改 '('
   )
6. Coordinator.handle(command)
7. CommandHandler → BlockOperations.updateSource → controller.text = "...()"
8. 光标移到 '()' 之间
```

**选区包裹模式**：当选区非空时,`(` 包裹选区变为 `(selection)`：
```
mode: PairInsertMode.wrapSelection,
selection: 当前选区,
pairChar: ')',
prefixChar: '(',  // 选区前插入 '('
```

### 2.4 BaseBlockState onChanged 改动（v1.1 P0-1 修订）

**当前状态**：`buildEditField` 的 TextField 无 `onChanged` 回调。

**改动**：新增 `onChanged` 回调,统一处理自动配对 + 自动续列表。

```dart
// base_block_state.dart buildEditField 改动
TextField(
  controller: textController,
  focusNode: focusNode,
  // ... 其他配置 ...
  onChanged: _onTextChanged,  // 新增
  onSubmitted: (_) => focusNode.unfocus(),
);

/// 输入变化回调：自动配对 + 自动续列表统一入口。
///
/// **Hard Rule（§2.1.1）**：必须基于 [TextEditingController.value]（含 composing）
/// 而非 String 判断。composing region 非 collapsed 时禁止自动行为。
void _onTextChanged(String text) {
  if (!isFocused) return;  // 仅聚焦块处理

  // §2.1.1 Hard Rule：composing region 检查
  final value = textController.value;
  if (value.composing != TextRange.empty) return;  // IME 组合输入态,跳过

  // CodeBlock 例外：不应用自动配对 / 自动续列表
  if (isCodeBlock) return;

  _handleAutoPair(value);     // §3.3.6 自动配对（接收 TextEditingValue）
  _handleAutoContinue(value); // §3.3.8 自动续列表（接收 TextEditingValue）
}
```

**与 _isCommitting 的关系**：
- `_isCommitting` 标志用于区分"本地输入 commit"与"外部命令修改"
- 自动配对 / 自动续列表产生的 Command 会触发 didUpdateWidget → 检测 source 变化 → 同步 controller
- 需要设置 `_isCommitting = true` 防止 didUpdateWidget 把 Command 产生的变化误判为本地输入

### 2.5 CodeBlock 例外

CodeBlock 禁用自动配对 + 自动续列表（§3.6 第 5 点 + §3.8 第 4 点）。

**实现**：`_onTextChanged` 中通过 `isCodeBlock` 判断跳过。

**isCodeBlock 判断**：复用 PR #2B 的 `coordinator.isFocusedOnCodeBlock` 便捷属性,或通过 `BlockType.fromElement` 判断。

### 2.6 BaseBlockState input handler 边界（v1.1 P1-6 新增）

**背景**：PR #3 后 BaseBlockState 将承担：selection sync / input / auto pair / auto continue / controller sync / lifecycle 等多职责,接近 God Object 边界。PR #3 不拆 BaseBlockState,但**建立 input handler 边界**,防止后续 PR 继续堆积。

**目录结构**：

```
lib/presentation/blocks/
├── base_block_state.dart        # 基类（接收事件,委托 InputHandler）
└── input/                       # 输入处理子目录（PR #3 新增）
    ├── input_handler.dart       # InputHandler 入口（协调 auto pair + auto continue）
    ├── auto_pair_rules.dart     # 配对规则表 + 触发条件检测
    └── auto_continue_rules.dart # 续行规则表 + 触发条件检测
```

**职责边界**：

| 组件 | 职责 | 不负责 |
|------|------|--------|
| `BaseBlockState` | 接收 `TextEditingValue`,委托 `InputHandler` | ❌ 不实现配对 / 续行规则 |
| `InputHandler` | 协调 auto pair + auto continue,构造 Command | ❌ 不直接修改 controller |
| `AutoPairRules` | 检测是否触发配对,返回 `PairInsertCommand?` | ❌ 不调用 Coordinator |
| `AutoContinueRules` | 检测是否触发续行,返回 `InsertNewLineWithPrefixCommand?` | ❌ 不调用 Coordinator |

**BaseBlockState 改动后职责**：

```dart
// base_block_state.dart
void _onTextChanged(String text) {
  if (!isFocused) return;
  final value = textController.value;
  if (value.composing != TextRange.empty) return;
  if (isCodeBlock) return;

  // 委托 InputHandler（不直接实现规则）
  _inputHandler.handle(value, blockId, coordinator);
}
```

**约束**：
- ❌ BaseBlockState 不直接实现配对 / 续行规则
- ❌ AutoPairRules / AutoContinueRules 不直接调用 Coordinator（只返回 Command?）
- ✅ InputHandler 负责调用 Rules 检测 + 调用 Coordinator.handle()

---

## 3. Command 设计

### 3.1 PairInsertCommand（v1.1 P0-2 修订：新增 insertOffset）

**v1.0 问题**：原设计通过 `c.selection?.baseOffset ?? source.length` 推断 cursor 位置,但 selection 有两个概念（用户选择 / 当前光标）,Command 不应依赖 selection 推断 cursor。

**v1.1 修订**：新增 `insertOffset` 字段,类似 `InsertTextCommand`,让 Command 明确描述"在哪里做什么",而不是"当前状态是什么"。

```dart
/// 自动配对模式。
enum PairInsertMode {
  /// 光标后追加配对符右半部分（无选区时）。
  appendAfterCursor,
  /// 选区包裹为 prefix + selection + suffix（有选区时）。
  wrapSelection,
}

/// 自动配对 Command：追加配对符右半部分或包裹选区。
///
/// **关键约束**（§9.2 R4）：不修改原始用户输入,只追加配对符右半部分。
/// 原始输入（如 '('）由 IME 直接提交到 controller,本 Command 只追加 ')'。
///
/// **v1.1 修订**：新增 [insertOffset] 字段,不通过 selection 推断 cursor。
/// Command 是历史记录对象,必须描述"我要在哪里做什么",
/// 而不是"当前状态是什么"。
///
/// **CommandOrigin**：[CommandOrigin.ime]（§2.2 决策）
@immutable
final class PairInsertCommand extends EditorCommand {
  /// 目标块 ID。
  final BlockId blockId;

  /// 配对符右半部分（如 ')' / ']' / '}' / '`'）。
  ///
  /// **v1.1 修订**：移除 `prefixChar` 字段。appendAfterCursor 模式只追加
  /// suffixChar（prefixChar 已由 IME 提交,Command 不需要知道）;
  /// wrapSelection 模式同样只追加 suffixChar 到选区末尾。
  final String suffixChar;

  /// 插入位置（绝对 offset,基于 source）。
  ///
  /// **v1.1 新增**：appendAfterCursor 模式 = 光标位置（'(' 之后）;
  /// wrapSelection 模式 = 选区末尾（selection.end）。
  final int insertOffset;

  /// 配对模式。
  final PairInsertMode mode;

  /// 光标偏移（相对插入文本末尾,默认 0 = 末尾,负数 = 前移）。
  /// appendAfterCursor 模式：光标在 suffixChar 之前（offset = -suffixChar.length）
  /// wrapSelection 模式：光标在 suffixChar 之后（offset = 0）
  final int cursorOffset;

  const PairInsertCommand({
    required this.blockId,
    required this.suffixChar,
    required this.insertOffset,
    this.mode = PairInsertMode.appendAfterCursor,
    this.cursorOffset = 0,
    super.origin = CommandOrigin.ime,
  }) : super(displayName: '自动配对');
}
```

**与 v1.0 差异**：
- ✅ 新增 `insertOffset` 字段（P0-2 修订）
- ✅ 移除 `prefixChar` 字段（Command 不需要知道 prefix,只追加 suffix）
- ✅ 移除 `selection` 字段（cursor 位置由 `insertOffset` 明确描述）
- ✅ `wrapSelection` 模式由 `insertOffset = selection.end` 表达

### 3.2 InsertNewLineWithPrefixCommand（v1.1 P0-3 修订：删除 currentSource）

**v1.0 问题**：Command 携带 `currentSource` 字段,意味着 History 中 Command + Snapshot 混合,长期会导致 Command 越来越胖。Command 应只携带"意图",Handler 负责读取 State 执行。

**v1.1 修订**：删除 `currentSource` 字段,Handler 通过 `editor.getBlock(c.blockId)` 读取当前 source。

```dart
/// 自动续列表 Command：插入换行 + 续行前缀。
///
/// **触发条件**：用户按回车（onChanged 检测到 '\n'）,且当前行有列表 / 引用前缀。
///
/// **续行规则**（§3.8）：
/// - `- item` → `- `（无序列表）
/// - `* item` → `* `（无序列表）
/// - `1. item` → `2. `（有序列表,编号 +1）
/// - `> quote` → `> `（引用）
/// - `- [ ] task` → `- [ ] `（任务列表）
///
/// **退出规则**：当前行为空模式（如 `- ` 后无内容）,回车清除前缀。
///
/// **v1.1 修订**：删除 `currentSource` 字段。Command = 意图,Handler = 执行。
/// Handler 通过 `editor.getBlock(c.blockId)` 读取当前 source。
@immutable
final class InsertNewLineWithPrefixCommand extends EditorCommand {
  /// 目标块 ID。
  final BlockId blockId;

  /// 续行前缀（如 '- ' / '1. ' / '> '）。
  final String prefix;

  /// 是否为退出续行（清除空行前缀）。
  final bool isExit;

  const InsertNewLineWithPrefixCommand({
    required this.blockId,
    required this.prefix,
    this.isExit = false,
    super.origin = CommandOrigin.ime,
  }) : super(displayName: '自动续列表');
}
```

**与 v1.0 差异**：
- ✅ 删除 `currentSource` 字段（P0-3 修订,Command 不携带 State）
- ✅ Handler 负责读取 source 计算

### 3.3 CommandHandler 新增 _handle* 方法

```dart
// command_handler.dart _dispatch 新增分支
PairInsertCommand c => _handlePairInsert(c, operations),
InsertNewLineWithPrefixCommand c => _handleNewLineWithPrefix(c, operations),

/// 处理 [PairInsertCommand]（v1.1：基于 insertOffset,不推断 cursor）。
bool _handlePairInsert(PairInsertCommand c, BlockOperations ops) {
  final element = editor.getBlock(c.blockId);
  if (element == null) return false;
  final source = fromElement(element);

  // v1.1：直接使用 c.insertOffset,不通过 selection 推断
  final offset = c.insertOffset;
  if (offset < 0 || offset > source.length) return false;

  // 两种模式都是追加 suffixChar 到 insertOffset 位置
  // （wrapSelection 模式的 insertOffset = selection.end,语义一致）
  final newSource = source.substring(0, offset) + c.suffixChar + source.substring(offset);
  return ops.updateSource(c.blockId, newSource);
}

/// 处理 [InsertNewLineWithPrefixCommand]（v1.1：Handler 读取 source,不依赖 Command 携带）。
bool _handleNewLineWithPrefix(InsertNewLineWithPrefixCommand c, BlockOperations ops) {
  final element = editor.getBlock(c.blockId);
  if (element == null) return false;
  final source = fromElement(element);  // v1.1：Handler 读取 source

  if (c.isExit) {
    // 退出续行：清除当前行前缀（替换 "- \n" 为 "\n"）
    // ... 实现细节：找到最后一个 '\n' 前的前缀,移除 ...
  } else {
    // 续行：在 source 末尾追加 prefix
    final newSource = source + c.prefix;
    return ops.updateSource(c.blockId, newSource);
  }
}
```

---

## 4. 实施计划

### 4.1 文件改动清单（v1.1 修订：新增 input/ 目录）

| 文件 | 类型 | 改动 |
|------|------|------|
| `editor_command.dart` | 修改 | 新增 PairInsertCommand + InsertNewLineWithPrefixCommand + PairInsertMode enum |
| `commands.dart` | 修改 | re-export 2 个新 Command + PairInsertMode enum |
| `command_handler.dart` | 修改 | _dispatch 新增 2 个 case + _handlePairInsert + _handleNewLineWithPrefix |
| `editor_coordinator.dart` | 修改 | _syncSelectionAfterCommand 新增 2 个 case（PairInsert + NewLineWithPrefix 的 selection 同步） |
| `base_block_state.dart` | 修改 | buildEditField 新增 onChanged + _onTextChanged（委托 InputHandler,不直接实现规则） |
| `blocks/input/input_handler.dart` | **新增** | InputHandler 入口（协调 auto pair + auto continue,构造 Command,调用 Coordinator） |
| `blocks/input/auto_pair_rules.dart` | **新增** | 配对规则表（4 种配对符 + 触发条件检测,返回 `PairInsertCommand?`） |
| `blocks/input/auto_continue_rules.dart` | **新增** | 续行规则表（5 种前缀 + 优先级 + 退出条件检测,返回 `InsertNewLineWithPrefixCommand?`） |
| `auto_pair_test.dart` | 新增 | 单元测试 |
| `auto_continue_test.dart` | 新增 | 单元测试 |

### 4.2 自动配对规则（§3.6）

| 输入 | 配对 | 光标位置 | 选区行为 |
|------|------|----------|----------|
| `(` | `()` | 中间 | `(selection)` |
| `[` | `[]` | 中间 | `[selection]` |
| `{` | `{}` | 中间 | `{selection}` |
| `` ` `` | ` `` `` | 中间 | `` `selection` `` |

**触发条件检测**（v1.1：基于 TextEditingValue）：
```dart
// blocks/input/auto_pair_rules.dart
class AutoPairRules {
  static const Map<String, String> _pairs = {
    '(': ')',
    '[': ']',
    '{': '}',
    '`': '`',
  };

  /// 检测 onChanged 是否触发了自动配对。
  ///
  /// **v1.1 修订**：接收 [TextEditingValue] 而非 String,确保 composing 已检查。
  /// 返回 PairInsertCommand?（null = 不触发）。
  /// 调用方（InputHandler）已保证 composing == TextRange.empty,此处不再检查。
  static PairInsertCommand? detect({
    required TextEditingValue newValue,
    required TextEditingValue oldValue,
    required BlockId blockId,
  }) {
    // 检测新增字符是否为配对符左半部分
    // 比较 newValue.text 和 oldValue.text 差异,找到新增字符
    // 若新增字符在 _pairs 中 → 构造 PairInsertCommand
    //
    // v1.1：使用 newValue.selection.baseOffset 作为 insertOffset
    // （不通过 selection 推断,而是明确读取当前光标位置）
    //
    // 选区包裹模式：若 oldValue.selection 非 collapsed → wrapSelection
    //   insertOffset = oldValue.selection.end
    // 单光标模式：appendAfterCursor
    //   insertOffset = newValue.selection.baseOffset（'(' 已提交,光标在 '(' 之后）
  }
}
```

**禁止无条件补全的字符**（v1.3 硬规则）：
- ❌ `*` / `$` / `#` / `-` / `>`：需 AST 上下文判断,Phase 3.3 不实现

### 4.3 自动续列表规则（§3.8,v1.1 P0-4 + P1-5 修订）

| 当前行模式 | 回车后续行 | 退出条件 |
|-----------|------------|----------|
| `- [ ] task` | `- [ ] ` | `- [ ] ` 后无内容 → 清除 |
| `1. item` | `2. `（编号 +1） | `1. ` 后无内容 → 清除 |
| `> quote` | `> ` | `> ` 后无内容 → 清除 |
| `- item` | `- ` | `- ` 后无内容 → 清除 |
| `* item` | `* ` | `* ` 后无内容 → 清除 |

**v1.1 修订（P1-5）：列表规则优先级**

**问题**：v1.0 顺序为 `- ` / `* ` / `1.` / `>` / `- [ ] `,导致 `- [ ] task` 先匹配 `- ` 变成 `-`,而非 checkbox 模式。

**v1.1 修订**：调整匹配顺序,**checkbox 优先**（最具体的模式先匹配）：

| 优先级 | 模式 | 原因 |
|--------|------|------|
| 1 | `- [ ] ` | 最具体（`- ` 的超集）,必须先匹配 |
| 2 | `\d+\. ` | 数字列表,与 `- ` / `* ` 无交集 |
| 3 | `> ` | 引用,与 `- ` / `* ` 无交集 |
| 4 | `- ` | 无序列表 |
| 5 | `* ` | 无序列表 |

**前缀检测**（v1.1：修复 regex + 优先级 + 基于 TextEditingValue）：
```dart
// blocks/input/auto_continue_rules.dart
class AutoContinueRules {
  /// v1.1 P1-5：按优先级排序,checkbox 最优先
  static const List<_ContinuePattern> _patterns = [
    // 优先级 1：checkbox（最具体,必须先匹配,否则会被 '- ' 抢先）
    _ContinuePattern(
      prefix: '- [ ] ',
      nextPrefix: '- [ ] ',
      regex: r'^- \[ \] (.*)$',  // v1.1 P0-4：修复 regex（原 r'^- \[ \] (.*)' 正确,但显式标注 $ 避免歧义）
    ),
    // 优先级 2：有序列表（编号 +1 动态计算）
    _ContinuePattern(
      prefix: r'\d+\. ',
      nextPrefix: null,  // null = 动态计算（数字 +1）
      regex: r'^(\d+)\. (.*)$',
    ),
    // 优先级 3：引用
    _ContinuePattern(
      prefix: '> ',
      nextPrefix: '> ',
      regex: r'^> (.*)$',
    ),
    // 优先级 4：无序列表（-）
    _ContinuePattern(
      prefix: '- ',
      nextPrefix: '- ',
      regex: r'^- (.*)$',
    ),
    // 优先级 5：无序列表（*）
    _ContinuePattern(
      prefix: '* ',
      nextPrefix: '* ',
      regex: r'^\* (.*)$',
    ),
  ];

  /// 检测 onChanged 是否触发了自动续列表。
  ///
  /// **v1.1 修订**：接收 [TextEditingValue] 而非 String,确保 composing 已检查。
  /// 返回 InsertNewLineWithPrefixCommand?（null = 不触发）。
  /// 调用方（InputHandler）已保证 composing == TextRange.empty,此处不再检查。
  static InsertNewLineWithPrefixCommand? detect({
    required TextEditingValue newValue,
    required BlockId blockId,
  }) {
    // 1. 检测 newValue.text 是否以 '\n' 结尾
    // 2. 提取倒数第二行（换行前的最后一行）
    // 3. 按优先级顺序匹配 _patterns（checkbox 优先）
    // 4. 若匹配且该行有内容 → 续行（追加 prefix）
    //    - 有序列表：编号 +1（如 '1.' → '2.'）
    // 5. 若匹配但该行无内容（只有前缀）→ 退出（清除前缀）
    //    - isExit = true
    // 6. v1.1 P0-3：Command 不携带 currentSource,Handler 读取
  }
}
```

**v1.1 P0-4 regex 修复说明**：
- 原 v1.0 regex `r'^- \[ \] (.*)'` 实际是正确的 Dart raw string（`\[` 和 `\]` 是正则转义）
- v1.1 显式添加 `$` 锚点（`r'^- \[ \] (.*)$'`）避免歧义,提升可读性
- 真正的 bug 是优先级问题（P1-5）：checkbox 必须在 `- ` 之前匹配

---

## 5. 测试计划

### 5.1 自动配对测试（`test/presentation/blocks/auto_pair_test.dart`）

| # | 测试用例 | 验证 |
|---|---------|------|
| 1 | 输入 `(` → 自动补 `)` | source 包含 `()`,光标在中间 |
| 2 | 输入 `[` → 自动补 `]` | source 包含 `[]`,光标在中间 |
| 3 | 输入 `{` → 自动补 `}` | source 包含 `{}`,光标在中间 |
| 4 | 输入 `` ` `` → 自动补 `` ` `` | source 包含 ` `` ``,光标在中间 |
| 5 | 有选区时输入 `(` → 包裹选区 | source 包含 `(selection)` |
| 6 | CodeBlock 输入 `(` → 不配对 | source 保持 `(` |
| 7 | 输入 `*` → 不配对（v1.3 禁止） | source 保持 `*` |
| 8 | 输入 `$` → 不配对 | source 保持 `$` |
| 9 | 输入 `#` → 不配对 | source 保持 `#` |
| 10 | Undo 撤销配对 → 只撤销 `)` | source 恢复为 `(` |
| 11 | Undo 再撤销 → 撤销 `(` | source 恢复为空 |
| 12 | **v1.1 P0-1**：IME composing 状态输入 `(` → 不配对 | source 保持 `(`,composing 期间不触发 |
| 13 | **v1.1 P0-2**：PairInsertCommand.insertOffset 正确 | 光标位置基于 insertOffset,非 selection 推断 |

### 5.2 自动续列表测试（`test/presentation/blocks/auto_continue_test.dart`）

| # | 测试用例 | 验证 |
|---|---------|------|
| 1 | `- item` + 回车 → `- ` | source 包含 `- item\n- ` |
| 2 | `* item` + 回车 → `* ` | source 包含 `* item\n* ` |
| 3 | `1. item` + 回车 → `2. ` | source 包含 `1. item\n2. ` |
| 4 | `> quote` + 回车 → `> ` | source 包含 `> quote\n> ` |
| 5 | `- [ ] task` + 回车 → `- [ ] ` | source 包含 `- [ ] task\n- [ ] ` |
| 6 | `- ` + 回车 → 清除前缀（退出） | source 只包含 `\n` |
| 7 | CodeBlock 回车 → 原样换行 | source 包含 `\n`,无续行前缀 |
| 8 | `1. item` + 回车 + `2. item2` + 回车 → `3. ` | 编号递增 |
| 9 | 普通文本 + 回车 → 无续行 | source 只包含 `\n` |
| 10 | Undo 撤销续行 → 只撤销前缀 | source 恢复为 `item\n` |
| 11 | **v1.1 P1-5**：`- [ ] task` 不被 `- ` 抢先匹配 | 续行 `- [ ] ` 而非 `- ` |
| 12 | **v1.1 P0-1**：IME composing 状态回车 → 不续行 | composing 期间不触发 |
| 13 | **v1.1 P0-3**：InsertNewLineWithPrefixCommand 无 currentSource 字段 | Command 不携带 State,Handler 读取 |

### 5.3 集成测试

| 测试 | 文件 | 验证 |
|------|------|------|
| 自动配对 + Toolbar 协作 | `integration_test/auto_pair_toolbar_test.dart` | 配对后按 B 按钮,选区正确 |
| 自动续列表 + Undo 协作 | `integration_test/auto_continue_undo_test.dart` | 续行后 undo,状态正确 |

---

## 6. 风险评估

| # | 风险 | 影响 | 概率 | 缓解措施 |
|---|------|------|------|----------|
| R1 | onChanged 检测配对符时与 IME 组合输入冲突 | High | Medium | 检测 composing region,组合输入态不触发配对 |
| R2 | 自动配对 undo 分两步,用户体验异常 | Medium | High | Phase 3.4+ 实现 Coalescing（合并相邻 ime origin Transaction） |
| R3 | onChanged + `\n` 检测在多行 Block 内逻辑复杂 | Medium | Medium | Phase 3.3 仅支持单行前缀续行,多行嵌套留 Phase 3.4+ |
| R4 | PairInsertCommand 与 _isCommitting 标志交互 | Medium | Medium | Command 产生的变化通过 didUpdateWidget 同步,设置 _isCommitting 防止反向同步 |
| R5 | 自动配对在选区跨越多行时行为未定义 | Low | Low | Phase 3.3 仅支持单行选区包裹,多行选区不触发配对 |
| R6 | 续行前缀检测正则表达式性能 | Low | Low | 5 种前缀,正则简单,无性能问题 |

---

## 7. 验收标准

### 7.1 功能验收

- [ ] 输入 `(` / `[` / `{` / `` ` `` 自动配对（4 种配对符）
- [ ] 有选区时配对符包裹选区
- [ ] CodeBlock 禁用自动配对
- [ ] `*` / `$` / `#` / `-` / `>` 不触发自动配对
- [ ] `- item` 回车自动续 `- `
- [ ] `1. item` 回车自动续 `2. `（编号递增）
- [ ] `> quote` 回车自动续 `> `
- [ ] `- [ ] task` 回车自动续 `- [ ] `
- [ ] 空行回车退出续行
- [ ] CodeBlock 回车原样换行
- [ ] Undo 可撤销自动配对 / 续列表操作

### 7.2 架构验收

- [ ] `flutter analyze --no-fatal-infos --fatal-warnings`：0 errors / 0 warnings
- [ ] `flutter test`：全部通过
- [ ] TC-ARCH-UI-4：editor_coordinator.dart ≤ 200 行
- [ ] ADR-0008：新 Command 子类与 sealed class 同文件
- [ ] Hard Rule 2.3：所有修改通过 EditorCommand → Coordinator.handle()
- [ ] 无 onChanged → 直接修改 controller.text 反模式
- [ ] **v1.1 P0-1**：composing region 检查 Hard Rule（§2.1.1）
- [ ] **v1.1 P0-2**：PairInsertCommand 含 insertOffset,不通过 selection 推断
- [ ] **v1.1 P0-3**：InsertNewLineWithPrefixCommand 无 currentSource（Command 不携带 State）
- [ ] **v1.1 P1-5**：列表规则优先级（checkbox 优先于 `- `）
- [ ] **v1.1 P1-6**：BaseBlockState 委托 InputHandler,不直接实现规则（§2.6）

---

## 8. Human Owner 决策审批结果（v1.1 已审批）

### 8.1 IME 兼容性方案（§2.1）— ✅ Approved

**审批结果**：onChanged 统一路径 + composing region 检查 Hard Rule。

**附加约束**（v1.1 P0-1）：必须检测 `TextEditingValue.composing`,`composing != TextRange.empty` 时禁止自动行为。详见 §2.1.1。

### 8.2 CommandOrigin 与 Coalescing（§2.2）— ✅ Approved

**审批结果**：`CommandOrigin.ime` + 不合并（两个独立 undo 步骤）。

**Phase 3.4 技术债**：IME Transaction Coalescing（合并相邻 ime origin Transaction,实现 undo 1 次撤销 `()`）。待 ADR 记录。

### 8.3 PR 拆分策略 — ✅ Approved

**审批结果**：单一 PR #3（自动配对 + 自动续列表）+ 小 commit 划分。

**commit 划分**（§9）：6 个小 commit,保持可回滚。

---

## 9. 实施顺序（v1.1：小 commit 划分,保持可回滚）

按 Human Owner §8.3 审批,采用 6 个小 commit,每个 commit 独立可回滚：

### Commit 1: Add PairInsertCommand + InsertNewLineWithPrefixCommand

**文件**：`editor_command.dart` + `commands.dart`
**内容**：
- 新增 `PairInsertMode` enum
- 新增 `PairInsertCommand`（v1.1：含 `insertOffset`,无 `prefixChar` / `selection`）
- 新增 `InsertNewLineWithPrefixCommand`（v1.1：无 `currentSource`）
- `commands.dart` re-export

### Commit 2: Add CommandHandler dispatch + _handle* methods

**文件**：`command_handler.dart` + `editor_coordinator.dart`
**内容**：
- `_dispatch` 新增 2 个 case（PairInsert + NewLineWithPrefix）
- `_handlePairInsert`（v1.1：基于 `insertOffset`）
- `_handleNewLineWithPrefix`（v1.1：Handler 读取 source）
- `EditorCoordinator._syncSelectionAfterCommand` 新增 2 个 case

### Commit 3: Add AutoPairRules + tests

**文件**：`blocks/input/auto_pair_rules.dart` + `test/.../auto_pair_test.dart`
**内容**：
- 配对规则表（4 种配对符）
- `detect()` 方法（v1.1：接收 `TextEditingValue`）
- 单元测试（11 用例）

### Commit 4: Add AutoContinueRules + tests

**文件**：`blocks/input/auto_continue_rules.dart` + `test/.../auto_continue_test.dart`
**内容**：
- 续行规则表（v1.1：优先级排序,checkbox 优先）
- `detect()` 方法（v1.1：接收 `TextEditingValue`）
- 单元测试（10 用例）

### Commit 5: Wire BaseBlockState input pipeline

**文件**：`blocks/base_block_state.dart` + `blocks/input/input_handler.dart`
**内容**：
- `InputHandler` 入口（协调 auto pair + auto continue）
- `BaseBlockState.buildEditField` 新增 `onChanged: _onTextChanged`
- `_onTextChanged`（v1.1：composing 检查 + 委托 InputHandler）
- CodeBlock 例外处理

### Commit 6: Integration tests + verification

**文件**：`integration_test/auto_pair_toolbar_test.dart` + `integration_test/auto_continue_undo_test.dart`
**内容**：
- 自动配对 + Toolbar 协作测试
- 自动续列表 + Undo 协作测试
- `flutter analyze` + `flutter test` 验证

---

**本 Task Contract 由 AI Agent 起草,版本 v1.1,状态 Accepted（Human Owner v1.0 审批 "Approved with changes",v1.1 落地 6 项修改）。**
