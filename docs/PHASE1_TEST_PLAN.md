# Phase 1 严格测试方案 v2

> Phase 1（底层重构）退出前的严格测试计划。
>
> **v2 修订**：收紧 Phase 边界、增加架构约束、修正 isolate 测试、引入测试分类、补充 Golden/恢复/AI Verification Report、声明性能环境、按 AI 友好方式重组目录。
>
> 设计原则：
> 1. **不信任任何"看起来对了"的实现** —— 每条断言必须验证具体行为
> 2. **测试即架构守门** —— ADR 决策必须有可执行约束
> 3. **Phase 边界严格** —— Phase 1 只验证"地基"，不验证"上层装修"
> 4. **可分类、可延期** —— 非关键测试不阻塞 Phase 退出
> 5. **AI 可执行** —— 每个 PR 必须产出 AI Verification Report

---

## 0. Phase 边界声明（v2 新增）

### Phase 1 测试范围（IN-SCOPE）

| 模块 | 测试目标 |
|------|---------|
| `core/parser/` | 解析正确性、嵌套、优先级、边界 |
| `core/router/` | 路由表、初始位置、栈深度、深链接 |
| `data/storage/` | .md 单一真相源、迁移幂等、原子写 |
| `data/models/` | Document AST 不可变性、copyWith |
| `domain/providers/` | Provider 唯一性、autoDispose |
| `domain/services/` | 错误分类、消息友好性 |
| `presentation/widgets/markdown_input_field.dart` | 工具栏按钮齐全性 |
| 架构约束 | 分层依赖、Repository 唯一入口 |

### Phase 1 不测试范围（OUT-OF-SCOPE，移到 Phase 2+）

| 移除项 | 原因 | 去向 |
|--------|------|------|
| TC-1.8.5 公式渲染（WebView LaTeX 请求）| 属 Renderer 架构 | Phase 2 编辑模型 |
| TC-1.8.6 表格 DOM 渲染 | 属 Parser+Renderer 集成 | Phase 2 |
| TC-1.8.8 1000 行滚动帧时间 <16ms | 属 UI 性能优化 | Phase 3 UI Implementation |
| WYSIWYG 块编辑 | 属编辑内核 | Phase 2 |
| 复杂 UI 动画 / 主题 | 属 UI 实现 | Phase 3 |

### 集成测试保留最小集（Critical Integration）

- TC-1.8.1 CRUD 完整往返
- TC-1.8.2 导出 PDF（仅验证文件存在 + 魔数）
- TC-1.8.3 导出 Word（仅验证 zip 魔数）
- TC-1.8.4 撤销重做
- TC-1.8.7 导出失败友好降级
- TC-1.8.11 离线可用

---

## 1. 测试分类（v2 新增）

### 1.1 分类定义

| 类别 | 定义 | 阻塞 Phase 退出？ |
|------|------|-----------------|
| **Critical** | 涉及数据完整性、架构约束、ADR 决策 | ✅ 阻塞 |
| **Major** | 涉及核心功能但非架构 | ✅ 阻塞 |
| **Minor** | UX 细节、边界美学、性能优化 | ❌ 可延期到 Phase 2 |
| **Performance** | 性能基线 | ⚠️ Critical 指标阻塞，Minor 可延期 |

### 1.2 分类清单

| TC | 类别 | 说明 |
|----|------|------|
| TC-1.1.x（Provider 唯一）| Critical | ADR-0002 |
| TC-1.2.1-1.2.15（Storage）| Critical | ADR-0003 |
| TC-1.3.x（路由）| Critical | 死代码消除 |
| TC-1.5.x（解析器）| Major | ADR-0004 |
| TC-1.6.x（工具栏）| Major | UI/parser 对齐 |
| TC-1.7.x（错误消息）| Major | 用户体验 |
| TC-1.8.1-1.8.4（E2E 核心）| Critical | 数据流 |
| TC-1.8.5-1.8.6（渲染）| **OUT-OF-SCOPE** | 移除 |
| TC-1.8.8（滚动性能）| Minor | 移到 Phase 3 |
| TC-ARCH-x | Critical | 架构守门 |
| TC-RECOVERY-x | Critical | 数据安全 |
| TC-PERF-x | Performance | 分指标 |

