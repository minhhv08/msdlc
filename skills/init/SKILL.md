---
name: msdlc-init
description: Khởi tạo msdlc trong dự án tiêu thụ khi người dùng gọi `/msdlc:init`, nói "init msdlc", "setup msdlc", hoặc muốn tạo `.claude/profile.md`, `.claude/rules/`, `.claude/shared/agent-memory.md` để pipeline chạy được trong Codex/Claude. Skill này là wrapper Codex cho command Claude ở `commands/init.md`.
---

# msdlc-init

Thực thi đúng contract của command Claude `commands/init.md`, nhưng trong môi trường Codex:

1. Đọc file `../../commands/init.md` từ thư mục skill này.
2. Làm theo hướng dẫn trong command đó như nguồn sự thật.
3. Khi command nhắc tới `$CLAUDE_PLUGIN_ROOT`, hiểu là thư mục plugin `msdlc`.
4. Nếu đang chạy trong Codex, vẫn tạo/cập nhật các artifact runtime trong dự án tiêu thụ theo convention hiện có của msdlc:
   - `.claude/profile.md`
   - `.claude/rules/*.md`
   - `.claude/shared/agent-memory.md`
5. Không ghi đè cấu hình đã có nếu command không cho phép ghi đè.
6. Sau khi xong, báo các file đã tạo/giữ nguyên và nhắc người dùng điền các phần còn thiếu trong profile/rules.

Các hook bảo mật trong `.claude-plugin/plugin.json` là cơ chế riêng của Claude Code. Trong Codex, hãy tuân thủ cùng tinh thần an toàn bằng các policy/tool approval hiện có thay vì cố đăng ký hook.
