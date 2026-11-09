# Gating — chỉ gọi agent khi cần (tiết kiệm token)

Dùng chung cho `deliver-story` và `deliver-task`. Main tự quyết định bằng dữ liệu đã có trong tay (`filesChanged`, `followUps`, requirement/ADR/plan, một lệnh grep rẻ) — **không spawn agent chỉ để quyết định**.

## Override theo dự án

Mục `## Pipeline` trong `.claude/msdlc.md` (dự án cũ chưa có file này → mục cùng tên trong `.claude/profile.md`) (không có mục/dòng nào → `auto`):

```markdown
## Pipeline
- security-audit: auto | always | never
- docs-sync: auto | always | never
- qc-design: auto | always-mapreduce        # chỉ deliver-story
- security-sensitive-paths: <glob/đường dẫn, tuỳ chọn>
- model-downgrade: auto | never
```

`always` = hành vi cũ (luôn chạy). Mọi lần bỏ qua đều ghi một dòng `skipped (lý do)` vào report — không bỏ im lặng.

## G1 — security-auditor

Quyết định ở **đầu bước review** (đã có `filesChanged` gom từ các wave). `auto` → **chạy** khi có ít nhất một dấu hiệu:

- `filesChanged` khớp `security-sensitive-paths` của profile (nếu có khai báo).
- Diff/tên file chạm: xác thực/phiên/phân quyền/role; crypto/token/secret/key; upload/download/đường dẫn file; endpoint/route/handler mới hoặc đổi chữ ký; truy vấn DB thô hoặc dựng câu lệnh động; parse/deserialize dữ liệu từ bên ngoài; gọi HTTP ra ngoài theo URL đầu vào; cấu hình bảo mật (CORS, header, cookie); file dependency/lockfile. Nhận diện theo tên + nội dung diff, không giả định stack.
- requirement/ADR/plan nhắc tới các chủ đề trên, hoặc `.claude/rules/security.md` có rule `MUST` mà phạm vi (scope) khớp file bị đổi.

Không chạy → gọi reviewer với cờ **`securityLite: true`** (reviewer kiêm checklist bảo mật nhanh, finding nghiêm trọng vào `blockingFindings`). Phase QC chỉ còn `qc-executor`; ngân sách auto-fix giữ nguyên.

## G2 — chronicler

Quyết định sau khi QC/security xong. `auto` → **chạy** khi có ít nhất một dấu hiệu:

- `filesChanged` chạm public API/contract (route, schema, interface/hàm export), cấu hình/env/CLI flag, file build/dependency, script setup/run.
- Grep tên file/symbol chính bị đổi trong `README*` và `docs/` có kết quả (tài liệu đang nhắc tới thứ vừa đổi).
- `followUps` của dev có mục về docs, hoặc mục "Impacted artifacts" của ADR / "Files sẽ tạo/sửa" của plan liệt kê tài liệu.
- Rule DoD trong `.claude/rules/` bắt buộc cập nhật docs/CHANGELOG cho mọi thay đổi.

Không chạy → report ghi `docs: skipped (không có thay đổi ảnh hưởng tài liệu)`.

## G3 — thiết kế test (chỉ `deliver-story`)

Quyết định **trước Phase 1**, chỉ từ `requirement.md` + `adr.md`. `auto`:

- **Story nhỏ** — mục Functional requirements + Acceptance của requirement cộng lại ≤ 8 mục **và** ADR chỉ chạm ≤ 2 project → **bỏ `qc-leader`**. Ở Wave 1 phát **một `qc-designer` chế độ full**, chỉ định file output `.claude/stories/{id}/tests/README.md` (case + Traceability Matrix + Coverage & Gaps trong một file); trả `{ file, casesWritten, gaps, followUps }`.
- **Story lớn** (ngược lại, hoặc `qc-design: always-mapreduce`) → map/reduce như cũ. Nếu `qc-leader` enumerate trả **đúng 1 bucket** → không gọi `qc-leader` merge: main tự ghi `tests/README.md` gọn (bảng `id → source` từ stub + `coverageGaps`).

## G4 — model theo lần gọi (Claude Code)

Agent tool nhận tham số `model` để ghi đè model mặc định của agent cho **một lần gọi** — không sửa định nghĩa agent. Override qua profile: `model-downgrade: auto | never` (mục `## Pipeline`; `never` = luôn dùng model mặc định).

- **`qc-executor` → `haiku`** cho lần chạy đầu và các lần re-run: việc chính là chạy lệnh test từ profile và đọc kết quả. Nếu lần chạy trả `failures` mà phần chẩn đoán không rõ nguyên nhân (message mơ hồ, nghi lỗi môi trường) → lần re-run sau dùng model mặc định.
- **`reviewer` → `sonnet`** khi diff nhỏ: tổng ≤ ~150 dòng đổi **và** ≤ 5 file **và** G1 không thấy vùng nhạy cảm. Ngược lại giữ model mặc định. Chế độ `verify` (re-review sau fix) luôn có thể dùng `sonnet`.
- **`security-auditor` chế độ `verify` → `sonnet`** (chỉ kiểm lại finding cũ). Lần audit đầu giữ model mặc định.
- Ghi model đã dùng cho mỗi agent vào mục `## Gating` của report.

Trong Codex: bỏ qua G4, chọn model theo `.codex-plugin/agent-models.toml` như cũ.
