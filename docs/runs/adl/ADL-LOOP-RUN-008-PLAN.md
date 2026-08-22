# ADL Loop Run #008 — Phase 3.9 Product Capability Audit（第一步规划）

**日期**: 2026-08-17
**前置**: Run #001-007 已完成 ADI 全链路（Observe → Persist → Orchestrate → Validate → Verify → Autonomous → Formal）
**状态**: 方案设计（Phase 3.9 第一步：Capability Audit）
**下一步**: 按首批审计项执行 Capability Audit → 发现问题进入 ADL Loop → 产出 Regression Asset

---

## 1. Phase 3.9 定位

Phase 3.8 技术 Gate 已收官（F1-F7 形式化验收通过）。不再继续堆 ADI 能力，
而是用已跑通的 ADL Loop **审计 FormulaFix 本身**：

```text
               FormulaFix Audit
                      │
        ┌─────────────┼─────────────┐
        ↓             ↓             ↓
   Capability      Behavior       Experience
      Audit          Audit          Audit
        │             │             │
       FFX        E2E + ADI      真机/Golden/
                                  Gesture/IME
```

- **Capability Audit**（本 Run，先行）：Markdown / Parser / Serializer / Formula /
  CodeBlock / List / Export / Autosave / Undo-Redo —— 问「能不能正确做」
- **Behavior Audit**（后续）：Enter / Backspace / Undo / Redo / Selection / Focus /
  IME / Block split-merge —— 问「用户这么操作后行为是否正确」
- **Experience Audit**（最后）：焦点 / 键盘 / 滚动 / 布局 / 小屏 / 主题 / 输入延迟 ——
  问「真的像 Typora/Obsidian/VSCode 那样自然吗」

Capability Audit 先行原因：可自动化、可量化，且有现成的 175 个测试文件作为基线。

---

## 2. 审计项契约模板（Audit Item Contract）

每个审计项必须完整填写以下 8 字段，缺一不可（缺失 = 审计项不成立）：

```yaml
id:          CAP-xxx              # 唯一编号
capability:  能力域 / 子能力       # 如 parser/heading
触发方式:    用户或系统如何触发     # 输入、命令、手势、文件加载
期望行为:    正确性断言            # 可自动化验证的期望结果
ADI 观察点:  失败时如何被捕获       # observation 类型 + 进入 ADL Loop 的路径
现有覆盖:    映射到现有测试         # 测试文件:测试名，或"缺口"
审计方法:    unit | integration | 真机
优先级:      P0（核心路径）| P1（常用）| P2（边缘）
```

---

## 3. 首批审计项清单（Capability Audit Batch 1，共 12 项）

### 3.1 Parser 域（Markdown 解析，P0）

| # | capability | 触发方式 | 期望行为 | ADI 观察点 | 现有覆盖 | 方法 | 优先级 |
|---|-----------|---------|---------|-----------|---------|------|--------|
| CAP-001 | parser/heading | 输入 `# Title` 等 6 级标题 | 解析为 HeadingElement(level, text) | 解析失败 → GlobalError → RenderOverflow 同链路 | markdown_parser_test.dart:Heading | unit | P0 |
| CAP-002 | parser/list | 输入 `- item` / `1. item` / 嵌套 | 解析为 ListElement(children, ordered, indent) | 同上 | markdown_parser_test.dart:List (18) | unit | P0 |
| CAP-003 | parser/table | 输入 `\| h1 \| h2 \|` + 分隔行 + 行 | 解析为 TableElement(headers, rows) | 同上 | edge_case_test.dart（表） | unit | P0 |
| CAP-004 | parser/code | 输入 ``` 代码块 + 语言标注 | 解析为 CodeElement(code, language) | 同上 | markdown_serializer_test.dart:Code (3) | unit | P0 |
| CAP-005 | parser/formula | 输入 `$$...$$` 与 `$...$` | 解析为 FormulaElement（display/inline） | 同上 | markdown_parser_test.dart:Formula (6) | unit | P0 |
| CAP-006 | parser/mermaid | 输入 ```mermaid 图 | 解析为 MermaidElement(source) | 同上 | edge_case_test.dart（mermaid） | unit | P1 |
| CAP-007 | parser/inline | Bold/Italic/Strikethrough/InlineCode/Link 组合嵌套 | 解析为对应 InlineElement 树 | 同上 | edge_case_test.dart:Bold (12)/Italic (8)/Strikethrough (6)/Link (3)/InlineCode (3) | unit | P0 |

