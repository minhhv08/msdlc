---
name: tracking
description: >-
  Đồng bộ trạng thái ticket trên board ngoài (Jira/Asana/Linear/Monday) với tiến độ pipeline msdlc — chuyển cột ticket tại các mốc (todo/planning/validate/approved/in-progress/review) và comment kết quả với prefix `[Claude]`. Được các skill pipeline (`spec`/`deliver`/`deliver-auto`) gọi TỰ ĐỘNG tại mỗi mốc; cũng dùng TAY khi cần re-sync một story. LUÔN dùng skill này khi cần "đồng bộ status ticket", "chuyển cột board", "cập nhật Jira/Asana theo story", hoặc khi một bước pipeline vừa xong và ticket cần đổi cột. KHÔNG tự chuyển Done — Done luôn do người.
---

# msdlc:tracking — Đồng bộ trạng thái story ↔ board ngoài

Skill này là **nơi duy nhất** chứa logic đồng bộ tracker của msdlc. Các skill pipeline chỉ gọi tới đây; mọi quyết định "có sync hay không / sync sang cột nào" đều nằm ở một chỗ. Nhờ vậy: **không cấu hình tracker = pipeline chạy y như cũ**, đảm bảo tại một điểm.

**Input:** `id` + `target-phase` + `kind` (tùy chọn). `target-phase` ∈ `todo | planning | validate | approved | in-progress | review`. `kind` ∈ `story | task`, **mặc định `story`**.
Ví dụ: `msdlc:tracking 001 review` (luồng thủ công, story) · `msdlc:tracking PROJ-123 validate task` (luồng board nhẹ). Nếu thiếu id/phase → hỏi user.

**Hai convention artifact theo `kind`** (chỉ khác nhau ở 2 điểm: nơi lấy ticket & nguồn nội dung comment; mọi logic resolve-cột/transition/non-fatal/never-Done bên dưới dùng chung):
- `kind=story` (mặc định — luồng thủ công `/spec`+`/deliver`+`deliver-auto`): artifact ở `.claude/stories/{id}/`, comment ở `validate` dùng `adr.md`, ở `review` dùng `report.md`. `id` là số thứ tự story (vd `001`).
- `kind=task` (luồng board nhẹ `tracking-poll`+`deliver-light`): artifact ở `.claude/tasks/{id}/`, comment ở `validate` dùng `plan.md`, ở `review` dùng `report.md`. `id` **chính là ID ticket board** (vd `PROJ-123`).

## Nguyên tắc bất biến

1. **No-op im lặng khi không đủ điều kiện.** Không có cấu hình tracker / story không gắn ticket / MCP chưa connect → **log một dòng rồi dừng**, KHÔNG lỗi, KHÔNG hỏi vặn. Đây là điều giữ tương thích ngược.
2. **KHÔNG BAO GIỜ tự chuyển sang Done/Closed/Completed** — kể cả khi được gọi với phase lạ. Done là quyền của người (giống lý do của gate ADR: output cần người verify).
3. **Detect từ chính tool, đừng đoán.** Ưu tiên override tên cột trong profile; nếu không có thì suy từ danh sách transitions thực tế của ticket.
4. **Không sửa định nghĩa agent, không đụng code sản phẩm.** Skill chỉ đọc artifact story + gọi MCP tool của tracker.
5. **Lỗi giữa chừng cũng là non-fatal.** Qua guard rồi mà transition/comment vẫn fail (MCP rớt kết nối, transition không hợp lệ, thiếu quyền) → bắt lỗi, log một dòng mô tả rồi kết thúc bình thường — KHÔNG throw, KHÔNG làm dừng skill/pipeline đang gọi tới. Sync là side-effect, không phải gate; board lệch một nhịp thì lượt sync sau (hoặc người) chỉnh lại.

## Bước 1 — Guard: có nên sync không?

Thực hiện tuần tự, gặp điều kiện fail nào thì **log một dòng và dừng ngay**:

1. Đọc mục `## Task tracker` trong `.claude/profile.md`.
   - Mục không tồn tại / rỗng / chưa điền tool + project → *"[tracking] Không có cấu hình tracker trong profile — bỏ qua sync."* → dừng.
2. **Xác định ticket theo `kind`:**
   - `kind=story` (mặc định): đọc `.claude/stories/{id}/requirement.md`, lấy trường `Ticket:` ở dòng header (`> Status: … · Ticket: <ID|URL>`). Không có ticket hoặc giá trị là `—`/trống → *"[tracking] Story {id} chưa gắn ticket — bỏ qua sync."* → dừng.
   - `kind=task`: **`{id}` CHÍNH LÀ ID ticket board** — ticket luôn tồn tại (đến từ board), KHÔNG đọc `requirement.md` và KHÔNG áp guard "chưa gắn ticket". Chỉ cần `{id}` không rỗng.
3. Xác định MCP connector theo profile (vd Jira→`Atlassian`, Asana→`Asana`, Linear→`Linear`, Monday→`monday`). Nếu connector chưa connect → *"[tracking] Connector <tên> chưa kết nối — bỏ qua sync (chạy được sau khi connect)."* → dừng. Không hỏi token/OAuth.

