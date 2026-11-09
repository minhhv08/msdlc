---
name: deliver
description: >-
  Chạy pipeline msdlc từ id do /spec tạo, tự định tuyến: STORY → architect → DỪNG duyệt ADR → deliver-story; TASK → task-planner → DỪNG duyệt plan → deliver-task. Dùng khi user gõ `/deliver {id}` hoặc nói 'chạy pipeline / deliver story X / build feature từ requirement'. Không dùng để chạy lẻ một agent.
---

# /deliver — Tự động hoá pipeline requirement → done

Điều phối chuỗi agent đã có trong workspace để hoàn thành một requirement từ đầu tới cuối, với **đúng một cổng duyệt sau ADR**.

Story: `architect` → **[GATE duyệt ADR]** → skill `deliver-story`. Task: `task-planner` → **[GATE duyệt plan]** → skill `deliver-task`.

Khi chạy trong Codex, đọc `.codex-plugin/agent-models.toml` của plugin trước mỗi lần dispatch agent. File này là nguồn sự thật cho model tier và reasoning effort; không tự nâng lên `gpt-6-astra` ngoài điều kiện escalation đã cấu hình.

## Input

- Tham số là **story id** (vd `/deliver 001`) hoặc **taskid** (vd `/deliver T-003`, `/deliver PROJ-123`). Nếu user không đưa id → liệt kê `.claude/stories/` + các `.claude/tasks/*/request.md` và hỏi, hoặc dùng id duy nhất nếu chỉ có một.

## Định tuyến theo loại id (làm ĐẦU TIÊN)

- `.claude/stories/{id}/requirement.md` tồn tại → **STORY** → Read `story.md` trong thư mục skill này và làm theo.
- `.claude/tasks/{id}/request.md` tồn tại → **TASK** → Read `task.md` trong thư mục skill này và làm theo (không gọi architect/deliver-story).
- Cả hai đều không có → dừng, báo user chạy `/spec` trước. KHÔNG tự bịa requirement.

Chỉ đọc file của nhánh đúng loại id.

## Nguyên tắc

- **Một cổng duyệt duy nhất** — sau ADR (story) hoặc sau plan (task). Không thêm gate ở các bước khác; không tự vượt gate.
- **Sync tracker là side-effect tự động, KHÔNG phải gate.** Các lời gọi `msdlc:tracking` chỉ chuyển cột ticket; chúng không dừng pipeline và tự no-op khi dự án không dùng tracker. Không bao giờ tự chuyển Done.
- **Không sửa định nghĩa agent.** Workflow tái dùng agent hiện có qua `agentType`.
- **Trung thực trạng thái.** Test fail/hạ tầng thiếu phải báo đúng, không tô hồng.
