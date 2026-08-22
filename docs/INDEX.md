# FormulaFix 文档全量索引（INDEX）

**生成日期**: 2026-08-22（文档整理轮）
**用途**: docs/ 下全部文档的单页索引——顶层 + 子目录 + RUN 报告分类表。
**入口**: 新读者从 [README.md](README.md) 进入（分类导航）；本页为全量清单（机器可核对）。

---

## 1. 顶层文档（40 篇）

### 1.1 架构与路线图

| 文档 | 说明 |
|------|------|
| [ARCHITECTURE.md](ARCHITECTURE.md) | 架构总览（当前 + 目标 + 问题 + 风险） |
| [ROADMAP.md](ROADMAP.md) | 路线图（Phase 0-4，含 Phase 3.10/3.11） |
| [DESIGN.md](DESIGN.md) | 总体设计 |
| [CRITICAL_REVIEW.md](CRITICAL_REVIEW.md) | 现状严厉批判报告 |
| [COMPREHENSIVE-TEST-REPORT.md](COMPREHENSIVE-TEST-REPORT.md) | 综合测试报告 |
| [FFX-VERIFICATION-ORCHESTRATOR-v1.md](FFX-VERIFICATION-ORCHESTRATOR-v1.md) | FFX 验证编排器设计 |
| [CONTRACT-SYNC-MINIMAL.md](CONTRACT-SYNC-MINIMAL.md) | Contract Sync 最小版 |

### 1.2 UI 设计与交互

| 文档 | 说明 |
|------|------|
| [UI-ARCHITECTURE.md](UI-ARCHITECTURE.md) | UI 架构 |
| [UI_SPEC.md](UI_SPEC.md) | 产品视觉设计 source of truth |
| [Component-Tree.md](Component-Tree.md) | 组件树 |
| [Interaction-Model.md](Interaction-Model.md) | 交互模型 |
| [UI_STATUS.md](UI_STATUS.md) | UI 还原度状态 |
| [UI_FIX_PLAN.md](UI_FIX_PLAN.md) | UI 修复实施计划 |

### 1.3 开发流程与规范

| 文档 | 说明 |
|------|------|
| [WORKFLOW.md](WORKFLOW.md) | 开发流程与 CI/CD |
| [GIT_WORKFLOW.md](GIT_WORKFLOW.md) | Git 详细流程 |
| [CODING_RULES.md](CODING_RULES.md) | 详细编码规范 |
| [TEST_SKIP_REGISTRY.md](TEST_SKIP_REGISTRY.md) | 测试 skip 登记 |
| [TEST_GAP_PLAN.md](TEST_GAP_PLAN.md) | 测试缺口计划 |
| [E2E_TEST_PLAN.md](E2E_TEST_PLAN.md) | E2E 测试计划 |

### 1.4 Phase 3.10/3.11 审计与验证

| 文档 | 说明 |
|------|------|
| [PHASE3.10-ENGINEERING-BASELINE-v1.md](PHASE3.10-ENGINEERING-BASELINE-v1.md) | 3.10 工程基线（DEBT 债务表） |
| [PHASE3.10-GATE-REPORT.md](PHASE3.10-GATE-REPORT.md) | 3.10 Final Gate 报告（G0-G12） |
| [PHASE3.10-TYPORA-GAP-ANALYSIS.md](PHASE3.10-TYPORA-GAP-ANALYSIS.md) | Typora 差距分析 |
| [FEATURE-CAPABILITY-COVERAGE-MATRIX-v1.md](FEATURE-CAPABILITY-COVERAGE-MATRIX-v1.md) | 能力覆盖矩阵 |
| [FEATURE-COMPLETION-EVIDENCE-MATRIX-v1.md](FEATURE-COMPLETION-EVIDENCE-MATRIX-v1.md) | 完成证据矩阵 |
| [FULL-CAPABILITY-REAUDIT.md](FULL-CAPABILITY-REAUDIT.md) | 能力全量再审计 |
| [BEHAVIOR-AUDIT-COVERAGE.md](BEHAVIOR-AUDIT-COVERAGE.md) | Behavior 审计覆盖 |
| [EXPERIENCE-AUDIT-COVERAGE.md](EXPERIENCE-AUDIT-COVERAGE.md) | 体验审计覆盖 |
| [PROJECT-FUNCTION-AUDIT-STATUS.md](PROJECT-FUNCTION-AUDIT-STATUS.md) | 功能审计状态 |
| [ADI-CLOSED-LOOP-AUDIT.md](ADI-CLOSED-LOOP-AUDIT.md) | ADI 闭环审计 |
| [CLI-ANYTHING-VERIFICATION-STATUS.md](CLI-ANYTHING-VERIFICATION-STATUS.md) | CLI 验证状态 |

