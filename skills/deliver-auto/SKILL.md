---
name: deliver-auto
description: >-
  Từ ADR đã duyệt của một story id: vỡ task (dev-leader) **song song** thiết kế test (qc-designer) → implement song song theo file-disjoint (dev-backend/dev-frontend) → chạy test + audit bảo mật song song (qc-executor + security-auditor, auto-fix ≤2) → đồng bộ docs (chronicler). Main agent TỰ điều phối bằng Agent tool (không dùng Workflow). Dùng khi .claude/stories/{id}/adr.md đã được duyệt và muốn tự động build + test + sync docs. Gọi qua skill /deliver (Bước B) hoặc trực tiếp với một story id. KHÔNG tự chạy nếu ADR chưa được duyệt.
---

# deliver-auto — Build tự động một story (main điều phối)

Main agent **tự điều phối** chuỗi agent có sẵn bằng **Agent tool** — không dùng Workflow. Mục tiêu: nhanh và minh bạch, main giữ quyền kiểm soát, chạy song song tối đa những việc không đụng nhau, và báo cáo trung thực.

**Tiền đề:** `.claude/stories/{id}/adr.md` đã tồn tại **và đã được user duyệt** (thường do `/deliver` lo cổng duyệt). Nếu chưa có ADR → dừng, báo user chạy bước architect/`/deliver` trước. KHÔNG tự bịa.

**Input:** một story id (vd `002`). Nếu không có → liệt kê `.claude/stories/` và hỏi, hoặc dùng id duy nhất nếu chỉ có một.

---

## Phase 1 — Plan + QC enumerate (song song)

Trước khi bắt đầu, gọi skill **`msdlc:tracking {id} in-progress`** (tự no-op nếu không có tracker) để đưa ticket sang cột InProgress.

Phát **hai Agent trong cùng một message** — chúng đều chỉ đọc `adr.md` + `requirement.md` + `profile.md` + `rules/`, không phụ thuộc dữ liệu của nhau và không đụng file (dev-leader ghi `tasks/`, qc-leader enumerate không ghi file), nên chạy song song an toàn:

- **Agent `dev-leader`** — vỡ task (mô tả ngay dưới).
- **Agent `qc-leader` (chế độ enumerate)** — liệt kê test-case stub + đề xuất bucket cân bằng + coverage (xem "Thiết kế test song song" ở Phase 2 cho JSON trả về). Chạy sớm ở đây để `buckets` sẵn sàng ngay khi vào Phase 2, cho phép fan-out `qc-designer` ngay từ Wave 1.

Gọi **Agent `dev-leader`**: đọc ĐẦY ĐỦ `.claude/stories/{id}/adr.md` + `.claude/stories/{id}/requirement.md`, vỡ thành task atomic, GHI ra `.claude/stories/{id}/tasks/NN-slug.md` + `.claude/stories/{id}/tasks/README.md` (index + dependency graph), và **trả về danh sách task có cấu trúc**, mỗi task gồm:

- `id` (vd `"01"`), `file` (tên file task đã ghi), `title`
- `project`: một trong các project tên trong `.claude/profile.md` | `docs` | `cross-cutting`
- `agent`: `dev-backend` (mọi code server-side — bất kỳ ngôn ngữ/framework backend nào theo profile) | `dev-frontend` (UI web)
- `dependsOn`: danh sách task id phụ thuộc (rỗng nếu không)
- `touchesFiles`: đường dẫn (từ gốc workspace) các file/thư mục task sẽ TẠO/SỬA — **kể cả file dùng chung** (file build/deps, file cấu hình, lớp đăng ký route/bean/filter, registry/đối tượng dùng chung của lockstep…). Khai báo càng đầy đủ càng song song được nhiều; để rỗng nếu không chắc (sẽ bị xếp tuần tự cho an toàn).

Yêu cầu dev-leader tôn trọng **hợp đồng lockstep** mô tả trong `.claude/profile.md`: vd migration immutable (thêm bản mới thay vì sửa bản đã apply), các artifact phải đồng bộ 1-1, thứ tự migration của project sở hữu schema trước các phía phụ thuộc.

Nếu dev-leader không trả task nào → dừng và báo user.

> Nguồn sự thật cho graph là danh sách dev-leader trả về. Nếu cần, đọc lại `.claude/stories/{id}/tasks/` để đối chiếu/dọn file trùng số thứ tự.

---

## Phase 2 — Implement (wave song song theo file-disjoint) + QC design song song

Triển khai theo **wave topo**. Lặp tới khi mọi task xong:

