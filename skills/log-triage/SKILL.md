---
name: msdlc-log-triage
description: Gom log lỗi production thành các bug riêng biệt và tạo ticket Bug dedup ở board intake khi người dùng gọi `/msdlc:log-triage`, dán stack trace/log lỗi, hoặc yêu cầu "triage log", "tạo bug ticket từ log". Skill này là wrapper Codex cho command Claude ở `commands/log-triage.md`.
---

# msdlc-log-triage

Thực thi đúng contract của command Claude `commands/log-triage.md`, nhưng trong môi trường Codex:

1. Đọc file `../../commands/log-triage.md` từ thư mục skill này.
2. Làm theo command đó như nguồn sự thật cho fixbug-intake.
3. Khi command yêu cầu agent `bug-triage`, đọc prompt `../../agents/bug-triage.md`.
   - Nếu Codex có subagent phù hợp, gọi subagent bằng prompt đó.
   - Nếu không có subagent, main agent tự áp dụng prompt đó để phân cụm log và lọc noise.
4. Chỉ tạo ticket Bug ở intake/Todo và ghi ledger theo command.
5. Không tự build, không tự duyệt, không tự chuyển Done. Luồng tiếp theo thuộc `msdlc-tracking-poll`.

Trong Codex, việc tạo ticket cần connector board tương ứng đang khả dụng. Nếu thiếu connector hoặc thiếu cấu hình `## Task tracker`, dừng mềm và báo rõ điều kiện còn thiếu.
