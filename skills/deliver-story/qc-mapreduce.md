# Thiết kế test map/reduce — chỉ đọc khi G3 chọn nhánh map/reduce

## Thiết kế test song song (map/reduce, chạy trong lúc dev implement)

Khâu thiết kế test được cắt thành **map/reduce** để không thành đường găng của Phase 3. Ba bước, chạy song song với việc vỡ task + implement:

1. **Map — `qc-leader` (enumerate).** Đã chạy **song song với `dev-leader` ở Phase 1** (không phụ thuộc task breakdown). Nó đọc `requirement.md` + `adr.md` (+ mục liên quan của `adr/design.md`, không đọc `adr/alternatives.md`) + `profile.md` + `rules/`, **chỉ liệt kê stub** (id + title + source + type + priority — KHÔNG viết steps chi tiết), cấp **id toàn cục duy nhất**, đề xuất **bucket cân bằng**, và trả JSON:

   ```json
   { "stubs": [ { "id": "TC-001", "title": "...", "source": "REQ-3 / ADR §2", "type": "Functional|Negative|Boundary|NFR|Integration|Regression", "priority": "High|Medium|Low" } ],
     "buckets": [ ["TC-001", "TC-004"], ["TC-002", "TC-003"] ],
     "coverageGaps": [ "<item requirement/ADR chưa phủ / ambiguity / open question>" ] }
   ```

2. **Fan-out — `qc-designer` × N (chế độ design-subset).** Vì `buckets` đã sẵn sau Phase 1, phát fan-out **ngay ở Wave 1** (kèm cùng message với dev, xem step 3). Với **mỗi bucket** trong `buckets`, phát **một Agent `qc-designer` riêng**, truyền danh sách stub của bucket đó + **file output riêng** `.claude/stories/{id}/tests/testcases-part-{k}.md` (k = 1..N). Mỗi instance flesh-out stub thành đặc tả đầy đủ (Preconditions/Test Data/Steps/Expected/Notes), **giữ nguyên `id`/`source` từ stub**, không đẻ case ngoài stub, trả JSON `{ file, casesWritten, designed, gaps, followUps }`. Các file part rời nhau và rời hoàn toàn với `tasks/`/code → an toàn chạy song song với nhau và với dev. Nếu chỉ có 1 bucket (story nhỏ) → chỉ 1 `qc-designer`, không fan-out thừa.

3. **Reduce — main tự ghép, KHÔNG gọi `qc-leader` merge, KHÔNG đọc lại file part.** Sau khi mọi `qc-designer` xong, main ghi `.claude/stories/{id}/tests/README.md` chỉ từ dữ liệu đã có trong tay:
   - **Traceability Matrix:** nhóm stub theo `source` → danh sách id (+ title, type, priority, file part chứa nó). Stub nào **không có** trong `designed` của designer phụ trách → đánh dấu *chưa thiết kế*.
   - **Phân bố theo `type`** (đếm từ stub) — để người đọc thấy ngay vùng mỏng.
   - **Coverage & Gaps:** `coverageGaps` của enumerate + `gaps` của từng designer + stub chưa thiết kế + bucket lỗi/skip (designer trả JSON hỏng hoặc không ghi file).
   - Link tới các `tests/testcases-part-*.md`. Không tự bịa case mới; gap → `followUps` của Phase 5.
   Designer trả JSON thiếu `designed` → coi như đã thiết kế đủ `casesWritten` stub đầu của bucket nếu khớp số lượng, không khớp thì ghi gap "không xác minh được bucket k" — chỉ khi đó mới được Grep id trong file part đó để đối chiếu (không Read nguyên file).

> enumerate overlap với khâu vỡ task ở Phase 1; fan-out design overlap với dev implement (bắt đầu ngay Wave 1). Đến Phase 3 đã có test suite + traceability sẵn.
