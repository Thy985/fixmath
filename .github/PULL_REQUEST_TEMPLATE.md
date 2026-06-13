## Linked Issue

<!-- Every PR must reference a tracked issue. "feat: 项目批评" repeated 8x
     in history because there was no issue tracker. Don't repeat that. -->
Fixes #

## Type of Change

<!-- One box. Mixing types in one PR makes review and revert harder. -->
- [ ] `feat` — new feature (user-visible behavior change)
- [ ] `fix` — bug fix
- [ ] `refactor` — code change that neither fixes a bug nor adds a feature
- [ ] `perf` — performance improvement
- [ ] `test` — adding or updating tests
- [ ] `docs` — documentation only
- [ ] `ci` — CI/CD pipeline change
- [ ] `chore` — tooling, dependencies, config (no behavior change)
- [ ] `revert` — reverts a previous commit

## Description

<!-- One paragraph: WHAT and WHY. Skip WHAT — the diff shows that. -->

## Commit History Discipline

<!-- This is the rule we keep breaking. Be honest. -->
- [ ] Commits are atomic (one logical change each)
- [ ] Commit messages follow Conventional Commits (`type(scope): subject`)
- [ ] No force-push was used to rewrite already-published commits
- [ ] No rebase/filter-branch was used to erase evidence of prior work
- [ ] No agent-identity (e.g. `Coder <coder@mavis.local>`) commits slipped in

## Scope

<!-- What this PR touches AND what it does NOT touch. -->
**Touches:**
-

**Out of scope (intentionally NOT changed):**
-

## Test Plan

<!-- How was this verified? Be specific. -->
- [ ] `flutter analyze` — 0 errors
- [ ] `flutter test` — N/N pass
- [ ] Manual verification on device/emulator:
- [ ] Other:

## Risk & Rollback

<!-- Every PR has risk. Be honest about it. -->
**Risk:**
**Rollback plan:** `git revert <merge-sha>`

## Screenshots (UI change only)

<!-- Attach before/after for UI-affecting PRs. -->
<!-- Screenshot here -->

---

Generated with [Claude Code](https://claude.ai/code)