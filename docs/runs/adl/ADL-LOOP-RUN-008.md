# ADL Loop Run #008 — Phase 3.9 Capability Audit Batch 1

**日期**: 2026-08-18
**前置**: Run #001-007 已完成 ADI 全链路（Observe → Persist → Orchestrate → Validate → Verify → Autonomous → Formal）
**状态**: ✅ Batch 1 审计完成（12 项全部执行；发现 3 个真实 bug，已修复并产出 Regression Asset）
**下一步**: Batch 2（Behavior Audit 或 Batch 1 扩展审计项）

---

## 执行摘要

Run #008 执行 Phase 3.9 第一步：**Capability Audit Batch 1**（见
ADL-LOOP-RUN-008-PLAN.md）。审计覆盖 4 域 12 项，核心成果：

1. **CAP-008 round-trip fuzz 发现 3 个真实 parser bug**（全部已修复）
2. 其余 11 项审计全部通过现有测试基线（无新发现）
3. 新增 `roundtrip_fuzz_test.dart` 作为 Regression Asset（1000 轮随机语料常驻 CI）

## 审计执行明细

### 基线审计（CAP-001/002/003/004/005/006/007 Parser）

| 审计项 | 覆盖文件 | 结果 |
|--------|---------|------|
| CAP-001/002/004/005/007（heading/list/code/formula/inline） | markdown_parser_test + inline_parser_test + serializer_test | ✅ 65 项全绿 |
| CAP-008 round-trip fuzz | **roundtrip_fuzz_test.dart（新增）** | ✅ 1000 轮 + sanity 全绿 |
| CAP-009 boundary | edge_case_test（未配对 `* _ ~ \` [ ] ~` 20 用例）+ resilience | ✅ 34 项全绿 |
| CAP-010/011 editing | undo_redo 3 文件 + transaction 原子性 3 文件 | ✅ 56 项全绿 |
| CAP-012 export | export_integration + svg_to_pdf + word_ooxml | ✅ 64 项全绿 |

## 发现并修复的 3 个真实 bug（ADL Loop 闭环）

> fuzz 测试（CAP-008）第 1 轮即发现 round-trip 结构不一致；逐一最小
> 复现 → 定位根因 → 修复 → 回归。修复全部位于
> `lib/core/parser/markdown_parser.dart`（+17/-3），现有 126 项 parser 相关
> 测试 + fuzz 1000 轮全部通过。

### BUG-1：多行段落合并丢失硬换行（round-trip 不保真）

**现象**：`α β γ   leading\n--- tab...` parse 后 4 个 inline → serialize →
重新 parse 只剩 3 个 inline（换行信息丢失，结构不一致）。

**根因**：parser 合并多行段落到 `pendingParagraph` 时用
`children.addAll(inline)` 直接拼接，`\n`（Markdown hard-break）未保留。

**修复**：合并前若 children 非空，先 `add(TextElement('\n'))`。

### BUG-2：`|` 开头非表格行被静默吞掉（数据丢失）

**现象**：`|pipe| a_b trailing`（不以 `|` 结尾、非合法表格行）在
parse→serialize 后**整行消失**。

**根因**：parser 的 `trimmedLine.startsWith('|')` 分支中 `_parseTableRow`
返回 null 时仍 `continue`，未降级为段落。

**修复**：cells == null 时不再 continue，flushTable 后降级为普通段落解析。

### BUG-3：列表项后紧跟段落时列表被延迟到文档末尾（顺序错误）

**现象**：`line\nbreak\n- item\n中文测试` round-trip 后 `- item` 被移到最后。

**根因**：普通段落分支前未 `flushListItems()`——挂起的列表要等文档结束
才 flush，顺序错乱。

**修复**：段落分支前显式 `flushListItems()`。

## Regression Asset

```text
flutter_app/test/parser/roundtrip_fuzz_test.dart（新增，~240 行）
  - MarkdownCorpusGenerator：固定 seed（20260817）可复现随机语料
  - 1000 轮：不崩溃 + parse→serialize→parse→serialize 收敛不动点
  - AST 结构等价比较器（sealed switch，覆盖全部 DocumentElement 类型）
```

此测试是 Batch 1 发现 3 个 bug 的直接工具，常驻 test 套件防止回归。

## 关键设计决策

1. **fuzz 语料设计**：fragment 池（含中文/公式/边界字符）+ block 池
   （heading/list/code/table/hr/formula），随机拼接；固定 seed 保证可复现。
   两个边界契约明确记录：
   - 不生成空行（EmptyLineElement 是块分隔符，serializer 契约要求调用方过滤）
   - 行内前缀从 fragment 池取（从 block 池取会拿到 ` ``` ` 未闭合 fence）
2. **AST 比较器用显式类型检查**而非双类型 record pattern（本 SDK 版本
   pattern 变量绑定不稳定，AGENTS.md §11.3 教训：保守写法优先）。
3. **fuzz 断言 = 不动点 + 结构等价**：`serialize(parse(serialize(parse(md))))
   == serialize(parse(md))`（二次 round-trip 收敛），比逐字 round-trip
   宽松但能捕获真实保真问题（本次即命中 3 个）。

## 审计结论

```text
Capability Audit Batch 1: 12 项执行完毕
  Parser 7 项    ✅ 基线全绿（fuzz 发现并修复 3 bug）
  Serializer 2 项 ✅（round-trip fuzz 覆盖 + boundary 34 项）
  Editing 2 项   ✅ 56 项全绿（undo-redo / transaction 原子性不变量）
  Export 1 项    ✅ 64 项全绿（markdown/word/pdf 导出集成）

