# Phase 1 严格测试方案

> Phase 1（底层重构）退出前的严格测试计划。每个测试用例必须全部通过，Phase 1 才能退出。
>
> 设计原则：**不信任任何"看起来对了"的实现**。每条断言必须验证具体行为，而非"函数返回非 null"。

---

## 0. 退出标准

| 维度 | 通过线 |
|------|--------|
| 单元测试覆盖率 | ≥ 70%（关键模块 `core/parser` / `data/storage` ≥ 90%） |
| 集成测试 | 100% 通过 |
| 性能测试 | 全部达标（详见 §9） |
| 错误注入测试 | 全部不崩溃 + 友好提示 |
| 回归测试 | 现有 236 个测试 0 退化 |
| Bug 严重度 | 无 P0/P1 未修复 |

---

## 1. Provider 唯一性（ROADMAP 1.1）

### TC-1.1.1 全局定义唯一性（静态扫描）
- **方法**：`grep -rn "sharedPreferencesProvider =" lib/`
- **断言**：仅 1 行命中
- **同样验证**：`darkModeProvider` / `documentsProvider` 等所有 Provider

### TC-1.1.2 容器内单实例
- **方法**：创建 `ProviderContainer()`，读取 `darkModeProvider` 两次
- **断言**：`identical(state1, state2)` 为 `true`

### TC-1.1.3 状态变更广播
- **方法**：监听 `darkModeProvider`，修改状态
- **断言**：监听器被调用 1 次，新状态正确

### TC-1.1.4 并发访问无竞态
- **方法**：并发 5 个 isolate 读 `documentsProvider`
- **断言**：返回值一致，无异常

### TC-1.1.5 autoDispose 行为
- **方法**：创建 autoDispose provider，触发 dispose
- **断言**：资源（Stream / Timer）被释放，`debugPrint` 无泄漏警告

---

## 2. 存储单一真相源（ROADMAP 1.2）

### TC-1.2.1 创建不生成 JSON
- **方法**：在临时目录创建文档
- **断言**：`<dir>/*.md` 存在；`<dir>/formula_fix_documents.json` 不存在

### TC-1.2.2 读取从 .md
- **方法**：手动写入 .md 文件，通过 repository 读取
- **断言**：内容与文件一致

### TC-1.2.3 删除文件物理移除
- **方法**：删除文档
- **断言**：`.md` 文件不在磁盘；`listDocuments()` 不含该文档

### TC-1.2.4 重命名同步文件名
- **方法**：重命名文档
- **断言**：旧文件名不存在；新文件名存在；内容一致

### TC-1.2.5 JSON 迁移幂等
- **方法**：预置 JSON → 调用 `migrateIfNeeded` → 再调用一次
- **断言**：第一次迁移 2 个文档，第二次返回 true 不重复迁移

### TC-1.2.6 迁移中断恢复
- **方法**：迁移到一半 kill 进程 → 重新启动
- **断言**：备份文件 `*.json.bak` 存在；重试成功；数据无丢失

### TC-1.2.7 H1 标题规则
- **方法**：创建文档标题 "我的笔记"
- **断言**：.md 文件首行为 `# 我的笔记`

### TC-1.2.8 front matter 往返
- **方法**：写入 `created_at: 2026-07-18` → 读取
- **断言**：meta 一致；body 不含 front matter

### TC-1.2.9 时间戳精度
- **断言**：`createdAt` / `updatedAt` 精度到秒，不为 null

### TC-1.2.10 原子写无 .tmp 残留
- **方法**：写 100 次文档
- **断言**：目录中无 `*.tmp` 文件

### TC-1.2.11 GBK 兜底
- **方法**：手动写入 GBK 编码 .md
- **断言**：`decodeBytesAuto` 正确解码，不抛 FormatException

### TC-1.2.12 大目录性能
- **方法**：预置 1000 个 .md 文件，调用 `listDocuments()`
- **断言**：耗时 < 500ms（CI 环境）

### TC-1.2.13 大文件不 OOM
- **方法**：读取 10MB 的 .md
- **断言**：不抛 OutOfMemoryError；内容完整

### TC-1.2.14 并发写保护
- **方法**：两个 isolate 同时写同一文档
- **断言**：不产生损坏文件；最终内容为后写者

