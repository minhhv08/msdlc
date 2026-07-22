---
description: Quét board ngoài một lượt và tự khởi động luồng NHẸ của msdlc cho các ticket đang chờ — nhận ticket ở cột intake (claim: Todo→planning), phân tích + comment plan chờ duyệt (dừng ở Validate); ticket đã Approved thì build gọn (chuyển in-progress TRƯỚC khi làm) rồi Review. Dùng cùng /loop hoặc schedule để chạy định kỳ.
allowed-tools: Read, Write, Glob, Grep, Task, Skill
---

Bạn đang chạy **một lượt poll** của msdlc theo **luồng NHẸ** (dành cho task board là feat/fixbug nhỏ): quét board ngoài, tự *khởi động* luồng cho các ticket đang chờ. Lệnh này chạy **đúng một lượt rồi dừng** — việc lặp là do harness (`/loop <interval> /msdlc:tracking-poll` hoặc `schedule` cron), KHÔNG tự chế vòng lặp ở đây.

**Nguyên tắc cốt lõi — giữ cổng duyệt:** máy KHÔNG BAO GIỜ tự vượt gate. Cột board CHÍNH LÀ cổng: poll nhận ticket, comment **plan chi tiết** rồi đẩy tới `Validate` và DỪNG; chỉ ticket đã được **người** kéo sang cột Approved mới được tự build. Không bao giờ tự chuyển Done.

**Luồng nhẹ khác luồng thủ công thế nào:** đường board dùng `.claude/tasks/{taskid}/` (taskid = ID ticket, vd `PROJ-123`), agent `task-planner` (không phải `architect`), plan chi tiết ở `plan.md` (không phải ADR), và build gọn bằng skill `deliver-light` (không phải `deliver-auto`). Luồng thủ công `/spec`+`/deliver` (dùng `.claude/stories/` + ADR + `deliver-auto`) không liên quan tới lệnh này.

**"Chuyển trạng thái TRƯỚC khi làm":** mỗi mốc, đổi cột board để phản ánh việc-sắp-làm rồi mới làm — claim `planning` trước khi phân tích, `in-progress` trước khi build. Cột board luôn phản ánh trạng thái thật và đóng vai khóa nhẹ.

## Bước 0 — Guard

1. Đọc mục `## Task tracker` trong `.claude/profile.md`.
   - Không có mục / chưa điền tool + project → báo *"Chưa cấu hình tracker trong profile — không có gì để poll. Chạy `/msdlc:init` để cấu hình."* và **dừng**.
   - **Cờ bật poll** chưa bật (mặc định tắt) → báo *"Poll đang tắt (opt-in). Bật cờ poll trong `.claude/profile.md` mục Task tracker để dùng."* và **dừng**.
2. Xác định connector MCP + cột intake (vd `Todo`) + cột build-trigger (vd `Approved`) + tên cột `planning`/`validate`/`in-progress`/`review` từ profile. Connector chưa connect → báo và dừng (không hỏi token/OAuth).

## Bước R — Resume các task dở dang (chạy ĐẦU mỗi lượt)

Luồng nhẹ chỉ quét hai cột intake+Approved, nên ticket kẹt ở cột trung gian (`planning`/`in-progress`) do lượt trước fail sẽ bị bỏ rơi nếu không nhặt lại. Quét `.claude/tasks/*/`, với **mỗi** task fetch cột hiện tại của ticket rồi rẽ nhánh (xử lý tuần tự):

- Có thư mục nhưng **không có `plan.md`** (task-planner chết giữa chừng) → **resume phân tích**: gọi lại Agent `task-planner` cho `{taskid}` → ghi `plan.md`. Giữ nguyên `{taskid}`, không claim lại.
- Có `plan.md`, ticket vẫn ở **`planning`** (comment/transition dở) → gọi skill **`msdlc:tracking {taskid} validate task`** (comment plan + đẩy sang `Validate`).
- Có `plan.md`, ticket ở **`in-progress`**, **không có `report.md`** (build chết giữa chừng) → **resume build**: gọi skill **`deliver-light {taskid}`** (các sub-agent idempotent) → ghi `report.md` → gọi **`msdlc:tracking {taskid} review task`**.
- Có **`report.md`** → xong → bỏ qua.

## Bước 1 — Nhận ticket ở cột intake → Validate (giữ gate, KHÔNG build)

Fetch các ticket ở **cột intake** (theo profile). Với **mỗi** ticket (xử lý tuần tự):