---

## 2. 架构约束测试（v2 新增）

### TC-ARCH-1 业务层禁止直接访问文件系统

- **方法**：静态扫描 `lib/presentation/**/*.dart`
- **禁止模式**：`File(` / `Directory(` / `RandomAccessFile`
- **断言**：0 命中
- **理由**：ADR-0003 要求文件操作必须经 `data/storage/`
- **工具**：`grep -rn "File(\|Directory(\|RandomAccessFile" lib/presentation/`

### TC-ARCH-2 Repository 唯一入口

- **方法**：扫描 `File.writeAsString` / `File.readAsString` / `File.writeAsBytes`
- **允许位置**：`lib/data/storage/`、`lib/core/services/file_service.dart`（`decodeBytesAuto` 兜底）
- **断言**：其他位置 0 命中
- **工具**：`grep -rn "writeAsString\|readAsString\|writeAsBytes" lib/ --include="*.dart"`

### TC-ARCH-3 分层依赖方向

- **方法**：分析 import 语句
- **断言**：
  - `lib/core/**/*.dart` 不 import `presentation/` / `domain/` / `providers/`
  - `lib/data/**/*.dart` 不 import `presentation/` / `domain/` / `providers/`
  - `lib/presentation/**/*.dart` 不直接 import `core/services/*Service`（除路由、常量）
- **工具**：自定义 dart 脚本或 `dart_code_metrics`

### TC-ARCH-4 禁止 `print()`

- **方法**：扫描 `lib/**/*.dart`
- **断言**：0 命中 `print(`（`debugPrint(` 允许）
- **对应**：AGENTS.md §6.1 #4

### TC-ARCH-5 禁止 `!` 强制解包（除非同行 null 检查）

- **方法**：静态分析
- **断言**：`!` 后不跟 `.` 且同行无 `!= null` / `?.` → 报告
- **对应**：AGENTS.md §2.2

### TC-ARCH-6 同名 Provider 全局唯一

- **方法**：`grep -rn "Provider =" lib/ --include="*.dart"`
- **断言**：每个 Provider 名仅 1 处定义
- **对应**：AGENTS.md §6.1 #2、ADR-0002

### TC-ARCH-7 文件行数 ≤ 400

- **方法**：扫描 `lib/**/*.dart`
- **断言**：每个文件 ≤ 400 行
- **对应**：AGENTS.md §1.2

### TC-ARCH-8 禁止新增全局静态状态

- **方法**：扫描 `static.*_cache` / `static.*_instance`
- **白名单**：`MermaidService._cache`（历史遗留，Phase 2 清理）
- **对应**：AGENTS.md §6.1 #7

### TC-ARCH-9 pubspec 依赖与 import 一致

- **方法**：比对 `pubspec.yaml` dependencies 与 `import 'package:...'` 集合
- **断言**：无未声明依赖
- **对应**：AGENTS.md §4.3

### TC-ARCH-10 一次性文件不入库

- **方法**：`git status` 工作区检查 + `.gitignore` 规则
- **断言**：工作区无 `*.log` / `*.tmp` / `*_output.txt` / `.workbuddy/`
- **对应**：AGENTS.md §6.2 #6/#12

---

## 3. Provider 测试（修正版）

### TC-1.1.1 全局定义唯一性
- **方法**：`grep -rn "sharedPreferencesProvider =" lib/`
- **断言**：仅 1 行命中
- **类别**：Critical

### TC-1.1.2 容器内单实例
- **方法**：`ProviderContainer()`，读 `darkModeProvider` 两次
- **断言**：`identical(state1, state2) == true`
- **类别**：Critical

### TC-1.1.3 状态变更广播
- **方法**：监听 `darkModeProvider`，修改状态
- **断言**：监听器被调用 1 次；新状态正确
- **类别**：Critical

### TC-1.1.4 并发异步访问（v2 修正：不用 isolate）
- **方法**：
  ```dart
  final results = await Future.wait([
    ref.read(documentsProvider.future),
    ref.read(documentsProvider.future),
    ref.read(documentsProvider.future),
  ]);
  ```
