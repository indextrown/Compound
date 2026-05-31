#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'USAGE'
Create a GitHub issue, branch, and draft PR for this repository.

Usage:
  .agents/skills/compound-github-workflow/scripts/create-issue-pr.sh --title "Add CompoundWidget helper" --type feature

Options:
  -t, --title TEXT       Issue title. Required.
      --type TYPE        One of: feature, fix, hotfix, chore, refactor, test, docs, ci.
                         Default: chore.
      --body TEXT        Issue/PR summary text. Recommended.
      --body-file PATH   Use an existing markdown file as the issue body.
      --base BRANCH      Base branch for the PR. Default: main.
      --branch NAME      Branch name to create/use. Default: <type>/<issue>-<slug>.
      --assignee LOGIN   Issue assignee. Default: @me.
      --no-assignee      Do not assign the issue.
      --ready            Create a ready-for-review PR instead of a draft PR.
      --no-empty-commit  Do not create an empty starter commit when the branch has no diff.
      --allow-dirty      Allow running with local uncommitted changes.
      --remote NAME      Git remote to push. Default: origin.
      --repo OWNER/REPO  Explicit GitHub repository for gh commands.
  -h, --help             Show this help.

Notes:
  - Requires GitHub CLI: gh auth login
  - By default, the script refuses to run in a dirty worktree.
  - A PR needs at least one commit, so the script creates an empty starter commit by default.
  - If --body-file is used, template guide text must be replaced before running.
USAGE
}

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "missing required command: $1"
}

validate_body_file() {
  local file="$1"

  if rg -n \
    -e "이슈에 대해 간단하게 설명해 주세요" \
    -e "수정/추가할 예정인 파일명을 적어주세요" \
    -e "해야 할 작업들을 나열해 주세요" \
    -e "짧고 명확한 작업 이름" \
    -e "왜 이 작업이 필요한지" \
    -e "현재 어떤 문제가 있는가" \
    -e "어떤 명령으로 확인할 것인가" \
    -e "이 변경이 무엇을 하는지" \
    -e "왜 이 PR이 필요한지" \
    -e "핵심 변경 내용을 실제 수정사항으로 바꿉니다" \
    -e "실제 실행한 검증 명령을 적습니다" \
    -e "작업 요청서 링크 또는 파일명" \
    "$file" >/dev/null 2>&1; then
    fail "body file still contains template guide text: $file"
  fi
}

label_and_prefix_for_type() {
  case "$1" in
    feature) LABEL="✨ feature"; PREFIX="feature"; PR_TYPE_LABEL="Feature: 기능 추가" ;;
    fix) LABEL="🔧 fix"; PREFIX="fix"; PR_TYPE_LABEL="Fix: 일반 버그 수정" ;;
    hotfix) LABEL="🔥 hotfix"; PREFIX="hotfix"; PR_TYPE_LABEL="Hotfix: 긴급 버그 수정" ;;
    chore) LABEL="⚙️ chore"; PREFIX="chore"; PR_TYPE_LABEL="Chore: 환경 설정 및 기타 작업" ;;
    refactor) LABEL="🔨 refactor"; PREFIX="refactor"; PR_TYPE_LABEL="Refactor: 코드 개선" ;;
    test) LABEL="✅ test"; PREFIX="test"; PR_TYPE_LABEL="Test: 테스트 코드 작성" ;;
    docs) LABEL="📃 docs"; PREFIX="docs"; PR_TYPE_LABEL="Docs: 문서 작성 및 수정" ;;
    ci) LABEL="🤖 ci"; PREFIX="ci"; PR_TYPE_LABEL="CI: CI/CD 및 GitHub Actions 작업 및 수정" ;;
    *) fail "unsupported type '$1'. Use one of: feature, fix, hotfix, chore, refactor, test, docs, ci" ;;
  esac
}

