# Changelog

## [0.6.0] — 2026-07-22

### Added

- **Git flow cho luồng board (opt-in)**: `/msdlc:tracking-poll` giờ có thể tách một nhánh riêng cho mỗi task từ base branch, build xong tự commit → push → tạo merge/pull request → comment link MR vào ticket.
  - **Skill mới `msdlc:git-flow`** (`{taskid} start|finish`): nơi duy nhất chứa logic git. `start` tạo/switch nhánh `<type>/<taskid>-<slug>` off base (type theo `msdlc:commit`, slug từ title ticket); `finish` một commit qua `msdlc:commit` + push + tạo MR (auto qua `gh`/`glab` nếu có + auth, không thì fallback dựng link "create MR" điền sẵn từ remote URL) + ghi `> MR:` vào report. Tự **no-op** khi cờ tắt / không phải git repo. **Máy không bao giờ tự merge** — merge là quyền người (đối xứng never-auto-Done).
  - **Mục `## Git` trong `profile.md`**: cờ bật (mặc định `no`), base branch (trống→auto-detect default branch), branch pattern, MR tool (trống→suy từ remote), MR target.
- `init.md`: thêm Bước 2d hỏi & điền mục `## Git` khi dự án là git repo + dùng poll.

### Changed

- **`tracking-poll`**: khi git flow bật → Bước 2 chèn `git-flow start` TRƯỚC build và `git-flow finish` SAU build; chỉ **một build/lượt** (không juggle nhiều nhánh trên working tree chung); Bước R resume thêm nhánh finish dở (report có nhưng thiếu `> MR:`). Không bao giờ build trên base (start fail → skip ticket, không clobber). Tắt cờ → hành vi 0.5.0 y nguyên.
- **`tracking`**: comment mốc `review` nếu report có dòng `> MR:`/`> PR:` → đính kèm link MR + nhắc review-rồi-merge (không đổi contract).
- `deliver-light`: report template chừa chỗ cho dòng `> MR:` (do `git-flow finish` điền); deliver-light vẫn KHÔNG tự commit (commit do git-flow qua `msdlc:commit`).
- README: thêm skill `git-flow`, cập nhật sequence poll + section board (git flow, một build/lượt, không tự merge), glossary.

## [0.5.0] — 2026-07-22

### Changed

- **Thiết kế lại luồng đồng bộ board ngoài sang LUỒNG NHẸ** (task board chỉ là feat/fixbug nhỏ, không hợp nghi thức spec+ADR+QC map/reduce). `/msdlc:tracking-poll` giờ:
  - **Nhận ticket bằng claim/lock**: chuyển `Todo → planning` TRƯỚC khi phân tích (ticket rời cột intake nên session khác không nhận trùng; ghi `claim.md` local chống overlap cùng máy).
  - Chạy agent nhẹ `task-planner` (thay `architect`) dò codebase → ghi `.claude/tasks/{taskid}/plan.md` + comment **plan chi tiết** vào ticket cho user duyệt → đẩy `Validate` rồi dừng.
  - Ticket đã `Approved` (người kéo = duyệt plan) → chuyển `in-progress` TRƯỚC → build gọn bằng `deliver-light` → `Review`.
  - Thêm **bước resume** đầu mỗi lượt: nhặt lại task kẹt ở `planning`/`in-progress` do lượt trước fail (dựa trên cột board + tồn tại `plan.md`/`report.md`).
  - Luồng thủ công `/spec`+`/deliver`+`deliver-auto` (dùng `.claude/stories/` + ADR) **giữ nguyên**, không đụng.

### Added

- **Agent `task-planner`**: phân tích task nhỏ từ board dựa trên codebase, ghi `plan.md` (phương án + subtask file-disjoint có `touchesFiles`/`dependsOn` + files đụng + acceptance). Không tạo ADR/docs, không viết code — bản nhẹ của `architect`.
- **Skill `deliver-light`**: build gọn từ `plan.md` — implement song song theo subtask file-disjoint (dev-backend/dev-frontend) → reviewer (≤1 vòng) → qc-executor + security-auditor song song (≤2 vòng) → chronicler → `report.md`. Không vỡ task bằng `dev-leader`, không QC map/reduce. KHÔNG tự gọi `tracking` (poll lo transition).
- **Convention `.claude/tasks/{taskid}/`** cho luồng board (`taskid` = ID ticket), tách khỏi `.claude/stories/{id}/` của luồng thủ công.