- **断言**：3 个结果完全相等；无重复初始化日志；无数据竞争
- **类别**：Major
- **修正说明**：Riverpod Provider 状态属于 isolate 内存，不能跨 isolate 共享。改用 `Future.wait` 验证并发异步读

### TC-1.1.5 autoDispose 资源释放
- **方法**：创建 autoDispose provider → 触发 dispose
- **断言**：Stream 被 close；Timer 被 cancel；无泄漏警告
- **类别**：Critical

---

## 4. Storage 严格测试

### TC-1.2.1 创建不生成 JSON
- **断言**：`<dir>/*.md` 存在；`formula_fix_documents.json` 不存在
- **类别**：Critical

### TC-1.2.2 读取从 .md
- **断言**：内容与文件一致
- **类别**：Critical

### TC-1.2.3 删除文件物理移除
- **断言**：磁盘无 `.md`；`listDocuments()` 不含
- **类别**：Critical

### TC-1.2.4 重命名同步文件名
- **断言**：旧文件名不存在；新文件名存在；内容一致
- **类别**：Critical

### TC-1.2.5 JSON 迁移幂等
- **断言**：第一次迁移 N 个；第二次返回 true 不重复
- **类别**：Critical

### TC-1.2.6 H1 标题规则
- **断言**：.md 首行为 `# <title>`
- **类别**：Major

### TC-1.2.7 front matter 往返
- **断言**：meta 一致；body 不含 front matter
- **类别**：Major

### TC-1.2.8 原子写无 .tmp 残留
- **方法**：写 100 次
- **断言**：无 `*.tmp` 文件
- **类别**：Critical

### TC-1.2.9 GBK 兜底
- **方法**：手动写入 GBK 编码 .md
- **断言**：`decodeBytesAuto` 解码正确，不抛 FormatException
- **类别**：Critical

### TC-1.2.10 大目录性能
- **方法**：预置 1000 个 .md
- **断言**：`listDocuments()` < 500ms（见 §9 环境）
- **类别**：Performance

### TC-1.2.11 大文件不 OOM
- **方法**：读取 10MB .md
- **断言**：不抛 OutOfMemoryError；内容完整
- **类别**：Major

### TC-1.2.12 SharedPreferences 清理
- **断言**：迁移后 `pref_last_content` 键不存在
- **类别**：Critical

### TC-1.2.13 时间戳精度
- **断言**：`createdAt` / `updatedAt` 精度到秒，不为 null
- **类别**：Major

---

## 5. 路由测试

### TC-1.3.1 初始路由
- **断言**：`routeName == '/files'`
- **类别**：Critical

### TC-1.3.2 首屏文案
- **断言**：`find.text('文件管理')` 命中 1 个
- **类别**：Major

### TC-1.3.3 DocumentListScreen 已注册
- **断言**：`router.routes.containsKey('/files')`
- **类别**：Critical

### TC-1.3.4 文件点击跳转
- **断言**：路由变为 `/editor`
- **类别**：Major

### TC-1.3.5 返回栈不重复
- **断言**：返回到 /files 不重复入栈
- **类别**：Major

### TC-1.3.6 深链接重定向
- **方法**：启动直接 push `/editor`
- **断言**：重定向到 `/files`
- **类别**：Critical

### TC-1.3.7 栈深度
- **断言**：`navigator.stack.length <= 3`
- **类别**：Major

### TC-1.3.8 不存在文件
- **断言**：显示友好错误，不崩溃
- **类别**：Major

### TC-1.3.9 Android 返回键
- **断言**：/editor → /files；/files → 退出
- **类别**：Major

---

## 6. 解析器测试

### TC-1.5.1 行内代码
- 输入：`` `code` ``
- 断言：`InlineCodeElement('code')`
- 类别：Major

### TC-1.5.2 链接
- 输入：`[text](url)`
- 断言：`LinkElement(text: 'text', url: 'url')`
- 类别：Major

### TC-1.5.3 图片
- 输入：`![alt](url)`
- 断言：`ImageElement(alt: 'alt', url: 'url')`
- 类别：Major

### TC-1.5.4 斜体两种语法
- `*text*` / `_text_` → `ItalicElement`
- 类别：Major

### TC-1.5.5 删除线
- `~~text~~` → `StrikethroughElement`
- 类别：Major