### 3.2 Serializer 域（round-trip，P0）

| # | capability | 触发方式 | 期望行为 | ADI 观察点 | 现有覆盖 | 方法 | 优先级 |
|---|-----------|---------|---------|-----------|---------|------|--------|
| CAP-008 | serializer/roundtrip | 任意合法 Markdown → parse → serialize | 序列化结果与原文语义等价（round-trip 一致） | 不一致 → 断言失败 → 捕获 | markdown_serializer_test.dart:Paragraph (11) | unit | P0 |
| CAP-009 | serializer/boundary | 含未配对 `* _ ` [ ] ~` 的文本 | 不误识别、不崩溃（ADR-0007 边界） | 同上 | edge_case_test.dart（边界字符） | unit | P1 |

### 3.3 Editing 域（P0）

| # | capability | 触发方式 | 期望行为 | ADI 观察点 | 现有覆盖 | 方法 | 优先级 |
|---|-----------|---------|---------|-----------|---------|------|--------|
| CAP-010 | editing/undo-redo | insert/delete → undo/redo | 状态恢复到预期快照，history 栈一致 | 状态损坏 → InvariantViolation → 捕获 | block_operations_split_undo_test.dart 等 editing/ (15+ 文件) | unit | P0 |
| CAP-011 | editing/transaction | 多操作组合 → commit/rollback | 原子性：全成或全不成 | 半提交 → TransactionRollback → 捕获 | command_handler_atomicity_test.dart | unit | P0 |

### 3.4 Export 域（P1）

| # | capability | 触发方式 | 期望行为 | ADI 观察点 | 现有覆盖 | 方法 | 优先级 |
|---|-----------|---------|---------|-----------|---------|------|--------|
| CAP-012 | export/markdown-word-pdf-txt | 文档 → 各导出格式 | 字节流非空、内容保真、公式/Mermaid 正确渲染 | 导出失败 → ExportFailure → classifyError | export_integration_test.dart / word_ooxml_builder_test.dart / svg_to_pdf_integration_test.dart | integration | P1 |

---

## 4. 与 ADL Loop 的接入点（关键设计）

**审计发现问题如何进入已跑通的 ADL Loop**：

```text
Capability Audit（unit/integration 断言）
        ↓ 失败
ADI 捕获（ErrorSnapshot → observation → 分类）
        ↓
ffx adi latest-error / trace-show / replay
        ↓
Agent reasoning → 真实 git diff（Run #005/006/007 已验证链路）
        ↓
Fresh build → validate（F1-F7 形式化验收）
        ↓
Regression Asset（新测试加入 test/ 基线）
        ↓
Capability Audit 再跑（闭环回归）
```

**关键差异（相对 Run #006/007）**：此前的 bug 由 FaultInjection 或注入的
`SizedBox` 确定性触发；Phase 3.9 的 bug 来自**真实产品断言失败**（如 parser
round-trip 不一致、undo 状态损坏）——ADI 需要能捕获这些非 RenderOverflow
类别的真实失败（InvariantViolation / TransactionRollback / ExportFailure 等）。

**执行顺序（Batch 1 第一步）**：
1. CAP-001/002/004/005/007（parser 核心，P0）：跑现有测试确认基线全绿
2. CAP-008（round-trip）：新增**随机语料 round-trip 模糊测试**（fuzz 1000 轮），
   最可能发现真实 bug —— 这是 Batch 1 的首个「主动找 bug」动作
3. CAP-010/011（editing）：验证 undo-redo 与事务原子性的不变量（InvariantChecker 已在）
4. CAP-012（export）：集成级导出断言

**成功标准（Batch 1）**：12 项审计全部执行，基线全绿；若 fuzz/断言发现真实 bug，
至少 1 个进入 ADL Loop 并产出 Regression Asset（新增测试）。

---

## 5. 风险与边界

- **审计 ≠ 修 bug**：本 Run 只负责「发现并记录」；修复由 ADL Loop 的
  Agent Repair 阶段完成（或人工修复后由 ADI 验证）。
- **范围控制**：Batch 1 限 Parser/Serializer/Editing/Export 四域 12 项；
  Behavior/Experience Audit 不在本 Run。
- **CI 安全**：审计测试与现有测试同层，不新增 dart-define 门控
  （真实断言本就应常驻测试集）。
