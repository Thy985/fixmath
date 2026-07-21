# FormulaFix Design Document

> Version 2.0 | 2026-07-18 初版 · 2026-07-21 Typora 化修订
> Visual prototype: `formulafix-redesign.design/` (14 screens，含 5 张 Typora 化对比页)
> Design tokens: `design-system/tokens.json`
> UI specification: `docs/UI_SPEC.md`

## 0. Design Philosophy

FormulaFix is a **mobile-first WYSIWYG academic writing tool** with portable Markdown viewing.

Four "not" principles:
- Not a Markdown editor with a preview pane — it is WYSIWYG (what you see is what you get)
- Not a desktop Typora port — it is mobile-first, redesigned for thumb-zone ergonomics
- Not a generic note app — it is purpose-built for formulas, charts, and academic writing
- Not a walled garden — it opens any `.md` file from any source (WeChat, email, downloads, AirDrop)

Visual tone: **warm paper + deep ink**. Serif for content, sans for chrome. Academic gravitas without cold tech-blue sterility.

### 0.1 Typora 化总原则（v2.0，2026-07-21）

**用户看到的是 Document，而不是 Block。** Block 是工程抽象，不应成为用户认知对象；BlockRenderer 是排版引擎，不是卡片系统。FormulaFix 的 UI 方向走 Typora 化，不走 Notion 化。

由此推导出**三层 UI 哲学**：

| 层级 | 可见性 | 内容 |
|------|--------|------|
| Layer 1 · 常驻 | 始终可见 | 标题 + 正文 + 极简状态栏。仅此而已 |
| Layer 2 · 情境 | 选中/点击才浮现 | 选区浮动工具栏、行内格式菜单 |
| Layer 3 · 隐藏 | 默认不可见 | AI 助手（以行内轻提示出现，非弹窗）、文档分析、公式校验、引用管理 |

四条具体反"Notion 化"准则：
1. **公式回归自然排版**：块公式无底色、无边框、无编号、无卡片，就是文档流中居中的一行 serif italic 排式（像 LaTeX `\[ \]` 印在纸上）
2. **活动行无 Block 感**：当前编辑行不加底色、不加左侧高亮条，仅以闪烁插入符标识活动位置
3. **工具栏情境化**：格式工具栏不在底部常驻，只在选中文本时浮于选区上方
4. **首页是文件列表，不是仪表盘**：去掉 Hero 问候、统计三连、模板网格、脉冲 FAB，回归纯排版文件列表 + 一条"打开任意 .md 文件"便携入口

对照原型：`pages/editor-typora.html`、`pages/home-v3.html`。原 `editor.html` / `home.html` 保留为旧版对比，D3/D4/D5 决策已被 D6/D7/D8 取代（见 §6）。

## 1. Design Token System

All visual constants are defined in `design-system/tokens.json`.

### Token hierarchy

```
tokens.json
  ├── color.light / color.dark      → Flutter ColorScheme
  ├── radius                        → BorderRadius constants
  ├── shadow                        → BoxShadow constants
  ├── typography.scale              → TextTheme (body, h1, h2, meta, caption...)
  ├── spacing                       → EdgeInsets / SizedBox constants
  └── component                     → Widget style presets (button, card, tabBar...)
```

### Flutter mapping

```dart
ColorScheme light = ColorScheme(
  primary:     Color(0xFF1E3A5F),  // deep ink blue
  onPrimary:   Color(0xFFFFFFFF),
  surface:     Color(0xFFFAFAF7),  // warm paper
  onSurface:   Color(0xFF1A1D23),
  // ... see tokens.json color.light for full map
);

ColorScheme dark = ColorScheme(
  primary:     Color(0xFF5B8DB8),  // softer blue
  surface:     Color(0xFF0F1419),  // deep ink
  onSurface:   Color(0xFFE8EAED),
  // ... see tokens.json color.dark for full map
);
```

### Font mapping

| Token key | Flutter | Use case |
|-----------|---------|----------|
| `typography.sans` | System font (default) | UI chrome, buttons, navigation |
| `typography.serif` | `GoogleFonts.sourceSerif4()` or Songti SC | Document body, headings, formulas |
| `typography.mono` | `GoogleFonts.jetBrainsMono()` | Inline code, file extensions |

## 2. Screen Inventory