### TC-1.5.6 任务列表
- `- [ ]` → `checked: false`；`- [x]` → `checked: true`
- 类别：Major

### TC-1.5.7 水平线三种语法
- `---` / `***` / `___` → `HorizontalRuleElement`
- 类别：Major

### TC-1.5.8 代码块
- `` ```python\ncode\n``` `` → `CodeElement(language: 'python')`
- 类别：Major

### TC-1.5.9 表格
- 断言：`TableElement(headers, rows)` 结构正确
- 类别：Major

### TC-1.5.10 嵌套样式
- `**bold *italic* bold**` → BoldElement 内含 ItalicElement
- 类别：Critical

### TC-1.5.11 优先级（图片 > 链接）
- `![alt](url)` 不被识别为 link
- 类别：Critical

### TC-1.5.12 代码块内不解析 markdown
- 类别：Critical

### TC-1.5.13 空文档
- 输入：`""` → 返回 `[]`
- 类别：Major

### TC-1.5.14 解析性能
- 1000 行 < 50ms（见 §9）
- 类别：Performance

### TC-1.5.15 公式内不解析 markdown
- `$E = mc^2$` → FormulaElement，不变斜体
- 类别：Critical

### TC-1.5.16 未闭合语法回退
- `**unclosed bold` → TextElement，不崩溃
- 类别：Critical

### TC-1.5.17 Unicode 支持
- `# 中文标题` → `HeadingElement(text: '中文标题')`
- 类别：Major

### TC-1.5.18 CRLF 兼容
- `line1\r\nline2` → 两段，不含 `\r`
- 类别：Major

---

## 7. 工具栏测试

### TC-1.6.1 14 个按钮存在
- 类别：Major

### TC-1.6.2 每个按钮插入正确标记
- 类别：Major

### TC-1.6.3 选中包裹
- 选 "hello" → 加粗 → `**hello**`
- 类别：Major

### TC-1.6.4 未选中光标定位
- 类别：Minor

### TC-1.6.5 代码块成对围栏
- 类别：Major

### TC-1.6.6 撤销链路
- 类别：Major

### TC-1.6.7 横向滚动可见所有按钮
- 类别：Minor

### TC-1.6.8 暗色模式对比度 ≥ 4.5:1
- 类别：Minor（移到 Phase 3 严格执行）

### TC-1.6.9 高频点击不崩溃
- 类别：Major

---

## 8. 错误消息测试

### TC-1.7.1 不含 stack trace
- 断言：不含 "stack" / "at " / ".dart:"
- 类别：Critical

### TC-1.7.2 不含源文件路径
- 断言：不含 `d:/` / `/Users/` / `/home/`
- 类别：Critical

### TC-1.7.3 不含 LaTeX 源
- 断言：不含 `\frac` / `\sum` 等 LaTeX 命令
- 类别：Critical

### TC-1.7.4 消息长度 < 60 字符
- 类别：Major

### TC-1.7.5 含行动建议
- 断言：含"请检查" / "请重试" / "请确认"
- 类别：Major

### TC-1.7.6 根因区分
- 断言：FileNotFound vs PermissionDenied 消息不同
- 类别：Major

### TC-1.7.7 i18n-ready
- 断言：走 `ExportFailure` 枚举或本地化 key
- 类别：Minor

### TC-1.7.8 日志与 UI 分离
- 断言：`debugPrint` 输出 detail；UI 不显示
- 类别：Major

---

## 9. 集成测试（Critical 集成子集）

### TC-1.8.1 CRUD 完整往返
- 类别：Critical

### TC-1.8.2 导出 PDF（仅验证魔数）
- 断言：文件存在；size > 0；首 4 字节 `%PDF`
- 类别：Critical

### TC-1.8.3 导出 Word（仅验证 zip 魔数）
- 断言：文件存在；首 2 字节 `PK`
- 类别：Critical

### TC-1.8.4 撤销重做
- 类别：Major

### TC-1.8.7 导出失败友好降级
- 类别：Critical

### TC-1.8.11 离线可用
- 类别：Major

---

## 10. 错误注入 + 恢复测试（v2 扩展）

### 错误注入

