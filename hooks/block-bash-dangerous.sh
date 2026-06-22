#!/usr/bin/env bash
# msdlc hook — PreToolUse: Bash
# Hai nhóm bảo vệ:
#   A) Đọc file secrets qua shell (cat/head/... nhắm vào .env, key, SSH...)
#   B) Lệnh phá hủy / nguy hiểm (rm -rf hệ thống, pipe-to-shell, force-push, drop DB...)
# Exit 1 → Claude Code hủy lệnh; exit 0 → cho qua.

set -euo pipefail

TOOL_INPUT=$(cat)
CMD=$(printf '%s' "$TOOL_INPUT" \
  | python3 -c "import sys,json; print(json.load(sys.stdin).get('command',''))" 2>/dev/null \
  || true)

[ -z "$CMD" ] && exit 0

block() {
  printf '[msdlc] BLOCKED: %s\n' "$1" >&2
  exit 1
}

# ═══════════════════════════════════════════════════════════════════════════════
# A. ĐỌC FILE SECRETS QUA SHELL
# ═══════════════════════════════════════════════════════════════════════════════

if printf '%s' "$CMD" | grep -qiE \
  '\b(cat|head|tail|less|more|strings|xxd|hexdump|od)\b[^|]*\.env(\s|$|\.|[^a-zA-Z])'; then
  block "Không đọc file .env qua shell — có thể chứa credentials."
fi

if printf '%s' "$CMD" | grep -qiE \
  '\b(cat|head|tail|less|strings|xxd)\b[^|]*\.(pem|key|p12|pfx|jks|keystore|ppk)\b'; then
  block "Không đọc file khóa/cert qua shell."
fi

if printf '%s' "$CMD" | grep -qiE \
  '\b(cat|head|tail|less|strings)\b[^|]*(\.ssh/|\.aws/credentials|\.gnupg/)'; then
  block "Không đọc cấu hình bảo mật hệ thống (~/.ssh, ~/.aws, ~/.gnupg) qua shell."
fi

# ═══════════════════════════════════════════════════════════════════════════════
# B. LỆNH PHÁ HỦY / NGUY HIỂM
# ═══════════════════════════════════════════════════════════════════════════════

if printf '%s' "$CMD" | grep -qE ':\(\)\s*\{.*:\|:'; then
  block "Fork bomb pattern bị phát hiện."
fi

if printf '%s' "$CMD" | grep -qE \
  'rm\s+(-[a-zA-Z]*f[a-zA-Z]*r[a-zA-Z]*|-[a-zA-Z]*r[a-zA-Z]*f[a-zA-Z]*)(\s+"?|\s+'"'"'?)(\/\s*$|\/\s*[*]|~\s*$|~\s*[*]|\$HOME\s*$|\$HOME\/\*|\/etc\b|\/usr\b|\/var\b|\/bin\b|\/boot\b|\/sys\b|\/proc\b|\/lib\b|\/sbin\b)'; then
  block "rm -rf nhắm vào thư mục hệ thống bị chặn."
fi

if printf '%s' "$CMD" | grep -qE '>\s*/dev/(sd[a-z]|nvme[0-9]|vd[a-z]|hd[a-z]|xvd[a-z])'; then
  block "Ghi đè thiết bị lưu trữ bị chặn."
fi

if printf '%s' "$CMD" | grep -qE 'mkfs(\.[a-z]+)?\s+/dev/'; then
  block "Lệnh format ổ đĩa (mkfs) bị chặn."
fi

if printf '%s' "$CMD" | grep -qE '\bdd\b.*of=/dev/(sd[a-z]|nvme|vd[a-z]|hd[a-z]|zero|null)'; then
  block "dd ghi vào thiết bị hệ thống bị chặn."
fi

if printf '%s' "$CMD" | grep -qiE '(curl|wget)\s[^|]*\|\s*(bash|sh|zsh|fish|python[23]?|perl|ruby)\b'; then
  block "Pipe từ internet vào shell (supply-chain risk) bị chặn."
fi

if printf '%s' "$CMD" | grep -qiE \
  'git\s+push\b.*(--force|-f)\b.*(main|master)\b' \
  || printf '%s' "$CMD" | grep -qiE \
  'git\s+push\b.*(main|master)\b.*(--force|-f)\b'; then
  block "git push --force lên main/master bị chặn — dùng --force-with-lease hoặc hỏi team."
fi

if printf '%s' "$CMD" | grep -qE 'git\s+reset\s+--hard\s+(HEAD\^{2,}|HEAD~[2-9]|[0-9a-f]{7,40})'; then
  block "git reset --hard nhiều commit bị chặn — dùng git revert thay thế."
fi

if printf '%s' "$CMD" | grep -qiE '\b(DROP\s+(DATABASE|SCHEMA|TABLE)|TRUNCATE\s+TABLE)\b'; then
  block "Lệnh SQL phá hủy schema/dữ liệu bị chặn. Chạy thủ công trong client nếu chắc chắn."
fi

if printf '%s' "$CMD" | grep -qE 'chmod\s+(-R\s+)?777\s+(/etc|/usr|/var|/bin|/boot|~|/root|\$HOME)'; then
  block "chmod 777 trên thư mục hệ thống/home bị chặn."
fi

exit 0