slugify() {
  local value="$1"
  local slug

  slug="$(printf '%s' "$value" \
    | tr '[:upper:]' '[:lower:]' \
    | LC_ALL=C sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//; s/-+/-/g' \
    | cut -c 1-48)"

  if [[ -z "$slug" ]]; then
    slug="$TYPE"
  fi

  printf '%s' "$slug"
}

checked_pr_type_line() {
  local type_label="$1"
  local line_label="$2"

  if [[ "$type_label" == "$line_label" ]]; then
    printf -- '- [x] %s\n' "$line_label"
  else
    printf -- '- [ ] %s\n' "$line_label"
  fi
}

write_issue_body() {
  local destination="$1"

  cat >"$destination" <<EOF
## 💡 Issue
${BODY:-$TITLE}

## 📁 작업할 파일
- 작업 과정에서 확정합니다.

## 🔥 Tasks
- [ ] ${BODY:-$TITLE}

## 🎨 스크린샷(선택)
| 기능 |          스크린샷           |
| :--: | :-------------------------: |
| GIF  | <img src = "" width ="250"> |
EOF
}

write_pr_body() {
  local destination="$1"
  local issue_number="$2"

  {
    printf '## 💡 PR 유형\n'
    checked_pr_type_line "$PR_TYPE_LABEL" "Feature: 기능 추가"
    checked_pr_type_line "$PR_TYPE_LABEL" "Fix: 일반 버그 수정"
    checked_pr_type_line "$PR_TYPE_LABEL" "Hotfix: 긴급 버그 수정"
    checked_pr_type_line "$PR_TYPE_LABEL" "Chore: 환경 설정 및 기타 작업"
    checked_pr_type_line "$PR_TYPE_LABEL" "Refactor: 코드 개선"
    checked_pr_type_line "$PR_TYPE_LABEL" "Test: 테스트 코드 작성"
    checked_pr_type_line "$PR_TYPE_LABEL" "Docs: 문서 작성 및 수정"
    checked_pr_type_line "$PR_TYPE_LABEL" "CI: CI/CD 및 GitHub Actions 작업 및 수정"
    cat <<EOF

## ✏️ 변경 사항
${BODY:-$TITLE}

## 🚨 관련 이슈
- close #${issue_number}

## 🎨 스크린샷
|기능|스크린샷|
|:--:|:--:|
|GIF|<img src = "" width ="250">|

## 🔥 추가 설명
EOF
  } >"$destination"
}

TITLE=""
TYPE="chore"
BODY=""
BODY_FILE=""
BASE_BRANCH="main"
BRANCH_NAME=""
ASSIGNEE="@me"
ASSIGN_ISSUE=1
DRAFT_PR=1
CREATE_EMPTY_COMMIT=1
ALLOW_DIRTY=0
REMOTE="origin"
REPO=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -t|--title)
      TITLE="${2:-}"
      shift 2
      ;;
    --type)
      TYPE="${2:-}"
      shift 2
      ;;
    --body)
      BODY="${2:-}"
      shift 2
      ;;
    --body-file)
      BODY_FILE="${2:-}"
      shift 2
      ;;
    --base)
      BASE_BRANCH="${2:-}"
      shift 2
      ;;
    --branch)
      BRANCH_NAME="${2:-}"
      shift 2
      ;;
    --assignee)
      ASSIGNEE="${2:-}"
      ASSIGN_ISSUE=1
      shift 2
      ;;
    --no-assignee)
      ASSIGN_ISSUE=0
      shift
      ;;
    --ready)
      DRAFT_PR=0
      shift
      ;;
    --no-empty-commit)
      CREATE_EMPTY_COMMIT=0
      shift
      ;;
    --allow-dirty)
      ALLOW_DIRTY=1
      shift
      ;;
    --remote)
      REMOTE="${2:-}"
      shift 2
      ;;
    --repo)
      REPO="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "unknown option: $1"
      ;;
  esac
done

