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
- model-downgrade: auto | never             # áp cho G4 + G5
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
- **Story lớn** (ngược lại, hoặc `qc-design: always-mapreduce`) → map/reduce như cũ. Không còn bước `qc-leader` merge: main tự ghép `tests/README.md` từ stub + `coverageGaps` + JSON của designer (xem `qc-mapreduce.md`).

## G4 — model theo lần gọi (Claude Code)

Agent tool nhận tham số `model` để ghi đè model mặc định của agent cho **một lần gọi** — không sửa định nghĩa agent. Override qua profile: `model-downgrade: auto | never` (mục `## Pipeline`; `never` = luôn dùng model mặc định).

- **`qc-executor` → `haiku`** cho lần chạy đầu và các lần re-run: việc chính là chạy lệnh test từ profile và đọc kết quả. Nếu lần chạy trả `failures` mà phần chẩn đoán không rõ nguyên nhân (message mơ hồ, nghi lỗi môi trường) → lần re-run sau dùng model mặc định.
- **`reviewer` → `sonnet`** khi diff nhỏ: tổng ≤ ~150 dòng đổi **và** ≤ 5 file **và** G1 không thấy vùng nhạy cảm. Ngược lại giữ model mặc định. Chế độ `verify` (re-review sau fix) luôn có thể dùng `sonnet`.
- **`security-auditor` chế độ `verify` → `sonnet`** (chỉ kiểm lại finding cũ). Lần audit đầu giữ model mặc định.
- **`chronicler` → `haiku`** khi G2 quyết định chạy và `filesChanged` ≤ 5 file (đồng bộ vài đoạn README/docs/CHANGELOG từ diff nhỏ); diff lớn hơn giữ model mặc định.
- Ghi model đã dùng cho mỗi agent vào mục `## Gating` của report.

Trong Codex: bỏ qua G4 và G5, chọn model theo `.codex-plugin/agent-models.toml` như cũ.
Trong DeepSeek harness: bỏ qua G4 và G5 (tên `haiku`/`sonnet` không tồn tại), chọn model theo `.deepseek-plugin/agent-models.toml`; việc nhẹ (`qc-executor`, review diff nhỏ, verify) dùng `deepseek-chat`.

## G5 — model theo độ lớn việc (agent lập kế hoạch)

Cùng cơ chế tham số `model` như G4, áp cho các agent **lập kế hoạch** — nơi model đắt nhất đang chạy ở mọi story/task dù việc nhỏ. Tắt bằng `model-downgrade: never`. Chỉ dùng số liệu rẻ để quyết định, không spawn agent để phân loại.

**Tier S / M / L**

- **Story** — N = số mục Functional requirements + Acceptance trong `requirement.md`. *Tín hiệu nặng*: (a) đổi hợp đồng/schema dùng chung theo lockstep của profile; (b) tích hợp hệ thống ngoài mới; (c) NFR nặng (bảo mật/phân quyền, hiệu năng, nhất quán dữ liệu, đồng thời); (d) đụng ≥ 3 project.
  - **S**: N ≤ 8 và không có tín hiệu nặng. **L**: N ≥ 20, hoặc ≥ 2 tín hiệu nặng. **M**: còn lại.
  - Tính **trước ADR** (cho `architect`) chỉ từ requirement; tính lại **sau ADR** (cho `dev-leader`, `qc-leader`) với số project/lockstep thật trong "Impacted artifacts" của ADR. Tier S sau ADR chính là "story nhỏ" của G3.
- **Task** (cho `task-planner`) — **S** nếu là fixbug, hoặc mô tả ngắn (≤ ~15 dòng) với scope 1 project/vài file rõ và không có Open question, hoặc ticket do `log-triage` tạo (có marker `[bug-sig:` — đã có evidence + suspectedFiles). Còn lại **M**.

**Bảng model** (ô "mặc định" = không truyền `model`, dùng model trong định nghĩa agent):

| Agent | S | M | L |
|---|---|---|---|
| `architect` | `sonnet` | `opus` | mặc định (fable) |
| `dev-leader` | `sonnet` | mặc định (opus) | mặc định (opus) |
| `qc-leader` enumerate | (G3 đã bỏ qua) | `sonnet` | mặc định (opus) |
| `task-planner` | `sonnet` | mặc định (opus) | — (task vượt tầm luồng nhẹ → nêu ở Open questions) |

`dev-leader` không hạ ở tier M vì `touchesFiles` thiếu sót có thể làm hai dev sửa chồng một file.

**Lưới an toàn — hạ model không được làm tụt chất lượng**

- **Người vẫn duyệt** ADR/plan ở gate trước mọi bước build: kế hoạch yếu bị bắt ở đó, chưa tốn tiền build.
- **Chạy lại sau góp ý của người → nâng một bậc** so với tier đã tính (S→M, M→L): `architect` chạy lại ở GATE, `task-planner` chế độ cập nhật khi reopen/revision ở Validate. Lần đầu bằng model rẻ chưa đạt thì lần sau không dùng lại model đó.
- Ngoại lệ **rẻ hơn**: `task-planner` chế độ cập nhật ở Bước 2 của poll (chỉ fold câu trả lời Open question của người vào plan đã duyệt) luôn dùng `sonnet` — việc cơ học.
- Tóm tắt gate ghi **tier + model đã dùng** để người biết ADR/plan do model nào lập; thấy yếu thì yêu cầu chạy lại.
- Ghi `tier` và model từng agent vào mục `## Gating` của report.