| # | Screen | File | Navigation source |
|---|--------|------|-------------------|
| 1 | Home (Portable Viewer) | `pages/home-v2.html` | Tab: "首页" |
| 2 | Home (Legacy, for comparison) | `pages/home.html` | Tab: "首页" |
| 3 | WYSIWYG Editor | `pages/editor.html` | Deep link from any doc |
| 4 | Reader (Light) | `pages/reader.html` | Tab: "阅读" / external file open |
| 5 | Reader (Dark) | `pages/reader-dark.html` | Reader with dark mode on |
| 6 | Formula Insert Sheet | `pages/formula-sheet.html` | Editor: tap formula button |
| 7 | Export & Share Sheet | `pages/export-sheet.html` | Editor/Reader: share action |
| 8 | File Browser | `pages/files.html` | Tab: "文件" |
| 9 | Profile & Settings | `pages/profile.html` | Tab: "我的" |
| 10 | **Home v3 · 极简文件列表（Typora 化）** | `pages/home-v3.html` | Tab: "首页"（取代 #2 旧版） |
| 11 | **Editor · Typora 化（Document 非 Block）** | `pages/editor-typora.html` | Deep link from any doc（取代 #3 旧版） |
| 12 | **Home v2 · 便携查看器（Typora 化）** | `pages/home-v2-typora.html` | Tab: "首页"（便携入口+外部文件+文档列表融合） |
| 13 | **Reader · Typora 化（公式自然排版）** | `pages/reader-typora.html` | Tab: "阅读" / 外部文件打开（取代 #3 旧版 reader） |
| 14 | **Reader · 深色 + Typora 化** | `pages/reader-dark-typora.html` | Reader 深色模式 + Typora 化（取代 #4 旧版） |

## 3. Navigation Architecture

### Bottom Tab Bar (4 tabs)

```
首页 (home)  →  Home screen with hero CTA
文件 (files) →  File browser
阅读 (reader)→  Reading history / bookshelf
我的 (me)    →  Profile & settings
```

Tab bar is hidden on **Editor** and **Reader** screens (immersive mode). User returns via chevron-left in top bar.

### Screen flow

```
Home ──tap doc──→ Editor
Home ──tap ext──→ Reader
Home ──hero CTA──→ File picker / New doc
Reader ──edit btn──→ Editor (same file)
Editor ──formula btn──→ Formula Sheet (modal)
Editor ──share btn──→ Export Sheet (modal)
Files ──tap file──→ Editor or Reader (based on ownership)
Tab:阅读 ──tap item──→ Reader
```

## 4. Dark Mode Strategy

