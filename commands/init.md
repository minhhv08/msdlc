---
description: Cấu hình project hiện tại để dùng plugin msdlc — copy agent-memory.md + tạo profile.md rồi giúp điền.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
---

Bạn đang giúp user **khởi tạo cấu hình msdlc cho project hiện tại**. Plugin không tự mang cấu hình theo, nên các file sau phải tồn tại trong `.claude/` của project: `.claude/shared/agent-memory.md` (bản dùng chung), `.claude/profile.md` (đặc thù project — *facts*: stack/lệnh/path/lockstep) và `.claude/rules/` (rule theo project — *normative*: convention/kiến trúc/security/DoD/commit). Agent đọc cả ba lúc chạy.

## Bước 1 — Copy file từ plugin vào project

Chạy đúng lệnh sau (dùng biến `$CLAUDE_PLUGIN_ROOT` trỏ tới gốc plugin):

```bash
mkdir -p .claude/shared .claude/rules
cp "$CLAUDE_PLUGIN_ROOT/shared/agent-memory.md" .claude/shared/agent-memory.md
if [ -f .claude/profile.md ]; then
  echo "ĐÃ CÓ .claude/profile.md — KHÔNG ghi đè"
else
  cp "$CLAUDE_PLUGIN_ROOT/shared/profile.template.md" .claude/profile.md
  echo "Đã tạo .claude/profile.md từ template"
fi
# Copy template rules — KHÔNG ghi đè file đã có (giữ rule user đã điền)
for f in global backend frontend security testing; do
  if [ -f ".claude/rules/$f.md" ]; then
    echo "ĐÃ CÓ .claude/rules/$f.md — KHÔNG ghi đè"
  else
    cp "$CLAUDE_PLUGIN_ROOT/shared/rules/$f.md" ".claude/rules/$f.md"
    echo "Đã tạo .claude/rules/$f.md từ template"
  fi
done
```

- Nếu `$CLAUDE_PLUGIN_ROOT` rỗng (không chạy trong ngữ cảnh plugin), hỏi user đường dẫn cài plugin rồi copy thủ công.
- Nếu `profile.md` / file rule nào đã tồn tại → KHÔNG đè; chuyển sang Bước 2 để rà soát/điền bổ sung.

## Bước 2 — Dò stack và điền `profile.md`

Đừng để template rỗng. Tự dò codebase rồi điền `.claude/profile.md`:

1. Tìm dấu hiệu stack: `pom.xml`/`build.gradle` (Java), `composer.json`/`artisan` (PHP/Laravel), `package.json` (Node/JS, đọc `scripts`), `pyproject.toml`/`requirements.txt` (Python), `go.mod` (Go), `Cargo.toml` (Rust)… Dùng Glob/Grep/Read.
2. Từ đó suy ra cho từng mục của profile:
   - **Projects & stack** — mỗi thư mục project + ngôn ngữ/framework/version + port (nếu thấy).
   - **Đường dẫn quy ước** — giữ mặc định `.claude/stories/{id}/...`, `docs/`; chỉnh nếu repo dùng khác.
   - **Lệnh build/test/run** — lấy từ `scripts` trong package.json, từ Maven/Gradle/Composer/Makefile… Ghi lệnh test 1 file/method nếu suy được.
   - **Hạ tầng local** — dò `docker-compose.yml`/`.env.example` cho DB/cache + cổng.
   - **Hợp đồng lockstep** — chỉ điền nếu repo thực sự có ràng buộc liên-project (schema dùng chung, registry phải đồng bộ, cache cần evict). Không bịa; để trống nếu là dự án đơn lẻ.
   - **Quy tắc commit** — không điền vào profile nữa; commit rule sống ở `.claude/rules/global.md` nhóm `## Commit` (xem Bước 2b).
3. Với mục không chắc → ghi `<!-- cần xác nhận: ... -->` và HỎI user thay vì bịa.

## Bước 2b — Auto-seed `.claude/rules/` từ config sẵn có

Đừng để rule rỗng nếu repo đã có nguồn convention. Dò và **TRÍCH** (không hardcode, không bịa) thành rule nháp; mỗi rule seed gắn chú thích `<!-- seeded từ <nguồn>, cần xác nhận -->` để user duyệt:

1. `CLAUDE.md` / `CONTRIBUTING.md` → `global.md`: convention chung, kiến trúc bắt buộc/cấm, Definition-of-Done, quy tắc review, quy tắc commit (nhóm `## Commit`).
2. `.editorconfig` → `global.md` (`R-GLOBAL-*`): indent, charset, line ending nếu được nêu là bắt buộc.
3. Linter/formatter theo stack đã dò ở Bước 2:
   - eslint/prettier/stylelint → `frontend.md`
   - checkstyle/PMD/spotbugs (Java), phpcs/pint (PHP), ruff/black/flake8 (Python), golangci-lint (Go), clippy/rustfmt (Rust) → `backend.md`
4. Quy ước test (test runner, ngưỡng coverage nếu repo ép) → `testing.md`.
5. Ràng buộc bảo mật đã ghi ở đâu đó (CONTRIBUTING/security policy) → `security.md`.

Gắn `severity` hợp lý: thứ repo **ép/bắt buộc** (lint fail CI, policy) → `MUST`; thứ chỉ khuyến nghị → `SHOULD`. Nếu không tìm thấy nguồn nào cho một file → để bảng trống (agent sẽ suy từ code lân cận như cũ). Không bịa rule.

## Bước 3 — Hậu kiểm

- Đề xuất thêm `.claude/agent-memory-local/` vào `.gitignore` (memory cục bộ, không nên commit). **Lưu ý:** `.claude/rules/` và `.claude/profile.md` thì NÊN commit — đây là cấu hình dùng chung cho cả team.
- Tóm tắt cho user: đã copy file gì, đã điền mục nào của profile, rule nào được seed (kèm nguồn), mục/rule nào còn cần user xác nhận.
- Nhắc: chạy thử một mắt xích (`/spec`, hoặc gọi `architect`/`planner`) để xác nhận agent đọc được profile + rules.
