---
description: Quét board ngoài một lượt và tự khởi động luồng NHẸ của msdlc cho các ticket đang chờ — nhận ticket ở cột intake (claim: Todo→planning), phân tích + comment plan chờ duyệt (dừng ở Validate); ticket đã Approved thì build gọn (chuyển in-progress TRƯỚC khi làm) rồi Review. Dùng cùng /loop hoặc schedule để chạy định kỳ.
allowed-tools: Read, Write, Glob, Grep, Task, Skill, Bash, mcp__claude_ai_Atlassian__*, mcp__claude_ai_Asana__*, mcp__claude_ai_Linear__*, mcp__claude_ai_monday_com__*, mcp__claude_ai_Notion__*
# Poll cần MCP tool của connector tracker để FETCH cột + FETCH COMMENT + transition. Nếu dự án dùng MCP server tracker tên khác → thêm tool của nó vào đây (không có → poll không fetch/đọc comment được). Bash để git-flow thao tác git.
# Notion: "cột" = giá trị property Status của page; "chuyển cột" = notion-update-page; "board key" = database ID; comment qua notion-get-comments/notion-create-comment.
---

Bạn đang chạy **một lượt poll** của msdlc theo **luồng NHẸ** (dành cho task board là feat/fixbug nhỏ): quét board ngoài, tự *khởi động* luồng cho các ticket đang chờ. Lệnh này chạy **đúng một lượt rồi dừng** — việc lặp là do harness (`/loop <interval> /msdlc:tracking-poll` hoặc `schedule` cron), KHÔNG tự chế vòng lặp ở đây.

**Nguyên tắc cốt lõi — giữ cổng duyệt:** máy KHÔNG BAO GIỜ tự vượt gate: poll chỉ đẩy ticket tới `Validate` rồi dừng; chỉ ticket **người** kéo sang Approved mới được build. Không bao giờ tự chuyển Done.

**Tiết kiệm token:** lệnh này chạy lặp (`/loop`), nên phần đầu chỉ guard + quét nhanh; logic chi tiết nằm ở skill `msdlc:poll-run` và **chỉ được nạp khi có việc**.

## Bước 0 — Guard

1. Đọc mục `## Task tracker` trong `.claude/msdlc.md` (dự án cũ chưa có file này → mục cùng tên trong `.claude/profile.md`).
   - Không có mục / chưa điền tool + project → báo *"Chưa cấu hình tracker trong `.claude/msdlc.md` — không có gì để poll. Chạy `/msdlc:init` để cấu hình."* và **dừng**.
   - **Cờ bật poll** chưa bật (mặc định tắt) → báo *"Poll đang tắt (opt-in). Bật cờ poll trong `.claude/msdlc.md` mục Task tracker để dùng."* và **dừng**.
2. Xác định connector MCP + cột intake (vd `Todo`) + cột build-trigger (vd `Approved`) + tên cột `planning`/`validate`/`in-progress`/`review` từ profile. Connector chưa connect → báo và dừng (không hỏi token/OAuth).

## Bước Q — Quét nhanh (rẻ), không có việc thì dừng

Chỉ đọc/fetch tối thiểu, chưa nạp logic chi tiết:

1. **Task local dở dang:** liệt kê `.claude/tasks/*/`. Bỏ task local (`request.md` có `Ticket: —`) và task do `/deliver` điều khiển (`claim.md` nguồn `/deliver`). Còn lại, task **chưa xong** = không có `report.md`, hoặc (git flow bật) có `report.md` nhưng chưa có dòng `> MR:`. Chưa cần fetch cột của chúng.
2. **Cột intake:** một lần fetch danh sách ticket ở cột intake (id + title).
3. **Cột Approved:** một lần fetch danh sách ticket ở cột build-trigger; giữ các ticket **có** `.claude/tasks/{taskid}/plan.md` và **chưa có** `report.md` (ticket không đủ điều kiện → ghi một dòng lý do).

Cả ba đều rỗng → báo *"Không có ticket cần xử lý lượt này."* và **dừng** (không invoke skill nào).

Có ít nhất một mục → gọi skill **`msdlc:poll-run`**, truyền kết quả 3 danh sách trên; skill lo Bước R (resume), Bước 1 (intake → Validate), Bước 2 (Approved → build → Review), Bước 3–4 (tóm tắt).