- Toggle in Profile > Settings
- Affects all screens globally
- Reader has a per-article theme toggle (sun icon in floating toolbar)
- Editor inherits global setting
- Token swap: all `color.light.*` values have corresponding `color.dark.*` in tokens.json
- Dark mode primary is softer (#5B8DB8 vs #1E3A5F) to avoid glare on dark backgrounds

## 5. Typography Rules

- **Serif** for all document content: headings, body text, formula display, titles, stat numbers
- **Sans** for all UI chrome: button labels, tab labels, meta text, settings rows, badges
- **Mono** for: inline code spans, file extensions (.md, .pdf), formula source hints, keyboard shortcuts (⌘K)
- Editor body: 15px / 1.85 line-height (compact for editing)
- Reader body: 16px / 1.9 line-height (generous for reading)
- Never use mono for body text. Never use sans for document headings.

## 6. Key Design Decisions

### D1: WYSIWYG over Split View
The editor has NO edit/preview toggle. Content renders in-place. This is the core UX differentiator from v1.

### D2: Reader as Default for External Files
Files received from external sources (WeChat, email, downloads) open in Reader mode by default. Editing is one tap away (pencil button in floating toolbar) but not the default action.

### D3: Hero CTA for "Open Any File"  *(v2.0 已被 D6 取代)*
~~The home screen features a prominent hero section with dual CTA: "打开文件" (open) and "新建文档" (new). Opening external files is a first-class action, not buried in a menu.~~
**v2.0 修订**：首页不再用 Hero CTA 强调"打开文件"，改为极简文件列表 + 一条低调的"打开任意 .md 文件"虚线入口（见 D6）。便携查看器定位不变，但入口从"展示型"降为"工具型"。

### D4: Formula Blocks as Visual Signature  *(v2.0 已被 D7 取代)*
~~Display formulas use a distinct blue gradient background with left accent bar and equation numbering. This makes FormulaFix visually recognizable at a glance.~~
**v2.0 修订**：公式不再做"视觉签名"。块公式回归自然排版——无底色、无边框、无编号、无卡片，就是文档流中居中的一行 serif italic（见 D7）。FormulaFix 的辨识度来自内容与排版品质，不来自装饰性卡片。

### D5: Floating Toolbar (Not Keyboard Attachment)  *(v2.0 已被 D8 取代)*
~~The editor formatting toolbar floats as a pill bar above the keyboard area, not as a full-width keyboard attachment. This preserves screen real estate and feels lightweight.~~
**v2.0 修订**：工具栏不再常驻。改为情境化——只在选中文本时以药丸浮于选区上方，未选中时不可见（见 D8）。保持药丸形态与轻量感，但可见性由选区驱动。

### D6: Minimalist Home as File List（v2.0 新增）
首页是"任意来源 .md 即开即看"的便携查看器入口，不是 App 仪表盘。去掉 Hero 问候、统计三连、模板网格、脉冲 FAB；回归纯排版文件列表（标题 + 摘要 + 时间 + 细分隔线），加一条"打开任意 .md 文件"虚线入口。新建动作收敛为 header 的 + 图标。原型：`pages/home-v3.html`（基础版）、`pages/home-v2-typora.html`（便携查看器融合版，保留外部文件来源特色）。

### D7: Formula as Natural Typography（v2.0 新增）
块公式即文档排版，不是组件。无底色、无边框、无编号、无卡片；serif italic 19px 居中，纵向留白 my-6（24px，贴 Typora 桌面版 1.5em 节奏）。行内公式同样走纯 serif italic，无底色高亮（editor-typora 已清除 primary 6% 底色）。公式与正文是同一种东西——都是 Document。原型：`pages/editor-typora.html`、`pages/reader-typora.html`、`pages/reader-dark-typora.html`。

### D8: Contextual Selection Toolbar（v2.0 新增）
格式工具栏（bold/italic/formula/code/list/quote/heading/image）为 Layer 2 情境层：仅在选中文本时以药丸浮于选区正上方，未选中时完全不可见。不在底部常驻、不挂键盘。这对应三层 UI 哲学——Layer 1 只有标题+正文+极简状态栏。原型：`pages/editor-typora.html`。

### D10: Reader as Typora Document Window（v2.0 新增）
阅读器是用户阅读 Document 的窗口，Document Layer 100% Typora 化：块公式去卡片回归纯 serif italic 居中（无底色/边框/编号）、pull quote 降级为学术引用风（`border-l-2 border + serif italic + opacity 70%`，不用 accent 色/图标/粗边框）。Application Layer（阅读进度条/顶栏/外部文件 badge/浮动工具栏/图片占位符）保留不动——Typora 化 Document Layer，而非整个 Application Layer。深色版同步（reader-dark-typora）。原型：`pages/reader-typora.html`、`pages/reader-dark-typora.html`。

### D11: Home v2 Portable Viewer Typora 化（v2.0 新增）
home-v2 便携查看器版的 Typora 化：移除 Hero CTA/快捷访问三连/大搜索药丸/FAB/装饰水印，改为 minimal header + 虚线便携入口 + 极简来源 chips + 两个纯排版列表（最近外部文件/我的文档）。与 home-v3 差异化：home-v3 是纯文档列表视角，home-v2-typora 保留"便携查看器"特色（虚线入口+来源 chips+外部文件来源文字），是便携入口与文档列表的融合。原型：`pages/home-v2-typora.html`。

### D12: Tool Layer Fidelity（v2.0 新增）
工具面板（formula-sheet/export-sheet）属 Application Layer，不全面 Typora 化，但其内部"Document 镜子"区域必须与真实 Document 一致：formula-sheet 的 Live preview 卡片从渐变底+primary 色改为纯 serif italic + card 底 + border，与 editor-typora 真实公式一致；export-sheet 的 preview card 从图标块卡片改为打印预览感纯排版（serif 标题 + serif italic 公式示例 + meta）。符号网格/格式卡网格/分享目标等功能性 UI 保留不动。

### D13: Chrome Demotion（v2.0 新增，P2）
Application Layer 的次要 chrome 元素降级，避免抢 Document 焦点：home-v3 便携入口图标从 folder-open 换为更轻的 file-input（弱化"文件夹操作"感）；files.html 存储摘要卡从 primary/5 底+primary 图标+primary 进度环降为中性 card 底+muted 图标+border 进度环。这些是工具属性元素，不应使用品牌色强调。

### D9: AI as Inline Hint, Not Popup（v2.0 新增）
AI 助手属 Layer 3 隐藏层，以行内 ghost 提示出现（插入符后跟一段极淡 serif italic 建议文字，opacity-50），绝不以弹窗、侧栏、主 UI 元素形态出现。用户注意力始终在 Document 上。

## 7. Prototype Assets

- HTML prototype: `formulafix-redesign.design/` (view in design canvas)
- Static copy for reference: `docs/assets/ui-prototype/`
- Token JSON: `design-system/tokens.json`
- Typora 化对比页（v2.0，共 5 张）：`pages/editor-typora.html`、`pages/home-v3.html`、`pages/home-v2-typora.html`、`pages/reader-typora.html`、`pages/reader-dark-typora.html`

## 8. Relationship to AGENTS.md

This document is a **design reference**, not an architecture decision. It describes the target visual state. Implementation follows the phased approach in ROADMAP.md. The current Phase 0 focuses on engineering infrastructure; visual implementation targets Phase 2 (paradigm restructuring).

> **v2.0 注（2026-07-21）**：Phase 3.0 UI Skeleton 已落地 `EditorShell → DocumentSurface + ContextLayer + HiddenPanelHost + MinimalStatusBar`，与本文件 §0.1 三层 UI 哲学对齐。Phase 3.1 WYSIWYG Mode Migration 应以 `editor-typora.html` 为视觉蓝本。
