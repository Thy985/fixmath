# FormulaFix Design Document

> Version 1.0 | 2026-07-18
> Visual prototype: `formulafix-redesign.design/` (9 screens)
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

### D3: Hero CTA for "Open Any File"
The home screen features a prominent hero section with dual CTA: "打开文件" (open) and "新建文档" (new). Opening external files is a first-class action, not buried in a menu.

### D4: Formula Blocks as Visual Signature
Display formulas use a distinct blue gradient background with left accent bar and equation numbering. This makes FormulaFix visually recognizable at a glance.

### D5: Floating Toolbar (Not Keyboard Attachment)
The editor formatting toolbar floats as a pill bar above the keyboard area, not as a full-width keyboard attachment. This preserves screen real estate and feels lightweight.

## 7. Prototype Assets

- HTML prototype: `formulafix-redesign.design/` (view in design canvas)
- Static copy for reference: `docs/assets/ui-prototype/`
- Token JSON: `design-system/tokens.json`

## 8. Relationship to AGENTS.md

This document is a **design reference**, not an architecture decision. It describes the target visual state. Implementation follows the phased approach in ROADMAP.md. The current Phase 0 focuses on engineering infrastructure; visual implementation targets Phase 2 (paradigm restructuring).
