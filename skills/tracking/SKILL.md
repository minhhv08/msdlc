---
name: tracking
description: >-
  Đồng bộ trạng thái ticket trên board ngoài (Jira/Asana/Linear/Monday) với tiến độ pipeline msdlc — chuyển cột ticket tại các mốc (todo/planning/validate/approved/in-progress/review) và comment kết quả với prefix `[Claude]`. Được các skill pipeline (`spec`/`deliver`/`deliver-auto`) gọi TỰ ĐỘNG tại mỗi mốc; cũng dùng TAY khi cần re-sync một story. LUÔN dùng skill này khi cần "đồng bộ status ticket", "chuyển cột board", "cập nhật Jira/Asana theo story", hoặc khi một bước pipeline vừa xong và ticket cần đổi cột. KHÔNG tự chuyển Done — Done luôn do người.
---

# msdlc:tracking — Đồng bộ trạng thái story ↔ board ngoài

Skill này là **nơi duy nhất** chứa logic đồng bộ tracker của msdlc. Các skill pipeline chỉ gọi tới đây; mọi quyết định "có sync hay không / sync sang cột nào" đều nằm ở một chỗ. Nhờ vậy: **không cấu hình tracker = pipeline chạy y như cũ**, đảm bảo tại một điểm.

**Input:** `story-id` + `target-phase`. `target-phase` ∈ `todo | planning | validate | approved | in-progress | review`.
Ví dụ: `msdlc:tracking 001 review`. Nếu thiếu tham số → hỏi user story id và phase.

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
2. Đọc `.claude/stories/{id}/requirement.md`, lấy trường `Ticket:` ở dòng header (`> Status: … · Ticket: <ID|URL>`).
   - Không có ticket hoặc giá trị là `—`/trống → *"[tracking] Story {id} chưa gắn ticket — bỏ qua sync."* → dừng.
3. Xác định MCP connector theo profile (vd Jira→`Atlassian`, Asana→`Asana`, Linear→`Linear`, Monday→`monday`). Nếu connector chưa connect → *"[tracking] Connector <tên> chưa kết nối — bỏ qua sync (chạy được sau khi connect)."* → dừng. Không hỏi token/OAuth.

Qua hết Bước 1 nghĩa là: có tracker + có ticket + MCP sẵn sàng → tiếp tục.

## Bước 2 — Resolve tên cột đích

Từ `target-phase`, tìm tên status/cột thực tế trên board theo thứ tự:

1. **Override trong profile** (mục `## Task tracker`, ánh xạ phase→cột). Nếu có dòng cho phase này → dùng đúng tên đó.
2. **Detect theo keyword** từ danh sách transitions/statuses fetch được của ticket (case-insensitive, bỏ dấu). Ánh xạ phase → nhóm keyword:
   - `validate`, `review` → review-like: `review`, `qa`, `testing`, `verify`, `validate`, `staging`, `uat`
   - `in-progress` → in-progress: `progress`, `doing`, `wip`, `development`, `dev`, `đang làm`, `start`
   - `todo` → backlog/todo: `todo`, `to do`, `backlog`, `open`, `mới`
   - `planning` → planning-like: `planning`, `plan`, `design`, `grooming`; nếu không có cột planning riêng → giữ ở in-progress-like gần nhất hoặc bỏ qua transition (chỉ comment nếu cần).
   - `approved` → approved-like: `approved`, `ready`, `accepted`, `todo` (nếu board không có cột Approved riêng).
3. **Không match cột nào** → log *"[tracking] Không tìm thấy cột phù hợp cho phase '{phase}' trên board — để nguyên status, không đổi."* và bỏ qua transition (vẫn có thể comment ở Bước 3 nếu là mốc có comment).

Nếu nhiều cột cùng match và profile không override → chọn cột ưu tiên cao nhất theo thứ tự keyword ở trên, và ghi rõ trong log đã chọn cột nào.

## Bước 3 — Thực thi transition + comment

1. **Transition**: gọi MCP tool của tracker để chuyển ticket sang cột đã resolve. Nếu ticket đã ở đúng cột → bỏ qua transition (idempotent), vẫn tiếp tục phần comment nếu có.
2. **Comment** — chỉ ở hai mốc:
   - `validate`: comment link tới `.claude/stories/{id}/adr.md` (hoặc tóm tắt ADR + open questions), báo "ADR sẵn sàng, chờ người duyệt".
   - `review`: comment tóm tắt từ `.claude/stories/{id}/report.md` (số task, trạng thái test, số finding security theo severity) + nhắc "cần người review rồi chuyển Done thủ công".
   - Các phase khác (`todo`/`planning`/`approved`/`in-progress`): chỉ transition, **không** comment (tránh nhiễu ticket).
3. **Format comment**: prefix `[Claude]`, **ngôn ngữ theo ticket** (title/description tiếng Việt → comment tiếng Việt, tiếng Anh → tiếng Anh), ngắn gọn (2–5 bullet), tập trung WHAT chứ không HOW.

## Bước 4 — Báo lại

Log một dòng cho user: ticket đã chuyển từ cột nào sang cột nào (hoặc "giữ nguyên"), có comment hay không. Nếu là mốc `review`, nhắc rõ: **KHÔNG tự chuyển Done — chờ người review và đóng thủ công.**

## Ghi chú

- Skill này **tự chứa**: không phụ thuộc skill `task-tracker-handler` (nếu có ở môi trường), dù cùng triết lý (detect-from-tool, never-auto-Done). msdlc không được phụ thuộc file ngoài plugin.
- Bảng phase→cột ở đây là **nguồn sự thật** cho mọi lời gọi từ `spec`/`deliver`/`deliver-auto`/`tracking-poll`. Khi sửa mapping, sửa ở đây.
- Chi tiết cách fetch/transition/comment cho từng tool khác nhau — suy từ schema MCP tool của connector tương ứng; không hardcode field.