1. **Idempotent/claim check** — nếu `.claude/tasks/{taskid}/` đã tồn tại → task này đã được nhận (Bước R lo phần dở dang) → bỏ qua ở đây.
2. **Claim (chuyển trạng thái TRƯỚC):** gọi skill **`msdlc:tracking {taskid} planning task`** để chuyển ticket `Todo → planning`. Đây là hành động nhận ticket — sau khi rời cột intake, lượt poll khác sẽ không thấy ticket này nữa (khóa nhẹ, đảm bảo chỉ một session xử lý).
3. **Ghi dấu claim NGAY** trước khi phân tích dài: tạo `.claude/tasks/{taskid}/claim.md` (ghi ngày + nguồn `msdlc:tracking-poll`). Đây là guard local chống hai tick loop chồng nhau trên cùng máy. *(Tùy chọn tăng an toàn cross-máy: comment mềm `[Claude] claiming {taskid} <ngày>` lên ticket rồi re-fetch; nếu thấy claim sớm hơn của session khác → back off, bỏ ticket.)*
4. **Phân tích:** gọi **Agent `task-planner`** cho `{taskid}`, truyền **title + description + link ticket** → agent dò codebase và ghi `.claude/tasks/{taskid}/plan.md`.
5. **Comment plan + đẩy chờ duyệt:** gọi skill **`msdlc:tracking {taskid} validate task`** → chuyển ticket sang `Validate` + comment **plan chi tiết** (từ `plan.md`) với prefix `[Claude]` để user đọc/duyệt.
6. **DỪNG** với ticket này. **Tuyệt đối không build.** Ticket ở `Validate`, chờ người kéo sang `Approved`.

## Bước 2 — Ticket Approved → build gọn → Review

Fetch các ticket ở **cột build-trigger** (`Approved`). Với **mỗi** ticket (tuần tự):

1. Tìm `.claude/tasks/{taskid}/`. Không có thư mục hoặc **không có `plan.md`** (ticket tạo tay/chưa qua Bước 1) → log và bỏ qua; KHÔNG tự phân tích/plan ở đây (poll chỉ build task đã có plan duyệt).
2. **Idempotent:** đã có `report.md` → bỏ qua, không build lại.
3. **Chuyển trạng thái TRƯỚC khi làm:** gọi skill **`msdlc:tracking {taskid} in-progress task`** để chuyển `Approved → in-progress` — TRƯỚC khi build.
4. Gọi skill **`deliver-light {taskid}`** (build gọn: implement song song theo subtask file-disjoint → reviewer → qc-executor+security → chronicler). Skill tự ghi `.claude/tasks/{taskid}/report.md`. **Không hỏi gate** — gate đã được người vượt bằng thao tác kéo thẻ sang Approved.
5. Xong → gọi skill **`msdlc:tracking {taskid} review task`** để chuyển sang `Review` + comment tóm tắt kết quả.
6. Nếu `deliver-light` fail giữa chừng (dev/QC lỗi không tự fix nổi trong ngân sách) → log rõ task/ticket bị kẹt + lý do, **để nguyên ticket ở cột hiện tại** cho người xử lý; không retry trong cùng lượt và không tự kéo ticket lùi cột (Bước R lượt sau sẽ nhặt lại nếu còn dở).

**An toàn:** xử lý **tuần tự** từng ticket (deliver-light cấm git worktree → mọi thay đổi trên một working tree chung; build song song nhiều task sẽ đè nhau). Chạy **một poller cho mỗi board** — nhiều máy cùng poll một board không được phối hợp bằng khóa mạnh (tracker thiếu compare-and-swap).

## Bước 3 — Không đụng phần còn lại

KHÔNG fetch/không đổi ticket ở các cột `Validate` / `Review` / `Done` — đó là phần chờ người. Poll chỉ kích hoạt ở hai cột intake và Approved (cộng Bước R nhặt task dở ở `planning`/`in-progress`).

## Bước 4 — Tóm tắt lượt poll

Báo cho user (một khối ngắn): lượt này Bước R nhặt lại task nào; nhận bao nhiêu ticket ở intake, taskid nào được claim + đẩy sang Validate; task nào được build sang Review; ticket nào bị bỏ qua và lý do. Không có ticket nào cần xử lý → báo *"Không có ticket cần xử lý lượt này."*

## Ghi chú vận hành

- Chạy định kỳ: `/loop 10m /msdlc:tracking-poll` (interval, cần phiên đang mở) hoặc tạo scheduled cloud agent qua skill `schedule` (chạy nền kể cả tắt máy). Chọn theo nhu cầu; xem README.
- Mỗi lượt idempotent → chạy lại nhiều lần an toàn: trạng thái nằm ở cột board + sự tồn tại của `plan.md`/`report.md` trong `.claude/tasks/{taskid}/`.
- Cột `planning` giờ là bước **claim/lock**, không còn cosmetic — nên override tên cột `planning` trong profile để tránh detect-keyword đoán trượt.