### TC-1.2.15 SharedPreferences 清理
- **方法**：迁移后检查 `SharedPreferences`
- **断言**：`pref_last_content` 键不存在

---

## 3. 路由死代码消除（ROADMAP 1.3 / 1.4）

### TC-1.3.1 初始路由
- **方法**：`pumpWidget(App)`，检查初始路由
- **断言**：`routeName == '/files'`，不是 `'/'`

### TC-1.3.2 首屏文案
- **断言**：`find.text('文件管理')` 命中 1 个

### TC-1.3.3 DocumentListScreen 已注册
- **方法**：`router.routes.containsKey('/files')`
- **断言**：true

### TC-1.3.4 文件点击跳转
- **方法**：pump /files → 点击第一个文件
- **断言**：路由变为 `/editor`

### TC-1.3.5 返回栈
- **方法**：从 /editor 返回
- **断言**：回到 /files，不重复入栈

### TC-1.3.6 深链接重定向
- **方法**：启动时直接 push `/editor`
- **断言**：重定向到 `/files`（无文档上下文）

### TC-1.3.7 栈深度
- **断言**：任意时刻 `navigator.stack.length <= 3`

### TC-1.3.8 不存在文件
- **方法**：`go('/editor?path=nonexistent.md')`
- **断言**：显示友好错误，不崩溃

### TC-1.3.9 Android 返回键
- **方法**：模拟系统返回
- **断言**：在 /editor 回到 /files；在 /files 退出 App

### TC-1.3.10 路由切换性能
- **断言**：路由切换 < 200ms（release mode）

---

## 4. 解析器完整正确性（ROADMAP 1.5）

### TC-1.5.1 行内代码
- 输入：`` `code` ``
- 断言：`InlineCodeElement('code')`

### TC-1.5.2 链接
- 输入：`[text](url)`
- 断言：`LinkElement(text: 'text', url: 'url')`

### TC-1.5.3 图片
- 输入：`![alt](url)`
- 断言：`ImageElement(alt: 'alt', url: 'url')`

### TC-1.5.4 斜体两种语法
- `*text*` → `ItalicElement`
- `_text_` → `ItalicElement`

### TC-1.5.5 删除线
- `~~text~~` → `StrikethroughElement`

### TC-1.5.6 任务列表
- `- [ ] todo` → `TaskListItemElement(checked: false)`
- `- [x] done` → `TaskListItemElement(checked: true)`

### TC-1.5.7 水平线三种语法
- `---` / `***` / `___` → `HorizontalRuleElement`

### TC-1.5.8 代码块
- `` ```python\nprint('hi')\n``` `` → `CodeElement(language: 'python')`

### TC-1.5.9 表格
- 输入：`| H1 | H2 |\n| --- | --- |\n| a | b |`
- 断言：`TableElement(headers: ['H1','H2'], rows: [['a','b']])`

### TC-1.5.10 嵌套样式
- `**bold *italic* bold**`
- 断言：BoldElement 内含 ItalicElement

### TC-1.5.11 优先级（图片 > 链接）
- `![alt](url)` 不被识别为 link
- 断言：返回 ImageElement 而非 LinkElement

### TC-1.5.12 代码块内不解析
- `` ```\n**not bold**\n``` ``
- 断言：CodeElement.code 含 `**not bold**` 原文

### TC-1.5.13 空文档
- 输入：`""`
- 断言：返回 `[]`

### TC-1.5.14 解析性能
- 输入：1000 行混合内容
- 断言：< 50ms（CI 环境）

### TC-1.5.15 公式内不解析 markdown
- `$E = mc^2$` → FormulaElement.latex 含 `E = mc^2`，不变成斜体

### TC-1.5.16 未闭合语法回退
- 输入：`**unclosed bold`
- 断言：返回 `TextElement('**unclosed bold')`，不崩溃

### TC-1.5.17 Unicode 支持
- 输入：`# 中文标题`
- 断言：`HeadingElement(level: 1, text: '中文标题')`

### TC-1.5.18 CRLF 兼容
- 输入：`line1\r\nline2`
- 断言：解析为两段，不含 `\r`

---

## 5. 工具栏对齐（ROADMAP 1.6）