### 1.5 专项审计 / 调研 / 迁移

| 文档 | 说明 |
|------|------|
| [MARKDOWN-ECOSYSTEM-HANDWRITTEN-REVIEW.md](MARKDOWN-ECOSYSTEM-HANDWRITTEN-REVIEW.md) | Markdown 生态手写评审 |
| [MIGRATION-SPIKE-MARKDOWN-PARSER.md](MIGRATION-SPIKE-MARKDOWN-PARSER.md) | Parser 迁移 spike |
| [WORD-MIGRATION-SPIKE.md](WORD-MIGRATION-SPIKE.md) | Word 迁移 spike |
| [WORD-EXPORT-AUDIT.md](WORD-EXPORT-AUDIT.md) | Word 导出审计 |
| [WORD-EXPORT-PRODUCT-RELIABILITY-AUDIT.md](WORD-EXPORT-PRODUCT-RELIABILITY-AUDIT.md) | Word 导出可靠性审计 |
| [DOCX-QA-PIPELINE.md](DOCX-QA-PIPELINE.md) | DOCX QA 管线 |
| [OFFICECLI-RESEARCH.md](OFFICECLI-RESEARCH.md) | OfficeCLI 调研 |
| [phase3.1-review-backlog.md](phase3.1-review-backlog.md) | 3.1 评审待办 backlog |

## 2. 子目录

### 2.1 ADR（架构决策记录，29 篇）

见 [ADR/](ADR/) —— 按编号递增（0001 ~ 0030）。状态机 `Proposed → Accepted → Superseded/Deprecated`。
关键：ADR-0003（存储单一真相源）/ 0024（ADI）/ 0028（CLI before schema）/ 0029（嵌套 AST）/ 0030（Verification Orchestrator）。

### 2.2 contracts（任务契约，16 篇）

见 [contracts/](contracts/) —— phase2.1 ~ phase3.4 各阶段 Task Contract（含 PR 关联 / 验收清单）。

### 2.3 design（设计文档，2 篇）

见 [design/](design/) —— [adi-design-v1.md](design/adi-design-v1.md)（ADI 设计）/ [ui-spec.md](design/ui-spec.md)（UI 规范）。

### 2.4 releases（验证报告，11 篇）

见 [releases/](releases/) —— phase1/2/3 各阶段 Verification Report + 真机验收报告。

### 2.5 archive（已归档，2 篇）

见 [archive/](archive/) —— 已过期/被取代的历史文档：
| 文档 | 说明 |
|------|------|
| [REFACTOR_DESIGN.md](archive/REFACTOR_DESIGN.md) | 重构方案设计（被 ADR + Phase 3.10 Baseline 取代，2026-08-22 归档） |
| [PHASE1_TEST_PLAN.md](archive/PHASE1_TEST_PLAN.md) | Phase 1 测试计划（Phase 1 已完结，2026-08-22 归档） |

## 3. RUN 报告（35 篇，按类型归档）

### 3.1 Phase 3.11 Capability Hardening Loop（16 篇）—— [runs/phase3.11/](runs/phase3.11/)

