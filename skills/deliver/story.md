# deliver — luồng STORY (chỉ đọc khi id là story)

## Quy trình (story — main agent tự thực thi)

### Bước 0 — Tiền kiểm
1. Xác định `{id}` (đã có `requirement.md` theo bước định tuyến).
2. Nhắc tiền đề hạ tầng cho bước QC (qc-executor sẽ chạy test): các dependency local theo mục **Hạ tầng local** trong `.claude/profile.md` (vd DB/cache + cổng) cần up trước.
   Nếu chưa up, QC có thể trả `infraMissing` — vẫn chạy được tới đó rồi báo cáo.

### Bước A — Thiết kế kiến trúc (architect)
3. Gọi skill **`msdlc:tracking {id} planning`** (bỏ qua nếu tracker tắt — xem "Quy ước gọi tiết kiệm token" của `msdlc:tracking`) để đưa ticket sang cột Planning.
4. Nếu `.claude/stories/{id}/adr.md` **chưa có**: Read `../deliver-story/gating.md` mục **G5**, tính tier từ `requirement.md`, rồi gọi **Agent `architect`** cho story đó với tham số `model` theo bảng G5 (đọc requirement, ghi `adr.md` lõi + `adr/*.md` chi tiết khi cần + cập nhật `docs/architecture.md`).
   Nếu `adr.md` **đã có**: hỏi user muốn dùng lại ADR cũ hay chạy lại architect để cập nhật. Chạy lại architect sau góp ý của user ở GATE → **nâng một bậc** tier (G5).

### GATE — Duyệt ADR (BẮT BUỘC dừng)
5. Gọi skill **`msdlc:tracking {id} validate`** (bỏ qua nếu tracker tắt — xem "Quy ước gọi tiết kiệm token" của `msdlc:tracking`) để đưa ticket sang cột Validate + comment link ADR.
6. Tóm tắt phương án đã chọn + Open questions + đường dẫn `.claude/stories/{id}/adr.md`; ghi kèm **tier + model architect đã dùng** (G5) — user thấy ADR yếu thì yêu cầu chạy lại.
7. **DỪNG hẳn tại đây** và hỏi user có duyệt để build tiếp không. Tuyệt đối **không** tự chạy bước B khi chưa có xác nhận rõ ràng của user. Đây là cổng duyệt duy nhất của pipeline.

### Bước B — Build tự động (skill deliver-story)
8. Chỉ khi user đã duyệt: **ghi dấu duyệt vào ADR** — cập nhật dòng header của `.claude/stories/{id}/adr.md` từ `Status: Proposed` thành `Status: Accepted · Duyệt: <hôm nay>`. Đây là dấu duyệt bền mà `deliver-story` kiểm tra làm tiền đề — không có nó thì deliver-story từ chối chạy. Sau đó gọi skill **`msdlc:tracking {id} approved`** (bỏ qua nếu tracker tắt — xem "Quy ước gọi tiết kiệm token" của `msdlc:tracking`), rồi gọi **skill `deliver-story`** với story `{id}` (Skill tool). Main agent **tự điều phối** theo hướng dẫn của skill đó bằng Agent tool — KHÔNG dùng Workflow.
9. Main theo sát từng phase và tổng hợp kết quả khi xong.

### Bước C — Báo cáo
10. Tóm tắt cho user:
   - Số task đã plan / đã chạy, danh sách file thay đổi.
   - Trạng thái test: pass / fail (kèm failures) / `infraMissing`.
   - Bảo mật: số finding theo severity; `Critical`/`High` còn lại + đường dẫn báo cáo `.claude/stories/{id}/security/`.
   - `followUps` và lockstep cần chú ý.
   - Nếu đụng schema/dữ liệu được cache theo lockstep của profile → nhắc evict cache (key/lệnh lấy từ profile).
   - Nếu user muốn commit → dùng skill **`msdlc:commit`**.

- **Có thể bỏ qua Bước A** nếu user nói "build luôn từ ADR có sẵn" — nhưng KHÔNG được bỏ qua gate: vẫn **BẮT BUỘC** hỏi user xác nhận duyệt ADR một lần rõ ràng, và khi user xác nhận thì ghi `Status: Accepted` vào `adr.md` như ở bước 8, rồi mới vào Bước B. Không có xác nhận → không build.
