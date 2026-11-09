---
name: spec
description: >-
  Làm rõ yêu cầu trước khi thiết kế: phân loại STORY (lớn, cần ADR) hay TASK (feat/fixbug nhỏ), hỏi bằng AskUserQuestion tập trung chức năng (≤5 lượt), ghi .claude/stories/{id}/requirement.md hoặc .claude/tasks/{taskid}/request.md. Dùng khi user có ý tưởng/tính năng/bug nhưng chưa rõ scope, hoặc muốn 'viết spec/PRD', 'làm rõ yêu cầu'.
---

# Spec Discovery

Mục tiêu của skill này KHÔNG phải viết code, mà là **chốt chức năng cần làm** đủ rõ để đem đi thiết kế kiến trúc và vỡ task. Hỏi **thẳng vào chức năng** — hệ thống phải làm gì, với dữ liệu nào, theo quy tắc nào, thế nào là đúng. Không hỏi lan man về bối cảnh kinh doanh, persona, why-now, metric hay rủi ro dự án.

## Bước 0 — Phân loại: STORY hay TASK (làm TRƯỚC khi hỏi)

Mục đích: **tiết kiệm token**. Story đi luồng nặng (hỏi chức năng → `architect` + ADR → `dev-leader` → QC map/reduce); task đi luồng nhẹ (brief 1 lượt hỏi → `task-planner` → `deliver-task`). Chọn sai theo chiều "task bị làm như story" là đốt token vô ích; chiều ngược lại thì thiếu thiết kế — nên phân loại có lý do.

Dựa trên mô tả ban đầu của người dùng (+ dò nhanh codebase bằng `Glob`/`Grep` nếu cần xác định vùng code, **không đọc sâu**), đánh giá:

| Tín hiệu | → TASK | → STORY |
|---|---|---|
| Loại việc | fixbug, chỉnh/mở rộng nhỏ một tính năng đang có | tính năng/sản phẩm mới, luồng người dùng mới |
| Scope | 1 luồng, nói được trong 1–3 câu | nhiều luồng chức năng |
| Phạm vi code | vài file, 1 project (hoặc 1 thay đổi lockstep đã có pattern) | nhiều module/project, cần contract/API/data model mới |
| Quyết định kiến trúc | không có — bám pattern sẵn có | có lựa chọn kỹ thuật cần cân nhắc/ghi ADR |

- Đa số tín hiệu nghiêng về một phía → chọn phía đó. Lưng chừng → nghiêng **STORY** (thiếu thiết kế đắt hơn thừa).
- Người dùng đã nói rõ ("đây là bug nhỏ", "làm spec đầy đủ", "task", "story") → theo người dùng, bỏ đánh giá.
- **Báo kết quả trong 1 dòng kèm lý do** (vd *"Mình xếp đây là TASK (fixbug trong 1 module, không cần quyết định kiến trúc) → đi luồng nhẹ. Muốn làm story đầy đủ thì nói nhé."*) rồi đi tiếp ngay theo nhánh đã chọn — không chờ xác nhận riêng; người dùng có thể đổi ở bất kỳ lượt nào.
- Đang ở nhánh TASK mà câu trả lời lộ ra độ phức tạp của story (cần contract mới, nhiều luồng, quyết định kiến trúc) → nói rõ và **chuyển sang nhánh STORY**, tận dụng câu trả lời đã có (không hỏi lại).

→ **STORY**: Read `story.md` trong thư mục skill này (checklist cần chốt + output `requirement.md`), hỏi theo *Nguyên tắc hỏi* bên dưới.
→ **TASK**: Read `task.md` trong thư mục skill này (brief gọn + output `request.md`), hỏi theo *Nguyên tắc hỏi* bên dưới.
Chỉ đọc file của nhánh đã chọn (chuyển nhánh giữa chừng → đọc thêm file nhánh kia).

## Nguyên tắc hỏi

**Hỏi trực tiếp bằng tool `AskUserQuestion`** — KHÔNG in danh sách câu hỏi ra chat cho người dùng đọc rồi tự gõ trả lời. Người dùng chỉ cần bấm chọn (hoặc chọn "Other" để gõ ý khác). Môi trường không có `AskUserQuestion` → hỏi **từng câu một** trong chat, mỗi câu kèm phương án đề xuất, không dồn danh sách.

1. **Chỉ hỏi chỗ thật sự thiếu, đúng trọng tâm chức năng.** Đọc kỹ mô tả của người dùng + dò nhanh codebase (màn hình/API/model liên quan, pattern sẵn có) TRƯỚC khi hỏi. Cái gì đã rõ hoặc suy được từ code → không hỏi. Câu nào trả lời xong mà không đổi gì trong cách build/test → không hỏi. Bối cảnh "vì sao làm" lấy từ mô tả ban đầu, không hỏi riêng.

2. **Mỗi câu là một quyết định cụ thể, có đáp án đề xuất sẵn.** Không hỏi mở kiểu "dữ liệu gồm những gì?". Tự suy 2–4 phương án hợp lý từ mô tả + codebase, đặt phương án nên chọn lên đầu kèm "(Recommended)", `description` nói ngắn hệ quả của từng phương án. Ví dụ: *"Xoá bản ghi xử lý thế nào?"* → `Xoá mềm (Recommended)` / `Xoá cứng` / `Không cho xoá`. Dùng `multiSelect` khi chọn tập con (vd các thao tác CRUD nào có trong bản này, vai trò nào được thao tác).

3. **Tối đa 5 lần gọi** (chưa tính câu xác nhận cuối), mỗi lần tối đa 4 câu (giới hạn của tool). Hỏi theo thứ tự quan trọng: lần đầu là các điểm ảnh hưởng lớn nhất tới cách build (luồng, quy tắc, phân quyền); các lần sau hỏi tiếp điểm còn thiếu và đào sâu câu trả lời "Other" còn mơ hồ/mâu thuẫn — câu sau nên dựa trên câu trả lời trước. Đủ rõ thì dừng sớm, không cần dùng hết 5 lần. Vẫn thiếu sau lần thứ 5 → ghi *Open questions*, không hỏi thêm.

4. **Đừng tự bịa.** Phương án đề xuất là để người dùng chọn, không phải để tự điền thay. Câu người dùng bỏ qua/chưa quyết → *Open questions*.

5. **Xác nhận bằng một câu hỏi cuối.** Gọi `AskUserQuestion` một câu *"Spec đã đúng chưa?"* với option `Đúng, ghi file (Recommended)` (đặt bản tóm tắt bullet — luồng chức năng + quy tắc + acceptance + non-goals — trong `preview`) và `Cần sửa` (người dùng gõ chỗ sai qua "Other"/ghi chú). Có thể gộp câu xác nhận này vào lần gọi cuối nếu còn chỗ.

## Gắn ticket board (nếu dự án dùng tracker)

Nếu `.claude/msdlc.md` (dự án cũ chưa có file này → mục cùng tên trong `.claude/profile.md`) có mục `## Task tracker` đã cấu hình: hỏi (optional, **gộp làm một câu trong lần gọi `AskUserQuestion` đầu**, không tốn lượt riêng) story/task này có gắn ticket trên board không. Nếu có → ghi ID/URL vào trường `Ticket:` ở header; với **STORY** gọi thêm skill **`msdlc:tracking {id} todo`** để đưa ticket về cột intake (TASK không gọi — xem Nhánh TASK). Không có tracker hoặc không có ticket → **không invoke** `msdlc:tracking` (tiết kiệm token).
