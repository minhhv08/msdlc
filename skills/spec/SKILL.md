---
name: spec
description: Phân loại yêu cầu là STORY (tính năng lớn, cần ADR) hay TASK (feat/fixbug nhỏ) để chọn flow tiết kiệm token, rồi hỏi trực tiếp bằng AskUserQuestion, chỉ vào chức năng (tối đa 5 lần, có đáp án đề xuất sẵn, không hỏi lan man) — story → spec chức năng ở .claude/stories/{id}/requirement.md; task → brief gọn ở .claude/tasks/{taskid}/request.md (đi luồng nhẹ task-planner → deliver-task). LUÔN dùng skill này khi người dùng muốn build một sản phẩm/tính năng/sửa lỗi nhưng "chưa có PRD rõ ràng", nói các cụm như "muốn làm X nhưng chưa rõ scope", "giúp tao định nghĩa sản phẩm", "viết spec/PRD cho ý tưởng này", "làm rõ yêu cầu", "không biết bắt đầu từ đâu", hoặc khi đưa ra một ý tưởng còn chung chung và cần được làm rõ trước khi thiết kế kiến trúc hay vỡ task. Đây là mắt xích ĐẦU của pipeline; output là input cho `/deliver {id}`.
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

→ **STORY**: làm theo *Nguyên tắc hỏi* → *Câu hỏi chức năng* → *Output* bên dưới.
→ **TASK**: làm theo mục **Nhánh TASK** ở cuối file.

## Nguyên tắc hỏi

**Hỏi trực tiếp bằng tool `AskUserQuestion`** — KHÔNG in danh sách câu hỏi ra chat cho người dùng đọc rồi tự gõ trả lời. Người dùng chỉ cần bấm chọn (hoặc chọn "Other" để gõ ý khác). Môi trường không có `AskUserQuestion` → hỏi **từng câu một** trong chat, mỗi câu kèm phương án đề xuất, không dồn danh sách.

1. **Chỉ hỏi chỗ thật sự thiếu, đúng trọng tâm chức năng.** Đọc kỹ mô tả của người dùng + dò nhanh codebase (màn hình/API/model liên quan, pattern sẵn có) TRƯỚC khi hỏi. Cái gì đã rõ hoặc suy được từ code → không hỏi. Câu nào trả lời xong mà không đổi gì trong cách build/test → không hỏi. Bối cảnh "vì sao làm" lấy từ mô tả ban đầu, không hỏi riêng.

2. **Mỗi câu là một quyết định cụ thể, có đáp án đề xuất sẵn.** Không hỏi mở kiểu "dữ liệu gồm những gì?". Tự suy 2–4 phương án hợp lý từ mô tả + codebase, đặt phương án nên chọn lên đầu kèm "(Recommended)", `description` nói ngắn hệ quả của từng phương án. Ví dụ: *"Xoá bản ghi xử lý thế nào?"* → `Xoá mềm (Recommended)` / `Xoá cứng` / `Không cho xoá`. Dùng `multiSelect` khi chọn tập con (vd các thao tác CRUD nào có trong bản này, vai trò nào được thao tác).

3. **Tối đa 5 lần gọi** (chưa tính câu xác nhận cuối), mỗi lần tối đa 4 câu (giới hạn của tool). Hỏi theo thứ tự quan trọng: lần đầu là các điểm ảnh hưởng lớn nhất tới cách build (luồng, quy tắc, phân quyền); các lần sau hỏi tiếp điểm còn thiếu và đào sâu câu trả lời "Other" còn mơ hồ/mâu thuẫn — câu sau nên dựa trên câu trả lời trước. Đủ rõ thì dừng sớm, không cần dùng hết 5 lần. Vẫn thiếu sau lần thứ 5 → ghi *Open questions*, không hỏi thêm.

4. **Đừng tự bịa.** Phương án đề xuất là để người dùng chọn, không phải để tự điền thay. Câu người dùng bỏ qua/chưa quyết → *Open questions*.

5. **Xác nhận bằng một câu hỏi cuối.** Gọi `AskUserQuestion` một câu *"Spec đã đúng chưa?"* với option `Đúng, ghi file (Recommended)` (đặt bản tóm tắt bullet — luồng chức năng + quy tắc + acceptance + non-goals — trong `preview`) và `Cần sửa` (người dùng gõ chỗ sai qua "Other"/ghi chú). Có thể gộp câu xác nhận này vào lần gọi cuối nếu còn chỗ.

## Điểm cần chốt (checklist nội bộ — KHÔNG in ra cho người dùng)

Dùng để xác định câu nào còn thiếu; điểm nào đã rõ từ mô tả/codebase thì bỏ qua:

- **Luồng chức năng:** vai trò nào làm thao tác gì → hệ thống phản hồi gì (3–7 luồng ở vòng đầu).
- **Dữ liệu:** input/field + validate; output/hiển thị/API trả về.
- **Quy tắc nghiệp vụ & phân quyền:** điều kiện, công thức, trạng thái chuyển đổi; ai được làm gì.
- **Trường hợp biên & lỗi:** rỗng/trùng/vượt giới hạn, lỗi tích hợp → xử lý thế nào.
- **Tích hợp & ràng buộc kỹ thuật:** hệ thống/module/API đang có phải đụng tới; bảo mật/dữ liệu nhạy cảm/hiệu năng — chỉ khi liên quan.
- **Ngoài phạm vi:** cái gì KHÔNG làm ở bản này (đưa ứng viên dễ bị scope creep thành option `multiSelect`).
- **Nghiệm thu:** 3–7 tiêu chí kiểm được — tự đề xuất từ các luồng, người dùng duyệt ở câu xác nhận cuối.

