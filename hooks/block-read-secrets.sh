#!/usr/bin/env bash
# msdlc hook — PreToolUse: Read
# Chặn đọc file chứa secrets/credentials: .env, key, cert, SSH config, AWS creds...
# Exit 1 → Claude Code hủy lệnh Read; exit 0 → cho qua.

set -euo pipefail

TOOL_INPUT=$(cat)
FILE_PATH=$(printf '%s' "$TOOL_INPUT" \
  | python3 -c "import sys,json; print(json.load(sys.stdin).get('file_path',''))" 2>/dev/null \
  || true)

[ -z "$FILE_PATH" ] && exit 0

BASENAME=$(basename "$FILE_PATH")
FP_LOWER=$(printf '%s' "$FILE_PATH" | tr '[:upper:]' '[:lower:]')

# ── .env files ────────────────────────────────────────────────────────────────
if printf '%s' "$BASENAME" | grep -qiE '^\.env(\.[^/]*)?$|\.env$'; then
  printf '[msdlc] BLOCKED: Không đọc file env "%s" — có thể chứa credentials/tokens.\n' \
    "$FILE_PATH" >&2
  exit 1
fi

# ── Key / cert / keystore ─────────────────────────────────────────────────────
if printf '%s' "$BASENAME" | grep -qiE '\.(pem|key|p12|pfx|jks|keystore|crt|cer|der|asc|gpg|ppk)$'; then
  printf '[msdlc] BLOCKED: Không đọc file khóa/cert "%s".\n' "$FILE_PATH" >&2
  exit 1
fi

# ── Tên file rõ ràng là secrets ───────────────────────────────────────────────
if printf '%s' "$FP_LOWER" | grep -qiE \
  '/(secret|credential|password|passwd|private[-_]?key|auth[-_]?token|api[-_]?key|access[-_]?key)[^/]*$'; then
  printf '[msdlc] BLOCKED: Tên file có dấu hiệu chứa secrets "%s".\n' "$FILE_PATH" >&2
  exit 1
fi

# ── SSH / cloud credentials ───────────────────────────────────────────────────
if printf '%s' "$FILE_PATH" | grep -qE \
  '(^|/)\.ssh/|(^|/)\.aws/credentials|(^|/)\.config/gcloud|(^|/)\.gnupg/'; then
  printf '[msdlc] BLOCKED: Không đọc cấu hình bảo mật hệ thống "%s".\n' "$FILE_PATH" >&2
  exit 1
fi

exit 0
