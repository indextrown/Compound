---
name: compound-github-workflow
description: Use when working in the Compound repository and the user asks to create GitHub issues, branches, or pull requests automatically using the repository's labels and PR conventions.
---

# Compound GitHub Workflow

Use this skill only inside the Compound repository.

## Purpose

Create a GitHub issue, matching work branch, and draft pull request using the repository's existing labels and PR template conventions.

This is a repo-scoped Codex skill. Keep it under `.agents/skills`, not `.codex`; `.codex` is reserved here for project-local runtime hooks and config.

## Workflow

1. Confirm `gh` is installed and authenticated.
2. Prefer the bundled script for deterministic behavior:

```bash
.agents/skills/compound-github-workflow/scripts/create-issue-pr.sh \
  --title "Add CompoundWidget state resolver" \
  --type feature \
  --body "WidgetKit snapshot/timeline 생성을 위한 finite action 실행 helper를 추가한다."
```

3. Use `--body-file` when the user has prepared a detailed issue body. The script rejects body files that still contain template guide text.
4. Keep generated PRs as draft by default. Use `--ready` only when the user explicitly asks for a ready-for-review PR.
5. Do not bypass the script's dirty worktree check unless the user explicitly accepts `--allow-dirty`.

## Supported Types

- `feature` -> `✨ feature`, `feature/`
- `fix` -> `🔧 fix`, `fix/`
- `hotfix` -> `🔥 hotfix`, `hotfix/`
- `chore` -> `⚙️ chore`, `chore/`
- `refactor` -> `🔨 refactor`, `refactor/`
- `test` -> `✅ test`, `test/`
- `docs` -> `📃 docs`, `docs/`
- `ci` -> `🤖 ci`, `ci/`

## Notes

- The script creates an empty starter commit by default because GitHub PRs need a head branch with at least one commit.
- The PR body includes `close #<issue-number>` automatically.
- If the workflow should be reused across many repositories, move the generic parts into a user-level skill or plugin later.