## Output: .claude/stories/{id}/requirement.md

Sau khi người dùng xác nhận bản tóm tắt, ghi spec ra file **`.claude/stories/{id}/requirement.md`** (tính từ thư mục gốc dự án), trong đó `{id}` là **số thứ tự kế tiếp, padding 3 chữ số** (`001`, `002`, …):

- Tìm các thư mục con đang có trong `.claude/stories/`, lấy số lớn nhất rồi +1. Nếu `.claude/stories/` chưa tồn tại hoặc rỗng → dùng `001`.
- Mỗi yêu cầu (mỗi lần chạy skill) là **một thư mục `.claude/stories/{id}/` riêng**, để các bước sau (architecture, vỡ task) ghi thêm file vào cùng thư mục đó.
- Tạo thư mục nếu chưa có. KHÔNG ghi đè thư mục/id đã tồn tại — luôn cấp id mới.

Nội dung file theo ĐÚNG template sau:

```markdown
# Spec: [Tên sản phẩm/tính năng]

> Status: Draft · Ngày: [YYYY-MM-DD] · Người tạo: [tên] · Ticket: [ID|URL hoặc —]

## 1. Problem
- **Vấn đề / mục tiêu:** ... (1–2 câu, lấy từ mô tả ban đầu)

## 2. Users & Roles
- **Vai trò dùng chức năng:** ... (ai được làm gì)

## 3. Scope — Functional requirements
Các luồng chức năng (mỗi luồng: ai → thao tác → hệ thống phản hồi):
- [ ] F1. ...
- [ ] F2. ...

**Dữ liệu:** input/field + validate; output/hiển thị/API trả về.
**Quy tắc nghiệp vụ:** điều kiện, công thức, trạng thái, phân quyền.
**Trường hợp biên & lỗi:** ...

## 4. Non-goals
Rõ ràng KHÔNG làm ở phiên bản này:
- ...

## 5. Constraints
- **Kỹ thuật/tích hợp:** hệ thống/module/API đang có phải đụng tới ...
- **Bảo mật/dữ liệu:** ... (bỏ nếu không có)

## 6. Success criteria — Acceptance
- [ ] AC1. ... (kiểm được)
- [ ] AC2. ...

## 7. Open questions
- ❓ ... (bỏ mục nếu không có)
```

Quy tắc khi điền:
- Mỗi mục phải dựa trên câu trả lời thực của người dùng. Mục nào chưa rõ → để vào "Open questions", KHÔNG bịa.
- Giữ Scope ngắn gọn ở vòng đầu — thà ít luồng rõ ràng còn hơn nhiều luồng mơ hồ.
- Dùng ngôn ngữ cụ thể, kiểm được; thay "nhanh" bằng con số, thay "quản lý" bằng thao tác cụ thể.
- Mục không có nội dung thực (vd Constraints bảo mật) → ghi "—" hoặc bỏ dòng, không độn chữ.

## Gắn ticket board (nếu dự án dùng tracker)

Nếu `.claude/profile.md` có mục `## Task tracker` đã cấu hình: hỏi (optional, **gộp làm một câu trong lần gọi `AskUserQuestion` đầu**, không tốn lượt riêng) story/task này có gắn ticket trên board không. Nếu có → ghi ID/URL vào trường `Ticket:` ở header; với **STORY** gọi thêm skill **`msdlc:tracking {id} todo`** để đưa ticket về cột intake (TASK không gọi — xem Nhánh TASK). Không có tracker hoặc không có ticket → bỏ qua (skill `msdlc:tracking` tự no-op, không cần điều kiện gì thêm).

## Sau khi xong

Báo cho người dùng biết file `.claude/stories/{id}/requirement.md` đã sẵn sàng (nêu rõ `{id}` đã cấp) và đây là input cho bước tiếp theo (thiết kế kiến trúc → vỡ task). Bước tiếp là **`/deliver {id}`** (architect → GATE duyệt ADR → build).

---

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

```markdown
# Task: [tiêu đề ngắn]

> Kind: fixbug|feat · Ngày: [YYYY-MM-DD] · Người tạo: [tên] · Ticket: [ID|URL hoặc —]

## Mô tả
[fixbug: actual vs expected + cách tái hiện/log; feat: thay đổi cụ thể + nơi áp dụng + ví dụ]

## Acceptance
- [ ] ...

## Non-goals
- ... (bỏ mục nếu không có)

## Open questions
- ❓ ... (bỏ mục nếu không có)
```

**Tracker:** nhánh TASK **không** gọi `msdlc:tracking … todo` — `/deliver` sẽ claim thẳng ticket sang `planning` khi bắt đầu. Nếu profile bật **poll** và ticket đang nằm ở cột intake của board → nhắc người dùng: *"Ticket này `tracking-poll` sẽ tự nhặt — không cần chạy tay; nếu vẫn muốn chạy tay thì `/deliver {taskid}` sẽ claim trước để poll không nhặt trùng."*

**Sau khi xong:** báo `.claude/tasks/{taskid}/request.md` đã sẵn sàng và bước tiếp là **`/deliver {taskid}`** (luồng nhẹ: `task-planner` lập plan → **[GATE duyệt plan]** → `deliver-task`).