### Changed (tiếp)

- **`tracking` thêm tham số thứ ba `kind`** ∈ `story` (mặc định) \| `task`. Lời gọi 2 tham số cũ hành xử y hệt (backward-compat). `kind=task`: `{id}` chính là ID ticket (không đọc `requirement.md`); comment ở `validate` là plan chi tiết từ `tasks/{id}/plan.md`, ở `review` từ `tasks/{id}/report.md`. Cột `planning` giờ là bước claim/lock → khuyến nghị override tên cột trong profile.
- `profile.template.md`: thêm đường dẫn `.claude/tasks/{taskid}/` + `plan.md`; ghi chú poll dùng luồng nhẹ và cột `planning` là claim/lock.
- `README.md`: cập nhật bảng Agents/Skills, sơ đồ + sequence "Đồng bộ board ngoài" theo luồng nhẹ; thêm `.claude/stories/`+`.claude/tasks/` vào gợi ý `.gitignore`; phân biệt thuật ngữ `story` (thủ công) vs `task (board)`.

## [0.4.0] — 2026-07-09

### Fixed

- **Đóng lỗ gate ADR**: trạng thái duyệt giờ được persist bằng header `Status: Accepted` trong `adr.md` — `/deliver` ghi khi user duyệt (kể cả nhánh "build luôn từ ADR có sẵn", nay BẮT BUỘC xác nhận), `tracking-poll` ghi khi người kéo ticket sang Approved; `deliver-auto` từ chối chạy nếu ADR còn `Proposed` (ADR cũ không có `Status:` → hỏi xác nhận một lần, backward compat).
- **`tracking-poll` idempotency**: story gắn ticket nhưng thiếu `adr.md` (architect fail lượt trước) → resume trên story cũ thay vì cấp id mới (hết tạo story trùng); thêm nhánh xử lý khi `deliver-auto` fail giữa chừng.
- **`security-auditor` có JSON contract pipeline**: mục "Pipeline Output" mới — bắt buộc ghi report vào `security/` và trả `{ findings: [{severity,title,file,line,remediation,ruleId}] }` đúng schema orchestrator parse (trước đây thiếu hẳn).
- `/msdlc:init` không còn ghi đè `agent-memory.md` vô điều kiện — thêm guard no-overwrite như profile/rules.
- Mô tả skill `spec` sửa `spec.md` → `requirement.md` (tên artifact thật); typo `Planing`/`InProgess` trong README + profile template; hướng dẫn cài thủ công bỏ lệnh `claude plugin path` không tồn tại.

### Changed

- **Curate lại `tools` các agent**: dev-backend/dev-frontend/dev-leader/qc-designer thêm `Grep`/`Glob` (prompt yêu cầu dò codebase mà thiếu tool), bỏ NotebookEdit/Task*/MCP/Web thừa; qc-executor bỏ `Edit`/`NotebookEdit` (khớp boundary "không tự sửa code"); security-auditor bỏ Task*/MCP.
- `architect` có memory footer (trước khai `memory: local` mà không có giao thức → memory chết); quy ước diagram đọc từ profile (mục mới `## Quy ước diagram`), fallback mặc định PlantUML + `docs/diagrams/` như cũ.
- `deliver-auto`: nguyên tắc xử lý JSON contract hỏng (retry 1 lần → fallback đọc artifact → dừng có báo); phát hiện cycle `dependsOn` → liệt kê task kẹt + abort pipeline (không QC trên code dở); reviewer/security-auditor nhận scope theo `filesChanged` gom từ các wave (tránh nhiễu working tree); frontmatter mô tả đủ qc-leader map/reduce + reviewer.
- `tracking`: lỗi transition/comment sau guard (MCP rớt giữa chừng) là non-fatal — log một dòng, không làm dừng pipeline.
- `dev-leader`: quy tắc routing rõ cho task `docs`/`cross-cutting` (docs-only không sinh task — chronicler lo; cross-cutting gán theo domain sở hữu đa số `touchesFiles`).
- Lời văn memory footer: "thư mục đã tồn tại" → "Write tự tạo thư mục nếu chưa có" (init không tạo sẵn thư mục memory); qc-executor gộp double memory section.
- Profile template: thêm dòng `todo →` vào mapping cột (kèm ghi chú trùng cột intake); `/msdlc:init` nhận diện thêm C#/.NET (`*.csproj`/`*.sln`) và Ruby (`Gemfile`).
- `plugin.json`: bump 0.4.0, thêm `"license": "MIT"`.
- docs: README chuyển sơ đồ ASCII sang **Mermaid** (GitHub render trực tiếp) — pipeline end-to-end, bên trong deliver-auto (Phase 1→5), cột board 🤖/👤, sequence vòng poll; thêm section **"Các workflow áp dụng"** với sơ đồ chọn workflow theo thứ đang có + 5 công thức dùng (trọn gói / từ requirement / từ ADR / gọi lẻ agent / vận hành theo board).