1. **Tập sẵn sàng** = các task chưa làm mà MỌI `dependsOn` đã xong (bỏ qua dep không tồn tại).
2. **Chọn wave** — gom tối đa ~6 task sẵn sàng có **tập `touchesFiles` rời nhau**:
   - Hai task **khác project** → không bao giờ đụng file chung → luôn chạy song song được.
   - Hai task **cùng project** → song song được **chỉ khi** `touchesFiles` không giao nhau (so cả prefix thư mục). Nếu giao dù 1 file → để task sau sang wave kế.
   - Task không khai báo `touchesFiles` (rỗng) → thận trọng: chỉ chạy một mình trong project đó ở wave này.
3. **Chạy song song**: phát **nhiều lệnh Agent trong cùng một message** cho các task trong wave (mỗi task → đúng `agent` của nó). **Ở Wave 1 (đầu tiên), kèm thêm các Agent `qc-designer` (chế độ design-subset) — một cho mỗi bucket mà `qc-leader` đã trả ở Phase 1** — vào cùng message để flesh-out test song song với dev (xem "Thiết kế test song song" bên dưới). Chúng chỉ ghi vào các file `tests/testcases-part-*.md` rời nhau (rời hoàn toàn với `tasks/`/code), nên an toàn chạy chung. Đây là điểm tăng tốc chính so với chạy lần lượt.
4. Mỗi dev agent nhận chỉ thị **idempotent check-before-write**:
   - Đọc `.claude/stories/{id}/tasks/{file}` (task spec) + `.claude/stories/{id}/adr.md` (bám thiết kế).
   - Đối chiếu codebase với "Acceptance criteria": nếu đã đạt hết → KHÔNG sửa, báo `already-done`; thiếu một phần → chỉ bổ sung (`partial`); chưa có → làm đầy đủ (`implemented`); không làm được → `skipped` kèm lý do.
   - Tôn trọng hợp đồng lockstep trong profile & nhắc evict cache (key/lệnh theo profile) nếu đụng dữ liệu được cache.
   - Trả về JSON block: `status`, `filesChanged` (chỉ file thực sự đụng lần này), `summary`, `followUps`.
5. Sau mỗi wave: với mỗi task trong wave, **append `## Result` vào task file** (`.claude/stories/{id}/tasks/{file}`) dựa trên JSON return của dev agent:

   ```markdown
   ## Result

   - **Status:** implemented | already-done | partial | skipped
   - **Files changed:** src/foo/bar.ts, src/foo/baz.ts
   - **Summary:** <một dòng mô tả dev đã làm gì>
   - **Follow-ups:** <lockstep, cache eviction, hoặc để trống>
   ```

   Ghi kể cả khi agent fail/skip (status = `skipped`, summary = lý do). Sau đó gom `filesChanged` + `followUps` toàn wave, đánh dấu task là done, sang wave kế. Nếu hết task ready mà chưa xong (cycle/lỗi) → log cảnh báo và dừng phase.

**An toàn:** không bao giờ chạy song song hai agent đụng cùng file → tránh ghi đè. KHÔNG dùng git worktree (thay đổi ở worktree riêng không gộp lại thành cây build được); luôn làm trên cùng working tree với tập file rời nhau.

### Thiết kế test song song (map/reduce, chạy trong lúc dev implement)

Khâu thiết kế test được cắt thành **map/reduce** để không thành đường găng của Phase 3. Ba bước, chạy song song với việc vỡ task + implement:

1. **Map — `qc-leader` (enumerate).** Đã chạy **song song với `dev-leader` ở Phase 1** (không phụ thuộc task breakdown). Nó đọc `requirement.md` + `adr.md` + `profile.md` + `rules/`, **chỉ liệt kê stub** (id + title + source + type + priority — KHÔNG viết steps chi tiết), cấp **id toàn cục duy nhất**, đề xuất **bucket cân bằng**, và trả JSON:

   ```json
   { "stubs": [ { "id": "TC-001", "title": "...", "source": "REQ-3 / ADR §2", "type": "Functional|Negative|Boundary|NFR|Integration|Regression", "priority": "High|Medium|Low" } ],
     "buckets": [ ["TC-001", "TC-004"], ["TC-002", "TC-003"] ],
     "coverageGaps": [ "<item requirement/ADR chưa phủ / ambiguity / open question>" ] }
   ```