### TC-1.6.1 14 个按钮存在
- 断言：`find.byTooltip(...)` 命中 14 个不同 tooltip（已实现）

### TC-1.6.2 每个按钮插入正确标记
- 逐个点击按钮，断言 controller.text 含预期片段

### TC-1.6.3 选中包裹
- 选 "hello"，点加粗 → `**hello**`

### TC-1.6.4 未选中光标定位
- 未选，点加粗 → `****`，光标在中间（offset = start+2）

### TC-1.6.5 代码块成对围栏（已实现）

### TC-1.6.6 撤销链路
- 点插入 → Ctrl+Z → 文本恢复
- 断言：`controller.text == beforeInsert`

### TC-1.6.7 旋转可访问
- 设备旋转 90° → 工具栏滚动可见所有按钮

### TC-1.6.8 暗色模式对比度
- 暗色模式下按钮 icon 色与背景对比度 ≥ 4.5:1（WCAG AA）

### TC-1.6.9 长工具栏滚动
- 横向滚动到末尾 → 表格按钮可见可点击

### TC-1.6.10 高频点击不崩溃
- 100 次 / 秒点击加粗 → 无异常，文本状态一致

---

## 6. 错误消息友好性（ROADMAP 1.7）

### TC-1.7.1 不含 stack trace
- 触发导出失败 → 用户可见消息
- 断言：不含 "stack" / "at " / ".dart:" 字样

### TC-1.7.2 不含源文件路径
- 断言：不含 `d:/` / `/Users/` / `/home/`

### TC-1.7.3 不含 LaTeX 源
- 公式渲染失败
- 断言：消息不含 `\frac` / `\sum` 等 LaTeX 命令

### TC-1.7.4 消息长度
- 断言：用户消息 < 60 字符

### TC-1.7.5 含行动建议
- 断言：含"请检查" / "请重试" / "请确认"等动作词

### TC-1.7.6 根因区分
- FileNotFound vs PermissionDenied → 消息文案不同
- 断言：两个消息字符串不相等

### TC-1.7.7 i18n-ready
- 断言：所有用户消息走 `ExportFailure` 枚举或本地化 key，不硬编码

### TC-1.7.8 日志与 UI 分离
- 断言：`debugPrint` 仍输出 detail（开发者可见），UI 不显示

---

## 7. 集成测试（ROADMAP 1.8）

### TC-1.8.1 CRUD 完整往返
- 创建 → 编辑 → 保存 → 关闭 → 重开
- 断言：内容一致；标题一致；时间戳 updatedAt > createdAt

### TC-1.8.2 导出 PDF
- 打开 .md → 导出 PDF
- 断言：文件存在；size > 0；首 4 字节为 `%PDF`

### TC-1.8.3 导出 Word
- 断言：文件存在；size > 0；为 zip 格式（首 2 字节 `PK`）

### TC-1.8.4 撤销重做
- 输入 → 修改 → 撤销 → 重做
- 断言：状态与修改后一致

### TC-1.8.5 公式渲染
- 插入 `$E=mc^2$` → 预览
- 断言：WebView 收到 LaTeX 渲染请求

### TC-1.8.6 表格渲染
- 插入表格 → 预览
- 断言：DOM 含 `<table>`

### TC-1.8.7 导出失败友好
- 故意写坏 LaTeX → 导出
- 断言：用户看到友好消息；不崩溃

### TC-1.8.8 滚动性能
- 1000 行文档滚动
- 断言：帧时间 < 16ms（release mode）

### TC-1.8.9 后台恢复
- 进入后台 5 分钟 → 回前台
- 断言：状态保持；无数据丢失

### TC-1.8.10 低内存
- 模拟系统低内存警告
- 断言：不崩溃；关键状态恢复

### TC-1.8.11 离线可用
- 飞行模式
- 断言：打开 / 编辑 / 保存 / 导出 PDF 全部可用（不需联网）

---

## 8. 错误注入测试

### TC-8.1 磁盘满
- 模拟写文件抛 `FileSystemException`
- 断言：用户看到"存储空间不足"；不崩溃；内存状态不变

### TC-8.2 权限拒绝
- 模拟读文件抛 `FileSystemException(Permission denied)`
- 断言：用户看到"无权限访问"