Qua hết Bước 1 nghĩa là: có tracker + có ticket + MCP sẵn sàng → tiếp tục.

## Bước 2 — Resolve tên cột đích

Từ `target-phase`, tìm tên status/cột thực tế trên board theo thứ tự:

1. **Override trong profile** (mục `## Task tracker`, ánh xạ phase→cột). Nếu có dòng cho phase này → dùng đúng tên đó.
2. **Detect theo keyword** từ danh sách transitions/statuses fetch được của ticket (case-insensitive, bỏ dấu). Ánh xạ phase → nhóm keyword:
   - `validate`, `review` → review-like: `review`, `qa`, `testing`, `verify`, `validate`, `staging`, `uat`
   - `in-progress` → in-progress: `progress`, `doing`, `wip`, `development`, `dev`, `đang làm`, `start`
   - `todo` → backlog/todo: `todo`, `to do`, `backlog`, `open`, `mới`
   - `planning` → planning-like: `planning`, `plan`, `design`, `grooming`. **Lưu ý:** với luồng board nhẹ (`kind=task`), `planning` là bước **claim/lock** (không còn cosmetic) — rất nên override tên cột này trong profile. Nếu board không có cột planning riêng → khuyến nghị chọn một cột "đang xử lý" làm nơi claim (không bỏ qua transition), để ticket thật sự rời cột intake và không bị session khác nhận lại.
   - `approved` → approved-like: `approved`, `ready`, `accepted`, `todo` (nếu board không có cột Approved riêng).
3. **Không match cột nào** → log *"[tracking] Không tìm thấy cột phù hợp cho phase '{phase}' trên board — để nguyên status, không đổi."* và bỏ qua transition (vẫn có thể comment ở Bước 3 nếu là mốc có comment).

Nếu nhiều cột cùng match và profile không override → chọn cột ưu tiên cao nhất theo thứ tự keyword ở trên, và ghi rõ trong log đã chọn cột nào.

## Bước 3 — Thực thi transition + comment

1. **Transition**: gọi MCP tool của tracker để chuyển ticket sang cột đã resolve. Nếu ticket đã ở đúng cột → bỏ qua transition (idempotent), vẫn tiếp tục phần comment nếu có.
2. **Comment** — chỉ ở hai mốc, nguồn nội dung theo `kind`:
   - `validate`:
     - `kind=story`: comment link tới `.claude/stories/{id}/adr.md` (hoặc tóm tắt ADR + open questions), báo "ADR sẵn sàng, chờ người duyệt".
     - `kind=task`: comment **plan chi tiết** đọc từ `.claude/tasks/{id}/plan.md` (Vấn đề / Phương án / Files sẽ đụng / Acceptance / Open questions) để user đọc và duyệt. Nếu tracker giới hạn độ dài comment → cắt gọn có chủ đích các mục chính, giữ full ở `plan.md`.
   - `review`: comment tóm tắt từ report (số task/subtask, trạng thái test, số finding security theo severity) + nhắc "cần người review rồi chuyển Done thủ công". Nguồn: `kind=story` → `.claude/stories/{id}/report.md`; `kind=task` → `.claude/tasks/{id}/report.md`.
   - Các phase khác (`todo`/`planning`/`approved`/`in-progress`): chỉ transition, **không** comment (tránh nhiễu ticket).
3. **Format comment**: prefix `[Claude]`, **ngôn ngữ theo ticket** (title/description tiếng Việt → comment tiếng Việt, tiếng Anh → tiếng Anh). Mặc định ngắn gọn (2–5 bullet), tập trung WHAT chứ không HOW. **Ngoại lệ:** comment plan ở `validate` với `kind=task` cần **chi tiết** (để user duyệt được trên board) — giữ đủ các mục chính của `plan.md`.

## Bước 4 — Báo lại

Log một dòng cho user: ticket đã chuyển từ cột nào sang cột nào (hoặc "giữ nguyên"), có comment hay không. Nếu là mốc `review`, nhắc rõ: **KHÔNG tự chuyển Done — chờ người review và đóng thủ công.**

## Ghi chú

- Skill này **tự chứa**: không phụ thuộc skill `task-tracker-handler` (nếu có ở môi trường), dù cùng triết lý (detect-from-tool, never-auto-Done). msdlc không được phụ thuộc file ngoài plugin.
- Bảng phase→cột ở đây là **nguồn sự thật** cho mọi lời gọi từ `spec`/`deliver`/`deliver-auto`/`tracking-poll`. Khi sửa mapping, sửa ở đây.
- **Hai convention artifact-root** (`stories/` cho `kind=story`, `tasks/` cho `kind=task`) chỉ ảnh hưởng hai điểm: xác định ticket (Bước 1.2) và nguồn nội dung comment (Bước 3.2). Toàn bộ resolve-cột/transition/non-fatal/never-Done dùng chung — không fork. Lời gọi 2 tham số cũ (không có `kind`) = `story`, hành xử y hệt trước.
- Chi tiết cách fetch/transition/comment cho từng tool khác nhau — suy từ schema MCP tool của connector tương ứng; không hardcode field.
