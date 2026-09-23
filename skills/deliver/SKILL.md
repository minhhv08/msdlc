---
name: deliver
description: >-
  Tự động hoá pipeline từ yêu cầu đến done, tự định tuyến theo loại id do /spec tạo: STORY (.claude/stories/{id}/requirement.md) → architect → DỪNG chờ duyệt ADR → deliver-story; TASK (.claude/tasks/{taskid}/request.md) → task-planner → DỪNG chờ duyệt plan → deliver-task (luồng nhẹ, ít token). LUÔN dùng skill này khi user gõ `/deliver {id}`, hoặc nói "chạy pipeline cho story/task X", "tự động làm requirement X từ đầu tới cuối", "deliver story X", "build feature từ requirement". Tiền đề: đã chạy /spec. KHÔNG dùng khi user chỉ muốn chạy lẻ một bước (architect/dev-leader/dev) — gọi thẳng agent tương ứng.
---

# /deliver — Tự động hoá pipeline requirement → done

Điều phối chuỗi agent đã có trong workspace để hoàn thành một requirement từ đầu tới cuối, với **đúng một cổng duyệt sau ADR**.

Pipeline: `architect` → **[GATE duyệt ADR]** → skill `deliver-story` (main tự điều phối: `dev-leader` → `dev-*` song song theo file-disjoint, **song song** thiết kế test map/reduce `qc-leader` → `qc-designer` ×N → `qc-leader` merge → `reviewer` (auto-fix ≤1) → `qc-executor`+`security-auditor` song song (auto-fix ≤2) → `chronicler`).

Khi chạy trong Codex, đọc `.codex-plugin/agent-models.toml` của plugin trước mỗi lần dispatch agent. File này là nguồn sự thật cho model tier và reasoning effort; không tự nâng lên `gpt-6-astra` ngoài điều kiện escalation đã cấu hình.

## Input

- Tham số là **story id** (vd `/deliver 001`) hoặc **taskid** (vd `/deliver T-003`, `/deliver PROJ-123`). Nếu user không đưa id → liệt kê `.claude/stories/` + các `.claude/tasks/*/request.md` và hỏi, hoặc dùng id duy nhất nếu chỉ có một.

## Định tuyến theo loại id (làm ĐẦU TIÊN)

- `.claude/stories/{id}/requirement.md` tồn tại → **STORY** → làm *Quy trình (story)* bên dưới.
- `.claude/tasks/{id}/request.md` tồn tại → **TASK** → làm mục **Luồng TASK** ở cuối file (không gọi architect/deliver-story).
- Cả hai đều không có → dừng, báo user chạy `/spec` trước. KHÔNG tự bịa requirement.

## Quy trình (story — main agent tự thực thi)

### Bước 0 — Tiền kiểm
1. Xác định `{id}` (đã có `requirement.md` theo bước định tuyến).
2. Nhắc tiền đề hạ tầng cho bước QC (qc-executor sẽ chạy test): các dependency local theo mục **Hạ tầng local** trong `.claude/profile.md` (vd DB/cache + cổng) cần up trước.
   Nếu chưa up, QC có thể trả `infraMissing` — vẫn chạy được tới đó rồi báo cáo.

### Bước A — Thiết kế kiến trúc (architect)
3. Gọi skill **`msdlc:tracking {id} planning`** (tự no-op nếu không có tracker) để đưa ticket sang cột Planning.
4. Nếu `.claude/stories/{id}/adr.md` **chưa có**: gọi **Agent `architect`** cho story đó (đọc requirement, ghi `.claude/stories/{id}/adr.md` + cập nhật `docs/architecture.md`).
   Nếu `adr.md` **đã có**: hỏi user muốn dùng lại ADR cũ hay chạy lại architect để cập nhật.

### GATE — Duyệt ADR (BẮT BUỘC dừng)
5. Gọi skill **`msdlc:tracking {id} validate`** (tự no-op nếu không có tracker) để đưa ticket sang cột Validate + comment link ADR.
6. Tóm tắt phương án đã chọn + Open questions + đường dẫn `.claude/stories/{id}/adr.md`.
7. **DỪNG hẳn tại đây** và hỏi user có duyệt để build tiếp không. Tuyệt đối **không** tự chạy bước B khi chưa có xác nhận rõ ràng của user. Đây là cổng duyệt duy nhất của pipeline.