### TC-8.3 文件被外部修改
- 打开后外部编辑 .md
- 断言：检测到变化时提示用户（不静默覆盖）

### TC-8.4 损坏 .md
- 写入非法 UTF-8 字节
- 断言：`decodeBytesAuto` 兜底，不崩溃

### TC-8.5 公式 SVG 服务挂掉
- `MermaidRendererHost` 未 mount
- 断言：导出走占位符路径，不抛异常

### TC-8.6 WebView 初始化失败
- fake platform 抛异常
- 断言：UI 显示降级文本，不空白

---

## 9. 性能基线

| 场景 | 基线 | 测量方式 |
|------|------|---------|
| `MarkdownParser.parse(1000 行)` | < 50ms | `Stopwatch` |
| `listDocuments(1000 文件)` | < 500ms | `Stopwatch` |
| 路由切换 | < 200ms | `flutter run --profile` + timeline |
| 1000 行文档滚动帧时间 | < 16ms | DevTools Performance |
| 冷启动 → /files 可见 | < 2s | `flutter run --profile` |
| 导出 100 页 PDF | < 10s | `Stopwatch` |
| 公式渲染单个 | < 100ms | `Stopwatch` |

---

## 10. 不可变性测试

### TC-10.1 StateNotifier 状态不可变
- 修改 `documentsProvider` 后 `state` 引用变化
- 断言：`identical(oldState, newState) == false`

### TC-10.2 集合不就地修改
- 监听 `documentsProvider`，调用 `addDocument`
- 断言：旧 `state.list` 长度不变；新 `state.list` 长度+1

### TC-10.3 Document 模型 copyWith
- 调用 `doc.copyWith(title: 'new')`
- 断言：原 `doc.title` 不变；新 `doc.title == 'new'`

---

## 11. 幂等性测试

### TC-11.1 多次迁移不重复
- `migrateIfNeeded()` 调用 3 次
- 断言：仅第一次实际迁移

### TC-11.2 多次保存
- 连续保存同一文档 3 次
- 断言：磁盘文件内容一致；时间戳 updatedAt 单调递增

### TC-11.3 多次删除
- 删除已删除文档
- 断言：返回 false，不抛异常

---

## 12. 执行清单

### 12.1 新增测试文件

- [ ] `test/provider_uniqueness_test.dart` — TC-1.1.x
- [ ] `test/storage_strict_test.dart` — TC-1.2.1 ~ 1.2.15（部分已存在）
- [ ] `test/router_strict_test.dart` — TC-1.3.x（部分已存在）
- [ ] `test/parser_strict_test.dart` — TC-1.5.x（部分已存在）
- [ ] `test/toolbar_strict_test.dart` — TC-1.6.x（部分已存在）
- [ ] `test/error_message_test.dart` — TC-1.7.x
- [ ] `test/e2e_flow_test.dart` — TC-1.8.x
- [ ] `test/fault_injection_test.dart` — TC-8.x
- [ ] `test/performance_test.dart` — TC-9
- [ ] `test/immutability_test.dart` — TC-10
- [ ] `test/idempotency_test.dart` — TC-11

### 12.2 现有测试回归
- [ ] `flutter test` 现有 236 个测试 0 退化

### 12.3 覆盖率检查
- [ ] `flutter test --coverage`
- [ ] `lcov --summary coverage/lcov.info` → 总覆盖率 ≥ 70%
- [ ] `core/parser/markdown_parser.dart` ≥ 90%
- [ ] `data/storage/` ≥ 90%

### 12.4 性能基线
- [ ] 在 release mode 跑 `performance_test.dart`
- [ ] 所有指标达标

---

## 13. 退出门槛

Phase 1 退出需满足：

1. §1-§11 所有测试用例 100% 通过
2. 覆盖率达标（§0）
3. 性能基线全部达标（§9）
4. 错误注入测试全部通过（§8）
5. 现有测试 0 退化
6. 无 P0/P1 bug 未修复
7. AI Self Review + Human Owner 签字

**任何一条不满足，Phase 1 不退出。**

---

**本文档由首席架构工程师维护，版本 v1.0，生效日期 2026-07-18。**
