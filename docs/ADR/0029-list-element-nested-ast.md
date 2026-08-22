# ADR-0029：ListElement 嵌套 AST 结构（修复嵌套列表 round-trip 不保真）

- **状态**：Proposed（Run #008 Batch 4，2026-08-18）
- **日期**：2026-08-18
- **决策者**：Human Owner（评审通过后 Accepted）
- **关联**：[ADR-0004 Markdown Parser Extension Strategy](./0004-markdown-parser-extension-strategy.md) / [ADL-LOOP-RUN-008.md](../runs/adl/ADL-LOOP-RUN-008.md)（BUG-5）

> **一句话决策**：`ListElement` 增加 `nested` 字段（`List<ListElement>`）承载嵌套子项，
> parser 不再把缩进子项**拍平合并**进父项文本，而是构建嵌套结构；serializer 递归
> 序列化。修复 BUG-5（嵌套列表 parse→serialize→parse 结构不一致，子项丢失列表语义）。

---

## 0. 背景

Run #008 Batch 3（ADL-LOOP-RUN-008.md 附录 BUG-5）fuzz 审计发现：

```text
输入:  - 水果\n  - 苹果\n  - 香蕉
parse#1: ListElement(o=false, i=1, children=[Text("水果\n  苹果\n  香蕉")])   ← 拍平合并
serialize: "  - 水果\n  苹果\n  香蕉"                                          ← 续行无前缀
parse#2: ListElement(o=false, i=1, children=[Text("水果")]), ParagraphElement   ← 苹果/香蕉变段落！
```

**根因**：`ListElement` 当前只有 `children + ordered + indent`，**没有嵌套子项结构**。
parser 遇到缩进子项（`  - 苹果`）时走 `indent > 0` 合并分支（markdown_parser.dart
`pendingListItems` 逻辑），把子项文本拼进父项 children（`"水果\n  苹果\n  香蕉"`）。
serialize 时 `InlineSerializer` 原样输出含 `\n` 的文本，续行无 `- ` 前缀；
重新 parse 时续行不再被识别为列表项 → 结构不一致（round-trip 不保真）。

**影响面**（调研）：`ListElement` 被 15 个文件引用；核心依赖为
block_types（类型映射）、block_operation（merge 判断 ordered 一致性）、
text/pdf exporter（消费 children+indent）、block_renderer（走 Fallback）、
command_replayer（`'list'` 命令回放构造）。

## 1. 决策

### 1.1 AST 结构：`ListElement` 增加 `nested` 字段

```dart
class ListElement extends DocumentElement {
  final List<InlineElement> children;   // 本项行内内容（不变）
  final bool ordered;                   // 本项是否有序（不变）
  final int indent;                     // 本项缩进层级（不变，用于渲染/导出）
  final List<ListElement> nested;       // 新增：嵌套子项列表（默认空）

  const ListElement({
    required this.children,
    this.ordered = false,
    this.indent = 0,
    this.nested = const [],
  });
}
```

- 兼容：`nested` 默认 `const []`，现有 `ListElement(children: ...)` 构造全部可用
- 语义：`nested` 只表达**列表嵌套**（`- a\n  - b`），不表达段落内续行
  （`- a\n  continuation` 仍是 children 内 `\n` 文本，见 §3 边界）

### 1.2 parser：构建嵌套而非拍平

`pendingListItems` 逻辑改为**按 indent 分层**：

```text
维护 List<ListElement> stack（按 indent 深度）
新列表项 indent > 栈顶 indent → 作为栈顶项的 nested 子项
indent == 栈顶 indent   → 同级新项
indent < 栈顶 indent    → 弹栈直到 indent 匹配
```

- 移除去掉缩进子项拍平合并逻辑（`indent > 0` merge 分支）
- 注意：`- [ ] task`（TaskListItemElement）不参与嵌套（独立元素，保持现状）

### 1.3 serializer：递归序列化

`block_serializer.dart` `fromElement` 的 ListElement 分支：

