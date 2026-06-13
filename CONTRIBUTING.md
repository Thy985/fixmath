# Contributing to FormulaFix

Thank you for your interest in contributing!

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/YOUR_USERNAME/fixmath.git`
3. Install dependencies: `cd flutter_app && flutter pub get`
4. Create a branch: `git checkout -b feature/your-feature-name`

## Development Workflow

```bash
# Run the app
cd flutter_app && flutter run

# Run tests
cd flutter_app && flutter test

# Run static analysis
cd flutter_app && flutter analyze
```

## Pull Request Process

1. Update documentation if needed
2. Add tests for new functionality
3. Ensure CI passes (analyze, test, build)
4. Update PR description with clear description and test plan
5. Request review from maintainers

## Code Style

- Follow Flutter/Dart conventions
- Use meaningful variable and function names
- Add comments for complex logic
- Keep functions small and focused

## Reporting Issues

Please use the issue templates to report:
- Bugs: Use [Bug Report](.github/ISSUE_TEMPLATE/bug_report.yml)
- Features: Use [Feature Request](.github/ISSUE_TEMPLATE/feature_request.yml)
- Refactors / tech debt: Use [Refactor](.github/ISSUE_TEMPLATE/refactor.yml)

## Commit Message Rules (Conventional Commits)

This project enforces Conventional Commits. Every commit message must follow:

```
<type>(<scope>): <subject>

<body — explain WHY, not WHAT>

<footer — references, breaking changes, co-authored-by>
```

**Allowed types:** `feat`, `fix`, `refactor`, `perf`, `test`, `docs`, `ci`, `chore`, `revert`, `build`, `style`

**Subject rules:**
- Imperative mood ("add", not "added" / "adds")
- Lowercase, no trailing period
- Max 72 characters
- No emoji

**One commit = one logical change.** Never mix refactor + feat + chore.

**Why this matters:** every commit on `master` should be deployable. Squashing 6 changes into one mega-commit (as PR #4 did) destroys `git bisect`, makes `git revert` impossible, and hides the development narrative.

## Git Identity (for AI agents and humans)

This repo's history shows 4 different author identities for the same physical contributor. We've consolidated them via `.mailmap`. To avoid creating new ghosts, every commit must use a single canonical identity:

```bash
git config user.name  "Thy985"
git config user.email "thy985@example.com"
```

**AI agents** (Claude Code, trae, etc.) committing on behalf of this contributor MUST:
1. Use the canonical identity above (configured globally via `git config --global`, or per-repo).
2. Append `Co-authored-by: Thy985 <thy985@example.com>` to the commit message — NEVER use the agent's own email as the primary author.

The `.mailmap` will rewrite any stray alias on `git log` / `git blame`, but the raw commit object still carries the original email. Configuring identity correctly at commit time prevents the mess from spreading.

## Branch Discipline

- **`master` is always deployable.** No WIP, no debug code, no `// TODO remove before merge`.
- **Branches are short-lived (1-3 days).** If a branch lives longer than a week, it's accumulating hidden merge cost — split or abandon it.
- **One branch = one concern.** Don't mix `feat(login)` with `chore(deps)` with `fix(typo)`.
- **Delete branches after merge.** Local: `git branch -d feature/foo`. Remote: `git push origin --delete feature/foo`.
- **No `--force` on shared branches.** If history needs correcting on a pushed branch, prefer `git revert` (which adds new commits and preserves old SHAs).

## Force-push / History Rewrite Policy

**`master` and any pushed branch MUST NOT be force-pushed.** Past force-pushes on this repo (see `git reflog`) orphaned every collaborator's local history and made `git blame` lie about when lines actually changed.

If you need to fix your own unpushed commits:
- Use `git commit --amend` (before push only)
- Use `git rebase -i HEAD~N` (before push only)

If a pushed commit is wrong, the answer is a **new** commit that fixes it (or a revert PR), not a rebase.

## Questions?

Feel free to open a discussion or contact the maintainers.