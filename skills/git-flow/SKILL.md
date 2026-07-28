---
name: git-flow
description: >-
  Quản lý git flow cho luồng board nhẹ của msdlc — trước khi phân tích thì đồng bộ đúng nhánh (op `sync`), mỗi task board làm trên một nhánh riêng tách từ base branch, build xong thì commit (một commit qua msdlc:commit) → push → tạo merge/pull request → trả URL để comment vào ticket. Nơi DUY NHẤT chứa logic git của msdlc; tự no-op khi tắt cờ hoặc không phải git repo. Máy KHÔNG tự merge — merge là quyền người. Được `tracking-poll` gọi (op `sync` trước mỗi lần task-planner phân tích, `start` trước build, `finish` sau build); cũng dùng tay khi cần re-sync một task. LUÔN dùng skill này khi cần "pull đúng nhánh trước khi phân tích", "tạo nhánh cho task board", "tạo MR sau khi build", hoặc khi một bước poll cần thao tác git.
---

# msdlc:git-flow — Nhánh/task + MR cho luồng board

Skill này là **nơi duy nhất** chứa logic git của msdlc: tạo nhánh theo task, commit, push, tạo MR. Gom một chỗ để: **không bật git flow = poll build thẳng trên branch hiện tại như cũ** (không regression), đảm bảo tại một điểm.

**Input:** `{taskid} {op}`. `op` ∈ `sync | start | finish`. Ví dụ: `msdlc:git-flow PROJ-123 sync`. Thiếu tham số → hỏi user.

> **Thứ tự trong luồng board:** `sync` (đồng bộ đúng nhánh TRƯỚC khi task-planner phân tích) → `start` (tạo/switch nhánh task sau khi duyệt, TRƯỚC build) → `finish` (commit + push + MR sau build).

## Nguyên tắc bất biến

1. **No-op im lặng khi không đủ điều kiện.** Cờ git flow tắt / không có mục `## Git` / thư mục không phải git repo → **log một dòng rồi dừng**, KHÔNG lỗi. Đây là điều giữ tương thích ngược (luồng 0.5.0 chạy y như cũ).
2. **KHÔNG BAO GIỜ tự merge** MR/PR — kể cả khi mọi thứ xanh. Merge là quyền người (đối xứng lý do never-auto-Done của `tracking`).
3. **KHÔNG BAO GIỜ build/commit trên base branch.** Nếu tạo/switch nhánh task thất bại → abort, để caller bỏ qua ticket; tuyệt đối không để code task rơi vào main/master/production.
4. **Working tree phải sạch trước khi rời nhánh.** Không clobber thay đổi chưa commit của ai.
5. **Lỗi sau guard là non-fatal.** Push/MR fail (mất mạng, thiếu quyền, thiếu CLI) → log một dòng, để nhánh đã đẩy lại cho người, KHÔNG throw, không làm dừng poll. MR luôn có đường lui (link tạo tay).

## Bước 0 — Guard (chung cho mọi op)

Thực hiện tuần tự, fail điều kiện nào thì **log một dòng và dừng (no-op)**:

1. Đọc mục `## Git` trong `.claude/profile.md`. Không có mục / **cờ "Bật git flow" ≠ yes** → *"[git-flow] Git flow tắt (opt-in) — bỏ qua."* → dừng.
2. `git rev-parse --is-inside-work-tree` không phải repo → *"[git-flow] Không phải git repo — bỏ qua."* → dừng.

Qua Bước 0 nghĩa là: git flow bật + đang trong git repo → tiếp tục.

## Bước 1 — Resolve config (từ profile + suy từ git)

- **Base branch**: lấy từ profile `## Git` → nếu trống, auto-detect default branch: `git symbolic-ref --quiet refs/remotes/origin/HEAD` (vd `origin/main` → `main`); vẫn không có → thử `main`/`master` đang tồn tại. Ghi rõ base đã chọn vào log.
- **Branch pattern**: profile → mặc định `<type>/<taskid>-<slug>`.
  - `type`: suy từ **loại ticket** (issue type: `Bug`/`Defect` → `fix`; còn lại → `feat`), giới hạn trong danh sách hợp lệ của `msdlc:commit` (`feat|fix|refactor|perf|docs|test|chore|build|ci|revert`).
  - `slug`: kebab-case từ **title ticket** (đọc header `.claude/tasks/{taskid}/plan.md` hoặc dùng thông tin caller truyền), bỏ dấu, cắt ~40 ký tự. Không có title → chỉ dùng `{taskid}`.
  - Ví dụ: `feat/PROJ-123-them-health-check`.
