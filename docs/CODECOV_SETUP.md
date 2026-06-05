# Codecov Setup Guide

## What is Codecov?

Codecov is a code coverage analysis tool that:
- Reports test coverage percentage
- Tracks coverage changes over time
- Provides coverage reports in pull requests
- Helps identify areas with low test coverage

---

## Setup Steps

### Step 1: Sign up for Codecov

1. Visit https://codecov.io
2. Click "Sign Up" button (top right)
3. Choose "Sign up with GitHub" - this is the easiest option
4. Authorize Codecov to access your GitHub account
5. You may need to select a plan (free tier is sufficient for open source)

### Step 2: Add Repository to Codecov

**Option A: Via Codecov Dashboard**
1. After signing in, click "Add Repository" or "+" button
2. Search for "fixmath" in the repository list
3. Click "Setup" next to your repository
4. Copy the `CODECOV_TOKEN` shown on the page

**Option B: Via GitHub Marketplace**
1. Go to https://github.com/marketplace/codecov
2. Click "Install" or "Buy"
3. Select your account (Thy985)
4. Choose which repositories to include (select "fixmath" or "All repositories")
5. Complete the installation

### Step 3: Add CODECOV_TOKEN to GitHub Secrets

1. Go to https://github.com/Thy985/fixmath/settings/secrets/actions
2. Click "New repository secret"
3. Fill in:
   - **Name:** `CODECOV_TOKEN`
   - **Secret:** Paste the token from Codecov dashboard
4. Click "Add secret"

### Step 4: Verify Integration

1. Push a new commit or wait for CI to run
2. Go to https://github.com/Thy985/fixmath/actions
3. Check the "Coverage Report" step in the workflow
4. Visit https://codecov.io to see coverage reports

---

## Understanding Codecov Reports

### Coverage Percentage

| Percentage | Status | Color |
|------------|--------|-------|
| 80-100% | Excellent | Green |
| 60-79% | Good | Yellow |
| 40-59% | Moderate | Orange |
| 0-39% | Low | Red |

### PR Comments

Once configured, Codecov will automatically:
- Comment on PRs with coverage changes
- Show diff coverage (lines added/removed)
- Flag files that decreased coverage

---

## Troubleshooting

### "Repository not found" in Codecov

1. Click "Resync" button on Codecov dashboard
2. Ensure the repository is public (Codecov free tier)
3. Check if Codecov GitHub App has access to your repository

### Coverage not uploading

1. Check if `CODECOV_TOKEN` is correctly added to GitHub Secrets
2. Verify the workflow step `codecov/codecov-action@v4` is running
3. Check GitHub Actions logs for errors

### Token Issues

**If your token shows as "Deactivated":**
1. Go to https://app.codecov.io
2. Find your repository
3. Click "Settings" → "General"
4. Look for "Deactivate" vs "Activate" status
5. If deactivated, click "Activate" to enable tracking

---

## Alternative: Use GitHub's Built-in Coverage

If Codecov setup is too complex, you can use GitHub's built-in coverage reports:

1. No additional setup required
2. Artifacts contain `lcov.info` coverage data
3. Download from GitHub Actions artifacts
4. View locally using coverage tools

The CI workflow is already configured to generate coverage reports - they're just not being uploaded to an external service.

---

## Codecov Dashboard Features

After activation, you can:
- View overall coverage trend graph
- See per-file coverage breakdown
- Compare coverage between branches
- Set coverage targets/banners
- Integrate with Slack for notifications

---

## Quick Reference

| Item | Value/Link |
|------|------------|
| Codecov Website | https://codecov.io |
| Codecov Dashboard | https://app.codecov.io |
| GitHub App | https://github.com/marketplace/codecov |
| Repository Settings | https://github.com/Thy985/fixmath/settings/secrets/actions |
| CI Workflow | `.github/workflows/flutter-ci.yml` |

---

## Notes

- Codecov free tier works for public repositories
- Coverage data is public on Codecov (no privacy concerns for open source)
- You can adjust sensitivity in Codecov settings if needed
- The `fail_ci_if_error: false` setting prevents CI from failing due to Codecov issues

---

Generated with [Claude Code](https://claude.ai/code)
Date: 2026-06-05