---
name: auto-deliver
description: >-
  Từ ADR đã duyệt của một story id: vỡ task (planner) **song song** thiết kế test (qc-designer) → implement song song theo file-disjoint (dev-backend/dev-frontend) → chạy test + audit bảo mật song song (qc-executor + security-auditor, auto-fix ≤2) → đồng bộ docs (doc-syncer). Main agent TỰ điều phối bằng Agent tool (không dùng Workflow). Dùng khi .claude/stories/{id}/adr.md đã được duyệt và muốn tự động build + test + sync docs. Gọi qua skill /deliver (Bước B) hoặc trực tiếp với một story id. KHÔNG tự chạy nếu ADR chưa được duyệt.
---

# auto-deliver — Build tự động một story (main điều phối)

Main agent **tự điều phối** chuỗi agent có sẵn bằng **Agent tool** — không dùng Workflow. Mục tiêu: nhanh và minh bạch, main giữ quyền kiểm soát, chạy song song tối đa những việc không đụng nhau, và báo cáo trung thực.

**Tiền đề:** `.claude/stories/{id}/adr.md` đã tồn tại **và đã được user duyệt** (thường do `/deliver` lo cổng duyệt). Nếu chưa có ADR → dừng, báo user chạy bước architect/`/deliver` trước. KHÔNG tự bịa.

**Input:** một story id (vd `002`). Nếu không có → liệt kê `.claude/stories/` và hỏi, hoặc dùng id duy nhất nếu chỉ có một.

---

## Phase 1 — Plan + QC design (song song)

Phát **cùng một message** hai Agent chạy song song — chúng chỉ đọc `requirement.md` + `adr.md` (có sẵn trước phase này) và ghi ra **thư mục rời nhau** (`tasks/` vs `tests/`) nên không bao giờ đụng file:

### 1a. Agent `planner`

Gọi **Agent `planner`** (1 lần): đọc ĐẦY ĐỦ `.claude/stories/{id}/adr.md` + `.claude/stories/{id}/requirement.md`, vỡ thành task atomic, GHI ra `.claude/stories/{id}/tasks/NN-slug.md` + `.claude/stories/{id}/tasks/README.md` (index + dependency graph), và **trả về danh sách task có cấu trúc**, mỗi task gồm:

- `id` (vd `"01"`), `file` (tên file task đã ghi), `title`
- `project`: một trong các project tên trong `.claude/profile.md` | `docs` | `cross-cutting`
- `agent`: `dev-backend` (mọi code server-side — bất kỳ ngôn ngữ/framework backend nào theo profile) | `dev-frontend` (UI web)
- `dependsOn`: danh sách task id phụ thuộc (rỗng nếu không)
- `touchesFiles`: đường dẫn (từ gốc workspace) các file/thư mục task sẽ TẠO/SỬA — **kể cả file dùng chung** (file build/deps, file cấu hình, lớp đăng ký route/bean/filter, registry/đối tượng dùng chung của lockstep…). Khai báo càng đầy đủ càng song song được nhiều; để rỗng nếu không chắc (sẽ bị xếp tuần tự cho an toàn).

Yêu cầu planner tôn trọng **hợp đồng lockstep** mô tả trong `.claude/profile.md`: vd migration immutable (thêm bản mới thay vì sửa bản đã apply), các artifact phải đồng bộ 1-1, thứ tự migration của project sở hữu schema trước các phía phụ thuộc.

Nếu planner không trả task nào → dừng và báo user.

> Nguồn sự thật cho graph là danh sách planner trả về. Nếu cần, đọc lại `.claude/stories/{id}/tasks/` để đối chiếu/dọn file trùng số thứ tự.

### 1b. Agent `qc-designer` (song song với planner)

Gọi **Agent `qc-designer`**: đọc `requirement.md` + `adr.md`, thiết kế test case (positive/negative/boundary/edge) + traceability + coverage/gaps, ghi vào `.claude/stories/{id}/tests/`. Vì chạy trước implement nên **thiết kế bám spec/ADR** (không bám diff — chưa có code thay đổi). Test suite này làm input cho qc-executor ở Phase 3.

> qc-designer **không phụ thuộc** output của planner: không đọc `tasks/`, không ghi vào `tasks/`. Hai agent độc lập hoàn toàn → an toàn chạy chung một wave.

---

## Phase 2 — Implement (wave song song theo file-disjoint)

Triển khai theo **wave topo**. Lặp tới khi mọi task xong:

1. **Tập sẵn sàng** = các task chưa làm mà MỌI `dependsOn` đã xong (bỏ qua dep không tồn tại).
2. **Chọn wave** — gom tối đa ~6 task sẵn sàng có **tập `touchesFiles` rời nhau**:
   - Hai task **khác project** → không bao giờ đụng file chung → luôn chạy song song được.
   - Hai task **cùng project** → song song được **chỉ khi** `touchesFiles` không giao nhau (so cả prefix thư mục). Nếu giao dù 1 file → để task sau sang wave kế.
   - Task không khai báo `touchesFiles` (rỗng) → thận trọng: chỉ chạy một mình trong project đó ở wave này.
3. **Chạy song song**: phát **nhiều lệnh Agent trong cùng một message** cho các task trong wave (mỗi task → đúng `agent` của nó). Đây là điểm tăng tốc chính so với chạy lần lượt.
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

---

## Phase 3 — QC + Security (song song, auto-fix ≤ 2)

> Test case đã được `qc-designer` thiết kế song song từ Phase 1 (ghi tại `.claude/stories/{id}/tests/`). Phase này chạy test **và** audit bảo mật song song trên cùng phần code vừa implement.

Phát **cùng một message** tất cả Agent sau song song — chúng chạy trên project/scope rời nhau nên không đụng file:

1a. **Agent `qc-executor` × N project** — lấy danh sách project đã có task trong story này (từ structured task list của planner, Phase 1). Với **mỗi project** có lệnh test trong `.claude/profile.md`, phát **một Agent `qc-executor` riêng** trong cùng message, chỉ định rõ project scope. Mỗi instance trả về `project`, `allPassed`, `infraMissing`, `failures[{test,message}]`, `report`.

> Ví dụ: story đụng 2 project backend + 1 project frontend → phát 3 `qc-executor` song song trong 1 message.

1b. **Agent `security-auditor`** (song song với các qc-executor) — audit diff của story này tìm lỗ hổng (theo lockstep/secrets/cache của profile). Ghi báo cáo vào `.claude/stories/{id}/security/` và trả về `findings[{severity,title,file,line,remediation}]`.

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

## Phase 4 — Docs (doc-syncer)

Gọi **Agent `doc-syncer`**: đồng bộ README/docs/docstring/inline comment với code vừa đổi. Lưu ý `docs/architecture.md` đã được architect cập nhật ở bước thiết kế — chỉ bổ sung phần còn lệch, không tự thêm tính năng chưa có trong code.

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

<cache eviction keys cần chạy, infra còn thiếu, v.v.>
```

Nếu user muốn commit → dùng skill **`msdlc:commit`**.

## Nguyên tắc

- **Main tự điều phối bằng Agent tool** — chạy song song tối đa các task file-disjoint; không dùng Workflow.
- **Không sửa định nghĩa agent** — chỉ tái dùng qua Agent tool.
- **Idempotent** — luôn check-before-write để chạy lại trên codebase đã có không phá đồ.
- **Trung thực trạng thái** — test fail / thiếu hạ tầng phải báo đúng.
