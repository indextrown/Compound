---
name: compound-github-workflow
description: Compound 저장소에서 GitHub 이슈, 브랜치, 커밋, PR을 저장소 라벨/브랜치/커밋/PR 컨벤션에 맞게 자동 생성해야 할 때 사용합니다.
---

# Compound GitHub 워크플로우

이 skill은 Compound 저장소 안에서만 사용합니다.

## 목적

저장소의 기존 라벨, 브랜치명, 커밋 제목, PR 템플릿 컨벤션에 맞춰 conventional commit, GitHub issue, 작업 브랜치, draft PR을 생성합니다.

이 skill은 repo-scoped Codex skill입니다. `.codex`가 아니라 `.agents/skills` 아래에 둡니다. 이 저장소에서 `.codex`는 project-local runtime hook과 config 용도로만 사용합니다.

## 커밋 워크플로우

사용자가 저장소 컨벤션에 맞춰 커밋을 요청하면 bundled commit script를 우선 사용합니다.

```bash
.agents/skills/compound-github-workflow/scripts/create-commit.sh \
  --type chore \
  --scope codex \
  --subject "add conventional commit helper"
```

규칙:

1. 커밋 제목 형식은 `type(scope): subject` 또는 `type: subject`입니다.
2. 지원하는 commit type은 `feat`, `fix`, `chore`, `docs`, `refactor`, `test`, `style`, `perf`, `ci`, `build`입니다.
3. script는 기본적으로 이미 staged 상태인 변경만 커밋합니다.
4. 특정 파일만 stage해야 하면 `--add PATH`를 사용합니다.
5. tracked 변경 전체를 stage해야 할 때만 `--all`을 사용합니다.
6. 커밋 제목 끝에 issue/PR 번호를 직접 붙이지 않습니다.
7. 관련 없는 untracked file은 그대로 둡니다.

## Issue / PR 워크플로우

1. `gh`가 설치되어 있고 인증되어 있는지 확인합니다.
2. 결정적인 동작을 위해 bundled script를 우선 사용합니다.

```bash
.agents/skills/compound-github-workflow/scripts/create-issue-pr.sh \
  --title "Add CompoundWidget state resolver" \
  --type feature \
  --body "WidgetKit snapshot/timeline 생성을 위한 finite action 실행 helper를 추가한다."
```

3. 사용자가 상세 issue body 파일을 준비한 경우 `--body-file`을 사용합니다.
4. body file에 템플릿 안내 문구가 남아 있으면 script가 실패해야 합니다.
5. 생성되는 PR은 기본적으로 draft로 둡니다.
6. 사용자가 명시적으로 ready-for-review PR을 요청한 경우에만 `--ready`를 사용합니다.
7. 사용자가 명시적으로 허용하지 않는 한 dirty worktree check를 `--allow-dirty`로 우회하지 않습니다.

## 지원 타입

- `feature` -> `✨ feature`, `feature/`
- `fix` -> `🔧 fix`, `fix/`
- `hotfix` -> `🔥 hotfix`, `hotfix/`
- `chore` -> `⚙️ chore`, `chore/`
- `refactor` -> `🔨 refactor`, `refactor/`
- `test` -> `✅ test`, `test/`
- `docs` -> `📃 docs`, `docs/`
- `ci` -> `🤖 ci`, `ci/`

## 메모

- `create-issue-pr.sh`는 기본적으로 empty starter commit을 만듭니다. GitHub PR은 base와 비교되는 head commit이 필요하기 때문입니다.
- PR body에는 `close #<issue-number>`가 자동으로 들어갑니다.
- 이 workflow를 여러 저장소에서 재사용해야 한다면, generic한 부분은 나중에 user-level skill 또는 plugin으로 분리합니다.
