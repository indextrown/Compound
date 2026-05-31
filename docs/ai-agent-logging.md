# AI Agent Logging

이 저장소는 Codex hook을 사용해 AI agent 작업 기록을 남긴다.

목적은 단순 보관이 아니라 재현성, 디버깅 가능성, 오류 원인 추적 가능성을 확보하는 것이다. 나중에 결과물이 왜 그렇게 나왔는지 설명하려면 사용자 prompt, agent가 실행한 명령, tool 결과, turn 종료 시점을 같은 session 기준으로 추적할 수 있어야 한다.

## 공식 기준

- Codex skills는 repo 공유 workflow일 때 `.agents/skills` 아래에 둔다.
- Codex hooks는 project-local runtime hook일 때 `.codex/hooks.json` 또는 `.codex/config.toml`에 둔다.
- 이 저장소는 hook 설정 표현을 `.codex/hooks.json` 하나로 유지한다. 같은 layer에서 inline `[hooks]`와 `hooks.json`을 섞지 않는다.
- project-local hook은 프로젝트 `.codex/` layer가 trusted 상태일 때 실행된다. 새 hook 또는 변경된 hook은 Codex에서 `/hooks`로 검토하고 trust해야 한다.
- repo-local hook command는 Codex를 하위 디렉터리에서 시작해도 동작하도록 git root 기준 경로를 사용한다.

## 구성

- 설정: `.codex/hooks.json`
- hook script: `.codex/hooks/agent_audit_log.py`
- 로그 출력: `.codex/agent-logs/YYYY-MM-DD.jsonl`

`.codex/agent-logs/`는 로컬 실행 기록이므로 git에 커밋하지 않는다.

issue / PR 생성처럼 Codex가 반복 수행할 workflow는 hook이 아니라 skill로 관리한다.

- skill: `.agents/skills/compound-github-workflow/SKILL.md`
- skill script: `.agents/skills/compound-github-workflow/scripts/create-issue-pr.sh`

## 기록 이벤트

- `UserPromptSubmit`: 사용자가 보낸 prompt
- `PreToolUse`: shell command 또는 file edit 실행 직전
- `PostToolUse`: shell command 또는 file edit 실행 후 결과
- `PermissionRequest`: 권한 요청
- `Stop`: agent turn 종료

각 줄은 JSONL record이며 `summary`와 redacted `payload`를 포함한다.

## 주의

Codex hook은 런타임 기능이다. skill은 agent에게 작업 방식을 알려주는 데 적합하지만, tool 실행을 빠짐없이 자동 기록하는 장치는 아니다. 따라서 이 저장소에서는 hook을 1차 기록 장치로 사용하고, 필요하면 별도 skill은 "작업 전후에 로그를 확인하고 요약하라"는 운영 규칙을 담는 용도로만 둔다.

현재 Codex hook 동작은 런타임 버전에 영향을 받는다. 특히 tool-level hook은 `Bash`와 `apply_patch` 계열 기록에는 유용하지만, 모든 파일 수정 경로가 항상 `PreToolUse` / `PostToolUse`로 잡힌다고 가정하지 않는다. 중요한 변경 추적은 git diff와 함께 확인한다.

## 확인 방법

Codex를 새로 시작한 뒤 `/hooks`에서 project-local hook을 검토하고 trust한다. 이후 아무 prompt나 shell command가 필요한 작업을 수행한 뒤 아래 명령으로 로그 생성을 확인한다.

```sh
ls -la .codex/agent-logs
tail -n 5 .codex/agent-logs/*.jsonl
```
