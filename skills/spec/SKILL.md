---
name: spec
description: Phỏng vấn người dùng để biến một ý tưởng phần mềm còn mơ hồ thành một bản spec (PRD) có cấu trúc, xuất ra file spec.md. LUÔN dùng skill này khi người dùng muốn build một sản phẩm/tính năng từ đầu nhưng "chưa có PRD rõ ràng", nói các cụm như "muốn làm X nhưng chưa rõ scope", "giúp tao định nghĩa sản phẩm", "viết spec/PRD cho ý tưởng này", "làm rõ yêu cầu", "không biết bắt đầu từ đâu", hoặc khi đưa ra một ý tưởng còn chung chung và cần được làm rõ trước khi thiết kế kiến trúc hay vỡ task. Đây là mắt xích ĐẦU của pipeline idea → spec → architecture → tasks; output spec.md sẽ là input cho agent architect và dev-leader ở các bước sau.
---

# Spec Discovery

Mục tiêu của skill này KHÔNG phải viết code, mà là **gỡ bỏ sự mơ hồ**: dẫn dắt người dùng qua một cuộc phỏng vấn có cấu trúc để biến một ý tưởng còn lờ mờ thành một bản spec rõ ràng, đủ chắc để đem đi thiết kế kiến trúc và vỡ task.

Khi build từ đầu, nút thắt luôn là "tôi chưa biết chính xác mình đang làm gì, cho ai, ràng buộc nào". Skill này ép trả lời đúng những câu đó — đặc biệt là những câu mà lúc hào hứng người ta hay bỏ qua (non-goals, định nghĩa "xong", rủi ro).

## Nguyên tắc dẫn dắt

Đây là phần quan trọng nhất — đọc kỹ trước khi hỏi:

1. **Hỏi theo từng cụm, không dồn một lúc.** Mỗi lượt chỉ hỏi 1 phase (3–5 câu liên quan). Dồn 20 câu cùng lúc khiến người dùng trả lời qua loa. Hỏi xong phase này, đọc câu trả lời, rồi mới sang phase sau.

2. **Phát hiện câu trả lời mơ hồ và đào sâu.** Đây là giá trị cốt lõi. Nếu câu trả lời chung chung, đừng ghi lại nguyên văn — hỏi lại cho cụ thể:
   - "user" → user nào chính xác? Vai trò gì? Nội bộ hay khách hàng?
   - "nhanh hơn" → nhanh hơn bao nhiêu, đo bằng gì?
   - "quản lý X" → quản lý gồm những thao tác cụ thể nào (xem/tạo/sửa/xoá)?
   - "tích hợp với hệ thống cũ" → hệ thống nào, qua API hay DB, có contract chưa?

3. **Chủ động ép ra non-goals.** Người ta hầu như không tự nói ra cái mình KHÔNG làm. Phải hỏi thẳng: "Ở phiên bản đầu, có tính năng nào bạn rõ ràng muốn để lại sau không?" Một scope không có non-goals là scope chưa được suy nghĩ.

4. **Phản chiếu lại trước khi chốt.** Sau khi đủ thông tin, tóm tắt lại toàn bộ cho người dùng xác nhận TRƯỚC KHI ghi file. Hỏi: "Mình hiểu đúng chưa? Có gì sai/thiếu không?"

5. **Đừng tự bịa.** Nếu một phần người dùng thật sự chưa nghĩ tới, đừng đoán hộ — ghi vào mục "Open questions" để giải quyết sau. Một spec trung thực về cái-chưa-biết tốt hơn một spec giả vờ đã biết hết.

## Các phase phỏng vấn

Đi tuần tự, mỗi phase một lượt hỏi. Có thể bỏ qua/gộp nếu người dùng đã trả lời sẵn trong hội thoại trước đó.

