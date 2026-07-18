# FormulaFix UI Specification

> Version 1.0 | 2026-07-18
> Tokens: `design-system/tokens.json`
> Prototype: `formulafix-redesign.design/pages/`

---

# Screen 1: Home — Portable Viewer

**File**: `pages/home-v2.html`
**Navigation source**: Bottom Tab "首页"
**Device**: Mobile, max-width 390px centered

## Layout (top to bottom, scrollable)

### 1.1 Status Bar
- Height: 48px, transparent background
- Content: decorative "9:41" + signal/wifi/battery icons (iOS style)
- Non-interactive

### 1.2 Greeting Bar
- Height: auto (~56px)
- Padding: horizontal 20px
- Layout: horizontal flex
  - Left: Avatar circle, 40x40px, rounded-full, bg primary/10, centered serif "Σ" in primary color
  - Middle-left (flex-1): Two lines stacked
    - "早上好，学者" — 12px, muted-foreground, sans
    - "开始今天的写作" — 18px, font-semibold, serif, foreground
  - Right: Bell icon button (ghost, 40x40px, rounded-full)

### 1.3 Hero Section
- Margin: 20px horizontal, 20px top
- Corner radius: 16px
- Background: gradient from primary (#1E3A5F) to #2A4F7A
- Text color: white
- Padding: 20px
- Content:
  - Eyebrow: "PORTABLE MARKDOWN VIEWER", 11px, uppercase, tracking-widest, white/70
  - Headline: "随时打开任意 .md 文件", 22px, serif, font-bold
  - Sub: "从微信、邮件、文件、AirDrop 一键打开，公式与图表即时渲染", 12px, white/80
  - Button row (flex, gap 8px, margin-top 16px):
    - "打开文件" — flex-1, height 44px, rounded-xl, bg white, text primary, font-medium 14px, icon folder-open 18px
    - "新建文档" — flex-1, height 44px, rounded-xl, bg white/15, border white/25, text white, font-medium 14px, icon plus 18px
  - Source chips row (flex, gap 6px, margin-top 12px, flex-wrap):
    - 5 pills: rounded-full, bg white/10, px 8px py 2px, 10px text white/80
    - Each: icon (11px) + label ("微信" "邮件" "下载" "AirDrop" "文件App")
- Decorative: faint serif "∫" at bottom-right, 120px, white/8%

### 1.4 Quick Access Row
- Margin: 16px horizontal, 16px top
- Layout: 3 equal-width buttons, rounded-xl, bg card, border border, padding 12px, flex column center gap 4px
  - "最近打开" — icon file-search, primary 20px, label 11px
  - "剪贴板" — icon clipboard, primary 20px, label 11px
  - "收藏" — icon star, primary 20px, label 11px

### 1.5 Search Pill
- Margin: 16px horizontal, 16px top
- Height: 44px, rounded-full, bg muted
- Padding: 16px horizontal, flex center gap 8px
- Left: search icon, muted-foreground, 16px
- Center: placeholder "搜索任意文档、公式、标签...", 14px, muted-foreground
- Right: kbd tag "⌘K", 10px, rounded, border border, muted-foreground

### 1.6 Recent External Files Section
- Header: margin 24px top 20px horizontal, flex justify-between
  - Left: "最近打开" 18px serif font-semibold + "外部" badge (10px, bg accent/10, text accent, px 6px py 2px rounded)
  - Right: "查看全部 →" 12px primary text button
- List: margin-top 12px, vertical stack, gap 10px

#### External File Card
- Rounded-xl, bg card, border border/70, padding 12px, flex gap 12px items-center, shadow-sm
- Left: source icon block, 40x40px, rounded-lg, tinted bg
  - WeChat: bg #07C160/10, icon message-circle in #07C160
  - Email: bg primary/10, icon mail in primary
  - Download: bg primary/10, icon download-cloud in primary
- Middle (flex-1, min-w-0):
  - Title: 14px font-semibold, truncate
  - Source: flex items-center gap 6px, margin-top 2px
    - icon smartphone 10px muted + "来自微信 · 张教授" 11px muted-foreground
  - Time: 10px muted-foreground/70
- Right:
  - Cached: icon circle-check, success, 16px
  - Not cached: nothing (or cloud-off)

### 1.7 My Documents Section
- Header: "我的文档" 18px serif + "管理" 12px muted text button
- Grid: 2 columns, gap 12px, margin-top 12px

#### Document Card (grid tile)
- Rounded-xl, bg card, border border/70, padding 16px, aspect-ratio 4/5, flex column justify-between, shadow-sm
- Top: icon (22px, tinted) — file-text/bar-chart-3/book-open/file-plus
- Title: 14px font-semibold serif, line-clamp-2, margin-top 8px
- Meta: 10px muted-foreground, margin-top auto
- Tag: 10px, px 6px py 2px rounded, tinted bg + text (primary/accent/success)
- New-doc tile: dashed border, bg transparent, no shadow, muted-foreground

### 1.8 FAB (Floating Action Button)
- Position: fixed, right 20px, bottom 88px (above tab bar)
- Size: 56x56px, rounded-full, bg primary, text white, shadow-lg
- Icon: plus, 26px

### 1.9 Bottom Tab Bar
- Position: fixed bottom, max-w-md centered, h-64px
- Background: card/95, backdrop-blur, border-top border
- 4 equal tabs: home (icon home) / files (icon folder-open) / reader (icon book-open) / me (icon user)
- Active: icon 22px primary + label 11px primary font-medium
- Inactive: icon 22px muted-foreground + label 11px muted-foreground
- Home indicator: w-32 h-1 bg-black/20 rounded-full, centered, margin 4px bottom

### Interactions
| Gesture | Target | Action |
|---------|--------|--------|
| Tap "打开文件" hero button | System file picker | Opens .md file from any source |
| Tap "新建文档" hero button | Editor screen | Creates blank document |
| Tap external file card | Reader screen | Opens in read-only mode |
| Tap my document card | Editor screen | Opens in edit mode |
| Tap FAB | Editor screen | Creates blank document |
| Tap search pill | Search overlay | Filters all documents |

---

# Screen 2: WYSIWYG Editor

**File**: `pages/editor.html`
**Navigation source**: Deep link from Home, Files, or new document
**Mode**: Immersive (no bottom tab bar)

## Layout

### 2.1 Floating Top Bar
- Position: sticky top-0, z-30
- Height: 48px, backdrop-blur-md, bg editor-bg/85, border-bottom border/50
- Padding: horizontal 16px
- Layout: flex justify-between items-center
  - Left: ghost circle button (36x36px), icon chevron-left 18px — back navigation
  - Center: column center
    - Document title: 13px font-medium, serif, max-width 180px, truncate
    - Save status: green dot (6px circle, bg success) + "已自动保存" 10px muted-foreground
  - Right: two ghost circle buttons — icon more-horizontal 18px + icon share 18px

### 2.2 Document Body (immersive paper)
- Background: editor-bg (#FDFDFB)
- Padding: horizontal 24px, top 24px, bottom 128px
- NO card shadow, NO rounded corners — full-bleed paper
- Typography: serif throughout, 15px body, 1.85 line-height

#### Document Content Structure
- **H1**: 26px, font-bold, serif, line-height 1.25
- **Meta line**: 11px, muted-foreground, flex row with calendar/tag icons, margin-bottom 24px
- **H2**: 19px, font-semibold, serif, margin-top 24px, margin-bottom 12px
- **Paragraph**: 15px, serif, line-height 1.85, foreground/90, margin-bottom 16px
- **Display formula block**:
  - Rounded-lg, padding 20px horizontal / 16px vertical
  - Background: gradient 135deg #EBF0F5 → #E8EEF2
  - Border-left: 3px solid primary
  - Formula text: 19px, serif italic, primary color, centered
  - Label below: right-aligned, 10px, muted-foreground, "(1.1) Einstein 场方程"
- **Inline formula**: serif italic, bg primary/5, px 6px py 2px, rounded, text primary
- **Bullet list**: pl-4px, gap 8px, bullet dot (6px circle, bg primary, margin-top 8px)
- **Callout block**: rounded-lg, border-left 4px accent, bg accent/5, px 16px py 12px, icon lightbulb accent
- **Active editing line**: subtle primary left-border 3px, bg primary/3%, blinking caret (2px x 20px, bg primary, animate blink)
- **Rendering formula indicator**: same formula block style but opacity-70, with 12px spinner top-right

### 2.3 Floating Contextual Toolbar
- Position: fixed, ~100px from bottom, horizontally centered (left-1/2, -translate-x-1/2), z-40
- Style: rounded-full, bg card, shadow-lg, border border/80, backdrop-blur, px 6px py 4px
- Layout: flex items-center gap 2px
- Buttons: 7 icon buttons (32x32px, rounded-full)
  - bold (active: bg primary/10, text primary)
  - italic
  - function (primary color — FormulaFix signature button)
  - code
  - list
  - quote
  - heading
  - divider: w-px h-5 bg-border
  - image

### 2.4 Bottom Status Bar
- Position: fixed bottom-0, max-w-md centered, height 32px
- Background: card/95, backdrop-blur, border-top border/60
- Padding: horizontal 16px
- Layout: flex justify-between
  - Left: "第 3 节 · 第 12 行" 11px muted-foreground, icon align-left
  - Center: "2,341 字 · 47 公式"
  - Right: "读写 · 3 分钟", icon clock

### Interactions
| Gesture | Target | Action |
|---------|--------|--------|
| Tap chevron-left | Previous screen | Save & navigate back |
| Tap bold/italic/etc in toolbar | Document | Toggle formatting at cursor |
| Tap function in toolbar | Formula Sheet | Open formula insertion panel |
| Type in document body | Document | WYSIWYG content editing |
| Scroll document | Self | Natural scroll, status bar updates line/section |

---

# Screen 3: Reader (Light)

**File**: `pages/reader.html`
**Navigation source**: Tab "阅读", external file open, or Home tap
**Mode**: Immersive (no bottom tab bar)

## Layout

### 3.1 Progress Bar
- Position: fixed top-0, full width, z-50
- Height: 2px, bg transparent
- Inner bar: width 66% (indicating scroll position), bg primary

### 3.2 Reader Top Bar
- Position: sticky top-2px (below progress bar), z-40
- Height: 48px, backdrop-blur-sm, bg editor-bg/85
- Padding: horizontal 12px
- Layout: flex justify-between items-center
  - Left: ghost circle 36x36px, icon chevron-left 18px
  - Center: column
    - Title: 12px font-medium, max-width 160px, truncate
    - Source: 10px muted-foreground, icon message-circle (green for WeChat)
  - Right: two ghost circle buttons — bookmark 18px, share-2 18px

### 3.3 External File Badge
- Margin: 12px horizontal, 8px top
- Style: rounded-full, bg primary/8, border primary/15, px 10px py 4px
- Content: icon eye 11px primary + "外部文件 · 只读副本" 10px primary font-medium

### 3.4 Article Header
- Padding: horizontal 28px, top 20px, bottom 8px
- Eyebrow tag: "统计学习 / 笔记" 10px uppercase tracking-wider, primary/70, font-medium
- H1: "贝叶斯统计笔记" 28px serif font-bold, line-height 1.25, margin-top 8px
- Meta row: flex gap 12px, 11px muted-foreground, margin-top 12px
  - Author (icon user) · Date (icon calendar) · Reading time (icon clock) · Word count (icon type)
- Divider: centered 32px wide, 1px bg-border, margin-top 16px

### 3.5 Article Body
- Padding: horizontal 28px, vertical 16px
- Typography: 16px serif, line-height 1.9, foreground/90, paragraph gap 20px
- H2: 20px serif font-semibold, margin-top 32px, margin-bottom 12px
- Display formula: padding 24px/20px, formula 21px serif italic primary
- Bullet list: bullet dot 18px serif primary, gap 8px, text 16px serif line-height 1.8
- Pull quote: border-left 4px accent, bg accent/5, rounded-r-lg, px 20px py 16px, icon quote accent
- Image placeholder: rounded-xl, bg-muted/50, border, aspect 16/10, icon image centered
- End-of-article ornament: centered "— · —" in serif 16px

### 3.6 Article Actions
- Padding: horizontal 28px, bottom 8px
- Layout: flex justify-between
  - Left: ghost icon buttons (thumbs-up, message-circle), 36x36px
  - Right: "阅读进度 66%" 11px muted-foreground tabular-nums

### 3.7 Floating Reader Toolbar
- Position: fixed bottom 24px, centered (left-1/2, -translate-x-1/2), z-40
- Style: rounded-2xl, bg card, border border/80, shadow-lg, backdrop-blur, px 8px py 8px
- Layout: flex items-center gap 4px
  - **Edit button** (PRIMARY): 40x40px, rounded-xl, bg primary, text white, icon pencil 18px
  - Divider: w-px h-6 bg-border
  - 4 ghost buttons (36x36px): type (font size), sun/eye (theme), list (TOC), more-horizontal
- No home indicator needed (toolbar floats above it)

### Interactions
| Gesture | Target | Action |
|---------|--------|--------|
| Tap pencil button | Editor | Switch to edit mode for this file |
| Tap sun/eye button | Self | Toggle light/dark/sepia reading theme |
| Tap type button | Font size picker | Adjust reading font size |
| Tap list button | TOC overlay | Show table of contents |
| Tap bookmark | Self | Toggle bookmark on this article |
| Scroll | Self | Progress bar updates |

---

# Screen 4: Reader (Dark)

**File**: `pages/reader-dark.html`
**Differences from Screen 3**: HTML root has class "dark". All tokens swap to dark palette.
- Background: #0F1419 (deep ink)
- Card: #1A1D23, border: #2A2F38
- Text: #E8EAED (soft white)
- Primary: #5B8DB8 (softer blue)
- Accent: #F4A261 (warm amber)
- Formula bg: gradient #1E2A36 → #1C2530
- All other layout/spacing/typography identical to Screen 3

---

# Screen 5: Formula Insert Sheet

**File**: `pages/formula-sheet.html`
**Navigation source**: Editor, tap function icon in floating toolbar
**Mode**: Modal (editor dimmed behind)

## Layout

### 5.1 Backdrop
- Dimmed editor content at 30% opacity
- Black overlay at 40% opacity, full screen, z-40

### 5.2 Bottom Sheet
- Position: fixed bottom-0, z-50, max-w-md centered
- Max height: 88vh, flex column
- Rounded-t-2xl, bg card, shadow-2xl
- **Header** (flex-shrink-0): grabber bar + "插入公式" title + close button + "KaTeX" pill badge
- **Scrollable content** (flex-1, overflow-y-auto):
  - **Live preview card**: rounded-xl, bg formula gradient, border primary/20, padding 16px, centered large formula 22px serif italic primary + mono source below 11px muted
  - **Search input**: h-40px, rounded-lg, bg muted, px 12px, search icon + placeholder + "常用" tag
  - **Category tabs**: horizontal scroll, no-scrollbar, flex gap 8px
    - Active tab: pill, bg primary, text white, 12px font-medium
    - Inactive: pill, bg muted, text muted-foreground, 12px
    - Tabs: 常用, 希腊字母, 运算符, 箭头, 矩阵, 微积分, 逻辑
  - **Symbol grid**: 8 columns, gap 6px, max-height 220px
    - Each: aspect-square, rounded-lg, bg muted/60, centered serif 18px, hover primary/10
    - Recently used: first 3-4 symbols have small primary dot (4px) at top-right corner
  - **Quick templates**: horizontal scroll, gap 8px
    - Each chip: rounded-lg, border border, bg card, min-w 100px, padding 12px
    - Small label (10px muted) + formula preview (16px serif)
    - 6 templates: 分数, 根号, 积分, 求和, 矩阵, 极限
- **Action bar** (flex-shrink-0): border-top, flex items-center gap 8px, padding 8px 16px
  - "行内" pill (bg muted) + "块级" pill (bg primary/10, text primary, selected)
  - Spacer
  - "插入" CTA: rounded-lg, bg primary, text white, 13px font-medium, icon corner-down-left
- **Home indicator**: centered bar at bottom

### Interactions
| Gesture | Target | Action |
|---------|--------|--------|
| Tap symbol in grid | Formula input | Inserts symbol at cursor |
| Tap template chip | Formula input | Inserts template skeleton |
| Tap "行内"/"块级" toggle | Self | Switches between inline and block formula mode |
| Tap "插入" | Editor | Confirms and inserts formula |
| Tap category tab | Symbol grid | Filters symbols by category |
| Type in search | Symbol grid | Filters symbols by name/command |

---

# Screen 6: Export & Share Sheet

**File**: `pages/export-sheet.html`
**Navigation source**: Editor/Reader, tap share or export action
**Mode**: Modal (editor dimmed behind)

## Layout

### 6.1 Sheet Container
- Max height: 88vh, flex column, overflow hidden
- **Header** (flex-shrink-0): grabber + "导出与分享" title + close button
- **Scrollable content** (flex-1, overflow-y-auto):
  - **Preview card**: rounded-xl, bg muted/60, border, padding 16px, file icon + title + meta
  - **Format grid**: 3 columns, gap 10px, 6 format cards
    - Each: rounded-xl, border, padding 12px, flex column center, aspect 3/4
    - Selected: border primary, bg primary/5, ring primary/20
    - Each shows: icon + format name + extension + feature badge
    - Formats: Markdown (selected), PDF, Word, 纯文本, 图片, 分享链接 (disabled, 55% opacity)
  - **Share targets**: label "快速分享到" + horizontal row of 5 circular targets (48x48px)
    - WeChat (green), Email (primary), AirDrop (primary), System share (muted), Copy link (muted)
  - **Advanced options**: collapsible section
    - Header: "高级选项" + settings icon + chevron-down (rotated when expanded)
    - 4 toggle/dropdown rows:
      - "包含公式渲染" — toggle ON (primary bg, white thumb right)
      - "包含目录" — toggle ON
      - "嵌入字体" — toggle OFF (muted bg, white thumb left)
      - "纸张大小" — dropdown "A4 ▾"
- **Action bar** (flex-shrink-0): border-top
  - Left: "保存到文件" secondary button
  - Right: "导出 PDF" primary CTA button

### Interactions
| Gesture | Target | Action |
|---------|--------|--------|
| Tap format card | Self | Selects export format |
| Tap share target | System share sheet | Opens native share dialog |
| Toggle advanced option | Self | Enables/disables feature |
| Tap "导出 PDF" | Export service | Exports document in selected format |

---

# Screen 7: File Browser

**File**: `pages/files.html`
**Navigation source**: Bottom Tab "文件"

## Layout

### 7.1 Top Bar
- Sticky top-0, bg background/90, backdrop-blur, border-bottom, height 52px
- Left: "文件" 20px serif font-semibold
- Right: search + more-horizontal ghost buttons

### 7.2 Storage Summary
- Margin: 16px horizontal, 12px top
- Rounded-xl, bg primary/5, border primary/10, padding 12px
- Layout: flex items-center gap 12px
  - icon hard-drive primary 22px
  - Column: "本地存储" 13px font-medium + "已用 128 MB · 47 个文件" 11px muted
  - Right: progress indicator

### 7.3 Quick Access
- Margin: 24px horizontal, header: "快捷访问" 14px font-semibold
- Grid 4 cols, gap 8px: 收藏/最近/下载/回收站 — each rounded-xl bg card border, icon 18px + label 10px

### 7.4 Folders Section
- Header: "文件夹" 14px + "新建" primary text button
- List: gap 6px, each rounded-xl bg card border padding 12px flex items-center gap 12px
  - icon folder, amber color, 22px
  - Column: folder name 14px font-medium + "X 个文件 · Y MB" 11px muted
  - Right: chevron-right 14px muted

### 7.5 Recent Files Section
- Header: "最近文件" 14px
- List: gap 6px, each rounded-xl bg card border padding 12px flex items-center gap 12px
  - icon file-text in tinted bg block 36x36px rounded-lg
  - Column: filename 13px font-medium truncate + "X 字 · Y 公式 · time" 11px muted
  - Right: more-vertical (local) or external-link (external source)

### 7.6 Bottom Tab Bar
- Same as Home, "文件" tab active (icon folder-open, primary color)

### Interactions
| Gesture | Target | Action |
|---------|--------|--------|
| Tap folder | Folder contents | Navigate into folder |
| Tap file (local) | Editor | Opens in edit mode |
| Tap file (external) | Reader | Opens in read mode |
| Tap "新建" folder button | Create folder dialog | Creates new folder |

---

# Screen 8: Profile & Settings

**File**: `pages/profile.html`
**Navigation source**: Bottom Tab "我的"

## Layout

### 8.1 Top Bar
- Padding 16px horizontal, "我的" 20px serif font-semibold + settings icon button

### 8.2 User Card
- Margin 16px horizontal, 8px top
- Rounded-2xl, bg primary, padding 20px, text white
- Layout: flex items-center gap 12px
  - Avatar: 56x56px, rounded-full, bg white/20, "Σ" serif 24px
  - Column: "学者" 18px font-bold serif + email 12px white/70
- Stats row: flex justify-around, margin-top 16px
  - 3 columns: "47" (24px serif bold) / "文档" (11px white/70)
  - "347" / "公式", "86.2k" / "总字数"

### 8.3 Writing Streak
- Margin 16px horizontal, 16px top
- Rounded-xl, bg card, border, padding 16px
- "连续写作" 14px + "已坚持 23 天" 11px muted
- 7-day dots: 5 filled primary, 1 accent (today), 1 empty muted
  - Each dot: 24x24px rounded-full, day labels below 8px

### 8.4 Settings Groups
- Margin 16px horizontal
- Groups separated by 8px margin-top
- Each group: rounded-xl, bg card, border, overflow-hidden
- Each row: padding 14px 16px, flex justify-between, border-bottom border/60 (except last)

#### Group "通用"
- 深色模式 — toggle ON
- 编辑器主题 — "默认" chevron-right

#### Group "编辑器"
- 字号大小 — "标准" chevron-right
- 行间距 — "1.8" chevron-right
- 公式配色 — "蓝调" chevron-right
- 代码高亮 — toggle ON
- 自动补全括号 — toggle ON

#### Group "导出"
- 默认导出格式 — "PDF" chevron-right
- 导出分辨率 — "2x" chevron-right
- 纸张大小 — "A4" chevron-right
- 字体嵌入 — toggle ON

#### Group "关于"
- 关于 FormulaFix — chevron-right
- 给个好评 — chevron-right
- 反馈建议 — chevron-right

#### Group "危险区域" (border error/20)
- 清除缓存 — text error/80
- 退出登录 — text error/80

### 8.5 Footer
- Centered, margin-top 24px, margin-bottom 16px
- "FormulaFix v0.1.0" 11px muted
- "Made with ∫ for scholars" 10px muted/60 serif italic

### 8.6 Bottom Tab Bar
- Same structure, "我的" tab active (icon user, primary)

### Interactions
| Gesture | Target | Action |
|---------|--------|--------|
| Tap toggle | Setting | Enables/disables setting |
| Tap setting row | Setting detail | Opens detail/sub-page |
| Tap "清除缓存" | Confirmation dialog | Clears local cache |
| Tap "退出登录" | Confirmation dialog | Logs out user |

---

# Screen 9: Home (Legacy, for comparison)

**File**: `pages/home.html`
**Status**: Kept for before/after comparison. Navigation structure aligned with Home v2 (tabs: 首页/文件/阅读/我的).
**Differences from v2**: No hero section, simpler greeting, list-style recent docs instead of grid+external, original tab labels (写作/大纲/我的 — now patched to match v2).
