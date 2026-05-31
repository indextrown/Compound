#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'USAGE'
Create a commit that follows this repository's commit title convention.

Usage:
  .agents/skills/compound-github-workflow/scripts/create-commit.sh \
    --type chore \
    --subject "add conventional commit helper"

Options:
      --type TYPE        Commit type. Required unless --message is used.
                         Allowed: feat, fix, chore, docs, refactor, test, style, perf, ci, build.
      --scope SCOPE      Optional commit scope. Example: codex
      --subject TEXT     Commit subject. Required unless --message is used.
      --message TEXT     Full commit title. Example: "chore(codex): add commit helper"
      --body TEXT        Optional commit body paragraph.
      --body-file PATH   Optional commit body markdown file.
      --add PATH         Stage an explicit path. Can be repeated.
      --all              Stage tracked file changes with git add -u.
      --dry-run          Print the commit title and staged files without committing.
      --no-verify        Pass --no-verify to git commit.
  -h, --help             Show this help.

Notes:
  - By default, this script commits only already staged changes.
  - It never stages untracked files unless they are passed with --add.
  - The commit title format is: type(scope): subject or type: subject.
USAGE
}

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "missing required command: $1"
}

validate_type() {
  case "$1" in
    feat|fix|chore|docs|refactor|test|style|perf|ci|build) ;;
    *) fail "unsupported type '$1'. Use one of: feat, fix, chore, docs, refactor, test, style, perf, ci, build" ;;
  esac
}

validate_scope() {
  local scope="$1"

  [[ -z "$scope" ]] && return 0
  [[ "$scope" =~ ^[a-z0-9._/-]+$ ]] || fail "scope must match [a-z0-9._/-]+: $scope"
}

validate_subject() {
  local subject="$1"

  [[ -n "$subject" ]] || fail "subject is required"
  [[ "$subject" != " "* ]] || fail "subject must not start with whitespace"
  [[ "$subject" != *"." ]] || fail "subject must not end with a period"
}

validate_message() {
  local message="$1"
  local pattern='^(feat|fix|chore|docs|refactor|test|style|perf|ci|build)(\([a-z0-9._/-]+\))?: [^[:space:]].+$'

  [[ -n "$message" ]] || fail "message is required"
  if ! printf '%s\n' "$message" | grep -Eq "$pattern"; then
    fail "commit title must match: type(scope): subject or type: subject"
  fi
  if printf '%s\n' "$message" | grep -Eq ' \(#[0-9]+\)$'; then
    fail "do not append issue/PR number to the commit title manually: $message"
  fi
  if printf '%s\n' "$message" | grep -Eq '\.$'; then
    fail "commit title must not end with a period"
  fi
}

TYPE=""
SCOPE=""
SUBJECT=""
MESSAGE=""
BODY=""
BODY_FILE=""
DRY_RUN=0
NO_VERIFY=0
STAGE_ALL=0
ADD_PATHS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --type)
      TYPE="${2:-}"
      shift 2
      ;;
    --scope)
      SCOPE="${2:-}"
      shift 2
      ;;
    --subject)
      SUBJECT="${2:-}"
      shift 2
      ;;
    --message)
      MESSAGE="${2:-}"
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
    --add)
      ADD_PATHS+=("${2:-}")
      shift 2
      ;;
    --all)
      STAGE_ALL=1
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --no-verify)
      NO_VERIFY=1
      shift
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

require_command git
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || fail "current directory is not inside a git repository"

if [[ -n "$MESSAGE" ]]; then
  validate_message "$MESSAGE"
else
  [[ -n "$TYPE" ]] || fail "--type is required unless --message is used"
  validate_type "$TYPE"
  validate_scope "$SCOPE"
  validate_subject "$SUBJECT"

  if [[ -n "$SCOPE" ]]; then
    MESSAGE="${TYPE}(${SCOPE}): ${SUBJECT}"
  else
    MESSAGE="${TYPE}: ${SUBJECT}"
  fi

  validate_message "$MESSAGE"
fi

[[ -z "$BODY_FILE" || -f "$BODY_FILE" ]] || fail "body file not found: $BODY_FILE"

if [[ "$STAGE_ALL" -eq 1 ]]; then
  git add -u
fi

for path in "${ADD_PATHS[@]}"; do
  [[ -n "$path" ]] || fail "--add requires a non-empty path"
  git add -- "$path"
done

if git diff --cached --quiet; then
  fail "no staged changes to commit. Stage files first, pass --add PATH, or pass --all for tracked changes."
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

MESSAGE_FILE="$TMP_DIR/commit-message.txt"
printf '%s\n' "$MESSAGE" >"$MESSAGE_FILE"

if [[ -n "$BODY" || -n "$BODY_FILE" ]]; then
  printf '\n' >>"$MESSAGE_FILE"
fi

if [[ -n "$BODY" ]]; then
  printf '%s\n' "$BODY" >>"$MESSAGE_FILE"
fi

if [[ -n "$BODY_FILE" ]]; then
  if [[ -n "$BODY" ]]; then
    printf '\n' >>"$MESSAGE_FILE"
  fi
  cat "$BODY_FILE" >>"$MESSAGE_FILE"
  printf '\n' >>"$MESSAGE_FILE"
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  printf 'Commit title:\n%s\n\n' "$MESSAGE"
  printf 'Staged files:\n'
  git diff --cached --name-only
  exit 0
fi

COMMIT_ARGS=(commit -F "$MESSAGE_FILE")
if [[ "$NO_VERIFY" -eq 1 ]]; then
  COMMIT_ARGS+=(--no-verify)
fi

git "${COMMIT_ARGS[@]}"