**Phase 1 — Problem & context**
- Vấn đề cụ thể đang giải quyết là gì? (mô tả tình huống thực, không phải giải pháp)
- Vì sao là bây giờ? (why now)
- Nếu không build cái này thì sao — ai đau, đau thế nào?

**Phase 2 — Users & jobs**
- Ai sẽ dùng? (persona cụ thể, không phải "mọi người")
- Hiện họ đang giải quyết vấn đề này bằng cách nào? (workaround hiện tại)
- "Job-to-be-done" — họ thuê sản phẩm này để làm xong việc gì?

**Phase 3 — Scope (MVP)**
- Phiên bản NHỎ NHẤT mà vẫn có giá trị thật là gì?
- Liệt kê các luồng/user story cốt lõi (3–7 cái, không hơn ở vòng đầu).

**Phase 4 — Non-goals** (đừng bỏ qua)
- Cái gì rõ ràng KHÔNG làm ở phiên bản này?
- Có giả định/kỳ vọng nào cần loại trừ sớm để tránh scope creep?

**Phase 5 — Constraints**
- Ràng buộc kỹ thuật: stack, ngôn ngữ, hạ tầng, có phải tích hợp hệ thống sẵn có không?
- Timeline & nguồn lực: bao nhiêu người, deadline mềm/cứng?
- Compliance/bảo mật/dữ liệu nhạy cảm?

**Phase 6 — Success criteria**
- Định nghĩa "xong" của MVP này là gì?
- Đo lường thành công bằng metric nào? (định lượng nếu được)

**Phase 7 — Risks & open questions**
- Phần nào còn chưa chắc chắn nhất?
- Rủi ro lớn nhất có thể làm hỏng dự án?

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
- **Vấn đề:** ...
- **Why now:** ...
- **Hệ quả nếu không làm:** ...

## 2. Users & Jobs
- **Người dùng:** ... (persona cụ thể)
- **Workaround hiện tại:** ...
- **Job-to-be-done:** ...

## 3. Scope (MVP)
Phiên bản nhỏ nhất có giá trị:
- [ ] Luồng/story 1
- [ ] Luồng/story 2
- [ ] ...

## 4. Non-goals
Rõ ràng KHÔNG làm ở phiên bản này:
- ...
- ...

## 5. Constraints
- **Kỹ thuật:** stack / tích hợp / hạ tầng ...
- **Timeline & nguồn lực:** ...
- **Compliance/bảo mật:** ...

## 6. Success criteria
- **Definition of done:** ...
- **Metric đo lường:** ...

## 7. Open questions & risks
- ❓ Câu hỏi chưa trả lời: ...
- ⚠️ Rủi ro chính: ...
```

Quy tắc khi điền:
- Mỗi mục phải dựa trên câu trả lời thực của người dùng. Mục nào chưa rõ → để vào "Open questions", KHÔNG bịa.
- Giữ Scope ngắn gọn ở vòng đầu — thà ít story rõ ràng còn hơn nhiều story mơ hồ.
- Dùng ngôn ngữ cụ thể, đo được; thay "nhanh" bằng con số, thay "nhiều user" bằng đối tượng cụ thể.

## Gắn ticket board (nếu dự án dùng tracker)

Nếu `.claude/profile.md` có mục `## Task tracker` đã cấu hình: hỏi (optional) story này có gắn ticket trên board không. Nếu có → ghi ID/URL vào trường `Ticket:` ở header, rồi gọi skill **`msdlc:tracking {id} todo`** để đưa ticket về cột intake. Không có tracker hoặc không có ticket → bỏ qua (skill `msdlc:tracking` tự no-op, không cần điều kiện gì thêm).

## Sau khi xong

Báo cho người dùng biết file `.claude/stories/{id}/requirement.md` đã sẵn sàng (nêu rõ `{id}` đã cấp) và đây là input cho bước tiếp theo (thiết kế kiến trúc → vỡ task). Hỏi xem họ muốn đi tiếp tới phase architecture hay chỉnh sửa spec thêm.
