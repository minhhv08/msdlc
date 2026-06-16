# msdlc

Một plugin Claude Code đóng gói pipeline giao hàng **độc lập stack**:

```
idea → /spec → architect → [GATE duyệt ADR] → planner
     → dev-backend / dev-frontend (song song, file-disjoint)
     → qc-designer / qc-executor (auto-fix ≤2) → doc-syncer
```

Mọi đặc thù dự án (stack, đường dẫn, lệnh test, hợp đồng lockstep, quy tắc commit) **không nhúng cứng** trong agent — chúng đọc từ `.claude/profile.md` của dự án tiêu thụ lúc chạy.

## Thành phần

- **agents/**: `architect`, `planner`, `dev-backend`, `dev-frontend`, `qc-designer`, `qc-executor`, `security-auditor`, `doc-syncer`
- **commands/**: `init` — cấu hình project hiện tại để dùng plugin (copy file + dò stack + điền profile)
- **skills/**: `spec`, `deliver`, `auto-deliver`
- **shared/**: `agent-memory.md` (giao thức memory dùng chung), `profile.template.md` (mẫu profile)

## Cài đặt

1. Đăng ký + cài plugin (local marketplace):
   ```
   /plugin marketplace add ~/claude-plugins
   /plugin install msdlc@minhhv
   ```
2. **Trong mỗi dự án tiêu thụ**, chạy lệnh cấu hình — cách dễ nhất:
   ```
   /msdlc:init
   ```
   Lệnh này copy `agent-memory.md` + tạo `profile.md` trong `.claude/`, tự dò stack và giúp điền profile.

   Hoặc làm thủ công:
   ```bash
   mkdir -p .claude/shared
   cp <plugin>/shared/agent-memory.md            .claude/shared/agent-memory.md
   cp <plugin>/shared/profile.template.md .claude/profile.md
   ```
   Rồi **điền `.claude/profile.md`** cho dự án (stack, đường dẫn, lệnh build/test, hạ tầng, hợp đồng lockstep, quy tắc commit).

> **Vì sao phải copy 2 file này vào `.claude/`?** Prompt của agent (file `.md`) không được thay biến lúc cài và
> subagent đọc file theo đường dẫn tương đối từ gốc dự án. Agent tham chiếu `.claude/profile.md` và
> `.claude/shared/agent-memory.md` — nên hai file đó phải tồn tại trong `.claude/` của dự án tiêu thụ.
> `profile.md` vốn là per-project; `agent-memory.md` là bản dùng chung copy về.

3. (Tùy chọn) gitignore thư mục memory cục bộ trong dự án tiêu thụ:
   ```
   .claude/agent-memory-local/
   ```

## Dùng

- `/spec` — phỏng vấn biến ý tưởng thành requirement.
- `/deliver {id}` — chạy cả pipeline với một cổng duyệt sau ADR.
- Hoặc gọi từng agent qua Agent tool theo nhu cầu.

## Thiết kế "sạch hardcode"

- Agent chỉ giữ **vai trò + quy trình**; sự thật dự án nằm trong `profile.md`.
- `dev-backend` phục vụ mọi ngôn ngữ/framework backend (tự nhận diện theo file đụng tới); `dev-frontend` phục vụ UI web.
- Giao thức memory ~140 dòng gom 1 bản tại `shared/agent-memory.md` thay vì lặp trong từng agent.
