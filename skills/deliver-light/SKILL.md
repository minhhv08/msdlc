---
name: deliver-light
description: >-
  Build GỌN một task nhỏ (feat/fixbug) từ board ngoài đã có plan duyệt: implement song song theo subtask file-disjoint (dev-backend/dev-frontend) → reviewer (auto-fix ≤1) → qc-executor + security-auditor song song (auto-fix ≤2) → chronicler → ghi report. Main agent TỰ điều phối bằng Agent tool (không dùng Workflow), KHÔNG vỡ task bằng dev-leader, KHÔNG QC map/reduce. Dùng khi .claude/tasks/{taskid}/plan.md đã tồn tại (đã được người duyệt qua board — kéo ticket sang Approved). Gọi bởi msdlc:tracking-poll (Bước 2) hoặc trực tiếp với một taskid. KHÔNG tự chạy nếu chưa có plan.md.
---

# deliver-light — Build gọn một task board (main điều phối)

Bản **nhẹ** của `deliver-auto` cho task nhỏ trên board: bỏ bước vỡ task (`dev-leader`) và bỏ thiết kế test map/reduce (`qc-leader`/`qc-designer`). Việc vỡ subtask đã do `task-planner` làm sẵn trong `plan.md`. Main agent **tự điều phối** chuỗi agent bằng **Agent tool** — không dùng Workflow — chạy song song tối đa các subtask không đụng file, và báo cáo trung thực.

**Tiền đề:** `.claude/tasks/{taskid}/plan.md` đã tồn tại (do `task-planner` ghi, đã được người duyệt qua board). Kiểm tra thật, không tin lời gọi:
- Chưa có `plan.md` → dừng, báo cần chạy `task-planner`/`tracking-poll` trước. KHÔNG tự bịa plan.
- Đã có `.claude/tasks/{taskid}/report.md` → task đã build xong (idempotent) → báo và dừng, không build lại.

**Input:** một `taskid` (= ID ticket board, vd `PROJ-123`). Không có → liệt kê `.claude/tasks/` và hỏi, hoặc dùng id duy nhất nếu chỉ có một.

**Sync tracker:** skill này **KHÔNG tự gọi `msdlc:tracking`** (khác `deliver-auto`). Việc chuyển cột board là do `tracking-poll` lo — nó chuyển `in-progress` TRƯỚC khi gọi skill này và `review` SAU khi skill xong. Nhờ vậy skill chạy được cả khi gọi tay ở dự án không có tracker.

---

## Phase 1 — Implement (wave song song theo subtask file-disjoint)

1. Đọc `.claude/tasks/{taskid}/plan.md`, lấy **danh sách subtask** ở mục `## 5. Subtasks` (block JSON: `id`, `title`, `agent`, `touchesFiles`, `dependsOn`). Không parse được JSON → fallback đọc mục `## 4. Files sẽ tạo/sửa` để suy subtask; vẫn không được → dừng, báo user plan hỏng.
2. Triển khai theo **wave topo**, lặp tới khi mọi subtask xong:
   - **Tập sẵn sàng** = subtask chưa làm mà MỌI `dependsOn` đã xong.
   - **Chọn wave** = gom các subtask sẵn sàng có **tập `touchesFiles` rời nhau** (so cả prefix thư mục). Khác project → luôn rời. Cùng project → chỉ chung wave khi không giao file nào. Subtask `touchesFiles` rỗng → chạy một mình trong wave đó cho an toàn.
   - **Chạy song song**: phát **nhiều lệnh Agent trong cùng một message** cho các subtask trong wave (mỗi subtask → đúng `agent` của nó: `dev-backend` cho code server-side, `dev-frontend` cho UI). Task nhỏ 1 subtask → chỉ 1 Agent.
3. Mỗi dev agent nhận chỉ thị **idempotent check-before-write**: đọc `plan.md` (mục Phương án + Acceptance) + subtask được giao, đối chiếu codebase — đã đạt → `already-done`; thiếu phần → `partial`; chưa có → `implemented`; không làm được → `skipped` kèm lý do. Tôn trọng lockstep + rule `MUST` trong profile/rules; nhắc evict cache nếu đụng dữ liệu được cache. Trả JSON `{ status, filesChanged, summary, followUps }`.
4. Sau mỗi wave: gom `filesChanged` + `followUps` toàn wave, đánh dấu subtask done, sang wave kế. **Hết subtask ready mà còn subtask chưa xong** (cycle `dependsOn`, hoặc dep đã fail) → liệt kê subtask kẹt + chuỗi phụ thuộc, đánh dấu `skipped` (lý do blocked/cycle), rồi **dừng** — không chạy review/QC trên code dở; ghi tình trạng vào report (Phase 4 rút gọn) và báo user.

**An toàn:** không bao giờ chạy song song hai Agent đụng cùng file. **KHÔNG dùng git worktree** — luôn làm trên cùng working tree với tập file rời nhau.

---

## Phase 2 — Code Review (reviewer, auto-fix ≤ 1 vòng)

Gọi **Agent `reviewer`** với `taskid`, **truyền kèm tập `filesChanged` gom từ Phase 1** để giới hạn scope (quan trọng khi `tracking-poll` build nhiều task tuần tự trên cùng working tree). Reviewer đọc `git diff` (lọc theo tập file đó) + `.claude/tasks/{taskid}/plan.md` + `.claude/profile.md` + `.claude/rules/`, review theo các dimensions (correctness vs plan, lockstep, logic, convention & rule, readability), ghi `.claude/tasks/{taskid}/review/review-attempt-1.md`, trả JSON `{ approved, blockingFindings, suggestions, summary }` (finding bám rule mang `ruleId`).