| TC | 场景 | 类别 |
|----|------|------|
| TC-8.1 | 磁盘满 | Critical |
| TC-8.2 | 权限拒绝 | Critical |
| TC-8.3 | 文件被外部修改 | Major |
| TC-8.4 | 损坏 .md（非法 UTF-8）| Critical |
| TC-8.5 | 公式 SVG 服务挂掉 | Major |
| TC-8.6 | WebView 初始化失败 | Major |

### 恢复测试（v2 新增）

#### TC-RECOVERY-1 写入中断恢复
- **方法**：
  1. 开始 `writeDocument(doc)`
  2. 在 `.tmp` 写入后、rename 前模拟 kill 进程
  3. 重新启动 App
- **断言**：
  - 原文档仍存在且内容完整（旧版本）
  - `.tmp` 残留被清理或忽略
  - 用户可继续编辑
- **类别**：Critical

#### TC-RECOVERY-2 迁移中断恢复
- **方法**：
  1. JSON 迁移到一半 kill
  2. 重启 → `migrateIfNeeded()` 再次执行
- **断言**：
  - `*.json.bak` 备份存在
  - 所有文档已迁移为 .md
  - 无数据丢失
- **类别**：Critical

#### TC-RECOVERY-3 异常崩溃后状态恢复
- **方法**：
  1. 编辑文档未保存
  2. App 崩溃（模拟 `exit(1)`）
  3. 重启
- **断言**：
  - 磁盘上文档为上次保存状态
  - App 可正常启动，无白屏
- **类别**：Critical

#### TC-RECOVERY-4 权限恢复
- **方法**：
  1. 权限被收回
  2. 用户操作触发错误
  3. 用户在系统设置恢复权限
  4. 重试操作
- **断言**：
  - 不需要重启 App
  - 操作可成功
- **类别**：Major

#### TC-RECOVERY-5 存储空间恢复
- **方法**：
  1. 磁盘满，保存失败
  2. 用户清理空间
  3. 重试保存
- **断言**：
  - 文档状态保持
  - 重试可成功
- **类别**：Major

---

## 11. Golden UI 测试（v2 新增）

> 仅用于**布局回归**，不验证视觉美化（美化属 Phase 3）。

### TC-GOLDEN-1 FileManager 布局
- **方法**：pump `FileManagerScreen` → 截图
- **断言**：与 `test/golden/file_manager.png` 比较，差异 < 1%
- **类别**：Major
- **更新**：`flutter test --update-goldens`

### TC-GOLDEN-2 EditorScreen 布局
- **方法**：pump `EditorScreen`（带固定文本）
- **断言**：与 golden 比较
- **类别**：Major

### TC-GOLDEN-3 工具栏布局
- **方法**：pump `MarkdownInputField`
- **断言**：14 个按钮可见（可滚动）
- **类别**：Major

### TC-GOLDEN-4 暗色模式布局
- **方法**：dark mode 下重复 TC-GOLDEN-1/2/3
- **类别**：Minor

### TC-GOLDEN-5 旋转布局
- **方法**：横屏下 pump
- **断言**：布局不溢出
- **类别**：Minor

---

## 12. 不可变性测试

### TC-10.1 StateNotifier 状态引用变化
- 类别：Critical

### TC-10.2 集合不就地修改
- 类别：Critical

### TC-10.3 Document.copyWith
- 类别：Major

---

## 13. 幂等性测试

### TC-11.1 多次迁移不重复
- 类别：Critical

### TC-11.2 多次保存
- 类别：Major

### TC-11.3 多次删除
- 类别：Major

---

## 14. 性能测试（v2 增加环境声明）

### 14.1 测试环境声明（必须）

```markdown
Performance Environment:
  CI: GitHub Actions ubuntu-latest
  CPU: 4 cores, 16GB RAM (GitHub runner spec)
  OS: Ubuntu 22.04
  Flutter: 3.44.6 (stable)
  Dart: 3.12.2
  Mode: release (--profile 测试时)
  Repetitions: 10 次取中位数
```

本地开发者机器指标仅供参考，**以 CI 为退出标准**。

### 14.2 指标

