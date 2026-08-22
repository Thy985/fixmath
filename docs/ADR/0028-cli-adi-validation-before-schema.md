# ADR-0028：CLI AdiValidationBefore Schema 收敛（粗粒度并集）

- **状态**：Accepted（随 Run #007 F2 修复落地，2026-08-17）
- **日期**：2026-08-17
- **决策者**：Human Owner（评审通过）
- **关联**：[ADR-0024 Agent Diagnostic Interface](./0024-agent-diagnostic-interface.md)（§2.4 Validation Adapter 定义 Dart 侧 `before` 枚举）/ [ADI Design Document v1.0](../design/adi-design-v1.md) / [ADL-LOOP-RUN-007.md](../runs/adl/ADL-LOOP-RUN-007.md)（F2 验收）

> **一句话决策**：CLI `adi validate` 输出的 `before` 字段从 Dart 侧的多值枚举
> **收敛为二值** `'reproduced' / 'unknown'`——它表达的是「该 session 是否
> 出现过错误」的**粗粒度并集**，刻意降低信息密度，便于 Agent 跨语言消费；
> 精细分类（crash/fallback/invariantViolation）保留在 Dart 侧
> `AdiValidationBefore` 枚举（`adi_view.dart`），未来 v0.3 协议版本再对齐。

---

## 0. 背景

Run #007（commit `19ba062`）为完成 F2 验收（`before=reproduced` 绑定），
在 `tools/adi/adi.dart` 新增 `_deriveBeforeStatus(sessionId)`：遍历
`.adi/observations/*.json`，按 sessionId 匹配错误记录 → 返回
`'reproduced'`；否则返回 `'unknown'`。

与此同时，Dart 侧（`flutter_app/lib/core/observability/adi_view.dart`，
ADR-0024 §2.4 定义）已有精细枚举：

```dart
enum AdiValidationBefore {
  crash,                // 崩溃 / 异常
  fallback,             // 渲染降级 / fallback
  invariantViolation,   // 不变量违反（状态损坏）
  unknown,              // 未知 / 未分类
}
```

**问题**：CLI 输出（`'reproduced' / 'unknown'`）与 Dart 枚举
（`crash / fallback / invariantViolation / unknown`）**语义分裂**——
CLI 现在丢失了 Dart 侧已有的精细分类。若不做收敛声明，后续 Run 可能
误把 CLI 的 `'reproduced'` 当成 Dart 端枚举值使用（如 `before ==
AdiValidationBefore.reproduced`，而该值在 Dart 枚举中**不存在**），
造成长期维护陷阱。

## 1. 决策

### 1.1 CLI `before` 是 Dart `before` 的粗粒度并集

CLI `adi validate --after-fix` 输出的 `before` 字段语义定义为：

```
CLI before = 'reproduced'
    ⇔ 该 session 在 .adi/observations/ 中存在错误记录
    ⇔ Dart before ∈ { crash, fallback, invariantViolation }（任一）
       ∪ 原始 errorType 未经 Dart 分类（如 GlobalError → RenderOverflow 由 CLI 分类）

CLI before = 'unknown'
    ⇔ 该 session 无 observation
    ⇔ Dart before == unknown
```

即：**CLI `'reproduced'` 是 Dart `{crash, fallback, invariantViolation}`
的并集表达（粗粒度）**，不是某个 Dart 枚举值的直译。

### 1.2 信息密度取舍：CLI 刻意低密度

CLI 是 Agent（可能为 LLM）的消费面，跨语言、跨进程。二值 `before` 让
Agent 只需回答一个布尔问题：「这个 session 之前坏过吗？」——配合
`after`（pass/still_failing）即可形成 F1-F7 形式化闭环的最小判定。

精细分类（crash/fallback/invariantViolation）仍可通过
`adi latest-error` + `error_type` + message 从 CLI 侧获得，
不因本决策丢失。

### 1.3 v0.3 对齐计划（不设期限，随协议演进）

- **当前（v0.1/v0.2）**：CLI 粗粒度并集（本 ADR 声明）
- **未来 v0.3**：若 CLI 需要暴露精细分类，新增 `before_detail` 字段
  （取值对齐 Dart `AdiValidationBefore.name`），`before` 保持二值向后兼容
- **禁止**：把 CLI `'reproduced'` 直接映射为 Dart
  `AdiValidationBefore` 的枚举值（该值不存在）

## 2. 动机

1. **F2 验收的最小判定**：Run #007 的目标是补「before 状态绑定」
   （`reproduced → not_reproduced` 全链路），而非替换 Dart schema。
   二值表达恰好满足，不做过度设计。
2. **跨语言消费**：CLI（Dart 实现）输出给 Python Agent harness
   （`run006_agent.py`）、ffx CLI 消费；二值字符串比枚举序列化
   更不易在协议边界出错。
3. **避免 schema 漂移**：不声明收敛，后续 Run 可能误用
   `'reproduced'` 作为 Dart 枚举值 → 编译/语义错误。

## 3. 后果

### 正面

- CLI 与 Dart 的语义边界明确：CLI = 粗粒度布尔，Dart = 精细分类
- Agent 消费面稳定（二值 + after + invariants 即可闭环判定）
- F1-F7 形式化验收的 F2 有了明确、可复现的语义

### 负面 / 限制

- CLI 不暴露 crash/fallback/invariantViolation 的精细区分（需查
  `latest-error` 补全）
- 若未来 CLI 需要精细分类，需新增字段（v0.3 计划），不能直接改
  `before` 语义（破坏向后兼容）

## 4. 替代方案

| 方案 | 描述 | 否决原因 |
|------|------|---------|
| **A：修订 ADR-0024 §2.4** | 在 ADR-0024 中直接声明 CLI 并集语义 | ADR-0024 是「为什么」层（接口决策依据），CLI 实现细节已收敛到 design doc；本决策是**实现层的 schema 收敛**，独立 ADR 更清晰，避免污染 ADR-0024 的决策边界 |
| **B：新增 ADR-0028（采纳）** | 独立声明 CLI before schema 收敛 | 本 ADR |
| C：CLI 直接输出 Dart 枚举序列化 | `before: "crash"` 等 | 信息密度高但 Agent 需解析枚举；且 Run #007 的 observation 原始 errorType 是 `GlobalError`（未分类），CLI 无法直接给出 crash/fallback/invariantViolation 之一，强制输出反而失真 |

## 5. 验收 / Exit Criteria

- [x] `adi validate --after-fix` 输出 `before ∈ {reproduced, unknown}`
- [x] observation 存在（sessionId 匹配）→ `before=reproduced`（e2e_scenarios_test.dart 断言已同步）
- [x] observation 缺失 → `before=unknown`（回归安全网）
- [ ] v0.3 协议版本对齐计划（§1.3）随 ADI v0.3 落地时执行

> **维护注意**：任何新增 CLI 消费端（ffx / run006_agent.py / 未来 LLM
> harness）读取 `validate.before` 时，必须按本 ADR 语义（粗粒度布尔），
> 不得假设它与 Dart `AdiValidationBefore` 枚举值一一对应。