**Xử lý:**
- `approved: true` → tiếp Phase 3.
- `approved: false` → gọi **Agent dev** (backend/frontend tùy file bị flag) để **chỉ sửa blocking findings, KHÔNG đổi scope** → re-run reviewer 1 lần (ghi `review-attempt-2.md`).
- Sau 1 vòng: tiếp Phase 3 dù còn blocking — đưa findings còn lại vào `followUps` của Phase 4.

> Ngân sách: ≤ 1 vòng fix, độc lập với ngân sách ≤ 2 vòng của Phase 3.

---

## Phase 3 — QC + Security (song song, auto-fix ≤ 2)

Phát **cùng một message** các Agent sau (scope rời nhau nên không đụng file):

1a. **Agent `qc-executor` × N project** — lấy danh sách project mà các subtask đụng tới (từ `agent`/`touchesFiles` trong plan). Với **mỗi** project có lệnh test trong `.claude/profile.md`, phát **một `qc-executor`** trong cùng message, chỉ định project scope. Trả `project`, `allPassed`, `infraMissing`, `failures[{test,message}]`, `report`.

1b. **Agent `security-auditor`** (song song) — audit diff của task (truyền kèm `filesChanged` từ Phase 1 để giới hạn scope), tìm lỗ hổng theo lockstep/secrets/cache của profile **và rule `R-SEC-*`**. Ghi báo cáo vào `.claude/tasks/{taskid}/security/`, trả `findings[{severity,title,file,line,remediation,ruleId}]`. Vi phạm rule `MUST` nâng severity tối thiểu `High`.

2. **Ghi execution report & vòng auto-fix (ngân sách ≤ 2 vòng):** sau mỗi lần chạy qc-executor, mỗi project ghi `.claude/tasks/{taskid}/tests/{project}-execution-attempt-{N}.md` (Status/Commands/Result/Infra + bảng Failures + Notes).
   - Mọi project `allPassed` **và** không có finding `Critical`/`High` → xong Phase 3.
   - `infraMissing` → phần test không tự fix được, báo trung thực; vẫn xử lý security.
   - Còn lượt mà có **test failures** hoặc finding **Critical/High** → tăng `attempt`, gọi **Agent dev** (lỗi BE→`dev-backend`, UI→`dev-frontend`) **chỉ sửa cho qua test + bịt lỗ hổng Critical/High, không đổi scope**, chạy lại **chỉ qc-executor cho project lỗi** (và/hoặc security-auditor nếu còn finding).
   - **Tối đa 2 vòng.** Sau 2 vòng vẫn còn → dừng, báo cáo failures + findings còn lại.
   - Finding `Medium`/`Low`/`Info` → không chặn, đưa vào `followUps`.

---

## Phase 4 — Docs (chronicler)

Gọi **Agent `chronicler`**: đồng bộ README/docs/docstring/inline comment với code vừa đổi. Chỉ bổ sung phần lệch, không tự thêm tính năng chưa có trong code.

---

## Phase 5 — Báo cáo

Ghi **`.claude/tasks/{taskid}/report.md`**:

```markdown
# Delivery Report (light) — {taskid}

> Generated: {date} · Plan: [plan.md](plan.md)
<!-- git-flow finish sẽ chèn dòng `> MR: <url>` ngay dưới đây khi git flow bật; deliver-light để trống. -->
{mr-line-nếu-có}

## Subtasks
| # | Title | Agent | Status | Files changed |
|---|---|---|---|---|
| S1 | ... | dev-backend | implemented | src/foo.ext |

**Summary:** {N} subtasks — {implemented}/{already-done}/{partial}/{skipped}.

## Code Review
| Attempt | Approved | Blocking | Suggestions | Report |
|---|---|---|---|---|

## Tests
| Project | Status | Passed | Failed | Attempts | Report |
|---|---|---|---|---|---|

> BLOCKED projects (infra missing): ...

## Security
| Severity | Count | Status |
|---|---|---|

Security reports: `.claude/tasks/{taskid}/security/`

## Follow-ups
- [ ] <lockstep, cache eviction, blocking/finding còn lại (kèm ruleId), open items>
```

Sau khi ghi `report.md` → trả về JSON tóm tắt `{ taskid, subtasks, tests, security, followUps }` cho caller (`tracking-poll` dùng để comment ở mốc review). **KHÔNG tự chuyển Done** — Review chờ người verify.

Nếu user muốn commit → dùng skill **`msdlc:commit`**.

## Nguyên tắc

- **Main tự điều phối bằng Agent tool** — song song tối đa subtask file-disjoint; không dùng Workflow.
- **Không tự gọi tracking** — transition do `tracking-poll` lo (chuyển trạng thái TRƯỚC khi làm).
- **JSON contract hỏng → không im lặng bỏ qua**: yêu cầu lại agent đúng 1 lần; vẫn hỏng → fallback đọc artifact trên đĩa; không tái dựng được thì dừng phase và báo user.
- **Không sửa định nghĩa agent** — chỉ tái dùng qua Agent tool.
- **Idempotent** — check-before-write; có `report.md` thì không build lại.
- **Trung thực trạng thái** — test fail / thiếu hạ tầng phải báo đúng.
