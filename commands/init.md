---
description: Cấu hình project hiện tại để dùng plugin msdlc — copy agent-memory.md + tạo profile.md rồi giúp điền.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
---

Bạn đang giúp user **khởi tạo cấu hình msdlc cho project hiện tại**. Plugin không tự mang cấu hình theo, nên hai file phải tồn tại trong `.claude/` của project: `.claude/shared/agent-memory.md` (bản dùng chung) và `.claude/profile.md` (đặc thù project — agent đọc lúc chạy).

## Bước 1 — Copy file từ plugin vào project

Chạy đúng lệnh sau (dùng biến `$CLAUDE_PLUGIN_ROOT` trỏ tới gốc plugin):

```bash
mkdir -p .claude/shared
cp "$CLAUDE_PLUGIN_ROOT/shared/agent-memory.md" .claude/shared/agent-memory.md
if [ -f .claude/profile.md ]; then
  echo "ĐÃ CÓ .claude/profile.md — KHÔNG ghi đè"
else
  cp "$CLAUDE_PLUGIN_ROOT/shared/profile.template.md" .claude/profile.md
  echo "Đã tạo .claude/profile.md từ template"
fi
```

- Nếu `$CLAUDE_PLUGIN_ROOT` rỗng (không chạy trong ngữ cảnh plugin), hỏi user đường dẫn cài plugin rồi copy thủ công.
- Nếu `profile.md` đã tồn tại → KHÔNG đè; chuyển sang Bước 2 để rà soát/điền bổ sung.

## Bước 2 — Dò stack và điền `profile.md`

Đừng để template rỗng. Tự dò codebase rồi điền `.claude/profile.md`:

1. Tìm dấu hiệu stack: `pom.xml`/`build.gradle` (Java), `composer.json`/`artisan` (PHP/Laravel), `package.json` (Node/JS, đọc `scripts`), `pyproject.toml`/`requirements.txt` (Python), `go.mod` (Go), `Cargo.toml` (Rust)… Dùng Glob/Grep/Read.
2. Từ đó suy ra cho từng mục của profile:
   - **Projects & stack** — mỗi thư mục project + ngôn ngữ/framework/version + port (nếu thấy).
   - **Đường dẫn quy ước** — giữ mặc định `.claude/stories/{id}/...`, `docs/`; chỉnh nếu repo dùng khác.
   - **Lệnh build/test/run** — lấy từ `scripts` trong package.json, từ Maven/Gradle/Composer/Makefile… Ghi lệnh test 1 file/method nếu suy được.
   - **Hạ tầng local** — dò `docker-compose.yml`/`.env.example` cho DB/cache + cổng.
   - **Hợp đồng lockstep** — chỉ điền nếu repo thực sự có ràng buộc liên-project (schema dùng chung, registry phải đồng bộ, cache cần evict). Không bịa; để trống nếu là dự án đơn lẻ.
   - **Quy tắc commit** — nếu có `CLAUDE.md`/`CONTRIBUTING.md` nêu quy tắc thì trích; nếu không, để trống.
3. Với mục không chắc → ghi `<!-- cần xác nhận: ... -->` và HỎI user thay vì bịa.

## Bước 3 — Hậu kiểm

- Đề xuất thêm `.claude/agent-memory-local/` vào `.gitignore` (memory cục bộ, không nên commit).
- Tóm tắt cho user: đã copy file gì, đã điền mục nào của profile, mục nào còn cần user xác nhận.
- Nhắc: chạy thử một mắt xích (`/spec`, hoặc gọi `architect`/`planner`) để xác nhận agent đọc được profile.
