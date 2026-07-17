# FormulaFix Git 工作流

> 本文是 [AGENTS.md](file:///d:/Projects/Active/math/AGENTS.md) 第 5 章的展开版。

---

## 1. Branch 策略

### 1.1 分支模型

```
main              受保护，只接受 PR 合入；始终可构建可发布
  ├─ develop      日常集成分支（Phase 1 启用）
  │   ├─ feat/<scope>-<short-desc>
  │   ├─ fix/<scope>-<short-desc>
  │   ├─ refactor/<scope>-<short-desc>
  │   ├─ chore/<short-desc>
  │   ├─ docs/<short-desc>
  │   └─ test/<short-desc>
  └─ release/<version>   发布分支（仅 Phase 4 启用）
```

### 1.2 命名规则

| 类型 | 格式 | 示例 |
|------|------|------|
| 功能 | `feat/<scope>-<short-desc>` | `feat/parser-inline-code` |
| 修复 | `fix/<scope>-<short-desc>` | `fix/exporter-timeout-message` |
| 重构 | `refactor/<scope>-<short-desc>` | `refactor/providers-merge-duplicates` |
| 工程 | `chore/<short-desc>` | `chore/add-pubspec-yaml` |
| 文档 | `docs/<short-desc>` | `docs/setup-ci-workflow` |
| 测试 | `test/<short-desc>` | `test/add-editor-screen-test` |

**规则**：
- 全小写
- 单词用 `-` 分隔
- 不含 issue 编号（issue 在 PR 里关联）
- 长度 ≤ 40 字符

### 1.3 分支生命周期

1. 从 `develop`（或 `main`，Phase 0 期间）切出
2. 提交按 Conventional Commits 规范
3. PR 到 `develop`（或 `main`）
4. 合并后删除分支

### 1.4 保护规则

- `main`：禁止直接 push，必须 PR + 至少 1 人 review + CI 通过
- `develop`：禁止直接 push，必须 PR + CI 通过
- Phase 0 期间允许单人项目跳过 review，但 CI 必须通过

---

## 2. Commit Message 规范

### 2.1 格式（Conventional Commits）

```
<type>(<scope>): <subject>

<body>

<footer>
```

### 2.2 type 取值

| type | 含义 | 示例场景 |
|------|------|---------|
| `feat` | 新功能 | 新增 Markdown 行内代码解析 |
| `fix` | Bug 修复 | 修复导出超时消息 |
| `refactor` | 重构（无行为变化） | 合并重复 Provider |
| `docs` | 文档变更 | 更新 README |
| `chore` | 工程杂务 | 添加 pubspec.yaml |
| `test` | 测试 | 补充编辑器 widget 测试 |
| `perf` | 性能优化 | 增量解析 |
| `style` | 代码格式（不影响逻辑） | dart format |
| `ci` | CI 配置 | 修改 GitHub Actions |
| `build` | 构建系统 | 修改 pubspec / Gradle |

### 2.3 scope 取值

按模块划分：

| scope | 模块 |
|-------|------|
| `parser` | `core/parser/` |
| `renderers` | `core/renderers/` |
| `services` | `core/services/` |
| `router` | `core/router/` |
| `models` | `data/models/` |
| `exporter` | `domain/services/exporters/` |
| `export` | `domain/services/export_service.dart` |
| `screens` | `presentation/screens/` |
| `widgets` | `presentation/widgets/` |
| `theme` | `presentation/theme/` |
| `providers` | `providers/` 或 `domain/providers/` |
| `ci` | `.github/` |
| `docs` | `docs/` 或 `*.md` |
| `core` | 多个 core 子模块 |

### 2.4 subject 规则

- 中文或英文皆可，但**同一仓库内保持一致**（本项目默认中文）
- ≤ 50 字符
- 不加句号
- 祈使句：`添加行内代码解析` 而非 `添加了行内代码解析`

### 2.5 body 规则

- 解释 **what + why**，不解释 how（看代码就知道）
- 每行 ≤ 72 字符
- 关联 issue / ROADMAP 任务

### 2.6 footer 规则

- `Closes #<issue>` 关闭 issue
- `Refs #<issue>` 引用 issue
- `ROADMAP <phase.task>` 关联路线图任务
- `BREAKING CHANGE:` 标记破坏性变更

### 2.7 示例

**功能**：
```
feat(parser): 支持 Markdown 行内代码语法

补齐 _parseBoldAndItalic 中缺失的 `code` 解析分支，
对应工具栏已存在但解析器未识别的不一致问题。

ROADMAP 1.5
Closes #12
```

**修复**：
```
fix(exporter): 缩短超时消息避免 SnackBar 换行

旧文案含"WebView 渲染卡死"等技术术语，普通用户困惑。
新文案：'导出超时，请减少文档内容后重试'。

ROADMAP 1.7
```

**重构**：
```
refactor(providers): 合并重复的 darkModeProvider

providers/providers.dart 与 providers/editor_providers.dart
都定义了 darkModeProvider，导致跨屏幕状态不同步。
统一到 providers/providers.dart，删除 editor_providers.dart
中的重复定义。

ROADMAP 1.1
```

**工程**：
```
chore(ci): 添加 GitHub Actions workflow

包含 pub get / analyze / test / build 四个阶段，
PR 触发自动运行。

ROADMAP 0.4
```

**文档**：
```
docs: 建立 ADR 体系

新增 docs/ADR/ 下 6 份架构决策记录，
覆盖命名 / 状态管理 / 存储 / 解析器 / 导出器 / CI。

ROADMAP 0.3
```

### 2.8 禁止

- ❌ `update` / `misc` / `wip` 等无信息 type
- ❌ `fix: bug` / `feat: add feature` 等无意义 subject
- ❌ 一个 commit 含多个无关改动
- ❌ commit message 含密钥 / token

---

## 3. PR 流程

### 3.1 PR 模板

```markdown
## 关联
- Issue: #<num>
- ROADMAP: <phase.task>

## 改动说明
<what + why>

## 测试方式
- [ ] 手动测试：<步骤>
- [ ] 自动测试：`flutter test --name "<pattern>"`

## 影响范围
- [ ] 影响 public API
- [ ] 影响数据存储格式
- [ ] 影响性能
- [ ] 无影响（仅文档 / 重构）

## 自检
- [ ] `flutter analyze` 无 error
- [ ] `flutter test` 全部通过
- [ ] `flutter build apk --debug` 成功
- [ ] `flutter build web` 成功
- [ ] 已更新文档
- [ ] 已写测试（新功能 / bug 修复）
```

### 3.2 PR 检查清单

PR 合并前必须满足：

**自动检查（CI）**：
- [ ] `flutter pub get` 成功
- [ ] `flutter analyze` 无 error
- [ ] `flutter test` 全部通过
- [ ] `flutter build apk --debug` 成功
- [ ] `flutter build web` 成功

**人工检查**：
- [ ] PR 描述清晰
- [ ] 改动范围与描述一致
- [ ] 没有夹带未说明的改动
- [ ] 测试覆盖充分（新功能 / bug 修复必须有测试）
- [ ] 文档已同步
- [ ] commit message 符合规范
- [ ] 没有引入新的"禁止事项"（见 [AGENTS.md §6](file:///d:/Projects/Active/math/AGENTS.md)）

**Phase 相关检查**：
- [ ] 当前 PR 是否在允许的 Phase 范围内（Phase 0 不允许业务改动）
- [ ] 是否跨阶段（如 Phase 1 修复 + Phase 3 新功能不能混在同一 PR）

### 3.3 Review 礼仪

- 小 PR 鼓励（< 300 行）
- 大 PR（> 1000 行）必须分阶段提交
- review 评论对事不对人
- 用 "建议" / "考虑" 而非 "应该" / "必须"（除非真的是 hard rule）
- 区分 `nit:`（小建议）/ `question:`（疑问）/ `issue:`（必须改）

### 3.4 合并策略

- 默认 **Squash and merge**：单 commit 合入，保留 PR 描述
- 大重构可 **Rebase and merge**：保留每个 commit
- 禁止 **Create a merge commit**（除非明确需要）

---

## 4. Tag / Release 策略

### 4.1 版本号（Semantic Versioning）

```
MAJOR.MINOR.PATCH
```

- **MAJOR**：范式重构 / 不兼容的 API 变化
- **MINOR**：新功能（向后兼容）
- **PATCH**：bug 修复

### 4.2 Pre-release

- `0.x.y`：Phase 0-2 期间，未达到"Typora 端侧版"标准
- `1.0.0`：Phase 2 WYSIWYG 完成后首个正式版

### 4.3 Tag 格式

```
v0.1.0
v0.2.0-alpha.1
v1.0.0
```

---

## 5. 特殊情况

### 5.1 紧急修复（hotfix）

- 从 `main` 切 `hotfix/<short-desc>`
- 修复 + 测试
- PR 到 `main` 和 `develop`
- 合并后打 patch tag

### 5.2 回滚

- 优先用 `git revert`，不用 `git reset --hard`
- 回滚 PR 必须说明原因
- 数据相关回滚必须有数据备份方案

### 5.3 大重构

- 必须先有 ADR
- 必须拆分为多个小 PR
- 必须有 feature flag（如 `const enableWysiwyg = true`）渐进切换
- 必须保留旧实现一段时间

---

## 6. 相关文档

- [AGENTS.md](file:///d:/Projects/Active/math/AGENTS.md) — 总体规范
- [CODING_RULES.md](file:///d:/Projects/Active/math/docs/CODING_RULES.md) — 编码规范
- [ROADMAP.md](file:///d:/Projects/Active/math/docs/ROADMAP.md) — 路线图
