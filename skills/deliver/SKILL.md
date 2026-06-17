---
name: deliver
description: >-
  Tự động hoá toàn bộ pipeline từ requirement đến done cho một story id: thiết kế kiến trúc (architect) → DỪNG chờ duyệt ADR → vỡ task + implement + QC + sync docs (skill auto-deliver, main tự điều phối). LUÔN dùng skill này khi user gõ `/deliver {id}`, hoặc nói "chạy pipeline cho story X", "tự động làm requirement X từ đầu tới cuối", "deliver story X", "build feature từ requirement". Tiền đề: đã có .claude/stories/{id}/requirement.md (tạo bằng /spec). KHÔNG dùng khi user chỉ muốn chạy lẻ một bước (architect/planner/dev) — gọi thẳng agent tương ứng.
---

# /deliver — Tự động hoá pipeline requirement → done

Điều phối chuỗi agent đã có trong workspace để hoàn thành một requirement từ đầu tới cuối, với **đúng một cổng duyệt sau ADR**.

Pipeline: `architect` → **[GATE duyệt ADR]** → skill `auto-deliver` (main tự điều phối: `planner` → `dev-*` song song theo file-disjoint → `qc-designer` → `qc-executor`+`security-auditor` song song (auto-fix ≤2) → `chronicler`).

## Input

- Tham số là **story id**, ví dụ `/deliver 001`. Nếu user không đưa id → liệt kê `.claude/stories/` và hỏi, hoặc dùng id duy nhất nếu chỉ có một.

## Quy trình (main agent tự thực thi)

### Bước 0 — Tiền kiểm
1. Xác định `{id}`. Kiểm tra `.claude/stories/{id}/requirement.md` tồn tại.
   - Nếu **thiếu** → dừng, báo user chạy `/spec` trước để tạo requirement. KHÔNG tự bịa requirement.
2. Nhắc tiền đề hạ tầng cho bước QC (qc-executor sẽ chạy test): các dependency local theo mục **Hạ tầng local** trong `.claude/profile.md` (vd DB/cache + cổng) cần up trước.
   Nếu chưa up, QC có thể trả `infraMissing` — vẫn chạy được tới đó rồi báo cáo.

### Bước A — Thiết kế kiến trúc (architect)
3. Nếu `.claude/stories/{id}/adr.md` **chưa có**: gọi **Agent `architect`** cho story đó (đọc requirement, ghi `.claude/stories/{id}/adr.md` + cập nhật `docs/architecture.md`).
   Nếu `adr.md` **đã có**: hỏi user muốn dùng lại ADR cũ hay chạy lại architect để cập nhật.

### GATE — Duyệt ADR (BẮT BUỘC dừng)
4. Tóm tắt phương án đã chọn + Open questions + đường dẫn `.claude/stories/{id}/adr.md`.
5. **DỪNG hẳn tại đây** và hỏi user có duyệt để build tiếp không. Tuyệt đối **không** tự chạy bước B khi chưa có xác nhận rõ ràng của user. Đây là cổng duyệt duy nhất của pipeline.

### Bước B — Build tự động (skill auto-deliver)
6. Chỉ khi user đã duyệt: gọi **skill `auto-deliver`** với story `{id}` (Skill tool). Main agent **tự điều phối** theo hướng dẫn của skill đó bằng Agent tool — KHÔNG dùng Workflow.
   Trình tự: planner vỡ task → dev agent implement theo wave topo, **song song mọi task có tập file rời nhau** (nhiều lệnh Agent trong một message), tuần tự khi đụng file chung → qc-designer thiết kế test → qc-executor chạy test + security-auditor audit (song song; test fail hoặc lỗ hổng Critical/High thì dev fix rồi chạy lại, tối đa 2 vòng) → chronicler.
7. Main theo sát từng phase và tổng hợp kết quả khi xong.

### Bước C — Báo cáo
8. Tóm tắt cho user:
   - Số task đã plan / đã chạy, danh sách file thay đổi.
   - Trạng thái test: pass / fail (kèm failures) / `infraMissing`.
   - Bảo mật: số finding theo severity; `Critical`/`High` còn lại + đường dẫn báo cáo `.claude/stories/{id}/security/`.
   - `followUps` và lockstep cần chú ý.
   - Nếu đụng schema/dữ liệu được cache theo lockstep của profile → nhắc evict cache (key/lệnh lấy từ profile).
   - Nếu user muốn commit → dùng skill **`msdlc:commit`**.

## Nguyên tắc

- **Một cổng duyệt duy nhất, sau ADR.** Không thêm gate ở các bước khác; không tự vượt gate.
- **Không sửa định nghĩa agent.** Workflow tái dùng agent hiện có qua `agentType`.
- **Trung thực trạng thái.** Test fail/hạ tầng thiếu phải báo đúng, không tô hồng.
- **Có thể bỏ qua Bước A** nếu user nói "build luôn từ ADR có sẵn" — khi đó nhảy thẳng vào Bước B (vẫn nên xác nhận 1 lần).