## [0.3.0] — 2026-07-02

### Added

- Skill mới **`msdlc:tracking {id} {phase}`** — đồng bộ trạng thái story sang cột board ngoài (Jira/Asana/Linear/Monday) tại các mốc `todo/planning/validate/approved/in-progress/review`. Gom **toàn bộ** logic tracker vào một chỗ. **Opt-in**: không cấu hình `## Task tracker` trong `profile.md` hoặc story không gắn `Ticket:` → skill tự **no-op**, pipeline chạy thuần local như cũ. **Không bao giờ tự chuyển Done.**
- Command mới **`/msdlc:tracking-poll`** — quét board **một lượt** (idempotent): ticket ở cột intake → tạo story + `architect` + đẩy sang `Validate` rồi **dừng**; ticket ở cột `Approved` (do người kéo) → tự `deliver-auto` build → `Review`. Lặp giao cho harness (`/loop` hoặc `schedule`); msdlc không tự chế scheduling. Bật qua cờ `poll` trong profile (mặc định tắt).
- `profile.template.md` thêm mục `## Task tracker` (tool + connector MCP, project key, override tên cột từng mốc, cột intake/build-trigger, cờ poll).
- `requirement.md` thêm trường header `Ticket:` để liên kết story ↔ ticket board.

### Changed

- **Giữ đúng một cổng duyệt** khi dùng board: cột board CHÍNH LÀ gate — poll dừng ở `Validate`, chỉ ticket người kéo sang `Approved` mới được tự build. Máy không bao giờ tự vượt gate; sync chỉ là side-effect, không phải gate mới.
- `spec`/`deliver`/`deliver-auto` thêm lời gọi `msdlc:tracking` một dòng tại mỗi mốc (tự no-op khi không có tracker) — không rải logic tracker vào các skill này.
- `/msdlc:init` thêm **Bước 2c — Dò tracker**: phát hiện connector MCP đang connect, hỏi user điền mục `## Task tracker` (opt-in, không bịa tên cột).
- `.claude-plugin/marketplace.json` (source `.`) để repo cài trực tiếp qua `github:minhhv08/msdlc`.
- docs: README thêm section "Đồng bộ board ngoài" + sơ đồ flow board + hướng dẫn loop; bảng thuật ngữ thêm `tracker sync`/`poll`.

## [0.2.0] — 2026-07-01

### Added

- Agent mới **`qc-leader`** điều phối thiết kế test theo **map/reduce**: chế độ *enumerate* (liệt kê test-case stub + đề xuất bucket cân bằng + coverage) và *merge* (gộp các part thành Traceability Matrix + Coverage & Gaps ở `tests/README.md`).
- `qc-designer` thêm chế độ **design-subset**: nhận danh sách stub + file output riêng, flesh-out đặc tả đầy đủ, giữ nguyên `id`/`source`. Chế độ *full* (gọi lẻ) giữ nguyên — backward-compatible.
- Cơ chế **per-project rules** `.claude/rules/` (scope: `global`/`backend`/`frontend`/`security`/`testing`); mỗi rule có `id` + `severity` (`MUST`/`SHOULD`). Template trong `shared/rules/`.
- `reviewer` enforce rule: vi phạm `MUST` → blocking, `SHOULD` → suggestion; finding mang `ruleId`.
- `security-auditor` enforce `R-SEC-*`: vi phạm `MUST` được nâng severity tối thiểu `High`; finding mang `ruleId`.
- `/msdlc:init` copy `shared/rules/` (no-overwrite) + auto-seed rule từ CLAUDE.md/CONTRIBUTING/.editorconfig/linter, đánh dấu `<!-- seeded từ <nguồn>, cần xác nhận -->`.

