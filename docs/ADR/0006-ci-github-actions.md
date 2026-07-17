# ADR-0006: CI 选型 GitHub Actions

- **状态**：Accepted
- **生效日期**：2026-07-18
- **决策者**：首席架构工程师

## 背景

FormulaFix 项目当前无 CI 配置。代码分析显示：

1. **测试覆盖存在但未自动化**：`flutter_app/test/` 下有 11 个测试文件
2. **代码质量无人把关**：无 `flutter analyze` 自动运行
3. **构建可构建性无人验证**：缺 `pubspec.yaml`，但即使补齐后也无 CI 验证
4. **项目托管推断**：用户提到"GitHub Actions"，故托管平台为 GitHub

## 决策

**采用 GitHub Actions 作为唯一 CI/CD 平台。**

### Workflow 设计

```yaml
name: CI

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]

jobs:
  analyze:
    - flutter pub get
    - flutter analyze
  
  test:
    - flutter pub get
    - flutter test
  
  build:
    - flutter pub get
    - flutter build apk --debug
    - flutter build web
```

详细配置见 [.github/workflows/ci.yml](file:///d:/Projects/Active/math/.github/workflows/ci.yml)。

### Job 设计原则

1. **三个 job 独立**：analyze / test / build 并行（push 时）
2. **失败短路**：任一 job 失败即 PR 不能合并
3. **缓存 pub packages**：`actions/cache` 缓存 `~/.pub-cache`
4. **working-directory**：所有 step 在 `flutter_app/` 下运行（项目根有 `docs/` 等非 Flutter 文件）

## 动机

### 选择 GitHub Actions 的理由

1. **GitHub 原生**：无第三方依赖
2. **Flutter 社区支持完善**：`subosito/flutter-action@v2` 是事实标准
3. **免费额度够用**：公开仓库无限免费，私有仓库 2000 分钟/月
4. **矩阵构建**：可同时跑 Android / Web / iOS / Windows
5. **与 GitHub PR 流程无缝**：status check / required check

### 否决其他方案的理由

#### 方案 A：GitLab CI / Bitbucket Pipelines

**否决理由**：项目托管在 GitHub，跨平台 CI 增加维护成本。

#### 方案 B：CircleCI / Travis CI

**否决理由**：
- 第三方服务，免费额度有限
- GitHub Actions 已能满足全部需求

#### 方案 C：自建 Jenkins / Drone

**否决理由**：
- 需要服务器维护
- 对个人 / 小团队项目过重

## 后果

### 正面

- 每个 PR 自动跑 analyze / test / build
- 缓存机制让 CI 时间从首次 5 分钟降到增量 1-2 分钟
- 与 PR 模板 [GIT_WORKFLOW.md §3](file:///d:/Projects/Active/math/docs/GIT_WORKFLOW.md) 集成

### 负面

- 当前缺 `pubspec.yaml`，CI 全部失败
- 矩阵构建跑 Android + Web + iOS + Windows 会消耗较多免费额度

### 风险与缓解

| 风险 | 缓解 |
|------|------|
| 缺 pubspec.yaml CI 失败 | Phase 0 优先补齐 pubspec.yaml（ROADMAP 0.1） |
| 私有仓库免费额度耗尽 | 仅跑 Android + Web 两个平台；iOS / Windows 暂不进 CI |
| WebView 依赖测试失败 | 测试用 `MarkdownExporter.register({...})` 注入 fake（见 ADR-0005） |
| `flutter build apk` 慢 | 缓存 `~/.gradle/caches`；不跑 release（只 debug） |

## 实施计划

### Phase 0（本 ADR 对应任务）

1. 创建 [.github/workflows/ci.yml](file:///d:/Projects/Active/math/.github/workflows/ci.yml)
2. 三个 job：analyze / test / build
3. 缓存 pub-cache + gradle-cache
4. 触发：push 到 main / develop，PR 到 main / develop

### Phase 1

- 补充 `flutter test --coverage` + 上传 coverage 报告
- 添加 `very_good_analysis` 或 `flutter_lints` 严格 lint 规则

### Phase 2

- 添加集成测试（integration_test）
- 添加 iOS 矩阵
- 添加 release 构建 + 自动 tag

### Phase 3+

- 自动发布到 Google Play / TestFlight
- 自动 GitHub Release + Changelog

## 替代方案再次评估

如果未来 GitHub Actions 不能满足：

- **Plan B**：迁移到 self-hosted runner（仅私有仓库场景）
- **Plan C**：用 Codemagic / Bitrise 等专业 Flutter CI（成本敏感时评估）

## 参考

- [.github/workflows/ci.yml](file:///d:/Projects/Active/math/.github/workflows/ci.yml)
- [ROADMAP.md](file:///d:/Projects/Active/math/docs/ROADMAP.md) Phase 0 任务 0.4
- [GIT_WORKFLOW.md §3.2](file:///d:/Projects/Active/math/docs/GIT_WORKFLOW.md) PR 检查清单