发现 bug: 3（BUG-1 硬换行丢失 / BUG-2 `|` 行吞掉 / BUG-3 列表顺序）
修复:    3（markdown_parser.dart +17/-3，ADL Loop 闭环）
Regression Asset: roundtrip_fuzz_test.dart（1000 轮常驻 CI）
```

## 遗留与下一步

1. **Batch 2（Behavior Audit，2026-08-18 已执行）**：Enter/Backspace/Block
   split-merge 操作语义（split/merge 29 项 + CommandHandler 分派 35 项）+ 
   IME/composing/selection/focus（9 文件 99 项）**全部通过，未发现新 bug**。
2. **Batch 3（fuzz 扩展 + 多 seed，2026-08-18 已执行）**：语料池扩展
   （表格 cell 内公式 / Mermaid / 多行 code / 多列 table / CRLF 混合）+ 
   多 seed 参数化（FUZZ_SEED / FUZZ_ROUNDS dart-define）→ **发现并修复
   CRLF 任务列表 bug**（见附录 Batch 3）。
3. **Batch 4（ListElement 嵌套 AST，2026-08-18 已执行 + PR #154 已合并）**：
   ADR-0029 落地，修复 BUG-5（嵌套列表 round-trip 不保真），fuzz 恢复嵌套语料。
4. **Batch 5（专项审计扩展，2026-08-18 已执行）**：fuzz 多 seed CI 化 +
   Mermaid 专项（修复空代码块丢弃 bug）+ 表格 cell 公式专项 + undo-redo
   行为 fuzz（见附录 Batch 5）。
5. **Batch 6 候选**：Experience Audit（真机/Golden/手势/主题/输入延迟）。

---

## 附录：Batch 5 专项审计扩展（2026-08-18）

### 1. fuzz 多 seed CI 化（roundtrip_fuzz_test.dart）

主循环抽取为 `runFuzzScan(seed, rounds)`，新增 **multi-seed 扫描测试**
（5 seed × 200 轮：1 / 42 / 20260818 / 9999 / 314159）——CI 全量
自动覆盖多 seed，无需 workflow 改动；本地仍可 `--dart-define=FUZZ_SEED`
精细扫描。

### 2. Mermaid 专项审计（mermaid_audit_test.dart，新增 7 项）

| 审计项 | 结果 |
|--------|------|
| round-trip 保真（graph/flowchart/sequence/class + 中文节点） | ✅ |
| 空 Mermaid 块 | ✅ **发现并修复 BUG-6** |
| 无语言标注 code block 不误判 | ✅ |
| ```mermaid + 尾随空格 | ✅ |
| CRLF 混合 | ✅ |
| 内容含反引号/尖括号/公式符号 | ✅ |
| 相邻块交互（列表/段落紧邻） | ✅ |

**BUG-6（修复）**：空代码块（```` ```mermaid\n``` ````）被
`flushCodeBlock` 的 `if (codeLines.isEmpty) return;` 整体丢弃
（0 元素）→ round-trip 数据丢失。修复：移除 isEmpty 守卫，
空块也产出 `MermaidElement(code: '')` / `CodeElement`。

### 3. 表格 cell 内公式专项审计（table_formula_audit_test.dart，新增 6 项）

| 审计项 | 结果 |
|--------|------|
| round-trip 保真（cell 内公式） | ✅ |
| 公式 + 粗体/行内代码混合 | ✅ |
| 公式含竖线（\| 转义容错，不崩溃） | ✅ |
| 空 cell / 单 cell 表格 | ✅ |
| 分隔行含公式样式不误判 | ✅ |
| 含公式 cell 的多行表格 | ✅ |

**无新 bug**——表格 cell 内公式 round-trip 全保真。

### 4. undo-redo 行为 fuzz（undo_redo_fuzz_test.dart，新增 2 项）

随机 BlockOperation 序列（insert/delete/merge/split）apply → undo 全部
→ redo 全部 → 状态一致性断言（含二次 undo 幂等）+ 5 seed × 40 步扫描。
**无新 bug**。

### Batch 5 结论

```text
fuzz 多 seed CI 化        ✅ multi-seed 扫描测试（5 seed × 200 轮）
Mermaid 专项              ✅ 7 项全绿（发现并修复 BUG-6 空块丢弃）
表格 cell 公式专项        ✅ 6 项全绿（无新 bug）
undo-redo 行为 fuzz       ✅ 2 项全绿（5 seed × 40 步，无新 bug）
发现 bug: 1（BUG-6 空代码块丢弃，已修复）
```

---