### Changed

- **Song song hoá thiết kế test:** `qc-leader` (enumerate) chạy **song song với `dev-leader` ở Phase 1**; sang Phase 2 fan-out **N `qc-designer` (design-subset)** theo bucket ngay từ Wave 1 (mỗi bucket → `tests/testcases-part-{k}.md`), rồi `qc-leader` (merge) gộp — thay vì một `qc-designer` đơn — cắt đường găng của Phase 3. Story nhỏ → 1 bucket, không fan-out thừa.
- **Đổi tên agent `planner` → `dev-leader`** cho đối xứng với `qc-leader` (dev-leader vỡ ADR→task, qc-leader vỡ requirement/ADR→test). Cập nhật mọi tham chiếu trong skills, README, rules, init, manifest và contracts. Contract task giữ nguyên (chỉ đổi tên).
  - **Migration cho project đang dùng plugin:** nếu có memory cũ `.claude/agent-memory-local/planner/`, đổi tên thủ công thành `.claude/agent-memory-local/dev-leader/` để giữ lại institutional memory (không tự động xử lý).
- Mọi agent đọc thêm `.claude/rules/` đúng scope; `chronicler` nay cũng đọc profile + rules. Thiếu rules → giữ hành vi cũ (không regression).
- Quy tắc commit chuyển từ `profile.md` sang `.claude/rules/global.md` nhóm `## Commit`; skill `commit` ưu tiên rule của dự án, fallback về định dạng msdlc.
- Đổi tên skill `auto-deliver` → `deliver-auto` (gom cạnh `deliver` khi sắp xếp); cập nhật mọi tham chiếu trong `skills/deliver`, docs và prompt agent.
- fix: tách `dev-leader` ra Phase 1 riêng, `qc-designer` chạy song song với Wave 1 dev thay vì block dev agents.
- docs: cập nhật README — thành phần tách theo loại, bảng thuật ngữ, section hooks.

## [0.1.0] — 2025-06-22

### Added
- `hooks/block-read-secrets.sh` — chặn đọc file secrets/credentials qua Read tool
- `hooks/block-bash-dangerous.sh` — chặn lệnh Bash nguy hiểm (rm -rf hệ thống, pipe-to-shell, force-push main, DROP DATABASE…)
- Đăng ký hooks vào `plugin.json` (PreToolUse: Read + Bash)
- `agents/reviewer` — review code 6 chiều, auto-fix ≤1 vòng trước QC
- `skills/commit` — quy ước commit `(type): description` + Co-Authored-By AI
- Ghi `report.md` tổng hợp cuối pipeline vào `.claude/stories/{id}/`
- Ghi execution report `tests/{project}-execution-attempt-{N}.md` sau mỗi lần qc-executor chạy
- Ghi `## Result` vào task file sau khi dev agent hoàn thành
- Song song hoá dev tasks và qc-executor theo project scope

### Changed
- Chuẩn hoá quy ước commit toàn plugin (bỏ hướng dẫn commit khỏi từng agent, dồn vào skill commit)
- Chuẩn hoá section `Pipeline Output` cho tất cả agent

## [0.0.1] — 2025-06-17

### Added
- Khởi tạo plugin: `architect`, `planner`, `dev-backend`, `dev-frontend`, `qc-designer`, `qc-executor`, `security-auditor`, `chronicler`
- Skills: `spec`, `deliver`, `auto-deliver`
- Command: `init`
- `shared/agent-memory.md`, `shared/profile.template.md`
- `plugin.json` manifest
