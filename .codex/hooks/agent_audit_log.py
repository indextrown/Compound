#!/usr/bin/env python3
import hashlib
import json
import os
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


SENSITIVE_KEY_RE = re.compile(
    r"(api[_-]?key|authorization|cookie|password|passwd|secret|token|credential|private[_-]?key)",
    re.IGNORECASE,
)

SECRET_VALUE_PATTERNS = [
    re.compile(r"Bearer\s+[A-Za-z0-9._~+/=-]{12,}"),
    re.compile(r"sk-[A-Za-z0-9_-]{20,}"),
    re.compile(r"gh[pousr]_[A-Za-z0-9_]{20,}"),
    re.compile(r"xox[baprs]-[A-Za-z0-9-]{20,}"),
]

MAX_STRING_LENGTH = 20000
MAX_RAW_BYTES = 250000


def repo_root() -> Path:
    try:
        output = subprocess.check_output(
            ["git", "rev-parse", "--show-toplevel"],
            stderr=subprocess.DEVNULL,
            text=True,
        ).strip()
        if output:
            return Path(output)
    except Exception:
        pass
    return Path.cwd()


def redact_string(value: str) -> str:
    redacted = value
    for pattern in SECRET_VALUE_PATTERNS:
        redacted = pattern.sub("[REDACTED]", redacted)
    if len(redacted) > MAX_STRING_LENGTH:
        return redacted[:MAX_STRING_LENGTH] + "...[TRUNCATED]"
    return redacted


def sanitize(value: Any, parent_key: str = "") -> Any:
    if isinstance(value, dict):
        sanitized = {}
        for key, child in value.items():
            key_text = str(key)
            if SENSITIVE_KEY_RE.search(key_text):
                sanitized[key_text] = "[REDACTED]"
            else:
                sanitized[key_text] = sanitize(child, key_text)
        return sanitized

    if isinstance(value, list):
        return [sanitize(item, parent_key) for item in value]

    if isinstance(value, str):
        return redact_string(value)

    return value


def stable_hash(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8", errors="replace")).hexdigest()


def extract_summary(payload: dict[str, Any]) -> dict[str, Any]:
    tool_input = payload.get("tool_input")
    summary: dict[str, Any] = {
        "event": payload.get("hook_event_name"),
        "session_id": payload.get("session_id"),
        "turn_id": payload.get("turn_id"),
        "cwd": payload.get("cwd"),
        "model": payload.get("model"),
        "transcript_path": payload.get("transcript_path"),
        "tool_name": payload.get("tool_name"),
    }

    prompt = payload.get("prompt") or payload.get("user_prompt")
    if isinstance(prompt, str):
        summary["prompt_sha256"] = stable_hash(prompt)
        summary["prompt_preview"] = redact_string(prompt[:1000])

    if isinstance(tool_input, dict):
        command = tool_input.get("command") or tool_input.get("cmd")
        if isinstance(command, str):
            summary["command_sha256"] = stable_hash(command)
            summary["command_preview"] = redact_string(command[:2000])
        summary["tool_input_keys"] = sorted(str(key) for key in tool_input.keys())

    tool_response = payload.get("tool_response")
    if isinstance(tool_response, dict):
        status = tool_response.get("status") or tool_response.get("exit_code")
        if status is not None:
            summary["tool_status"] = status

    return {key: value for key, value in summary.items() if value is not None}


def main() -> int:
    raw = sys.stdin.buffer.read(MAX_RAW_BYTES + 1)
    truncated = len(raw) > MAX_RAW_BYTES
    raw = raw[:MAX_RAW_BYTES]

    try:
        payload = json.loads(raw.decode("utf-8"))
    except Exception as error:
        payload = {
            "hook_event_name": "Unknown",
            "parse_error": str(error),
            "raw_preview": raw.decode("utf-8", errors="replace")[:2000],
        }

    sanitized_payload = sanitize(payload)
    root = repo_root()
    log_dir = root / ".codex" / "agent-logs"
    log_dir.mkdir(parents=True, exist_ok=True)

    now = datetime.now(timezone.utc)
    entry = {
        "schema_version": 1,
        "recorded_at": now.isoformat(),
        "raw_input_truncated": truncated,
        "summary": extract_summary(sanitized_payload if isinstance(sanitized_payload, dict) else {}),
        "payload": sanitized_payload,
    }

    log_path = log_dir / f"{now.date().isoformat()}.jsonl"
    with log_path.open("a", encoding="utf-8") as file:
        file.write(json.dumps(entry, ensure_ascii=False, sort_keys=True))
        file.write("\n")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
