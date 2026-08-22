# FormulaFix 文档导航（docs/ README）

**目的**：统一导航 docs/ 下全部文档（架构 / ADR / 路线图 / 审计报告 / 运行报告），
按类别索引，避免文档散乱。**新读者从这里进入。**

> 📑 **全量索引**：需要机器可核对的完整清单（含子目录 + 35 篇 RUN 报告分类表）见
> [INDEX.md](INDEX.md)（2026-08-22 文档整理轮新增）。README 为分类导航，INDEX 为全量索引。

---

## 1. 架构与路线图（顶层）

| 文档 | 说明 |
|------|------|
| [ARCHITECTURE.md](ARCHITECTURE.md) | 架构总览（当前 + 目标 + 问题 + 风险） |
| [ROADMAP.md](ROADMAP.md) | 路线图（Phase 0-4，含 Phase 3.10） |
| [DESIGN.md](DESIGN.md) | 总体设计 |
| [REFACTOR_DESIGN.md](archive/REFACTOR_DESIGN.md) | 重构方案设计（**已归档**，2026-08-22） |
| [CRITICAL_REVIEW.md](CRITICAL_REVIEW.md) | 现状严厉批判报告 |
| [UI-ARCHITECTURE.md](UI-ARCHITECTURE.md) / [UI_SPEC.md](UI_SPEC.md) | UI 架构 / 规范 |
| [Component-Tree.md](Component-Tree.md) / [Interaction-Model.md](Interaction-Model.md) | 组件树 / 交互模型 |
| [WORKFLOW.md](WORKFLOW.md) / [GIT_WORKFLOW.md](GIT_WORKFLOW.md) / [CODING_RULES.md](CODING_RULES.md) | 开发流程 / Git / 编码规范 |

## 2. 架构决策记录（ADR，29 篇）

见 [ADR/](ADR/) —— 按编号递增（0001 ~ 0030），每个决策一份：
状态机 `Proposed → Accepted → Superseded/Deprecated`。
关键：ADR-0003（存储单一真相源）/ 0024（ADI）/ 0028（CLI before schema）/
0029（嵌套 AST）/ 0030（Verification Orchestrator）。

## 3. Phase 3.10 Verification Orchestrator（当前阶段）

| 文档 | 说明 |
|------|------|
| [PHASE3.10-ENGINEERING-BASELINE-v1.md](PHASE3.10-ENGINEERING-BASELINE-v1.md) | 3.10 工程基线（锚点） |
| [FFX-VERIFICATION-ORCHESTRATOR-v1.md](FFX-VERIFICATION-ORCHESTRATOR-v1.md) | Orchestrator 设计 |
| [PHASE3.10-TYPORA-GAP-ANALYSIS.md](PHASE3.10-TYPORA-GAP-ANALYSIS.md) | Typora 差距分析 |
| [FEATURE-CAPABILITY-COVERAGE-MATRIX-v1.md](FEATURE-CAPABILITY-COVERAGE-MATRIX-v1.md) | 能力覆盖矩阵 |
| [FEATURE-COMPLETION-EVIDENCE-MATRIX-v1.md](FEATURE-COMPLETION-EVIDENCE-MATRIX-v1.md) | 完成证据矩阵 |
| [ADR/0030-ffx-verification-orchestrator.md](ADR/0030-ffx-verification-orchestrator.md) | 架构决策（根） |

**Dogfood / 工程补强报告（2026-08-20 挂入，Gate-5 收口）**：

| 文档 | 说明 |
|------|------|
| [DOGFOOD-RUN-001-SMOKE.md](runs/dogfood/DOGFOOD-RUN-001-SMOKE.md) | Dogfood ① Smoke（real_runtime_path=true） |
| [DOGFOOD-RUN-002-KNOWN-GOOD.md](runs/dogfood/DOGFOOD-RUN-002-KNOWN-GOOD.md) | Dogfood ② Known-Good（vs Matrix 对照） |
| [DOGFOOD-RUN-003-KNOWN-BAD.md](runs/dogfood/DOGFOOD-RUN-003-KNOWN-BAD.md) | Dogfood ③ Known-Bad（回退 BUG-1 → FAIL） |
| [DOGFOOD-RUN-004-ADI-CONSUMER.md](runs/dogfood/DOGFOOD-RUN-004-ADI-CONSUMER.md) | Dogfood ④ ADI/Consumer 联合 |
| [DOGFOOD-RUN-005-REAL-REPAIR.md](runs/dogfood/DOGFOOD-RUN-005-REAL-REPAIR.md) | Dogfood ⑤ Real Agent Repair |
| [DOGFOOD-RUN-006-REGRESSION.md](runs/dogfood/DOGFOOD-RUN-006-REGRESSION.md) | REGRESSION path 补齐（serializer 第 2 能力） |
| [DOGFOOD-RUN-007-CONSUMER-ADAPTER.md](runs/dogfood/DOGFOOD-RUN-007-CONSUMER-ADAPTER.md) | Consumer Adapter 扩展（word/formula） |
| [CONTRACT-SYNC-MINIMAL.md](CONTRACT-SYNC-MINIMAL.md) | Contract Sync 最小版（Matrix ↔ contracts） |

