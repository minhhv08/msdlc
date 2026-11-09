# Thiết kế test map/reduce — chỉ đọc khi G3 chọn nhánh map/reduce

## Thiết kế test song song (map/reduce, chạy trong lúc dev implement)

Khâu thiết kế test được cắt thành **map/reduce** để không thành đường găng của Phase 3. Ba bước, chạy song song với việc vỡ task + implement:

1. **Map — `qc-leader` (enumerate).** Đã chạy **song song với `dev-leader` ở Phase 1** (không phụ thuộc task breakdown). Nó đọc `requirement.md` + `adr.md` + `profile.md` + `rules/`, **chỉ liệt kê stub** (id + title + source + type + priority — KHÔNG viết steps chi tiết), cấp **id toàn cục duy nhất**, đề xuất **bucket cân bằng**, và trả JSON:

   ```json
   { "stubs": [ { "id": "TC-001", "title": "...", "source": "REQ-3 / ADR §2", "type": "Functional|Negative|Boundary|NFR|Integration|Regression", "priority": "High|Medium|Low" } ],
     "buckets": [ ["TC-001", "TC-004"], ["TC-002", "TC-003"] ],
     "coverageGaps": [ "<item requirement/ADR chưa phủ / ambiguity / open question>" ] }
   ```

2. **Fan-out — `qc-designer` × N (chế độ design-subset).** Vì `buckets` đã sẵn sau Phase 1, phát fan-out **ngay ở Wave 1** (kèm cùng message với dev, xem step 3). Với **mỗi bucket** trong `buckets`, phát **một Agent `qc-designer` riêng**, truyền danh sách stub của bucket đó + **file output riêng** `.claude/stories/{id}/tests/testcases-part-{k}.md` (k = 1..N). Mỗi instance flesh-out stub thành đặc tả đầy đủ (Preconditions/Test Data/Steps/Expected/Notes), **giữ nguyên `id`/`source` từ stub**, không đẻ case ngoài stub, trả JSON `{ file, casesWritten, followUps }`. Các file part rời nhau và rời hoàn toàn với `tasks/`/code → an toàn chạy song song với nhau và với dev. Nếu chỉ có 1 bucket (story nhỏ) → chỉ 1 `qc-designer`, không fan-out thừa.

3. **Reduce — `qc-leader` (merge).** Chỉ khi có ≥ 2 bucket (1 bucket → main tự ghi `tests/README.md` gọn, xem G3). Sau khi tất cả `qc-designer` design-subset xong, phát lại **Agent `qc-leader` (chế độ merge)**: đọc các `tests/testcases-part-*.md` + `coverageGaps` từ bước enumerate, ghi `.claude/stories/{id}/tests/README.md` (Traceability Matrix tổng + Coverage & Gaps), trả JSON `{ totalCases, gaps }`. Gap rõ → đưa vào `followUps` của Phase 5.

> enumerate overlap với khâu vỡ task ở Phase 1; fan-out design + merge overlap với dev implement (bắt đầu ngay Wave 1). Đến Phase 3 đã có test suite + traceability sẵn.
