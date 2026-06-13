# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

> **How to use this file:**
> - `Added` — new features
> - `Changed` — changes in existing functionality
> - `Deprecated` — soon-to-be removed features
> - `Removed` — now removed features
> - `Fixed` — bug fixes
> - `Security` — vulnerability fixes
>
> Each entry references the issue / PR that introduced it.
> Do not put breaking changes only in `Changed` — also call them out at the top.

## [Unreleased]

### Added
- `.mailmap` to consolidate 4 author identities into one canonical `Thy985 <thy985@example.com>`
- `commitlint.config.json` enforcing Conventional Commits
- `.github/ISSUE_TEMPLATE/refactor.yml` for tracking refactor / tech-debt work
- Branch / force-push / identity policy documented in `CONTRIBUTING.md`

### Changed
- `.gitignore` now covers Flutter / Dart, Node / Vite, IDE, binaries, env files, logs
- `.github/PULL_REQUEST_TEMPLATE.md` now requires linked issue, type prefix, commit-history discipline checklist, scope, risk & rollback

### Removed
- None.

### Security
- `.gitignore` now blocks `.env`, `.env.local`, `*.pem`, `*.key` to prevent secret commits

---

## Historical entries (reconstructed from `git log`)

> This section was reconstructed retroactively. Future releases should add new
> `[X.Y.Z] - YYYY-MM-DD` sections at the top, not edit history here.

### [2.0.0] - 2026-06-05

**Tag:** `v2.0.0` (GitHub release: `v2.0.0 Debug APK`)

**Highlights:**
- PDF/Word/TXT export pipeline rewritten with custom SVG AST + parser + PDF vector renderer (replaced `pw.SvgImage`)
- DOCX zip-header `uncompressedSize` mismatch fix for non-ASCII content (CRC-32 regression test added)
- Markdown exporter god class split, with error classification
- Mermaid rendering moved to offline SVG path with shared `WebView` and md5 cache
- Flutter CI/CD pipeline (analyze + test + coverage + release APK + iOS build)
- PrefsService DI + debounced persistence + go_router routing

**Breaking changes:**
- MarkdownExporter API surface changed (split into per-format modules)

### [1.x] - 2025-12-29 → 2026-05-30

- Initial FormulaFix project (Vue + Vite, three-column layout)
- GitHub Pages deployment with `/fixmath/` base path
- DOCX formula rendering: KaTeX → image embedding
- Mavis/Claude Code AI agent iterations (mixed into history)

[Unreleased]: https://github.com/Thy985/fixmath/compare/v2.0.0...HEAD
[2.0.0]: https://github.com/Thy985/fixmath/releases/tag/v2.0.0
[1.x]: https://github.com/Thy985/fixmath/commits/master