2. **Fan-out — `qc-designer` × N (chế độ design-subset).** Vì `buckets` đã sẵn sau Phase 1, phát fan-out **ngay ở Wave 1** (kèm cùng message với dev, xem step 3). Với **mỗi bucket** trong `buckets`, phát **một Agent `qc-designer` riêng**, truyền danh sách stub của bucket đó + **file output riêng** `.claude/stories/{id}/tests/testcases-part-{k}.md` (k = 1..N). Mỗi instance flesh-out stub thành đặc tả đầy đủ (Preconditions/Test Data/Steps/Expected/Notes), **giữ nguyên `id`/`source` từ stub**, không đẻ case ngoài stub, trả JSON `{ file, casesWritten, followUps }`. Các file part rời nhau và rời hoàn toàn với `tasks/`/code → an toàn chạy song song với nhau và với dev. Nếu chỉ có 1 bucket (story nhỏ) → chỉ 1 `qc-designer`, không fan-out thừa.

3. **Reduce — `qc-leader` (merge).** Sau khi tất cả `qc-designer` design-subset xong, phát lại **Agent `qc-leader` (chế độ merge)**: đọc các `tests/testcases-part-*.md` + `coverageGaps` từ bước enumerate, ghi `.claude/stories/{id}/tests/README.md` (Traceability Matrix tổng + Coverage & Gaps), trả JSON `{ totalCases, gaps }`. Gap rõ → đưa vào `followUps` của Phase 5.

> enumerate overlap với khâu vỡ task ở Phase 1; fan-out design + merge overlap với dev implement (bắt đầu ngay Wave 1). Đến Phase 3 đã có test suite + traceability sẵn.

---

## Phase 2.5 — Code Review (reviewer, auto-fix ≤ 1 vòng)

Gọi **Agent `reviewer`** với story id: đọc `git diff` + `.claude/stories/{id}/adr.md` + `.claude/stories/{id}/requirement.md` + `.claude/profile.md` + `.claude/rules/` (mọi file rule), review implementation theo các dimensions (correctness vs spec, lockstep, logic, convention & project rules, test alignment, readability), ghi `.claude/stories/{id}/review/review-attempt-1.md`, và trả JSON `{ approved, blockingFindings, suggestions, summary }`. Mỗi finding bám một rule mang thêm field `ruleId` (vd `"R-BE-1"`); vi phạm rule `MUST` → `blockingFindings`, vi phạm rule `SHOULD` → `suggestions`.

**Xử lý kết quả:**
- `approved: true` → tiếp Phase 3.
- `approved: false` (có `blockingFindings`) → gọi **Agent dev** (backend/frontend tùy file bị flag) để **chỉ sửa các blocking findings, KHÔNG đổi scope** → re-run reviewer 1 lần nữa (ghi `review-attempt-2.md`).
- Sau 1 vòng fix: tiếp Phase 3 dù còn blocking findings — đưa findings còn lại vào Phase 5 dưới dạng `followUps`.

> Ngân sách: ≤ 1 vòng fix, độc lập với ngân sách ≤ 2 vòng của Phase 3.

---

## Phase 3 — QC + Security (song song, auto-fix ≤ 2)

> Test case đã được thiết kế theo map/reduce (`qc-leader` enumerate → `qc-designer` × N design-subset → `qc-leader` merge) song song từ Wave 1 của Phase 2 (ghi tại `.claude/stories/{id}/tests/`, tổng hợp ở `tests/README.md`). Việc này chạy trong lúc dev implement, nên đến Phase 3 đã có test suite + traceability sẵn. Phase này chạy test **và** audit bảo mật song song trên cùng phần code vừa implement.

Phát **cùng một message** tất cả Agent sau song song — chúng chạy trên project/scope rời nhau nên không đụng file:

1a. **Agent `qc-executor` × N project** — lấy danh sách project đã có task trong story này (từ structured task list của dev-leader, Phase 1). Với **mỗi project** có lệnh test trong `.claude/profile.md`, phát **một Agent `qc-executor` riêng** trong cùng message, chỉ định rõ project scope. Mỗi instance trả về `project`, `allPassed`, `infraMissing`, `failures[{test,message}]`, `report`.

> Ví dụ: story đụng 2 project backend + 1 project frontend → phát 3 `qc-executor` song song trong 1 message.

1b. **Agent `security-auditor`** (song song với các qc-executor) — audit diff của story này tìm lỗ hổng (theo lockstep/secrets/cache của profile **và rule `R-SEC-*` trong `.claude/rules/security.md`**). Ghi báo cáo vào `.claude/stories/{id}/security/` và trả về `findings[{severity,title,file,line,remediation,ruleId}]`. Vi phạm rule `MUST` trong `security.md` được nâng severity tối thiểu `High` (kèm `ruleId`) nên sẽ lọt vòng auto-fix Critical/High dưới đây.