| TC | 场景 | 基线 | 类别 |
|----|------|------|------|
| TC-PERF-1 | `MarkdownParser.parse(1000 行)` | < 50ms | Performance-Critical |
| TC-PERF-2 | `listDocuments(1000 文件)` | < 500ms | Performance-Critical |
| TC-PERF-3 | 路由切换（/files → /editor）| < 200ms | Performance-Major |
| TC-PERF-4 | 冷启动 → /files 可见 | < 2s | Performance-Major |
| TC-PERF-5 | 导出 100 页 PDF | < 10s | Performance-Minor |

**滚动帧时间、WebView 冷启动等 UI 性能移到 Phase 3**。

---

## 15. AI Verification Report（v2 新增）

### 15.1 每个 PR 必须产出

在 PR 描述末尾追加 `## AI Verification Report` 段落：

```markdown
## AI Verification Report

Task: ROADMAP 1.x <task name>
ADR: ADR-000X (if applicable)
Risk: Low / Medium / High

### Validation Evidence

| TC ID | Result | Evidence |
|-------|--------|---------|
| TC-1.2.1 | ✅ Pass | `test/storage/...:42` |
| TC-1.2.5 | ✅ Pass | `test/storage/...:108` |
| TC-1.2.6 | ❌ Fail | "Migration recovery: .bak not created" |
| TC-ARCH-1 | ✅ Pass | `grep` output: 0 hits |

### Failure Analysis (if any)

- TC-1.2.6 失败原因：rename 前未创建 .bak
- 修复方案：在 `writeDocument` 前调用 `File.copy(.bak)`
- Follow-up：本 PR 包含修复

### Coverage Delta

- 修改前：72.3%
- 修改后：74.1%
- 关键模块（core/parser）：91.2%

### Self Review Checklist

- [x] 符合 AGENTS.md 编码规范
- [x] 符合 ADR-000X
- [x] 无 scope drift
- [x] 无新技术债
- [x] 文档已同步

### Stop Conditions

- 5 次修复未通过 → 已触发 / 未触发
```

### 15.2 Phase 1 退出前的总报告

合并所有 PR 的 Verification Report，产出 `docs/PHASE1_VERIFICATION_REPORT.md`：

```markdown
# Phase 1 Verification Report

## Summary

- Total TCs: 100+
- Passed: 100+
- Failed: 0
- Coverage: 73.5%
- Critical 模块: 91.2%

## Per-ADR Evidence

### ADR-0002 Provider 唯一
- TC-1.1.1 ~ TC-1.1.5: ✅
- TC-ARCH-6: ✅

### ADR-0003 Storage 单一真相源
- TC-1.2.1 ~ TC-1.2.13: ✅
- TC-ARCH-1, TC-ARCH-2: ✅
- TC-RECOVERY-1, TC-RECOVERY-2: ✅

### ADR-0004 Parser 扩展
- TC-1.5.1 ~ TC-1.5.18: ✅
- TC-1.6.1 ~ TC-1.6.9: ✅

## Performance

| TC | Result | Baseline | Actual |
|----|--------|----------|--------|
| TC-PERF-1 | ✅ | 50ms | 32ms |
| TC-PERF-2 | ✅ | 500ms | 280ms |

## Human Owner Sign-off

- [ ] Approved by Human Owner
- Date: YYYY-MM-DD
```

---

## 16. 测试目录结构（v2 新增，AI 友好）