- **MR tool**: profile → nếu trống, suy từ `git remote get-url origin`: chứa `github.com` → `gh`; `gitlab` → `glab`; `bitbucket` → `bitbucket`. Không nhận ra → chế độ **link điền sẵn** (chỉ push, không auto-create).
- **MR target**: profile "MR target branch" → mặc định = base branch.

## Bước S — op `sync` (pull đúng nhánh, TRƯỚC khi phân tích)

Mục tiêu: đảm bảo `task-planner` phân tích trên **đúng nhánh + code mới nhất**, KHÔNG tạo nhánh task. Mô hình 2 cấp `base → nhánh task`: task đã có nhánh riêng (từng build, thường đang reopen/revision) → pull chính nhánh đó; chưa có → pull nhánh **base** (theo profile, không hardcode `master`).

1. **Clean-tree gate:** `git status --porcelain`. Có thay đổi chưa commit → **KHÔNG switch** (tránh clobber): *"[git-flow] Working tree bẩn — không switch, phân tích trên nhánh hiện tại."* → trả `{ status: "skip-dirty", branch: <nhánh hiện tại> }` và dừng (non-fatal, phân tích vẫn tiếp tục).
2. **Non-fatal trên mọi lỗi git (chống pull chồng chéo giữa các lượt poll):** mọi lệnh git ở op này (`fetch`/`checkout`/`pull`) đều best-effort. Gặp **git đang bận** (`index.lock` / *"another git process is running"*) hoặc lỗi bất kỳ → **log một dòng, KHÔNG throw**, bỏ switch → phân tích trên nhánh hiện tại. `index.lock` của git đã đảm bảo hai lượt poll chồng nhau không ghi tree đồng thời (lệnh thua fail ngay) → git op tự **"lần lượt từng task"**, không cần lockfile riêng.
3. `git fetch origin` (best-effort; fail mạng → log, tiếp tục offline).
4. **Xác định task đã có nhánh riêng chưa:** dựng `<branch>` theo branch pattern (Bước 1), kiểm tra tồn tại bằng `git rev-parse --verify --quiet <branch>` (local) hoặc `git ls-remote --heads origin <branch>` (remote).
   - **Đã có** → `git checkout <branch>` → `git pull --ff-only origin <branch>` (best-effort). Log: *"[git-flow] Task đã có nhánh riêng — pull `<branch>` trước khi phân tích."* → trả `{ status: "ok", mode: "task-branch", branch }`.
   - **Chưa có** → `git checkout <base>` → `git pull --ff-only origin <base>` (best-effort). Log: *"[git-flow] Task chưa có nhánh riêng — pull nhánh base `<base>` trước khi phân tích."* → trả `{ status: "ok", mode: "base", branch: <base> }`.
5. **TUYỆT ĐỐI KHÔNG `git checkout -b`** ở op này — nhánh task chỉ được tạo sau khi duyệt (op `start`). Đây là điểm phân biệt cốt lõi giữa `sync` và `start`.

## Bước 2 — op `start` (tạo/switch nhánh task, TRƯỚC khi build)

1. **Clean-tree gate**: `git status --porcelain`. Nếu **có thay đổi chưa commit**:
   - Nếu nhánh hiện tại là nhánh của một task khác (khớp pattern `<type>/<otherid>-...`) → thay đổi đó thuộc task đó, chưa `finish`. **Không clobber**: báo caller nên `finish` task đó trước (resume-owner). Trả `{ status: "dirty", owner: <otherid|unknown> }` và dừng.
   - Nếu không xác định chủ → dừng an toàn, báo *"[git-flow] Working tree bẩn ngoài dự kiến — dừng để tránh clobber."*.