[[ -n "$TITLE" ]] || fail "--title is required"
[[ -z "$BODY_FILE" || -f "$BODY_FILE" ]] || fail "body file not found: $BODY_FILE"

label_and_prefix_for_type "$TYPE"
require_command git
require_command gh
require_command rg
gh auth status >/dev/null 2>&1 || fail "gh is not authenticated. Run: gh auth login"

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

if [[ "$ALLOW_DIRTY" -eq 0 && -n "$(git status --porcelain)" ]]; then
  fail "worktree has uncommitted changes. Commit/stash them or pass --allow-dirty."
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

ISSUE_BODY_FILE="$TMP_DIR/issue.md"
PR_BODY_FILE="$TMP_DIR/pr.md"

if [[ -n "$BODY_FILE" ]]; then
  validate_body_file "$BODY_FILE"
  ISSUE_BODY_FILE="$BODY_FILE"
else
  write_issue_body "$ISSUE_BODY_FILE"
fi

GH_REPO_ARGS=()
if [[ -n "$REPO" ]]; then
  GH_REPO_ARGS=(--repo "$REPO")
fi

ISSUE_ARGS=(issue create "${GH_REPO_ARGS[@]}" --title "$TITLE" --body-file "$ISSUE_BODY_FILE" --label "$LABEL")
if [[ "$ASSIGN_ISSUE" -eq 1 ]]; then
  [[ -n "$ASSIGNEE" ]] || fail "--assignee requires a non-empty value"
  ISSUE_ARGS+=(--assignee "$ASSIGNEE")
fi

ISSUE_URL="$(gh "${ISSUE_ARGS[@]}")"
ISSUE_NUMBER="${ISSUE_URL##*/}"
[[ "$ISSUE_NUMBER" =~ ^[0-9]+$ ]] || fail "could not parse issue number from: $ISSUE_URL"

if [[ -z "$BRANCH_NAME" ]]; then
  BRANCH_NAME="${PREFIX}/${ISSUE_NUMBER}-$(slugify "$TITLE")"
fi

git fetch "$REMOTE" "$BASE_BRANCH" >/dev/null 2>&1 || fail "failed to fetch $REMOTE/$BASE_BRANCH"

if git show-ref --verify --quiet "refs/heads/$BRANCH_NAME"; then
  git switch "$BRANCH_NAME" >/dev/null
else
  git switch -c "$BRANCH_NAME" "$REMOTE/$BASE_BRANCH" >/dev/null
fi

if [[ -z "$(git log --oneline "$REMOTE/$BASE_BRANCH"..HEAD)" ]]; then
  if [[ "$CREATE_EMPTY_COMMIT" -eq 1 ]]; then
    git commit --allow-empty -m "${TYPE}: start #${ISSUE_NUMBER}" >/dev/null
  else
    fail "branch has no commits compared with $BASE_BRANCH. Commit changes or allow the default empty starter commit."
  fi
fi

git push -u "$REMOTE" "$BRANCH_NAME" >/dev/null

write_pr_body "$PR_BODY_FILE" "$ISSUE_NUMBER"
PR_TITLE="[${LABEL}] ${TITLE}"

if EXISTING_PR_URL="$(gh pr view "$BRANCH_NAME" "${GH_REPO_ARGS[@]}" --json url -q .url 2>/dev/null)"; then
  PR_URL="$EXISTING_PR_URL"
else
  PR_ARGS=(pr create "${GH_REPO_ARGS[@]}" --base "$BASE_BRANCH" --head "$BRANCH_NAME" --title "$PR_TITLE" --body-file "$PR_BODY_FILE")
  if [[ "$DRAFT_PR" -eq 1 ]]; then
    PR_ARGS+=(--draft)
  fi

  PR_URL="$(gh "${PR_ARGS[@]}")"
fi

cat <<EOF
Created issue and PR.

Issue:  ${ISSUE_URL}
Branch: ${BRANCH_NAME}
PR:     ${PR_URL}
EOF