```
test/
├── architecture/                 # TC-ARCH-x（架构守门）
│   ├── dependency_rule_test.dart
│   ├── file_access_test.dart
│   ├── layer_dependency_test.dart
│   ├── no_print_test.dart
│   ├── provider_uniqueness_test.dart
│   ├── file_size_test.dart
│   └── no_global_static_test.dart
│
├── provider/                     # TC-1.1.x
│   ├── uniqueness_test.dart
│   ├── instance_test.dart
│   └── auto_dispose_test.dart
│
├── storage/                      # TC-1.2.x + TC-RECOVERY-x
│   ├── crud_test.dart
│   ├── migration_test.dart
│   ├── atomic_write_test.dart
│   ├── gbk_test.dart
│   ├── large_file_test.dart
│   └── recovery_test.dart
│
├── router/                       # TC-1.3.x
│   ├── initial_route_test.dart
│   ├── stack_test.dart
│   └── deep_link_test.dart
│
├── parser/                       # TC-1.5.x
│   ├── inline_test.dart
│   ├── block_test.dart
│   ├── nested_test.dart
│   ├── priority_test.dart
│   ├── edge_case_test.dart
│   └── performance_test.dart
│
├── toolbar/                      # TC-1.6.x
│   ├── buttons_exist_test.dart
│   ├── insert_behavior_test.dart
│   └── stress_test.dart
│
├── error/                        # TC-1.7.x + TC-8.x
│   ├── message_friendly_test.dart
│   └── fault_injection_test.dart
│
├── integration/                 # TC-1.8.x（Critical 集成子集）
│   ├── crud_flow_test.dart
│   ├── export_test.dart
│   └── offline_test.dart
│
├── golden/                       # TC-GOLDEN-x
│   ├── file_manager_test.dart
│   ├── editor_test.dart
│   └── golden/                  # 基线图
│       ├── file_manager.png
│       ├── editor.png
│       └── toolbar.png
│
├── immutability/                 # TC-10.x
│   └── state_test.dart
│
├── idempotency/                  # TC-11.x
│   └── repeat_operation_test.dart
│
└── performance/                  # TC-PERF-x
    ├── parser_perf_test.dart
    ├── list_perf_test.dart
    └── cold_start_test.dart
```

**命名规则**：
- `<topic>_test.dart` 单一主题
- 每个文件 < 300 行
- TC ID 作为注释标注在测试组上：`// TC-1.2.5`

---

## 17. 执行清单

### 17.1 新增测试文件（按优先级）

**P0（Critical，阻塞退出）**：
- [ ] `test/architecture/dependency_rule_test.dart` — TC-ARCH-1~3
- [ ] `test/architecture/no_print_test.dart` — TC-ARCH-4
- [ ] `test/architecture/provider_uniqueness_test.dart` — TC-ARCH-6
- [ ] `test/storage/recovery_test.dart` — TC-RECOVERY-1~3
- [ ] `test/storage/migration_test.dart` — TC-1.2.5
- [ ] `test/storage/atomic_write_test.dart` — TC-1.2.8

**P1（Major，阻塞退出）**：
- [ ] `test/parser/edge_case_test.dart` — TC-1.5.16
- [ ] `test/error/message_friendly_test.dart` — TC-1.7.x
- [ ] `test/integration/crud_flow_test.dart` — TC-1.8.1
- [ ] `test/golden/file_manager_test.dart` — TC-GOLDEN-1

**P2（Performance，分指标）**：
- [ ] `test/performance/parser_perf_test.dart` — TC-PERF-1
- [ ] `test/performance/list_perf_test.dart` — TC-PERF-2

### 17.2 现有测试回归
- [ ] `flutter test` 现有 236 测试 0 退化

### 17.3 覆盖率检查
- [ ] 总覆盖率 ≥ 70%
- [ ] `core/parser/` ≥ 90%
- [ ] `data/storage/` ≥ 90%

### 17.4 AI Verification Report
- [ ] 每个 PR 含 `## AI Verification Report` 段落
- [ ] Phase 1 退出前产出 `docs/PHASE1_VERIFICATION_REPORT.md`

---

## 18. 退出门槛（v2 修订）

Phase 1 退出需满足 **全部 8 条**：

1. **Critical 测试 100% 通过**（含 TC-ARCH、TC-RECOVERY、TC-1.1/1.2/1.3 关键）
2. **Major 测试 ≥ 95% 通过**（允许 5% 非关键延期）
3. **Performance-Critical 达标**（TC-PERF-1/2 在 CI 环境达标）
4. **覆盖率达标**（总 ≥ 70%，关键模块 ≥ 90%）
5. **现有 236 测试 0 退化**
6. **无 P0/P1 bug 未修复**
7. **每个 PR 含 AI Verification Report**
8. **Human Owner 在 `PHASE1_VERIFICATION_REPORT.md` 签字**

**任何一条不满足，Phase 1 不退出。**

---

**本文档由首席架构工程师维护，版本 v2.0，生效日期 2026-07-18。**
**v1 → v2 变更摘要**：收紧 Phase 边界 / 增加架构约束 / 修正 isolate / 测试分类 / Golden / 恢复 / 性能环境 / AI Verification / 目录重组