## 附录：Batch 3 fuzz 扩展 + 多 seed（2026-08-18）

### 语料池扩展

`roundtrip_fuzz_test.dart` `_blocks` 池新增（Batch 3）：

```text
表格 cell 内公式（| $x$ | **bold** | / | $\\frac{1}{2}$ |）
Mermaid 块（```mermaid graph TD A-->B ```）
多行 code（```\nmultiline\ncode\nblock\n```）
多列 table（| a | b | c |）
有序/无序多行列表（1. one\n1. two / - a\n- b）
CRLF 混合（~15% 概率整篇 \r\n）
```

注意：**不放嵌套列表块** —— 当前 ListElement AST 是「拍平」设计
（嵌套子项合并进父项文本，`markdown_parser_test` 列表嵌套组锁定），
round-trip 不保真（BUG-5，见下）。

### 多 seed 参数化

```dart
// CI 默认：seed=20260817, 1000 轮
// 本地扫描：--dart-define=FUZZ_SEED=<n> --dart-define=FUZZ_ROUNDS=<n>
const seedStr = String.fromEnvironment('FUZZ_SEED', defaultValue: '20260817');
const rounds = int.fromEnvironment('FUZZ_ROUNDS', defaultValue: 1000);
```

本地 3 个 seed（7 / 20260818 / 9999）各 300 轮扫描全部通过。

### BUG-4（修复）：CRLF 任务列表误解析为普通列表项

**现象**：`- [x] task\r\n`（CRLF 输入）解析为 `ListElement` 而非
`TaskListItemElement`；LF 输入正常。round=64 的 CRLF 混合文档
parse→serialize→parse 结构不一致。

**根因**：taskMatch 正则 `^\s*- \[( |x|X)\]\s+(.+)$` 匹配原始 `line`
（尾部含 `\r`），`.` 不匹配 `\r` → taskMatch 失败 → 落入普通列表分支。

**修复**（`markdown_parser.dart`）：taskMatch 改用 `trimmedLine` 匹配
（与列表分支一致，trim 已去除 `\r`）。

**验证**：CRLF `- [x] task\r\n` → TaskListItemElement ✅；parser 全组合
160 项全绿；fuzz 默认 seed 1000 轮 + 3 个扫描 seed 全绿。

### BUG-5（已知限制，Batch 4 候选）：ListElement 嵌套 AST 拍平

**现象**：`- 水果\n  - 苹果\n  - 香蕉`（现有测试锁定的合并行为）round-trip
后 `苹果`/`香蕉` 变 ParagraphElement——嵌套子项被合并进父项文本，结构
信息在 AST 中丢失，serialize 后不可逆。

**根因**：`ListElement` AST 无嵌套子项结构（只有 children + ordered +
indent），parser 把缩进子项文本拼入父项 children（`markdown_parser_test`
列表嵌套组锁定此行为）。

**处置**：已知限制，fuzz 语料豁免嵌套列表块；**Batch 4 专项候选：
ListElement 嵌套 AST 重构**（需同步更新 BlockEditor 编辑模型，超审计
范围，按 AGENTS.md §6.3.3 不混入本 PR）。

### Batch 3 结论

```text
fuzz 扩展 + 多 seed: 语料池 4 类新增 + CRLF 混合 + 3 seed 扫描全绿 ✅
发现 bug: 1（BUG-4 CRLF 任务列表，已修复）
已知限制: 1（BUG-5 嵌套列表 AST 拍平，Batch 4 候选）
Regression Asset: roundtrip_fuzz_test.dart 语料扩展 + 多 seed 参数化
```

---

## 附录：Batch 2 Behavior Audit（2026-08-18）

Batch 1（Capability）聚焦「能不能正确做」；Batch 2（Behavior）聚焦
「用户这么操作后系统行为是否正确」。

### 审计范围与结果

| 行为域 | 覆盖 | 结果 |
|--------|------|------|
| Block split/merge | block_operations_split_transform / split_undo / split_merge_domain | ✅ 29 项全绿 |
| Enter/Backspace 操作语义 | CommandHandler 分派（SplitBlockCommand / MergeWithPreviousCommand / DeleteBlockCommand / InsertTextCommand / PairInsertCommand 等） | ✅ 35 项全绿 |
| IME composing 状态机 | composing_controller / composing_state / ime_mutation_forbidden | ✅ 全绿 |
| Selection/Focus | selection_cursor_domain / selection_sync / coordinator_state_focuson | ✅ 全绿 |
| IME 事件观测 | p0_ime_composing_event / p0_selection_changed_event（ADI 观测面） | ✅ 全绿 |
| IME 事务集成 | ime_transaction_integration | ✅ 全绿 |

**合计：163 项全绿，未发现新 bug**（Batch 1 的 3 个 parser bug 已修复，
Batch 2 未触发新回归）。

### Batch 2 结论

```text
Behavior Audit: 操作语义 + IME/Selection/Focus 共 163 项全绿 ✅
发现 bug: 0（Batch 1 修复的 3 个 parser bug 无回归）
Regression Asset: 无新增（Batch 1 roundtrip_fuzz_test.dart 已常驻）
```
