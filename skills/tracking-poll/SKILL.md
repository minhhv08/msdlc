---
name: msdlc-tracking-poll
description: Chạy một lượt poll board ngoài cho msdlc khi người dùng gọi `/msdlc:tracking-poll`, nói "poll board msdlc", "quét Jira/Asana/Linear/Notion để chạy task", hoặc muốn luồng board nhẹ claim ticket, lập plan, chờ duyệt, rồi build task đã Approved. Skill này là wrapper Codex cho command Claude ở `commands/tracking-poll.md`.
---

# msdlc-tracking-poll

Thực thi đúng contract của command Claude `commands/tracking-poll.md`, nhưng trong môi trường Codex:

1. Đọc file `../../commands/tracking-poll.md` từ thư mục skill này.
2. Làm theo command đó như nguồn sự thật cho luồng board nhẹ.
3. Khi command yêu cầu gọi agent Claude, dùng một trong hai cách theo khả năng hiện có:
   - Nếu Codex có công cụ subagent phù hợp, gọi subagent với nội dung prompt tương ứng trong `../../agents/*.md`.
   - Nếu không có subagent, main agent tự thực hiện vai trò đó nhưng phải đọc đúng file agent liên quan trước khi làm.
4. Khi command yêu cầu gọi skill msdlc khác, dùng skill tương ứng trong `../`.
5. Giữ nguyên các bất biến:
   - Poll là one-shot, không tự tạo scheduler.
   - Ticket ở Validate/Approved là human gate của board flow.
   - Không bao giờ tự chuyển Done.
   - Không làm gì nếu `## Task tracker` trong `.claude/profile.md` chưa bật poll hoặc connector chưa sẵn sàng.

Trong Codex, các connector Jira/Asana/Linear/Monday/Notion phụ thuộc vào app/tool đang có trong phiên. Nếu thiếu tool, dừng mềm và báo cần kết nối connector tương ứng.