| 文档 | 说明 |
|------|------|
| [RUN-001](runs/phase3.11/PHASE3.11-RUN-001-RUNNER-IZATION.md) | 独立 runner 化（7 能力真实执行） |
| [RUN-002](runs/phase3.11/PHASE3.11-RUN-002-MARKDOWN-HARDENING.md) | Markdown 加固 Golden Loop |
| [RUN-003](runs/phase3.11/PHASE3.11-RUN-003-REGRESSION-SEMANTICS-SERIALIZER.md) | regression 语义升级 + Serializer Golden Loop |
| [RUN-004](runs/phase3.11/PHASE3.11-RUN-004-FORMULA-EVIDENCE-LAYER.md) | Formula 跨证据层 Golden Loop |
| [RUN-005](runs/phase3.11/PHASE3.11-RUN-005-TAXONOMY-FREEZE.md) | taxonomy / 优先级冻结 |
| [RUN-006](runs/phase3.11/PHASE3.11-RUN-006-FOUR-STATE-AND-GENERALIZATION.md) | target_failure 四态 + Word/PDF 泛化 |
| [RUN-007](runs/phase3.11/PHASE3.11-RUN-007-EVIDENCE-STRENGTH-PDF-REAL-DEFECT.md) | Evidence Strength 冻结 + PDF Real Defect |
| [RUN-008](runs/phase3.11/PHASE3.11-RUN-008-BEHAVIOR-STRESS-TEST.md) | Behavior Family 压力测试（Undo） |
| [RUN-009](runs/phase3.11/PHASE3.11-RUN-009-CONTRACT-SYNC-META-VALIDATION.md) | Contract-Sync Meta-Validation |
| [RUN-010](runs/phase3.11/PHASE3.11-RUN-010-F3-RUNTIME-REAL-DEFECT.md) | F3 Runtime Real Defect Loop（Formula） |
| [RUN-011](runs/phase3.11/PHASE3.11-RUN-011-WORD-FULL-GOLDEN-LOOP.md) | Word Full Golden Loop |
| [RUN-012](runs/phase3.11/PHASE3.11-RUN-012-E6-PHYSICAL-RUNTIME.md) | E6 Physical Runtime（渲染 + 截图） |
| [RUN-013](runs/phase3.11/PHASE3.11-RUN-013-E8-VISUAL-FIDELITY-PIPELINE.md) | E8 Visual Fidelity Pipeline（三层） |
| [RUN-014](runs/phase3.11/PHASE3.11-RUN-014-E8-EVALUATOR.md) | E8 Evaluator（AST Diff 语义验证） |
| [RUN-015](runs/phase3.11/PHASE3.11-RUN-015-E8-VISION-WIRING.md) | E8 真实视觉提取 + FFX verify 接线 |
| [RUN-016](runs/phase3.11/PHASE3.11-RUN-016-VLM-STRUCTURE-MODE.md) | E8 VLM 结构模式（三态判定） |

### 3.2 ADL Loop（12 篇，含 PLAN）—— [runs/adl/](runs/adl/)

| 文档 | 说明 |
|------|------|
| [RUN-001](runs/adl/ADL-LOOP-RUN-001.md) ~ [RUN-008](runs/adl/ADL-LOOP-RUN-008.md) | ADL 闭环报告（Run #001-008） |
| `*PLAN.md` ×4 | ADL 各轮计划（RUN-002/005/006/008） |

### 3.3 Dogfood（7 篇）—— [runs/dogfood/](runs/dogfood/)

| 文档 | 说明 |
|------|------|
| [RUN-001](runs/dogfood/DOGFOOD-RUN-001-SMOKE.md) ~ [RUN-007](runs/dogfood/DOGFOOD-RUN-007-CONSUMER-ADAPTER.md) | Dogfood 闭环（Smoke → Known-Good/Bad → Real Repair → Regression） |

---

## 4. 索引核对

- 顶层 md：40 篇（含本 INDEX）
- ADR：29 篇 | contracts：16 篇 | design：2 篇 | releases：11 篇 | archive：2 篇
- RUN 报告：35 篇（phase3.11 ×16 + adl ×12 + dogfood ×7）
- 合计：**135 篇**