```dart
String _serializeListElement(ListElement e) {
  final prefix = e.ordered ? '1. ' : '- ';
  final self = '${'  ' * e.indent}$prefix${InlineSerializer.serialize(e.children)}';
  if (e.nested.isEmpty) return self;
  return [self, ...e.nested.map(_serializeListElement)].join('\n');
}
```

- 嵌套子项递归输出（其自身 indent 字段已含正确缩进）
- 注意：有序列表嵌套输出仍用 `1. ` 前缀（Markdown 有序列表编号由渲染器处理，
  round-trip 只要求结构一致，不要求编号连续）

### 1.4 编辑模型适配（最小改动）

- `block_types.dart`：`ListElement => listItem` 不变（类型仍是 listItem）
- `block_operation.dart`：`canMerge` 判断增加 `nested` 兼容性
  （两列表项 nested 结构可合并才合并；否则回退 paragraph）
- `command_replayer.dart` `'list'` 构造：`nested: (m['nested'] as List?)?.map(...)` 可选
- exporters（text/pdf/word）：nested 子项递归导出（否则导出丢失嵌套）

## 2. 动机

1. **round-trip 保真是 Phase 3.9 审计的硬目标**：BUG-5 是 fuzz 发现的真实
   数据保真缺陷，嵌套列表在真实 Markdown 文档中常见（TODO 大纲 / 层级清单）。
2. **AST 语义正确性**：嵌套列表本质是树结构，当前拍平为文本违背 AST 语义；
   编辑模型（BlockEditor）将来操作嵌套列表（缩进/提升）需要结构化表达。
3. **为导出器/渲染器铺路**：text/pdf 导出嵌套列表当前依赖 `indent` 字段
   （`'  ' * indent + prefix`），有嵌套结构后可递归生成正确前缀。

## 3. 后果

### 正面

- 嵌套列表 round-trip 保真（fuzz 断言可恢复嵌套语料）
- AST 语义正确（树结构而非拍平文本）
- 导出器/渲染器获得结构化嵌套信息

### 负面 / 边界

- **段落内续行仍走文本**：`- a\n  continuation`（缩进无列表标记）仍作为
  children 内 `\n` 文本（当前行为，不因本 ADR 改变）
- **有序列表编号不保真**：`1. a\n1. b` serialize→parse 编号重置为 `1.`
  （Markdown 语义允许；round-trip 断言基于结构等价，不要求编号连续）
- **TaskListItemElement 不嵌套**：`- [ ] a\n  - [ ] b` 中子项仍是独立元素
  （TaskListItemElement 无 nested；如需要可作 v0.2 扩展）
- **编辑模型影响面**：block_operation merge / command_replayer / exporters
  需同步适配（本 ADR 列出的 5 处）；BlockEditor 渲染走 Fallback 无需改

## 4. 替代方案

| 方案 | 描述 | 否决原因 |
|------|------|---------|
| **A：ListElement.nested 字段（采纳）** | children + ordered + indent + nested | 最小侵入：现有构造兼容，parser/serializer 局部改造 |
| B：独立 NestedListElement 类型 | 新类型表达嵌套 | 引入新 BlockType，编辑模型/导出器全链路都要加分支，侵入大 |
| C：保持拍平 + serializer 修复 | serializer 对含 `\n` children 输出续行前缀 | 无法区分「续行内容」与「嵌套子项」，本质问题未解决 |
| D：AST 加独立 ListItem 节点（children 内嵌） | 列表项为树节点 | 改动范围等同方案 A 但破坏 BlockType.listItem 映射，风险更高 |

## 5. 验收 / Exit Criteria

- [ ] `- 水果\n  - 苹果\n  - 香蕉` round-trip 结构等价（3 个嵌套 ListElement）
- [ ] `1. 项目\n  1. 子项目` round-trip 结构等价
- [ ] roundtrip_fuzz_test.dart 恢复嵌套列表语料（`_blocks` 池），1000 轮全绿
- [ ] parser 全组合 + editing + export 测试全绿（无回归）
- [ ] flutter analyze 0 error / 0 warning

> **维护注意**：任何消费 `ListElement.children` 的代码（渲染/导出/编辑操作）
> 若需处理嵌套，必须遍历 `nested`；`indent` 字段保持为「本项缩进」语义。