### Bước B — Build tự động (skill deliver-story)
8. Chỉ khi user đã duyệt: **ghi dấu duyệt vào ADR** — cập nhật dòng header của `.claude/stories/{id}/adr.md` từ `Status: Proposed` thành `Status: Accepted · Duyệt: <hôm nay>`. Đây là dấu duyệt bền mà `deliver-story` kiểm tra làm tiền đề — không có nó thì deliver-story từ chối chạy. Sau đó gọi skill **`msdlc:tracking {id} approved`** (tự no-op nếu không có tracker), rồi gọi **skill `deliver-story`** với story `{id}` (Skill tool). Main agent **tự điều phối** theo hướng dẫn của skill đó bằng Agent tool — KHÔNG dùng Workflow.
   Trình tự: dev-leader vỡ task → dev agent implement theo wave topo, **song song mọi task có tập file rời nhau** (nhiều lệnh Agent trong một message), tuần tự khi đụng file chung; **song song** với dev, thiết kế test theo map/reduce (qc-leader enumerate → qc-designer ×N flesh-out → qc-leader merge) → reviewer → qc-executor chạy test + security-auditor audit (song song; test fail hoặc lỗ hổng Critical/High thì dev fix rồi chạy lại, tối đa 2 vòng) → chronicler.
9. Main theo sát từng phase và tổng hợp kết quả khi xong.

### Bước C — Báo cáo
10. Tóm tắt cho user:
   - Số task đã plan / đã chạy, danh sách file thay đổi.
   - Trạng thái test: pass / fail (kèm failures) / `infraMissing`.
   - Bảo mật: số finding theo severity; `Critical`/`High` còn lại + đường dẫn báo cáo `.claude/stories/{id}/security/`.
   - `followUps` và lockstep cần chú ý.
   - Nếu đụng schema/dữ liệu được cache theo lockstep của profile → nhắc evict cache (key/lệnh lấy từ profile).
   - Nếu user muốn commit → dùng skill **`msdlc:commit`**.

## Nguyên tắc

- **Một cổng duyệt duy nhất, sau ADR.** Không thêm gate ở các bước khác; không tự vượt gate.
- **Sync tracker là side-effect tự động, KHÔNG phải gate.** Các lời gọi `msdlc:tracking` chỉ chuyển cột ticket; chúng không dừng pipeline và tự no-op khi dự án không dùng tracker. Không bao giờ tự chuyển Done.
- **Không sửa định nghĩa agent.** Workflow tái dùng agent hiện có qua `agentType`.
- **Trung thực trạng thái.** Test fail/hạ tầng thiếu phải báo đúng, không tô hồng.
- **Có thể bỏ qua Bước A** nếu user nói "build luôn từ ADR có sẵn" — nhưng KHÔNG được bỏ qua gate: vẫn **BẮT BUỘC** hỏi user xác nhận duyệt ADR một lần rõ ràng, và khi user xác nhận thì ghi `Status: Accepted` vào `adr.md` như ở bước 8, rồi mới vào Bước B. Không có xác nhận → không build.

---

## Luồng TASK (id có `.claude/tasks/{taskid}/request.md`)

Bản nhẹ cho feat/fixbug nhỏ: `task-planner` thay `architect`, `plan.md` thay ADR, `deliver-task` thay `deliver-story` (không `dev-leader`, không QC map/reduce). **Vẫn đúng một cổng duyệt** — duyệt plan, trước mọi bước build. Mọi lời gọi `msdlc:tracking` dùng `kind=task` và tự no-op khi task không gắn ticket.

1. **Tiền kiểm:** đã có `.claude/tasks/{taskid}/report.md` → task đã build xong → báo và dừng. Nhắc tiền đề hạ tầng local như Bước 0 của story.
2. **Plan:** ghi `.claude/tasks/{taskid}/claim.md` với nguồn **`/deliver`** (+ ngày) — đánh dấu task do phiên tay này điều khiển để `tracking-poll` không resume/build trùng — rồi gọi `msdlc:tracking {taskid} planning task`. Nếu **chưa có** `plan.md` → gọi **Agent `task-planner`** cho `{taskid}`, truyền **nội dung `request.md`** (tiêu đề làm title; Mô tả + Acceptance + Non-goals + Open questions làm description) và `Ticket:` nếu có → agent ghi `.claude/tasks/{taskid}/plan.md`. Đã có `plan.md` → hỏi user dùng lại hay lập lại (lập lại = task-planner chế độ cập nhật, truyền plan.md cũ + góp ý của user).
3. **GATE — Duyệt plan (BẮT BUỘC dừng):** gọi `msdlc:tracking {taskid} validate task`. Tóm tắt phương án + subtask + files đụng + Open questions + đường dẫn `plan.md`, rồi **DỪNG** hỏi user duyệt. User góp ý / trả lời Open questions → gọi `task-planner` chế độ cập nhật (plan.md hiện có + góp ý) rồi hỏi duyệt lại. Không có xác nhận rõ ràng → không build.
4. **Build:** khi user duyệt → gọi `msdlc:tracking {taskid} in-progress task` (chuyển TRƯỚC khi làm) → gọi **skill `deliver-task {taskid}`** (main tự điều phối, không hỏi gate lần nữa) → skill ghi `report.md`.
5. **Kết thúc:** gọi `msdlc:tracking {taskid} review task`, rồi báo cáo như Bước C (nguồn: `.claude/tasks/{taskid}/report.md`). Muốn commit → skill **`msdlc:commit`**. Không tự chuyển Done.
