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
- Có `plan.md`, ticket ở **`in-progress`**, **không có `report.md`** (build chết giữa chừng) → **resume build**: (nếu git flow bật) gọi **`git-flow {taskid} start`** để về đúng nhánh task → gọi skill **`deliver-light {taskid}`** (các sub-agent idempotent) → ghi `report.md` → (nếu git flow bật) **`git-flow {taskid} finish`** → gọi **`msdlc:tracking {taskid} review task`**.
- Có **`report.md`** nhưng (git flow bật và) **chưa có dòng `> MR:`** (finish fail lượt trước) → **resume finish**: `git-flow {taskid} start` (về nhánh task) → `git-flow {taskid} finish` (push + MR + ghi `> MR:`) → `msdlc:tracking {taskid} review task`.
- Có **`report.md`** (và có `> MR:` nếu git flow bật) → xong → bỏ qua.

> Resume build/finish cũng chỉ làm cho **một** task mỗi lượt khi git flow bật (xem giới hạn một-build/lượt ở Bước 2). Xong task resume nào thì về base cho lượt sau.

## Bước 1 — Nhận ticket ở cột intake → Validate (giữ gate, KHÔNG build)

Fetch các ticket ở **cột intake** (theo profile). Với **mỗi** ticket (xử lý tuần tự), rẽ nhánh theo `.claude/tasks/{taskid}/` đã tồn tại chưa:

### 1a. Ticket MỚI (chưa có `.claude/tasks/{taskid}/`) — claim + plan lần đầu

1. **Claim (chuyển trạng thái TRƯỚC):** gọi skill **`msdlc:tracking {taskid} planning task`** để chuyển ticket `Todo → planning`. Đây là hành động nhận ticket — sau khi rời cột intake, lượt poll khác sẽ không thấy ticket này nữa (khóa nhẹ, đảm bảo chỉ một session xử lý).
2. **Ghi dấu claim NGAY** trước khi phân tích dài: tạo `.claude/tasks/{taskid}/claim.md` (ghi ngày + nguồn `msdlc:tracking-poll`). Guard local chống hai tick loop chồng nhau trên cùng máy. *(Tùy chọn tăng an toàn cross-máy: comment mềm `[Claude] claiming {taskid} <ngày>` rồi re-fetch; thấy claim sớm hơn của session khác → back off, bỏ ticket.)*
3. **Phân tích:** gọi **Agent `task-planner`** cho `{taskid}`, truyền **title + description + link ticket** → agent dò codebase và ghi `.claude/tasks/{taskid}/plan.md`.
4. **Comment plan + đẩy chờ duyệt:** gọi skill **`msdlc:tracking {taskid} validate task`** → chuyển ticket sang `Validate` + comment **plan chi tiết** (từ `plan.md`) với prefix `[Claude]` để user đọc/duyệt.
5. **DỪNG** với ticket này. **Tuyệt đối không build.** Ticket ở `Validate`, chờ người kéo sang `Approved`.

### 1b. Ticket bị KÉO NGƯỢC về Todo (đã có `.claude/tasks/{taskid}/`) — REVISION: cập nhật lại plan

Người xem plan chưa ưng, comment thêm yêu cầu/góp ý rồi kéo thẻ về `Todo` = **yêu cầu sửa plan**. Xử lý:

1. **Re-claim:** gọi `msdlc:tracking {taskid} planning task` (Todo → planning).
2. **Đọc comment ticket:** fetch **toàn bộ comment** của ticket qua connector MCP của tracker (như khi fetch cột). Gom các comment **của người** (không phải `[Claude]`) đăng **sau** comment plan gần nhất — đây là feedback/yêu cầu bổ sung.
3. **Cập nhật plan:** gọi **Agent `task-planner`** cho `{taskid}` ở **chế độ cập nhật** — truyền title + description + link ticket + **plan.md hiện có** + **các comment feedback** → agent sửa `.claude/tasks/{taskid}/plan.md` cho khớp (giữ phần còn đúng, sửa/thêm theo feedback, cập nhật Open questions).
4. **Comment plan mới + đẩy chờ duyệt:** `msdlc:tracking {taskid} validate task` (comment bản plan đã cập nhật + → `Validate`).
5. **DỪNG.** Chờ người duyệt lại.

> Nếu ticket đã có dir nhưng KHÔNG ở Todo (ví dụ vẫn ở planning do lượt trước dở) → không xử ở đây, để **Bước R** lo.

## Bước 2 — Ticket Approved → build gọn → Review

Fetch các ticket ở **cột build-trigger** (`Approved`). Bỏ qua ngay ticket không đủ điều kiện (không có `.claude/tasks/{taskid}/plan.md` → ticket tạo tay/chưa qua Bước 1 → log và bỏ qua; hoặc đã có `report.md` hợp lệ → đã build → bỏ qua).

**Giới hạn một-build/lượt (khi git flow bật):** chỉ build **đúng MỘT** ticket đủ điều kiện mỗi lượt poll rồi dừng leg này, để không juggle nhiều nhánh trên working tree chung. `/loop` sẽ xử các ticket còn lại ở lượt sau. **Khi git flow tắt:** giữ hành vi cũ — build **tuần tự** các ticket đủ điều kiện (mọi thay đổi trên một working tree chung, không nhánh/MR).

Với ticket được chọn:

1. **Chuyển trạng thái TRƯỚC khi làm:** gọi skill **`msdlc:tracking {taskid} in-progress task`** để chuyển `Approved → in-progress`.
2. **Đọc comment duyệt + cập nhật plan (BẮT BUỘC, trước khi build):** fetch **toàn bộ comment** của ticket qua connector MCP. Gom các comment **của người** (không phải `[Claude]`) đăng **sau** comment plan gần nhất — đây thường là **câu trả lời cho Open questions** và điều kiện duyệt.
   - **Có comment người mới** → gọi **Agent `task-planner`** ở **chế độ cập nhật** (truyền plan.md hiện có + các comment) để fold câu trả lời vào `.claude/tasks/{taskid}/plan.md` (resolve Open questions, chốt scope theo câu trả lời). **Không** đưa về Validate lại — người đã duyệt bằng cách kéo sang Approved kèm câu trả lời; build theo plan đã cập nhật.
   - **Không có comment người mới** → dùng plan.md như hiện có.
   - Nếu sau khi fold vẫn còn **Open question chặn** (chưa được trả lời, ảnh hưởng scope) → không đoán bừa: ghi rõ vào report + comment ở mốc review, build phần đã rõ (hoặc bỏ qua ticket nếu không thể build an toàn), KHÔNG tự bịa.
3. **(Git flow bật) Tạo nhánh TRƯỚC khi build:** gọi skill **`git-flow {taskid} start`** → tạo/switch nhánh task tách từ base. Nếu trả `abort`/`dirty` (không tạo được nhánh, hoặc tree bẩn do task khác chưa `finish`) → **log + bỏ qua ticket, KHÔNG build trên base** (để Bước R lượt sau xử lý phần dở của task đang giữ tree).
4. Gọi skill **`deliver-light {taskid}`** (build gọn: implement song song theo subtask file-disjoint → reviewer → qc-executor+security → chronicler). Skill tự ghi `.claude/tasks/{taskid}/report.md`. **Không hỏi gate** — gate đã được người vượt bằng thao tác kéo thẻ sang Approved.
5. **(Git flow bật) Hoàn tất git:** gọi skill **`git-flow {taskid} finish`** → một commit (qua `msdlc:commit`) + push nhánh + tạo MR (auto qua `gh`/`glab` nếu có, không thì link tạo tay) + ghi dòng `> MR:` vào `report.md`.
6. Gọi skill **`msdlc:tracking {taskid} review task`** để chuyển sang `Review` + comment tóm tắt kết quả **kèm link MR** (tracking đọc `> MR:` trong report). **Máy KHÔNG tự merge** — người review MR rồi merge + đóng Done.
7. **(Git flow bật) Về base:** checkout lại base branch cho lượt sau.
8. Nếu `deliver-light` fail giữa chừng → log rõ task/ticket bị kẹt + lý do, **để nguyên ticket** cho người xử lý; **không** gọi `git-flow finish` (không tạo MR cho code dở); không retry cùng lượt (Bước R lượt sau nhặt lại). Nếu `git-flow finish` fail sau khi đã push → non-fatal, ticket vẫn sang Review với ghi chú cần tạo MR tay.

**An toàn:** xử lý **tuần tự** từng ticket (không dùng git worktree → mọi thay đổi trên một working tree chung; build song song nhiều task sẽ đè nhau). Git flow bật → **một build/lượt** + luôn `finish` trước khi rời nhánh → không có hai nhánh dở chồng nhau. Chạy **một poller cho mỗi board** — nhiều máy cùng poll một board không được phối hợp bằng khóa mạnh (tracker thiếu compare-and-swap).

## Bước 3 — Không đụng phần còn lại

KHÔNG fetch/không đổi ticket ở các cột `Validate` / `Review` / `Done` — đó là phần chờ người. Poll chỉ kích hoạt ở hai cột intake và Approved (cộng Bước R nhặt task dở ở `planning`/`in-progress`).

## Bước 4 — Tóm tắt lượt poll

Báo cho user (một khối ngắn): lượt này Bước R nhặt lại task nào; nhận bao nhiêu ticket ở intake, taskid nào được claim + đẩy sang Validate; task nào được build sang Review (kèm **nhánh + link MR** nếu git flow bật); ticket nào bị bỏ qua và lý do. Không có ticket nào cần xử lý → báo *"Không có ticket cần xử lý lượt này."*

## Ghi chú vận hành

- Chạy định kỳ: `/loop 10m /msdlc:tracking-poll` (interval, cần phiên đang mở) hoặc tạo scheduled cloud agent qua skill `schedule` (chạy nền kể cả tắt máy). Chọn theo nhu cầu; xem README.
- Mỗi lượt idempotent → chạy lại nhiều lần an toàn: trạng thái nằm ở cột board + sự tồn tại của `plan.md`/`report.md` trong `.claude/tasks/{taskid}/`.
- Cột `planning` giờ là bước **claim/lock**, không còn cosmetic — nên override tên cột `planning` trong profile để tránh detect-keyword đoán trượt.
- **Git flow (tùy chọn, cờ trong `## Git` của profile):** bật → mỗi task build trên một nhánh riêng tách từ base, build xong tự commit + push + tạo MR + comment link MR vào ticket; **một build/lượt**; **máy không tự merge** (người review MR & merge). Tắt (mặc định) → build thẳng trên branch hiện tại như luồng 0.5.0. Chi tiết ở skill `msdlc:git-flow`.
