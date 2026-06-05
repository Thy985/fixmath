# GitHub Repository Configuration Checklist

This document outlines the steps to fully configure your FormulaFix repository on GitHub.

---

## 1. Repository Topics

**Purpose:** Improve repository discoverability in GitHub search.

**Steps:**
1. Go to https://github.com/Thy985/fixmath
2. Click the ⚙️ Settings button (top right of repository page)
3. Scroll down to "Topics" section
4. Add the following topics:
   - `flutter`
   - `dart`
   - `markdown`
   - `latex`
   - `pdf`
   - `math`
   - `editor`
   - `formula-rendering`

---

## 2. Branch Protection

**Purpose:** Protect master branch from direct pushes, require PR reviews and CI passing.

**Steps:**
1. Go to https://github.com/Thy985/fixmath/settings/branches
2. Click "Add rule" under "Branch protection rules"
3. Configure:
   - **Branch name pattern:** `master`
   - ☑️ "Require pull request reviews before merging"
   - ☑️ "Require status checks to pass before merging"
   - ☑️ "Require branches to be up to date before merging"
   - ☑️ "Do not allow bypassing the above settings"
4. Click "Create"

---

## 3. Enable Dependabot Security Updates

**Purpose:** Automatically detect and alert about vulnerable dependencies.

**Steps:**
1. Go to https://github.com/Thy985/fixmath/settings/security_analysis
2. Under "Dependabot alerts", click "Enable"
3. Under "Dependabot security updates", click "Enable"

---

## 4. Enable Secret Scanning

**Purpose:** Detect secrets committed to the repository.

**Steps:**
1. Go to https://github.com/Thy985/fixmath/settings/security_analysis
2. Under "Secret scanning", click "Enable"
3. Enable "Push protection" to block commits containing secrets

---

## 5. Codecov Integration

**Purpose:** Track test coverage over time and view coverage reports.

**Steps:**
1. Visit https://codecov.io and sign in with GitHub
2. Authorize Codecov to access your repository
3. Copy the upload token provided
4. Go to https://github.com/Thy985/fixmath/settings/secrets/actions
5. Click "New repository secret"
6. Name: `CODECOV_TOKEN`
7. Value: Paste the token from Codecov
8. Click "Add secret"

The workflow will automatically upload coverage reports on each CI run.

---

## 6. GitHub Discussions (Optional)

**Purpose:** Enable community Q&A and discussions.

**Steps:**
1. Go to https://github.com/Thy985/fixmath/settings
2. Under "Features", check "Allow GitHub Discussions"
3. Configure discussion categories as needed

---

## 7. Enable Issues (if disabled)

**Purpose:** Allow bug reports and feature requests.

**Steps:**
1. Go to https://github.com/Thy985/fixmath/settings
2. Under "Features", ensure "Issues" is checked

---

## 8. Repository Metadata

**Current settings:**
- Name: `fixmath`
- Description: "FormulaFix - A local Markdown/LaTeX editor with math formula rendering and multi-format export (PDF, Word)"
- License: MIT
- Visibility: Public
- Issues: ✅ Enabled
- Projects: ✅ Enabled
- Wiki: ✅ Enabled

**To update description:**
1. Go to https://github.com/Thy985/fixmath/settings
2. Edit "Website" field if desired
3. Update description in main settings section

---

## CI/CD Status

The Flutter CI/CD workflow is configured and running:
- **Trigger:** Push to `master` or `develop` branches
- **Jobs:**
  - Flutter Analyze
  - Flutter Tests (with coverage)
  - Build Android APK (debug)
  - Build Android APK (release, master only)
  - Build iOS (simulator)
- **Artifacts:** Available for 7-30 days

View CI runs: https://github.com/Thy985/fixmath/actions

---

## Release Process

Releases are created automatically when CI passes on master:
1. Draft releases are created automatically
2. Review and publish the draft release
3. Add release notes manually if needed

---

Generated with [Claude Code](https://claude.ai/code)
Date: 2026-06-05