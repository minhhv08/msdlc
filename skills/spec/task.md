# spec — nhánh TASK (chỉ đọc khi Bước 0 phân loại là TASK)

## Nhánh TASK — brief gọn cho luồng nhẹ

Task không cần PRD: `task-planner` sẽ tự dò codebase và chốt phương án. Việc của spec chỉ là gom **đủ mô tả để không phải đoán scope** — thường 1–2 lần gọi `AskUserQuestion` là đủ, tối đa 5 lần như nhánh STORY.

**Hỏi trực tiếp bằng `AskUserQuestion`** (tối đa 4 câu, đáp án đề xuất sẵn; bỏ điểm người dùng đã nói hoặc suy được từ code). Điểm cần chốt — checklist nội bộ, KHÔNG in ra:
- *Fixbug:* hiện tượng (actual) vs mong đợi (expected); cách tái hiện / input / log lỗi nếu có; vùng code/màn hình/API liên quan (nếu biết).
- *Feat nhỏ:* thay đổi cụ thể là gì; áp dụng ở đâu (màn hình/API/module); ví dụ input → output mong muốn.
- *Cả hai:* tiêu chí "xong" (1–3 acceptance kiểm được); có gì rõ ràng KHÔNG làm không.

Vẫn áp dụng *Nguyên tắc hỏi* ở trên (hỏi bằng tool, đề xuất sẵn, đào sâu câu mơ hồ, đừng tự bịa) — chỗ chưa rõ ghi vào Open questions (task-planner sẽ đưa ra lúc duyệt plan). **Không** hỏi bối cảnh/why-now/metric/rủi ro dự án. Không cần bước phản chiếu riêng: brief ngắn — ghi luôn rồi cho người dùng xem.

**`{taskid}`:**
- Có ticket board (xem mục *Gắn ticket board* — gộp làm một câu trong cùng lần gọi trên) → `{taskid}` = **ID ticket** (vd `PROJ-123`), cùng convention với luồng board.
- Không có ticket → id local **`T-{NNN}`**: lấy số lớn nhất trong các thư mục `.claude/tasks/T-*` rồi +1, padding 3 chữ số (`T-001`, `T-002`, …).
- Thư mục `.claude/tasks/{taskid}/` đã tồn tại → KHÔNG ghi đè; báo người dùng (ticket đã được luồng board/lần trước xử lý) và hỏi muốn dùng tiếp hay không.

**Ghi `.claude/tasks/{taskid}/request.md`:**

Template: `templates/request.md` trong thư mục skill này — Read ngay trước khi ghi file (nhánh TASK).

**Tracker:** nhánh TASK **không** gọi `msdlc:tracking … todo` — `/deliver` sẽ claim thẳng ticket sang `planning` khi bắt đầu. Nếu profile bật **poll** và ticket đang nằm ở cột intake của board → nhắc người dùng: *"Ticket này `tracking-poll` sẽ tự nhặt — không cần chạy tay; nếu vẫn muốn chạy tay thì `/deliver {taskid}` sẽ claim trước để poll không nhặt trùng."*

**Sau khi xong:** báo `.claude/tasks/{taskid}/request.md` đã sẵn sàng và bước tiếp là **`/deliver {taskid}`** (luồng nhẹ: `task-planner` lập plan → **[GATE duyệt plan]** → `deliver-task`).