## 4. 审计报告（Phase 3.9 全量）

| 文档 | 说明 |
|------|------|
| [COMPREHENSIVE-TEST-REPORT.md](COMPREHENSIVE-TEST-REPORT.md) | 综合测试报告（测试项 × 覆盖 × 结论） |
| [PROJECT-FUNCTION-AUDIT-STATUS.md](PROJECT-FUNCTION-AUDIT-STATUS.md) | 功能审计状态总览 |
| [BEHAVIOR-AUDIT-COVERAGE.md](BEHAVIOR-AUDIT-COVERAGE.md) | 行为审计覆盖矩阵（CAP-BEH） |
| [EXPERIENCE-AUDIT-COVERAGE.md](EXPERIENCE-AUDIT-COVERAGE.md) | 体验审计覆盖（IME/输入延迟/主题） |
| [CLI-ANYTHING-VERIFICATION-STATUS.md](CLI-ANYTHING-VERIFICATION-STATUS.md) | CLI-Anything 验证状态 |
| [ADI-CLOSED-LOOP-AUDIT.md](ADI-CLOSED-LOOP-AUDIT.md) | ADI 闭环审计 |

## 5. Word 导出 / DOCX QA 专项

| 文档 | 说明 |
|------|------|
| [WORD-EXPORT-AUDIT.md](WORD-EXPORT-AUDIT.md) | Word 导出审计（CAP-WORD 001-016） |
| [WORD-EXPORT-PRODUCT-RELIABILITY-AUDIT.md](WORD-EXPORT-PRODUCT-RELIABILITY-AUDIT.md) | L1-L6 可靠性审计 |
| [WORD-MIGRATION-SPIKE.md](WORD-MIGRATION-SPIKE.md) | 生态迁移 Spike |
| [DOCX-QA-PIPELINE.md](DOCX-QA-PIPELINE.md) | DOCX QA 三级验收（Level A/B/C） |
| [OFFICECLI-RESEARCH.md](OFFICECLI-RESEARCH.md) | OfficeCLI 调研 |

## 6. Parser / 生态专项

| 文档 | 说明 |
|------|------|
| [MARKDOWN-ECOSYSTEM-HANDWRITTEN-REVIEW.md](MARKDOWN-ECOSYSTEM-HANDWRITTEN-REVIEW.md) | Markdown 生态手写盘点 |
| [MIGRATION-SPIKE-MARKDOWN-PARSER.md](MIGRATION-SPIKE-MARKDOWN-PARSER.md) | Parser 迁移 Spike（保留手写结论） |

## 7. ADL Loop 运行报告（Observe → Validate → Verify → Audit）

| 文档 | 说明 |
|------|------|
| [ADL-LOOP-RUN-001.md](runs/adl/ADL-LOOP-RUN-001.md) ~ [ADL-LOOP-RUN-008.md](runs/adl/ADL-LOOP-RUN-008.md) | Run #001-008 闭环报告（含 PLAN 文件） |

## 8. 测试计划与质量门禁

| 文档 | 说明 |
|------|------|
| [E2E_TEST_PLAN.md](E2E_TEST_PLAN.md) / [PHASE1_TEST_PLAN.md](archive/PHASE1_TEST_PLAN.md) | E2E / Phase 1 测试计划 |
| [TEST_GAP_PLAN.md](TEST_GAP_PLAN.md) / [TEST_SKIP_REGISTRY.md](TEST_SKIP_REGISTRY.md) | 测试缺口 / skip 登记 |
| [phase3.1-review-backlog.md](phase3.1-review-backlog.md) | 3.1 评审 backlog |
| [UI_FIX_PLAN.md](UI_FIX_PLAN.md) / [UI_STATUS.md](UI_STATUS.md) | UI 修复计划 / 状态 |

---

## 文档治理原则（2026-08-19）

```text
1. 新阶段文档：先在 ROADMAP.md 登记 Phase 条目 → 再落 design/ADR →
   报告类放入对应类别目录（本 README 分类）
2. 架构决策：一律走 ADR（docs/ADR/NNNN-*.md），AI 提交需 Human Owner 授权
3. 报告类文档：命名 `xxx-REPORT.md` / `xxx-AUDIT.md` / `xxx-COVERAGE.md`，
   避免与架构文档混名
4. 新文档必须挂入本 README 对应类别（防散乱）
```
