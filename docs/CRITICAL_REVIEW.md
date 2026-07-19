# FormulaFix 严厉批判报告

> 评判基准：**Typora 端侧手机版**
> 审查日期：2026-07-18
> 审查范围：`lib/` 全量源码、`test/`、`web/`
> 立场：直言不讳，所有判断必须有代码证据

> **状态更新（2026-07-19，Phase 1 关闭后）**
>
> 本报告为 2026-07-18 的历史审查快照，原始内容保留以备溯源。下列项已在 Phase 0 / Phase 1 修复，详细证据见 [Verification Report](file:///d:/Projects/Active/math/docs/releases/phase1-verification-report.md) 与 [AGENTS.md §10](file:///d:/Projects/Active/math/AGENTS.md)：
>
> | 项 | 章节 | 修复 commit | Phase |
> |----|------|------------|-------|
> | P0-2 三套存储互不相通 | §2.1 | `b43e5c1` | 1.2 |
> | P0-3 DocumentListScreen 死代码 | §2.2 | `b36d930` | 1.3 |
> | P0-4 路由初始位置错误 | §2.3 | `b36d930` | 1.4 |
> | P0-5 Provider 重复定义 | §2.4 | `ec76f06` | 1.1 |
> | P0-6 解析器缺 7 类元素 | §3.1 | `da4ab00` | 1.5 |
> | P0-7 工具栏与解析器不一致 | §3.2 | `d57d2f2` | 1.6 |
> | P2-27 错误消息透传 detail | §7.1 | `f6a73af` | 1.7 |
> | P3-30 缺 pubspec.yaml | §8.1 | - | 0.1 |
> | P3-31 残留文件 | §8.2 | - | 0.6 |
> | P3-32 manifest 默认描述 | §8.3 | - | 0.6 |
> | P3-33 main() 多余 async | §8.4 | `b43e5c1` 副作用 | 1.2（添加 `await StorageMigration`，async 现为必要） |
> | P3-35 测试覆盖不足 | §8.6 | PR #23 | 1.8（314 tests / 0 regression） |
>
> **仍存在项**（按 Phase 跟踪）：
>
> - P0-1 编辑/预览分离模式（§1.1）→ Phase 3 UI Implementation
> - P3-34 静态状态污染测试（§8.5）→ Phase 2
> - 其余 P1 / P2 体验与设计问题 → Phase 3+

---

## 总评

**这个项目目前不配称为"Typora 端侧手机版"。** 它本质上是一个"带公式预览的 Markdown 编辑器原型"，距离 Typora 的体验哲学差着范式级的距离。Typora 的灵魂是 **所见即所得（WYSIWYG）** —— 编辑即渲染、无分离预览、内容为王；当前项目却是 **"编辑/预览双模式"** —— 用户在两个完全不同的视图间反复横跳，每次切换都丢失上下文。

更严重的是：项目存在 **三套互不相通的文档存储**、**两套重复定义的全局 Provider**、**一条死路由**、**解析器对 7 类 Markdown 元素盲视**。这些问题不是"待优化"，是"地基已经歪了"。

下面按严重程度自上而下展开。

---

## 一、范式级问题（P0：与 Typora 哲学根本冲突）

### 1.1 编辑/预览分离模式 — Typora 灵魂的对立面

**证据**：
- [editor_screen.dart:300-321](file:///d:/Projects/Active/math/flutter_app/lib/presentation/screens/editor_screen.dart#L300-321)：`isPreview` 三元运算符在 `PreviewContent`（只读渲染）和 `MarkdownInputField`（纯文本 TextField）之间切换
- [editor_bottom_bar.dart:38-49](file:///d:/Projects/Active/math/flutter_app/lib/presentation/widgets/editor_bottom_bar.dart#L38-49)：底部栏一整个 ElevatedButton 用于切换"编辑/预览"模式
- [providers.dart:109](file:///d:/Projects/Active/math/flutter_app/lib/providers/providers.dart#L109)：`previewModeProvider` 全局状态

**问题**：
1. 用户写公式时，必须切到预览才能看到效果；切回编辑时光标位置可能丢失（TextField 重建）
2. 预览态下文档**完全只读**，不能在渲染结果上直接编辑
3. 切换是**整屏替换**，没有过渡，丢失滚动位置
4. Typora 的核心体验是"光标所在的段落即时渲染，离开光标后渲染结果替换源码" —— 这个项目反其道而行

**影响**：写一篇含 30 个公式的论文，用户要在两个视图间切换 60+ 次，每次都重新对齐上下文。这不是 Typora 体验，是"两半残废的体验"。

### 1.2 预览态被卡片包裹 — 反沉浸式

**证据**：[preview_content.dart:38-47](file:///d:/Projects/Active/math/flutter_app/lib/presentation/widgets/preview_content.dart#L38-47)

```dart
return Container(
  margin: const EdgeInsets.all(AppSpacing.pageMargin),  // 16px 外边距
  decoration: BoxDecoration(
    color: bg,
    borderRadius: BorderRadius.circular(AppSpacing.cardRadius),  // 12px 圆角
    boxShadow: AppShadows.card(isDark: isDark),  // 阴影
  ),
```

**问题**：预览内容被当成"卡片"漂浮在背景色之上，左右各留 16px + 内边距 16px = 单边 32px 浪费。手机宽度本来就 360-414px，去掉 64px 后正文区只剩 ~300px。Typora 是**全屏沉浸式**，内容铺满编辑区。

### 1.3 AppBar 标题写死 "FormulaFix"

**证据**：[editor_screen.dart:337-342](file:///d:/Projects/Active/math/flutter_app/lib/presentation/screens/editor_screen.dart#L337-342)

```dart
title: const Text(
  'FormulaFix',
  overflow: TextOverflow.fade,
  ...
),
```

**问题**：AppBar 永远显示 "FormulaFix"，不显示当前文档标题。用户打开 5 个文档，AppBar 一模一样。Typora 标题栏永远显示当前文件名 + 修改状态（`•` 表示未保存）。

---

## 二、数据架构问题（P0：地基已歪）

### 2.1 三套互不相通的存储机制

| 存储 | 写入方 | 读取方 | 文件位置 |
|------|--------|--------|---------|
| `SharedPreferences['pref_last_content']` | [editor_providers.dart:43-54](file:///d:/Projects/Active/math/flutter_app/lib/providers/editor_providers.dart#L43-54) 500ms 防抖 | [editor_providers.dart:39](file:///d:/Projects/Active/math/flutter_app/lib/providers/editor_providers.dart#L39) 启动恢复 | 系统偏好 |
| `formula_fix_documents.json` | [document_service.dart:68-72](file:///d:/Projects/Active/math/flutter_app/lib/core/services/document_service.dart#L68-72) | `DocumentListScreen` 列表 | app docs dir |
| `formulafix_<timestamp>.md` | [file_service.dart:69-77](file:///d:/Projects/Active/math/flutter_app/lib/core/services/file_service.dart#L69-77) | `FileManagerScreen` 列表 | app docs dir |

**问题**：
1. 同一段 Markdown 内容可能同时存在三份副本，互不同步
2. 用户在编辑器里输入 → 存到 SharedPreferences；点"保存" → 写成 `.md`；但**这两个动作不会更新 JSON 文档库**
3. 用户从文档列表打开一个 JSON 文档 → 编辑 → 退出 → 文档列表显示的还是旧内容（因为 `EditorScreen` 完全不调用 `DocumentService.updateDocument`）
4. `FileManagerScreen` 只扫 `.md`，看不到 JSON 文档；`DocumentListScreen` 只读 JSON，看不到 `.md`

**影响**：用户不知道自己的文档到底存哪了。这是**数据丢失级**的设计缺陷。

### 2.2 路由断裂 — DocumentListScreen 是死代码

**证据**：
- [app_router.dart:7-23](file:///d:/Projects/Active/math/flutter_app/lib/core/router/app_router.dart#L7-23)：只注册了 `/editor` 和 `/files`
- 全局搜索 `DocumentListScreen` 没有路由跳转入口

**问题**：`DocumentListScreen` 有完整实现（240 行），但没有任何路由能跳到它。从 `EditorScreen` 想看文档列表？做不到。从 `FileManagerScreen`？也不行。这个类是孤儿。

### 2.3 路由初始位置错误

**证据**：[app_router.dart:8](file:///d:/Projects/Active/math/flutter_app/lib/core/router/app_router.dart#L8) `initialLocation: '/editor'`

**问题**：用户启动 App 直接进空白编辑器。Typora 启动时显示**最近文件列表**或**文件树**，让用户先选文档。当前设计等于强迫用户每次都从空白开始。

### 2.4 Provider 重复定义

**证据**：
- [providers/providers.dart:8-23](file:///d:/Projects/Active/math/flutter_app/lib/providers/providers.dart#L8-23) 定义 `sharedPreferencesProvider` + `darkModeProvider`
- [providers/editor_providers.dart:4-23](file:///d:/Projects/Active/math/flutter_app/lib/providers/editor_providers.dart#L4-23) **又定义了一遍**

**问题**：Riverpod 的 Provider 是按 "identity" 注册的，两个同名 Provider 在不同文件里是**两个独立实例**。`EditorScreen` import `editor_providers.dart`、`DocumentListScreen` import `providers.dart`，结果是**两个屏幕的暗色模式可能不同步**。这是一个非常隐蔽的 bug。

---

## 三、解析能力缺失（P1：Markdown 标准都不完整）

### 3.1 行内元素缺一半

**证据**：[markdown_parser.dart:279-308](file:///d:/Projects/Active/math/flutter_app/lib/core/parser/markdown_parser.dart#L279-308) `_parseBoldAndItalic` 只识别 `**bold**`。

**缺失的 Markdown 元素**（Typora 全部支持）：

| 元素 | 语法 | 当前状态 |
|------|------|---------|
| 斜体 | `*italic*` / `_italic_` | ❌ 不识别（虽然有工具栏按钮但解析器不认） |
| 行内代码 | `` `code` `` | ❌ 不识别 |
| 链接 | `[text](url)` | ❌ 不识别（工具栏能插入但渲染成纯文本） |
| 图片 | `![alt](url)` | ❌ 完全缺失 |
| 删除线 | `~~del~~` | ❌ 不识别（工具栏能插入但解析器不认） |
| 任务列表 | `- [ ]` / `- [x]` | ❌ 完全缺失 |
| 引用块多行 | `> line1\n> line2` | ⚠️ 每行单独成 BlockquoteElement，不合并 |
| HTML 行内 | `<br>` / `<sub>` 等 | ❌ 完全缺失 |
| 脚注 | `[^1]` | ❌ 完全缺失 |
| 引用链接 | `[ref]` + `[ref]: url` | ❌ 完全缺失 |

**影响**：用户用工具栏插入的 `*斜体*`、`` `code` ``、`~~删除~~`、`[链接](url)` 在预览里**全部显示为原始字符串**。这是"自相矛盾"——工具栏的功能在解析器里没有对应实现。

### 3.2 工具栏与解析器不一致

**证据**：对比 [markdown_input_field.dart:175-225](file:///d:/Projects/Active/math/flutter_app/lib/presentation/widgets/markdown_input_field.dart#L175-225) 工具栏按钮 与 [markdown_parser.dart](file:///d:/Projects/Active/math/flutter_app/lib/core/parser/markdown_parser.dart) 解析器：

| 工具栏按钮 | 插入的语法 | 解析器是否识别 |
|-----------|----------|--------------|
| format_italic | `*text*` | ❌ |
| format_strikethrough | `~~text~~` | ❌ |
| code | `` `text` `` | ❌ |
| link | `[text](url)` | ❌ |

**影响**：用户点了工具栏按钮，编辑器里出现 `*斜体*`，切到预览还是看到 `*斜体*`。这是**功能性的欺骗**。

### 3.3 代码块无语法高亮

**证据**：`CodeRenderer` 仅展示代码文本（未读取实现，但 `data/models/document.dart` 的 `CodeElement` 只存 `code` + `language`，没有 token 化字段）。

**问题**：Typora 用 highlight.js 给代码块做语法高亮，当前项目把 Python 代码和纯文本渲染得一模一样。

### 3.4 嵌套列表逻辑 hacky

**证据**：[markdown_parser.dart:135-161](file:///d:/Projects/Active/math/flutter_app/lib/core/parser/markdown_parser.dart#L135-161)

```dart
if (indent > 0 && pendingListItems.isNotEmpty) {
  final lastItem = pendingListItems.removeLast();
  final mergedText = lastItem.children
      .where((c) => c is TextElement)
      .map((c) => (c as TextElement).text)
      .join();
  ...
  final reParsed = lastInlineText.isEmpty
      ? <InlineElement>[]
      : _parseInline(lastInlineText);
```

**问题**：嵌套列表的实现是"取出上一项的文本 → 拼上新行 → 重新解析"，完全破坏了 AST 的层级语义。子列表没有作为父项的 children，而是被压扁成一行的多行字符串。Typora 的列表是真正的树形结构。

---

## 四、编辑器交互问题（P1）

### 4.1 剪贴板导入对话框 — 骚扰用户

**证据**：[editor_screen.dart:71-103](file:///d:/Projects/Active/math/flutter_app/lib/presentation/screens/editor_screen.dart#L71-103)

**问题**：每次进入编辑器都检查剪贴板，如果有内容就弹 AlertDialog 问是否导入。用户复制了密码、验证码、其他 App 的文本，进编辑器就被问一次。Typora 从不主动骚扰用户。

### 4.2 AppBar 操作按钮对手机不友好

**证据**：[editor_screen.dart:347-360](file:///d:/Projects/Active/math/flutter_app/lib/presentation/screens/editor_screen.dart#L347-360)

```dart
actions: [
  IconButton(icon: ..., tooltip: '文件管理', visualDensity: VisualDensity.compact),
  IconButton(icon: ..., tooltip: '模板', visualDensity: VisualDensity.compact),
  PopupMenuButton<String>(...),
]
```

**问题**：3 个图标按钮挤在 AppBar 右侧，单手握持时拇指够不到。`visualDensity: VisualDensity.compact` 进一步压缩了点击区域。Typora 手机版应该把常用操作放底部工具栏，AppBar 只放标题 + 菜单。

### 4.3 编辑器底栏只有"预览切换"和"导出"

**证据**：[editor_bottom_bar.dart:36-72](file:///d:/Projects/Active/math/flutter_app/lib/presentation/widgets/editor_bottom_bar.dart#L36-72)

**问题**：底部栏占据 60+ dp 高度，却只放了 2 个按钮。"预览/编辑切换"按钮在 WYSIWYG 范式下根本不该存在。 Typora 底部应该是字数统计、保存状态、当前光标位置（行列号）。

### 4.4 工具栏缺关键功能

**证据**：[markdown_input_field.dart:157-225](file:///d:/Projects/Active/math/flutter_app/lib/presentation/widgets/markdown_input_field.dart#L157-225)

**缺失**：
- 撤销 / 重做按钮（`HistoryManager` 已实现但未接入 UI）
- 表格插入按钮
- 代码块插入按钮（只有行内 code）
- 水平分割线 `---`
- 图片插入
- 任务列表 `- [ ]`
- 大纲 / TOC 跳转

### 4.5 退出清缓存 — 反复冷启动 WebView

**证据**：[editor_screen.dart:51-65](file:///d:/Projects/Active/math/flutter_app/lib/presentation/screens/editor_screen.dart#L51-65)

```dart
@override
void dispose() {
  _controller.dispose();
  _clearExportCaches();  // 清空所有公式/Mermaid 缓存
  super.dispose();
}
```

**问题**：每次退出编辑器都清空 `FormulaPdfRenderer` / `FormulaSvgService` / `MermaidService` 全部缓存。用户切到文件管理再回来，所有公式要重新通过 WebView 渲染一遍（每条 30s 超时上限）。Typora 切换文档是即时的。

### 4.6 标题提取粗暴

**证据**：[editor_screen.dart:141-150](file:///d:/Projects/Active/math/flutter_app/lib/presentation/screens/editor_screen.dart#L141-150)

```dart
String? _extractTitle(String markdown) {
  final lines = markdown.split('\n');
  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.startsWith('# ')) {
      return trimmed.substring(2).trim();
    }
  }
  return null;
}
```

**问题**：只识别 `# 一级标题` 作为文件名。文档没一级标题就用 `formulafix` + 时间戳。Typora 用文件名作为文档标题，不需要从内容猜。

---

## 五、性能问题（P1）

### 5.1 每次按键全量解析

**证据**：[editor_screen.dart:67-69](file:///d:/Projects/Active/math/flutter_app/lib/presentation/screens/editor_screen.dart#L67-69) + [preview_content.dart:30](file:///d:/Projects/Active/math/flutter_app/lib/presentation/widgets/preview_content.dart#L30)

```dart
void _onTextChanged() {
  ref.read(editorContentProvider.notifier).state = _controller.text;
}
// PreviewContent.build:
final elements = MarkdownParser.parse(content);  // 每次都全量
```

**问题**：用户每按一个键，`editorContentProvider` 变化 → `PreviewContent` 重建 → `MarkdownParser.parse(content)` 全量重新解析整篇文档。文档 1000 行时，每个字符输入都要遍历 1000 行 + 重建所有 Widget。Typora 只重新渲染光标所在块。

### 5.2 WebView 启动开销大

**证据**：[main.dart:33-44](file:///d:/Projects/Active/math/flutter_app/lib/main.dart#L33-44) + [mermaid_host.dart](file:///d:/Projects/Active/math/flutter_app/lib/presentation/widgets/mermaid_host.dart)

**问题**：
- `MermaidRendererHost` 必须在 App 启动时挂载（隐藏在 -10000, -10000）
- WebView 加载 `mermaid_renderer.html` + `tex-svg.js` + `mermaid.min.js`，需要等 `onLoadStop`
- 在加载完成前所有渲染请求排队等待，每个最多 30s 超时
- 冷启动到可渲染公式至少 2-3 秒（取决于设备）

**影响**：用户启动 App 立刻输入公式，预览空白 3 秒。Typora 启动即可输入。

### 5.3 单条公式 30s 超时

**证据**：[formula_svg_service.dart:27](file:///d:/Projects/Active/math/flutter_app/lib/core/services/formula_svg_service.dart#L27) `_renderTimeout = Duration(seconds: 30)` + 并发上限 4

**问题**：导出含 100 个公式的论文，理想情况 100/4 × 30s = 12.5 分钟，实际因 WebView 卡死可能直接超时。`ExportService.exportAndShare` 整体超时是 120s（[export_service.dart:400](file:///d:/Projects/Active/math/flutter_app/lib/domain/services/export_service.dart#L400)），意味着文档超过 ~16 个未缓存公式就会超时失败。

### 5.4 导出无进度反馈

**证据**：[editor_screen.dart:152-171](file:///d:/Projects/Active/math/flutter_app/lib/presentation/screens/editor_screen.dart#L152-171)

```dart
ref.read(isExportingProvider.notifier).state = true;  // 只有 bool
try {
  await ExportService.exportAndShare(...);
}
```

**问题**：导出过程中 UI 只显示"导出中..."和一个转圈。用户不知道是渲染到第 50/100 个公式，还是卡死了。Typora 导出是同步的，几乎无等待。

---

## 六、设计 / 主题问题（P2）

### 6.1 只有两套主题，主色写死

**证据**：[app_constants.dart:5-6](file:///d:/Projects/Active/math/flutter_app/lib/core/constants/app_constants.dart#L5-6) + [app_theme.dart:4](file:///d:/Projects/Active/math/flutter_app/lib/presentation/theme/app_theme.dart#L4)

```dart
static const primary = Color(0xFF165DFF);  // 写死蓝色
static const Color primaryColor = Color(0xFF165DFF);
```

**问题**：
- 只有 light/dark 两套主题
- 主色 `#165DFF` 在 light 和 dark 模式下都是同一个蓝色（dark 用了 `#4080FF` 但只用于 `ColorScheme.fromSeed`）
- 没有 Typora 那种 GitHub / Night / Sepia / Newsprint 等多套主题
- 主题切换不改变主色，只是反色背景

### 6.2 字体大小固定，不可缩放

**证据**：[app_constants.dart:54-64](file:///d:/Projects/Active/math/flutter_app/lib/core/constants/app_constants.dart#L54-64) 全是 `static const double`

**问题**：用户不能调整编辑器字号。Typora 支持 `Ctrl + +/-` 缩放，记忆用户偏好。

### 6.3 颜色定义有两套

**证据**：
- [app_constants.dart:3-37](file:///d:/Projects/Active/math/flutter_app/lib/core/constants/app_constants.dart#L3-37) `AppColors`
- [app_theme.dart:4-16](file:///d:/Projects/Active/math/flutter_app/lib/presentation/theme/app_theme.dart#L4-16) `AppTheme.primaryColor` / `textPrimary` / `background` 等

**问题**：两套颜色常量并存，值还略有不同（`AppColors.error = 0xFFFF3B30`，`AppTheme.errorColor = 0xFFF53F3F`）。开发者不知道用哪套，UI 颜色不一致。

### 6.4 没有大纲 / TOC 面板

**问题**：Typora 有侧边大纲，点击跳转标题。当前项目完全没有。文档超过 10 屏后用户只能滚动找位置。

### 6.5 没有焦点模式 / 打字机模式

**问题**：Typora 的两个标志性写作模式。当前项目无概念。

### 6.6 没有字数统计

**证据**：[document_list_screen.dart:358-360](file:///d:/Projects/Active/math/flutter_app/lib/presentation/screens/document_list_screen.dart#L358-360)

```dart
int _countChars() {
  return doc.content.replaceAll(RegExp(r'\s'), '').length;
}
```

**问题**：字数统计只在文档列表卡片上显示，编辑器里看不到。Typora 底部永远显示字数 / 行数 / 字符数。

---

## 七、错误处理问题（P2）

### 7.1 把技术 detail 透传给用户

**证据**：[editor_screen.dart:221-253](file:///d:/Projects/Active/math/flutter_app/lib/presentation/screens/editor_screen.dart#L221-253)

```dart
case ExportFailure.parseError:
  if (detail != null && detail.isNotEmpty) {
    return '文档中有无法识别的内容: ${_clip(detail, 60)}';  // 透传 detail
  }
```

而 [export_service.dart:323-330](file:///d:/Projects/Active/math/flutter_app/lib/domain/services/export_service.dart#L323-330) 的 detail 长这样：

```dart
detail: '${e.message} | source: ${_truncate(e.source.toString(), 80)} | offset: ${e.offset}',
```

**问题**：用户在 SnackBar 上看到 `"文档中有无法识别的内容: Unexpected extension byte (at offset 1) | source: $$\alpha... | offset: 1"`。这是给开发者看的，不是给用户看的。

### 7.2 超时消息太长且技术化

**证据**：[editor_screen.dart:245-247](file:///d:/Projects/Active/math/flutter_app/lib/presentation/screens/editor_screen.dart#L245-247)

```dart
return '$formatLabel 导出超时（超过 120s）。'
    '可能原因：文档过大、公式/图表太多、或 WebView 渲染卡死。'
    '请尝试：减少公式/图表数量后重试，或简化文档内容。';
```

**问题**：SnackBar 显示 3 行技术化文案，"WebView 渲染卡死"这种术语不该出现。Typora 的错误消息永远是简洁的人话。

### 7.3 文件解码异常被吞

**证据**：[file_manager_screen.dart:46](file:///d:/Projects/Active/math/flutter_app/lib/presentation/screens/file_manager_screen.dart#L46) `} catch (_) {}` 完全静默

**问题**：`_loadFiles` 出错什么都不做，UI 显示"暂无保存的文档"，用户以为真的没文档，实际是 IO 出错。`_deleteFile` 同样静默。

---

## 八、工程化问题（P3）

### 8.1 缺 `pubspec.yaml`

**证据**：`flutter_app/` 根目录无 `pubspec.yaml`、无 `pubspec.lock`、无 `.dart_tool/`

**影响**：项目无法 `flutter pub get`，无法 build，无法 run。新人接手完全无法启动。README 和 ARCHITECTURE.md 中已标注此问题。

### 8.2 残留文件

**证据**：[export_service_tail.txt](file:///d:/Projects/Active/math/flutter_app/lib/domain/services/export_service_tail.txt) 内容仅为 `}`

### 8.3 manifest 描述仍是默认值

**证据**：[web/manifest.json:8](file:///d:/Projects/Active/math/flutter_app/web/manifest.json#L8) `"description": "A new Flutter project."`

### 8.4 main() 多余的 async

**证据**：[main.dart:9](file:///d:/Projects/Active/math/flutter_app/lib/main.dart#L9) `void main() async {` 但函数体无任何 await

### 8.5 静态状态污染测试

**证据**：[pdf_exporter.dart:27-30](file:///d:/Projects/Active/math/flutter_app/lib/domain/services/exporters/pdf_exporter.dart#L27-30)

```dart
static pw.Font? _cjkFont;
static bool _cjkFontLoadAttempted = false;
static DateTime? _cjkFontLoadFailedAt;
```

**问题**：CJK 字体加载状态是静态变量，跨测试用例共享。测试 A 触发加载失败 → 30 秒内测试 B 都拿不到字体。同理 `FormulaSvgService._cache`、`MermaidService._cache` 都是 static。

### 8.6 测试覆盖不足

**证据**：`test/` 目录 11 个测试文件，但**没有**：
- `editor_screen_test.dart`（编辑器交互）
- `document_list_screen_test.dart`（文档列表）
- `file_manager_screen_test.dart`（文件管理）
- 路由测试
- Provider 集成测试
- 三套存储的一致性测试

---

## 九、Typora 体验对齐差距总览

| Typora 特性 | 当前状态 | 差距 |
|------------|---------|------|
| 所见即所得（WYSIWYG）编辑 | ❌ 编辑/预览分离 | 范式级 |
| 实时块级渲染 | ❌ 每次按键全量解析 | 严重 |
| 侧边文件树 / 大纲 | ❌ 完全缺失 | 严重 |
| 多套主题 | ❌ 仅 light/dark | 中等 |
| 焦点 / 打字机模式 | ❌ 完全缺失 | 中等 |
| 字数统计实时显示 | ❌ 仅列表卡片 | 中等 |
| 完整 Markdown 语法 | ❌ 缺 7 类元素 | 严重 |
| 代码语法高亮 | ❌ 完全缺失 | 中等 |
| 表格可视化编辑 | ❌ 只能写语法 | 中等 |
| 图片支持 | ❌ 完全缺失 | 中等 |
| 链接 / 引用链接 | ❌ 完全缺失 | 严重 |
| 撤销 / 重做接入 UI | ❌ 实现未接入 | 中等 |
| 快捷键支持 | ❌ 完全缺失 | 中等 |
| 自动配对（`$`/`(`/`[`） | ❌ 完全缺失 | 中等 |
| 沉浸式全屏编辑 | ❌ 卡片包裹 | 严重 |
| 启动即可用 | ❌ WebView 冷启动 2-3s | 严重 |
| 文档单一存储源 | ❌ 三套并存 | 严重 |
| 跨文档状态一致 | ❌ Provider 重复 | 严重 |
| 错误消息人话 | ❌ 透传技术 detail | 中等 |
| 导出进度反馈 | ❌ 只有转圈 | 中等 |

**统计**：21 项 Typora 核心特性中，**0 项完全达成**，5 项部分实现，16 项完全缺失或范式错误。

---

## 十、严重程度分级

### P0 — 阻塞性问题（不修不能称为 Typora 端侧版）

1. 编辑/预览分离模式（1.1）
2. 三套存储互不相通（2.1）
3. DocumentListScreen 死代码（2.2）
4. 路由初始位置错误（2.3）
5. Provider 重复定义（2.4）
6. 解析器缺 7 类元素（3.1）
7. 工具栏与解析器不一致（3.2）

### P1 — 体验级问题（严重影响日常使用）

8. 预览被卡片包裹（1.2）
9. AppBar 标题写死（1.3）
10. 每次按键全量解析（5.1）
11. WebView 冷启动慢（5.2）
12. 单条公式 30s 超时（5.3）
13. 导出无进度反馈（5.4）
14. 剪贴板骚扰（4.1）
15. AppBar 操作挤（4.2）
16. 底栏按钮无用（4.3）
17. 工具栏缺关键功能（4.4）
18. 退出清缓存（4.5）
19. 嵌套列表 hacky（3.4）
20. 代码块无高亮（3.3）

### P2 — 完善性问题（影响专业感）

21. 主题只有两套（6.1）
22. 字号不可缩放（6.2）
23. 颜色定义两套（6.3）
24. 缺大纲 / TOC（6.4）
25. 缺焦点 / 打字机模式（6.5）
26. 编辑器无字数统计（6.6）
27. 错误消息透传 detail（7.1）
28. 超时消息技术化（7.2）
29. 异常被静默吞（7.3）

### P3 — 工程化问题

30. 缺 pubspec.yaml（8.1）
31. 残留文件（8.2）
32. manifest 默认描述（8.3）
33. main() 多余 async（8.4）
34. 静态状态污染测试（8.5）
35. 测试覆盖不足（8.6）

---

## 结论

当前项目不能称为"Typora 端侧手机版"，最多算"带公式预览的 Markdown 编辑器原型"。

**地基性问题（P0）必须先解决**，尤其是：
- 范式从"编辑/预览分离"转向"块级 WYSIWYG"
- 数据存储从三套并存收敛到单一来源
- 解析器补齐 7 类缺失元素，与工具栏对齐

在 P0 解决之前，**任何新增功能（主题、TOC、图片支持等）都是在歪地基上盖楼**。

下一步建议：
1. 先决定是否接受范式重构（WYSIWYG）的成本
2. 设计单一数据源（建议：以 `.md` 文件为单一真相，废弃 JSON 文档库）
3. 重写解析器补齐 Markdown 完整语法
4. 删除死代码（DocumentListScreen 或路由二选一）

---

**审查人**：AI 同伴
**审查时长**：约 1 小时
**审查深度**：全量 `lib/` + `web/`，未深入 `test/` 与 `build/`
