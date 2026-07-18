# FormulaFix 开发工作流与 CI/CD

> 本文是 [GIT_WORKFLOW.md](file:///d:/Projects/Active/math/docs/GIT_WORKFLOW.md) 和 [AGENTS.md](file:///d:/Projects/Active/math/AGENTS.md) 的上层编排，定义从需求到上线的全链路流程。

---

## 1. 总览

```
ROADMAP 任务 / Issue
        │
        ▼
  ┌─ 规划 ─────────────────────────────────────┐
  │  拆分任务 → 评估依赖 → 关联 ADR             │
  └────────────────────────────────────────────┘
        │
        ▼
  ┌─ Task Contract ────────────────────────────┐
  │  AI 填写任务契约 → 复杂任务 Human 审批      │
  └────────────────────────────────────────────┘
        │
        ▼
  ┌─ 开发 ─────────────────────────────────────┐
  │  AI 创建分支 → 编码 → 自测 → Self Review   │
  └────────────────────────────────────────────┘
        │
        ▼
  ┌─ CI/CD ────────────────────────────────────┐
  │  analyze → test → build → artifacts        │
  └────────────────────────────────────────────┘
        │
        ▼
  ┌─ Review ───────────────────────────────────┐
  │  Human Owner Code Review → 批准 / 驳回     │
  └────────────────────────────────────────────┘
        │
        ▼
  ┌─ 合并 ─────────────────────────────────────┐
  │  Squash & Merge → 删除分支 → 更新 ROADMAP  │
  └────────────────────────────────────────────┘
```

---

## 2. 任务生命周期

### 2.1 任务来源

| 来源 | 粒度 | 示例 |
|------|------|------|
| [ROADMAP.md](file:///d:/Projects/Active/math/docs/ROADMAP.md) 任务 | 1-3 天 | `ROADMAP 1.5` 补齐解析器 |
| [REFACTOR_DESIGN.md](file:///d:/Projects/Active/math/docs/REFACTOR_DESIGN.md) 阶段 | 1-2 周 | R1 地基重构 |
| GitHub Issue | 可变 | 用户反馈的 bug |
| Human Owner 指令 | 可变 | "增加暗色主题" |

### 2.2 任务状态流转

```
Backlog → Ready → In Progress → In Review → Done
```

| 状态 | 含义 | 谁负责 |
|------|------|--------|
| Backlog | 已记录，未排期 | — |
| Ready | 已拆分，无阻塞依赖，可领取 | AI / Human |
| In Progress | 正在开发 | AI（分支） |
| In Review | PR 已提交，等待 review | Human Owner |
| Done | 已合并到 main | — |

### 2.3 任务拆分规则

**核心原则：以认知边界划分，不以文件数量限制。**

一个任务必须满足：

1. **一个明确目标** — 可以一句话描述"这个任务要达成什么"
2. **一个验收标准** — 可以客观判断"是否完成"
3. **一个回滚方案** — 可以安全撤销

文件数量仅作为风险指标，不作为硬限制。

**需要拆分的情况**：

- 涉及多个架构目标（如同时改 parser 和 storage）
- 涉及多个独立模块且无共享依赖
- 无法一次验证的修改（如需要分阶段测试）

**基本约束**：

- 一个任务 = 一个 PR = 一个分支
- 一个任务 ≤ 3 天工作量
- 重构 PR 与功能 PR 严格分离
- 跨 Phase 的任务必须先完成前置 Phase

### 2.4 任务领取

**AI 领取任务**：
1. 确认当前 Phase 允许该任务
2. 创建分支 `feat/<scope>-<short-desc>` 或 `fix/<scope>-<short-desc>`
3. 在 PR 描述中关联 `Task scope: ROADMAP X.Y`

**Human 领取任务**：
1. 直接创建分支
2. 开发 + 自测
3. 提 PR 给另一人 review

---

## 3. 开发流程

### 3.1 AI 开发标准流程

```
┌─────────────────────────────────────────────────────────┐
│ 1. 读文档                                               │
│    AGENTS.md → 相关 ADR → ROADMAP 当前 Phase             │
│                                                         │
│ 2. 读代码                                               │
│    相关模块实际实现，不依赖文档描述                        │
│                                                         │
│ 3. 判断阶段                                             │
│    当前 Phase 允许该任务？不允许 → 告知 Human Owner       │
│                                                         │
│ 4. 创建分支                                             │
│    git checkout -b feat/<scope>-<short-desc>             │
│                                                         │
│ 5. 填写 Task Contract（必做）                            │
│    使用 .agent/templates/task-contract.md 模板           │
│    定义 Goal、Scope、Validation Plan、Success Criteria   │
│    复杂任务（Risk Medium+）→ 提交 Human Owner 审批       │
│                                                         │
│ 6. 写 TodoWrite（复杂任务 >3 步）                        │
│                                                         │
│ 7. 编码                                                 │
│    最小改动，能改一行不改两行                              │
│                                                         │
│ 8. 写测试                                               │
│    新功能必有测试，bug 修复必有回归测试                    │
│                                                         │
│ 9. 自测                                                 │
│    flutter analyze 无 error                              │
│    flutter test 全部通过                                 │
│    flutter build web 成功                                │
│                                                         │
│ 10. AI Self Review（AI 必做）                            │
│    □ 符合 AGENTS.md 编码规范                             │
│    □ 符合相关 ADR 决策                                   │
│    □ 无 scope drift（改动范围与任务描述一致）              │
│    □ 未引入新技术债（TODO 已标注 ticket）                 │
│    □ 测试覆盖充分（新功能有测试，bug 修复有回归测试）      │
│    □ 文档已同步（dartdoc、ROADMAP 状态）                 │
│    → 输出 AI Review Report 到 PR 描述                    │
│                                                         │
│ 11. 写文档                                              │
│    架构决策落 ADR，API 变更写 dartdoc                     │
│                                                         │
│ 12. Commit + Push                                       │
│     commit message 含 Task scope                        │
│                                                         │
│ 13. 创建 PR                                             │
│     填写 PR 模板，关联 issue                             │
│                                                         │
│ 14. 等待 Review                                         │
│     Human Owner 操作 merge                              │
└─────────────────────────────────────────────────────────┘
```

### 3.2 分支命名与类型

| 任务类型 | 分支前缀 | 示例 |
|---------|---------|------|
| 新功能 | `feat/` | `feat/parser-inline-code` |
| Bug 修复 | `fix/` | `fix/exporter-timeout` |
| 重构 | `refactor/` | `refactor/merge-providers` |
| 工程化 | `chore/` | `chore/update-ci` |
| 文档 | `docs/` | `docs/workflow-design` |
| 测试 | `test/` | `test/add-editor-tests` |

### 3.3 并行开发

AI 可以同时开发多个分支，但必须满足：
- 不同分支改动不同文件，无冲突
- 不同分支对应不同 ROADMAP 任务
- 每个分支独立 PR，互不依赖

---

## 4. CI/CD 流水线

### 4.1 当前流水线（Phase 0）

```
                 push 任意分支 / PR → main
                           │
                           ▼
                    ┌──────────┐
                    │  analyze  │  flutter analyze
                    └─────┬────┘
                          │ ✓
                          ▼
                    ┌──────────┐
                    │   test    │  flutter test
                    └─────┬────┘
                          │ ✓
                    ┌─────┴─────┐
                    │           │
                    ▼           ▼
              ┌──────────┐ ┌──────────┐
              │build-andr│ │build-web │
              │(debug)   │ │          │
              └──────────┘ └──────────┘
```

**触发条件**：`push` 到任意分支（`branches: ['**']`），或 PR 到 `main`/`develop`

**Job 依赖**：
- `test` 依赖 `analyze`（analyze 失败则 test 不跑）
- `build-android` 和 `build-web` 依赖 `test`（test 失败则不构建）

**并发控制**：同一 PR 新推送时自动取消旧 run

### 4.2 质量门禁

| 门禁 | 标准 | 阻断级别 |
|------|------|---------|
| `flutter analyze` | 0 error | 阻断 merge |
| `flutter test` | 全部通过 | 阻断 merge |
| `flutter build web` | 成功 | 阻断 merge |
| `flutter build apk --debug` | 成功 | 阻断 merge |
| Code Review | Human Owner 批准 | 阻断 merge |

### 4.3 缓存策略

| 缓存 | 路径 | Key |
|------|------|-----|
| pub packages | `~/.pub-cache` + `flutter_app/.dart_tool` | `os-pub-{pubspec.yaml hash}` |
| Gradle | `~/.gradle/caches` + `~/.gradle/wrapper` | `os-gradle-{FLUTTER_VERSION}` |

### 4.4 Artifacts

| Artifact | 路径 | 保留 |
|----------|------|------|
| test-coverage | `flutter_app/coverage/` | 最后成功 run |
| android-apk-debug | `flutter_app/build/app/outputs/flutter-apk/` | 最后成功 run |
| web-build | `flutter_app/build/web/` | 最后成功 run |

### 4.5 未来增强（Phase 2+）

```
                    PR 创建
                       │
                       ▼
                ┌──────────────┐
                │  analyze      │
                └──────┬───────┘
                       │
                ┌──────┴───────┐
                │   test        │
                └──────┬───────┘
                       │
                ┌──────┴──────────────────┐
                │                         │
                ▼                         ▼
          ┌──────────┐              ┌──────────┐
          │build-andr│              │build-web │
          │(debug)   │              │          │
          └────┬─────┘              └────┬─────┘
               │                        │
               ▼                        ▼
          ┌──────────┐              ┌──────────┐
          │coverage  │              │lighthouse│
          │report    │              │audit     │
          └──────────┘              └──────────┘
```

| 增强项 | 时机 | 说明 |
|--------|------|------|
| 覆盖率报告 | Phase 2 | `flutter test --coverage` + 上传到 Codecov |
| Lighthouse 审计 | Phase 4 | Web 构建后跑性能审计 |
| Release APK 构建 | Phase 4 | `flutter build apk --release` + 签名 |
| iOS 构建 | Phase 4 | 补齐 iOS 平台后 |
| 自动化版本 Tag | Phase 4 | 合并到 main 时自动打 tag |

---

## 5. Code Review 流程

### 5.1 Review 职责

**Human Owner**：
- 检查架构一致性（是否符合 ADR 和 AGENTS.md）
- 检查代码质量（命名、分层、依赖方向）
- 确认测试覆盖
- 确认文档同步
- 决定 merge 方式（Squash / Rebase）

**AI**：
- 不参与 review（AI 无 merge 权限）
- 收到 review 意见后修改代码，追加 commit 到同一分支

### 5.2 Review 检查清单

- [ ] 改动范围与 PR 描述一致
- [ ] 没有夹带未在 PR 描述中说明的改动
- [ ] 没有违反 AGENTS.md 禁止事项
- [ ] 测试覆盖充分
- [ ] 文档已同步
- [ ] CI 全部通过（analyze + test + build）
- [ ] 架构决策文件如是 AI 提交，已确认授权

### 5.3 Merge 策略

| 场景 | 策略 | 说明 |
|------|------|------|
| 小型功能 / fix | Squash and Merge | 保持 main 历史干净 |
| 大重构（多 commit） | Rebase and Merge | 保留分步提交历史 |
| 文档 / 工程化 | Squash and Merge | 单 commit 足够 |

### 5.4 Merge 后操作

1. 删除远程分支
2. 本地 `git checkout main && git pull`
3. 删除本地分支 `git branch -d feat/xxx`
4. 更新 ROADMAP 任务状态
5. 关闭关联 Issue

---

## 6. Phase 特定工作流

### 6.1 Phase 0：工程化 + UI Prototype Freeze（当前）

- **允许**：文档、CI、规范、工程配置、依赖版本修复
- **禁止**：修改 `lib/` 业务代码、修改 UI 行为
- **分支类型**：`chore/` `docs/` `ci/` `fix/`
- **UI Prototype Freeze**：冻结当前 UI 作为 Phase 3 参考基线，Phase 1-2 期间 UI 退化不视为 bug

### 6.2 Phase 1：底层重构

- **允许**：ROADMAP 1.1-1.8 任务
- **禁止**：新功能、UI 修改
- **分支类型**：`fix/` `refactor/` `feat/`（仅限 ROADMAP 任务）
- **每个任务独立分支**：1.1 合并 Provider 和 1.2 存储统一不能混在同一 PR
- **顺序**：1.1 → 1.2 → 1.3 / 1.4 / 1.5 可并行 → 1.6 → 1.7 → 1.8
- **UI 退化可接受**：本阶段聚焦底层，UI 在 Phase 3 重建

### 6.3 Phase 2：编辑模型

- **允许**：ROADMAP 2.1-2.7 任务
- **禁止**：UI 层修改（`presentation/` 目录）
- **分支类型**：`feat/` `refactor/`
- **核心理念**：定义"怎么编辑"，不定义"长什么样"
- **编辑内核**：纯 Dart 逻辑，可脱离 UI 独立运行和测试

### 6.4 Phase 3+：UI Implementation

- **启用**：`develop` 分支作为集成分支
- **分支模型**：`feat/` 从 `develop` 切出，PR 到 `develop`
- **Feature Flag**：UI 变更必须用 feature flag 包裹，支持一键回退
- **灰度发布**：完成后先在 `develop` 集成测试，再 PR 到 `main`
- **Phase 4**（多平台）遵循相同流程

---

## 7. 发布流程（Phase 4+ 启用）

```
develop 集成测试通过
        │
        ▼
  创建 release/x.y.z 分支
        │
        ▼
  版本号更新 + CHANGELOG
        │
        ▼
  CI 构建 release APK / Web
        │
        ▼
  PR release/x.y.z → main
        │
        ▼
  Squash & Merge
        │
        ▼
  git tag vx.y.z
        │
        ▼
  GitHub Release（附 APK artifact）
```

### 版本号规则（SemVer）

| 类型 | 示例 | 触发 |
|------|------|------|
| Major | 1.0.0 → 2.0.0 | 编辑模型 + UI 实现（Phase 2-3） |
| Minor | 0.1.0 → 0.2.0 | 新 Phase 完成 |
| Patch | 0.1.0 → 0.1.1 | Bug 修复 |

---

## 8. 文档同步规则

| 变更类型 | 需同步的文档 |
|---------|-------------|
| 新架构决策 | 新增 ADR → 更新 ARCHITECTURE.md |
| Agent 权限变更 | 更新 .agent/AI_POLICY.md |
| 上下文规则变更 | 更新 .agent/context/loading-rules.md |
| 新功能 | 更新 flutter_app/README.md |
| 任务完成 | 更新 ROADMAP.md 状态 |
| 规范变更 | 更新 AGENTS.md / CODING_RULES.md |
| 流程变更 | 更新本文档 / GIT_WORKFLOW.md |

---

## 9. 常见场景速查

### 场景 1：AI 接到 ROADMAP 任务

```
1. 读 ROADMAP 确认 Phase 允许
2. 创建分支 feat/xxx
3. 填写 Task Contract（Goal / Scope / Validation / Success Criteria）
4. 复杂任务 → Human Owner 审批
5. 编码 + 测试 + 自测
6. AI Self Review
7. Commit（含 Task scope）
8. Push + 创建 PR
9. 等待 Human Owner merge
```

### 场景 2：CI 报错

```
1. 看 CI 日志定位错误
2. 本地修复（或直接推修复 commit）
3. Push 到同一分支
4. CI 自动重跑
5. 通过后通知 Human Owner
```

### 场景 3：Human Owner 新增需求

```
1. Human Owner 在 ROADMAP 或 Issue 描述需求
2. AI 评估是否在允许的 Phase 范围内
3. 在范围内 → 创建分支开发
4. 不在范围内 → 告知 Human Owner，建议调整 Phase 或开例外
```

### 场景 4：架构决策

```
1. 识别到需要架构决策
2. 读已有 ADR，确认未覆盖
3. 创建 docs/ADR/NNNN-xxx.md（Proposed）
4. Human Owner 审核 → Accepted
5. 按 ADR 执行开发
```

---

## 10. 当前状态

| 项 | 状态 |
|----|------|
| 当前 Phase | Phase 0：工程化 + UI Prototype Freeze（全部退出条件满足） |
| AI 治理层 | AI_POLICY.md ✅ / loading-rules.md ✅ / task-contract.md ✅ / PR template ✅ |
| CI 状态 | analyze ✅ / test ✅ / build-web ✅ / build-android ✅ |
| 活跃分支 | `fix/ci-android-build`（待 PR） |
| 下一个任务 | Phase 1.1 合并重复 Provider |

---

**本文档由首席架构工程师维护，版本 v0.1，生效日期 2026-07-18。**