2. **Ghi execution report & vòng auto-fix (ngân sách chung ≤ 2 vòng):**

   Sau mỗi lần chạy qc-executor (lần đầu hoặc re-run), với mỗi project **ghi** `.claude/stories/{id}/tests/{project}-execution-attempt-{N}.md`:

   ```markdown
   # Execution Report — {project} (attempt {N})

   - **Status:** PASS | FAIL | BLOCKED
   - **Commands run:** <lệnh thực tế đã chạy>
   - **Result:** {passed}/{total} passed, {skipped} skipped
   - **Infra missing:** yes | no

   ## Failures
   | Test | Message |
   |---|---|
   | TestFoo#testBar | AssertionError: expected 200 but was 500 |

   ## Notes
   <environmental issues, stale-cache risk, lockstep mismatches>
   ```

   (Nếu `allPassed` và không có failure, mục Failures để trống.)

   Sau khi đã ghi report:
   - Mọi project `allPassed` **và** không có finding `Critical`/`High` → xong Phase 3.
   - `infraMissing` (hạ tầng test chưa up) → phần test **không tự fix được**, báo cáo trung thực; vẫn xử lý phần security.
   - Còn lượt mà có **test `failures`** hoặc finding **`Critical`/`High`** → tăng `attempt`, gọi **Agent dev** (lỗi backend → `dev-backend`, lỗi UI → `dev-frontend`) để **chỉ sửa cho qua test + bịt lỗ hổng Critical/High, không đổi scope**, rồi chạy lại **chỉ qc-executor cho project bị lỗi** (và/hoặc security-auditor nếu có finding chưa fix) — ghi report của lần chạy mới với `attempt` tăng lên.
   - **Tối đa 2 vòng fix.** Sau 2 vòng vẫn còn → dừng, báo cáo `failures` + findings còn lại.
   - Finding `Medium`/`Low`/`Info` → **không chặn**, đưa vào báo cáo Phase 5 dưới dạng `followUps`.

---

## Phase 4 — Docs (chronicler)

Gọi **Agent `chronicler`**: đồng bộ README/docs/docstring/inline comment với code vừa đổi. Lưu ý `docs/architecture.md` đã được architect cập nhật ở bước thiết kế — chỉ bổ sung phần còn lệch, không tự thêm tính năng chưa có trong code.

---

## Phase 5 — Báo cáo

Ghi **`.claude/stories/{id}/report.md`** với nội dung sau, rồi tóm tắt ngắn cho user trong conversation và dẫn link file:

```markdown
# Delivery Report — {id}

> Generated: {date}

## Tasks

| # | Title | Agent | Status | Files changed |
|---|---|---|---|---|
| 01 | ... | dev-backend | implemented | src/foo.ts |

**Summary:** {N} tasks — {implemented} implemented, {already-done} already-done, {partial} partial, {skipped} skipped.

## Code Review

| Attempt | Approved | Blocking | Suggestions | Report |
|---|---|---|---|---|
| 1 | No | 2 | 4 | review/review-attempt-1.md |
| 2 | Yes | 0 | 2 | review/review-attempt-2.md |

## Tests

| Project | Status | Passed | Failed | Attempts | Report |
|---|---|---|---|---|---|
| payment-service | PASS | 42 | 0 | 1 | tests/payment-service-execution-attempt-1.md |

> BLOCKED projects (infra missing): ...

## Security

| Severity | Count | Status |
|---|---|---|
| Critical | 0 | — |
| High | 1 | fixed |
| Medium | 2 | followUp |

Security reports: `.claude/stories/{id}/security/`

## Follow-ups

- [ ] <lockstep, cache eviction, open items>

## Notes

<cache eviction keys cần chạy, infra còn thiếu, vi phạm rule còn lại (kèm ruleId), v.v.>
```

> Khi liệt kê blocking findings / security findings còn lại trong report, ghi kèm `ruleId` nếu finding bám một rule trong `.claude/rules/` — để truy vết về rule cụ thể.

Sau khi ghi `report.md`: gọi skill **`msdlc:tracking {id} review`** (tự no-op nếu không có tracker) để đưa ticket sang cột Review + comment tóm tắt. **KHÔNG tự chuyển Done** — Review chờ người verify rồi đóng thủ công.

Nếu user muốn commit → dùng skill **`msdlc:commit`**.

## Nguyên tắc

- **Main tự điều phối bằng Agent tool** — chạy song song tối đa các task file-disjoint; không dùng Workflow.
- **Không sửa định nghĩa agent** — chỉ tái dùng qua Agent tool.
- **Idempotent** — luôn check-before-write để chạy lại trên codebase đã có không phá đồ.
- **Trung thực trạng thái** — test fail / thiếu hạ tầng phải báo đúng.
- **Sync tracker chỉ chuyển cột, không tự chuyển Done.** Các lời gọi `msdlc:tracking` (in-progress/review) là side-effect tự no-op khi không có tracker; Review là điểm dừng cuối của máy, Done do người.