2. `git fetch origin` (best-effort; fail mạng → log, tiếp tục offline).
3. `git checkout <base>` → `git pull --ff-only origin <base>` (best-effort; ff fail → log cảnh báo base có thể cũ, tiếp tục).
4. Tạo/switch nhánh task: nếu nhánh `<branch>` đã tồn tại (local hoặc remote) → `git checkout <branch>` (idempotent, resume). Chưa có → `git checkout -b <branch>`.
5. **Tạo/switch nhánh fail** → *"[git-flow] Không tạo được nhánh {branch} — abort, KHÔNG build trên base."* → trả `{ status: "abort" }`. Caller bỏ qua ticket.
6. Thành công → trả `{ status: "ok", branch, base }`. Log: đã ở nhánh `<branch>` tách từ `<base>`.

## Bước 3 — op `finish` (commit + push + MR, SAU khi build)

Tiền đề: đang ở nhánh task `<branch>` (nếu đang ở base/nhánh khác → checkout `<branch>`; nhánh không tồn tại → log lỗi, dừng non-fatal).

1. **Commit (một commit/task):** `git add -A`. Nếu `git status --porcelain` rỗng (không có thay đổi — vd build `already-done`) → bỏ qua commit, tiếp bước push (nhánh có thể đã có commit từ lượt trước). Có thay đổi → gọi skill **`msdlc:commit`** để tạo **một commit** đúng quy ước (`(type): mô tả` + trailer `Co-Authored-By`), mô tả suy từ title ticket + tóm tắt `plan.md`.
2. **Push:** `git push -u origin <branch>`. Fail (mất mạng/quyền) → log non-fatal, dừng (nhánh còn ở local cho người); trả `{ status: "push-failed", branch }`.
3. **Tạo MR/PR (idempotent, không tự merge):**
   - MR/PR cho nhánh này **đã tồn tại** (kiểm bằng `gh pr view <branch>` / `glab mr list --source-branch <branch>`, hoặc suy từ lần trước ghi trong report) → lấy **URL cũ**, không tạo trùng.
   - Chưa có + **CLI khả dụng + auth** (`gh`/`glab`): auto-create — `gh pr create --base <target> --head <branch> --title "<title>" --body "<tóm tắt report.md>"` (hoặc `glab mr create --source-branch <branch> --target-branch <target> --title ... --description ...`). Lấy URL trả về.
   - Chưa có + **không CLI/auth**: **fallback** — dựng **link create-MR điền sẵn** từ remote URL:
     - GitHub: `https://<host>/<owner>/<repo>/compare/<target>...<branch>?expand=1`
     - GitLab: `https://<host>/<owner>/<repo>/-/merge_requests/new?merge_request%5Bsource_branch%5D=<branch>&merge_request%5Btarget_branch%5D=<target>`
     - Bitbucket: `https://bitbucket.org/<owner>/<repo>/pull-requests/new?source=<branch>&dest=<target>`
   - (Chuyển remote SSH `git@host:owner/repo.git` / HTTPS về dạng web `https://host/owner/repo` khi dựng link.)
4. **Ghi MR url vào report:** append/cập nhật dòng `> MR: <url>` ở đầu `.claude/tasks/{taskid}/report.md` (để `tracking` mốc review đọc và đính vào comment, và để idempotent lượt sau).
5. Trả `{ status: "ok", mrUrl, branch, autoCreated: true|false }`. Log: đã push `<branch>`, MR: `<url>` (auto-created hoặc link tạo tay). **Nhắc: máy không merge — chờ người review & merge.**

> Sau `finish`, caller (`tracking-poll`) checkout lại base cho lượt sau.

## Bước 4 — Báo lại

Log một dòng cho user: op đã làm gì (nhánh nào, commit/không, push ok?, MR url + auto-created hay link tạo tay). Nếu có lỗi non-fatal → nêu rõ trạng thái để người xử lý tiếp.

## Ghi chú

- Skill này **tự chứa**: chỉ dùng `git` + CLI MR của host (nếu có) + skill `msdlc:commit`. Không phụ thuộc file ngoài plugin.
- **`sync` KHÔNG tạo nhánh** (chỉ pull đúng nhánh trước phân tích); nhánh task chỉ tạo ở `start` sau khi duyệt. Thứ tự: `sync` → `start` → `finish`.
- Chi tiết cách tạo MR khác nhau theo host — suy từ remote + CLI có sẵn; không hardcode host.
- **Không tự merge, không tự đóng ticket/Done** — chỉ tạo MR + trả URL. Người review MR, merge, rồi đóng ticket thủ công.
