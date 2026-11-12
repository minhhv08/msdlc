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

### GATE — Làm rõ rồi duyệt ADR (BẮT BUỘC dừng)
5. **Làm rõ trước khi xin duyệt — vòng lặp bắt buộc.** ADR chỉ được xin duyệt khi **mọi giả định và câu hỏi đã được chốt**. Đọc mục *Giả định & câu hỏi cần chốt* của `adr.md` (ADR cũ: mục "Assumptions & Open questions" — coi mọi mục chưa có quyết định rõ là chưa chốt) và đếm mục chưa chốt bằng Grep `^- \[ \]`. Còn mục chưa chốt → **KHÔNG xin duyệt**; hỏi user ngay:
   - Dùng **`AskUserQuestion`**, gom tối đa 4 câu/lần. Mỗi mục → một câu, phương án của architect làm option: *câu hỏi* → đề xuất đứng đầu kèm "(Recommended)", rồi phương án khác, rồi (nếu hợp lý) "Đưa ra ngoài scope (ghi follow-up)"; *giả định* → "Đúng, chốt giả định (Recommended)" / "Sai — dùng phương án khác" / "Đưa ra ngoài scope". `description` của option nói ngắn hệ quả. Môi trường không có `AskUserQuestion` → hỏi từng câu một trong chat, kèm phương án đề xuất. Không hỏi lại điều user đã chốt.
   - Không để mục nào treo: user nói "chưa biết" → đề xuất "Chốt theo đề xuất, ghi rủi ro" hoặc "Đưa ra ngoài scope", để mục luôn chốt được.
   - **Xử lý câu trả lời:** (a) user chọn đề xuất / xác nhận giả định / đưa ra ngoài scope → main **Edit** `adr.md`: `- [ ]` → `- [x] … → **Chốt:** … (<hôm nay>)`; ngoài scope thì thêm một dòng vào Consequences/Non-goals của ADR. (b) user chọn phương án khác đề xuất hoặc nhập thông tin mới ("Other") → chạy lại **Agent `architect` chế độ cập nhật**, truyền danh sách câu trả lời (`model` **nâng một bậc** theo G5), rồi đọc lại mục này vì có thể phát sinh mục mới.
   - **Lặp tới khi không còn `- [ ]`.** Chạy lại architect tối đa 3 lần cho một ADR — quá thì dừng, nói rõ mục nào cứ phát sinh và nhờ user chốt tay hoặc sửa requirement. Hết mục → đảm bảo ADR có dòng "Không còn mục chưa chốt."
6. Gọi skill **`msdlc:tracking {id} validate`** (bỏ qua nếu tracker tắt — xem "Quy ước gọi tiết kiệm token" của `msdlc:tracking`) để đưa ticket sang cột Validate + comment tóm tắt ADR.
7. Tóm tắt phương án đã chọn + **các quyết định đã chốt ở bước 5** + đường dẫn `.claude/stories/{id}/adr.md`; ghi kèm **tier + model architect đã dùng** (G5) — user thấy ADR yếu thì yêu cầu chạy lại.
8. **DỪNG hẳn tại đây** và hỏi user có duyệt để build tiếp không (lúc này không còn câu hỏi mở nào). Tuyệt đối **không** tự chạy bước B khi chưa có xác nhận rõ ràng của user. Đây là cổng duyệt duy nhất của pipeline.

### Bước B — Build tự động (skill deliver-story)
9. Chỉ khi user đã duyệt **và** `adr.md` không còn mục `- [ ]` (kiểm lại bằng Grep): **ghi dấu duyệt vào ADR** — cập nhật dòng header của `.claude/stories/{id}/adr.md` từ `Status: Proposed` thành `Status: Accepted · Duyệt: <hôm nay>`. Đây là dấu duyệt bền mà `deliver-story` kiểm tra làm tiền đề — không có nó thì deliver-story từ chối chạy. Sau đó gọi skill **`msdlc:tracking {id} approved`** (bỏ qua nếu tracker tắt — xem "Quy ước gọi tiết kiệm token" của `msdlc:tracking`), rồi gọi **skill `deliver-story`** với story `{id}` (Skill tool). Main agent **tự điều phối** theo hướng dẫn của skill đó bằng Agent tool — KHÔNG dùng Workflow.
10. Main theo sát từng phase và tổng hợp kết quả khi xong.

### Bước C — Báo cáo
11. Tóm tắt cho user:
   - Số task đã plan / đã chạy, danh sách file thay đổi.
   - Trạng thái test: pass / fail (kèm failures) / `infraMissing`.
   - Bảo mật: số finding theo severity; `Critical`/`High` còn lại + đường dẫn báo cáo `.claude/stories/{id}/security/`.
   - `followUps` và lockstep cần chú ý.
   - Nếu đụng schema/dữ liệu được cache theo lockstep của profile → nhắc evict cache (key/lệnh lấy từ profile).
   - Nếu user muốn commit → dùng skill **`msdlc:commit`**.

- **Có thể bỏ qua Bước A** nếu user nói "build luôn từ ADR có sẵn" — nhưng KHÔNG được bỏ qua gate: vẫn **BẮT BUỘC** làm bước 5 (ADR có sẵn mà còn mục chưa chốt thì hỏi user cho tới khi hết), rồi hỏi user xác nhận duyệt ADR một lần rõ ràng, và khi user xác nhận thì ghi `Status: Accepted` vào `adr.md` như ở bước 9, rồi mới vào Bước B. Không có xác nhận → không build.
