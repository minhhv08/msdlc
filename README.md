# msdlc

Một plugin Claude Code đóng gói pipeline giao hàng **độc lập stack** — với **đúng một cổng duyệt** do con người giữ:

```mermaid
flowchart LR
    idea(["💡 Ý tưởng mơ hồ"]) --> spec["📝 /spec<br/>phỏng vấn có cấu trúc<br/>→ requirement.md"]
    spec --> arch["🏛 architect<br/>thiết kế phương án<br/>→ adr.md"]
    arch --> gate{"🚧 GATE<br/>người duyệt ADR"}
    gate -->|"duyệt<br/>(Status: Accepted)"| auto["🤖 deliver-auto<br/>build ∥ test ∥ review ∥ docs"]
    gate -.->|"chưa duyệt"| stop(["⛔ dừng"])
    auto --> rep["📊 report.md"] --> commit["✅ /commit"]
```

> Chi tiết từng phase bên trong `deliver-auto` và các cách áp dụng: xem [Các workflow áp dụng](#các-workflow-áp-dụng).

Mọi đặc thù dự án **không nhúng cứng** trong agent — chúng đọc lúc chạy từ hai nguồn của dự án tiêu thụ:
- `.claude/profile.md` — **facts**: stack, đường dẫn, lệnh test, hợp đồng lockstep.
- `.claude/rules/` — **rule theo project**: convention, kiến trúc, bảo mật, Definition-of-Done, commit; chia theo scope (`global`/`backend`/`frontend`/`security`/`testing`), mỗi rule có `id` + `severity` (`MUST` chặn / `SHOULD` gợi ý). Không có rule → agent suy convention từ code lân cận như cũ.

## Thành phần

### Agents

Mỗi agent là một vai trò AI chuyên biệt — được gọi qua `Agent tool` bởi skill hoặc main agent điều phối.

| Agent | Vai trò |
|---|---|
| `architect` | Đọc `requirement.md`, thiết kế phương án kỹ thuật, ghi `adr.md` và cập nhật `docs/architecture.md`. |
| `task-planner` | (luồng board nhẹ) Phân tích một task nhỏ từ board dựa trên codebase hiện tại, ghi `plan.md` (phương án + subtask file-disjoint + files đụng + acceptance) ra `.claude/tasks/{taskid}/`. Bản nhẹ của `architect`; không tạo ADR/docs, không viết code. |
| `bug-triage` | (luồng fixbug-intake) Đọc log lỗi production, đối chiếu codebase, gom thành các **loại bug riêng biệt** (một lỗi lặp N lần = 1 bug) và **lọc bỏ noise** (timeout third-party, config sai môi trường, health-check…); sinh `signatureBasis` ổn định làm khóa khử trùng. Trả JSON `{ bugs[], discarded[] }` cho `/msdlc:log-triage`. Không viết code, không tạo ticket, không đụng MCP. |
| `dev-leader` | Đọc `adr.md` + `requirement.md`, vỡ thành danh sách task atomic có dependency graph, ghi ra `tasks/`. |
| `dev-backend` | Implement code server-side (bất kỳ ngôn ngữ/framework theo profile): service, controller, repository, migration, API endpoint… |
| `dev-frontend` | Implement UI web theo task spec — đọc profile để biết framework/component convention của dự án. |
| `qc-leader` | Điều phối thiết kế test theo map/reduce: *enumerate* (liệt kê test-case stub + chia bucket cân bằng + coverage) và *merge* (gộp các part → Traceability Matrix + Coverage & Gaps ở `tests/README.md`). Đối xứng với `dev-leader`. |
| `qc-designer` | Thiết kế test case (positive/negative/boundary/edge) từ spec + ADR, ghi ra `tests/`. Chế độ *design-subset*: flesh-out một bucket stub do `qc-leader` giao (fan-out song song); chế độ *full*: tự làm trọn gói khi gọi lẻ. |
| `qc-executor` | Chạy test suite thực tế bằng lệnh trong profile, báo pass/fail/infraMissing, auto-fix ≤2 vòng. |
| `reviewer` | Review diff theo nhiều chiều (đúng spec, lockstep, logic, convention & **rule dự án**, test alignment, readability); vi phạm rule `MUST` → blocking (kèm `ruleId`). Trả verdict có cấu trúc. |
| `security-auditor` | Audit diff tìm lỗ hổng bảo mật (injection, auth/authz, secrets leak, crypto, SSRF, XSS/CSRF, IDOR…) **và rule `R-SEC-*`**, auto-fix Critical/High ≤2 vòng. |
| `chronicler` | Đồng bộ README/docs/docstring/inline comment với code vừa thay đổi — không tự thêm tính năng chưa có trong code. |

### Skills

Skills là lệnh `/tên` người dùng gọi trực tiếp trong Claude Code.

| Skill | Lệnh | Mô tả |
|---|---|---|
| `spec` | `/spec` | Phỏng vấn có cấu trúc để biến ý tưởng còn mơ hồ thành `requirement.md` rõ ràng (mục tiêu, scope, AC, ràng buộc). |
| `deliver` | `/deliver {id}` | Chạy toàn bộ pipeline cho một story: architect → **[GATE duyệt ADR]** → deliver-auto. |
| `deliver-auto` | (nội bộ) | Điều phối Phase 1–5 sau khi ADR đã duyệt: (dev-leader ∥ qc-leader enumerate) → dev (song song) ∥ qc-designer ×N (fan-out từ Wave 1) → qc-leader merge → reviewer → qc-executor + security-auditor → chronicler. |
| `deliver-light` | (nội bộ) | **Build GỌN** cho task board nhỏ đã có `plan.md` duyệt: implement song song theo subtask file-disjoint (dev-backend/dev-frontend) → reviewer → qc-executor + security-auditor → chronicler → `report.md`. Không vỡ task bằng dev-leader, không QC map/reduce. Gọi bởi `tracking-poll`. |
| `tracking` | `/msdlc:tracking {id} {phase} [kind]` | Đồng bộ trạng thái sang cột board ngoài (Jira/Asana/Linear/Monday/Notion) tại một mốc (`todo`/`planning`/`validate`/`approved`/`in-progress`/`review`). `kind` ∈ `story` (mặc định, luồng thủ công — artifact `.claude/stories/`, comment ADR) \| `task` (luồng board nhẹ — artifact `.claude/tasks/`, comment plan). Được `spec`/`deliver`/`deliver-auto`/`tracking-poll` gọi tự động; tự **no-op** nếu dự án không cấu hình tracker. Không bao giờ tự chuyển Done. |
| `git-flow` | `/msdlc:git-flow {taskid} {sync\|start\|finish}` | (luồng board, opt-in) `sync`: pull đúng nhánh TRƯỚC khi phân tích (task chưa có nhánh riêng → nhánh base; đã có → chính nhánh task đó), KHÔNG tạo nhánh. `start`: tách nhánh riêng cho mỗi task từ base branch. `finish`: build xong thì một commit (qua `msdlc:commit`) + push + tạo MR/PR + trả link để comment vào ticket. Auto-create MR qua `gh`/`glab` nếu có, không thì fallback link tạo MR tay. Tự **no-op** nếu tắt cờ / không phải git repo. **Máy không bao giờ tự merge.** |
| `commit` | `/commit` | Tạo git commit tuân thủ quy ước commit của dự án (`.claude/rules/global.md` nhóm `## Commit`); mặc định msdlc: `(type): description` + khai báo `Co-Authored-By` khi có AI hỗ trợ. |

### Commands

Commands là lệnh `/plugin:tên` dùng để setup — thường chỉ chạy một lần trên mỗi dự án.

| Command | Lệnh | Mô tả |
|---|---|---|
| `init` | `/msdlc:init` | Copy `agent-memory.md` + tạo `profile.md` + `.claude/rules/` vào `.claude/` của dự án, tự dò stack điền profile và auto-seed rule từ config sẵn có. |
| `tracking-poll` | `/msdlc:tracking-poll` | Quét board ngoài **một lượt** và tự khởi động **luồng nhẹ** cho ticket đang chờ: ticket ở cột intake → claim (Todo→planning) + `task-planner` phân tích + comment plan chi tiết → đẩy sang Validate rồi **dừng**; ticket ở cột Approved (do người kéo) → chuyển in-progress rồi build gọn (`deliver-light`) → Review. Dùng cùng `/loop` hoặc `schedule` để chạy định kỳ. Opt-in (cờ poll trong profile). |
| `log-triage` | `/msdlc:log-triage [log\|đường-dẫn-file]` | (fixbug-intake) Đọc log lỗi production (dán trực tiếp hoặc đường dẫn file) → agent `bug-triage` gom thành các loại bug + lọc noise → **tạo ticket Bug ở cột intake (Todo)** trên board để `tracking-poll` xử lý. **Bỏ qua noise** và **bỏ qua bug đã có ticket** (khử trùng qua marker `[bug-sig:…]` trên board + ledger `.claude/bug-triage/ledger.md`). CHỈ đổ ticket vào Todo — không tự build/duyệt/Done. One-shot; lặp qua `/loop` nếu trỏ file log cố định. Cần cấu hình `## Task tracker`. |

### Hooks

Hooks tự động đăng ký qua `plugin.json` — không cần cấu hình thêm.

| Hook | Trigger | Mô tả |
|---|---|---|
| `block-read-secrets.sh` | `Read` | Chặn đọc `.env*`, file khóa/cert (`.pem`, `.key`, `.p12`…), tên file rõ là secrets, SSH/cloud credentials. |
| `block-bash-dangerous.sh` | `Bash` | Chặn fork bomb, `rm -rf` hệ thống, pipe-to-shell từ internet, `git push --force` lên main/master, lệnh SQL phá hủy schema, và đọc secrets qua shell. |

### Shared

File dùng chung — copy vào `.claude/` của dự án tiêu thụ khi init.

| File | Mô tả |
|---|---|
| `shared/agent-memory.md` | Giao thức memory ~140 dòng dùng chung cho mọi agent — định nghĩa cách đọc/ghi/cập nhật memory cục bộ. |
| `shared/profile.template.md` | Mẫu `profile.md` — nguồn sự thật cho *facts* của dự án (stack, lệnh build/test, lockstep). |
| `shared/rules/*.md` | Mẫu `.claude/rules/` — nguồn *rule* theo project (`global`/`backend`/`frontend`/`security`/`testing`); mỗi rule có `id` + `severity`. |

## Cài đặt

### Dùng với Codex

Repo này có thêm manifest Codex tại `.codex-plugin/plugin.json`, trỏ tới cùng thư mục `skills/` để Codex có thể nhận diện plugin và kích hoạt các skill msdlc.

Các lệnh Claude dạng `/msdlc:init`, `/msdlc:tracking-poll`, `/msdlc:log-triage` được expose cho Codex bằng các skill wrapper:

| Claude command | Codex skill |
|---|---|
| `/msdlc:init` | `msdlc-init` |
| `/msdlc:tracking-poll` | `msdlc-tracking-poll` |
| `/msdlc:log-triage` | `msdlc-log-triage` |

Lưu ý tương thích:
- Agent prompt vẫn nằm ở `agents/*.md`; khi Codex không có "Agent tool" kiểu Claude, skill wrapper sẽ đọc prompt agent tương ứng và main agent tự thực hiện vai trò đó, hoặc dùng công cụ subagent nếu phiên Codex có.
- Hooks trong `.claude-plugin/plugin.json` là cơ chế riêng của Claude Code; Codex không đăng ký các hook đó qua manifest `.codex-plugin`.
- Runtime artifact vẫn dùng convention `.claude/` trong dự án tiêu thụ (`profile.md`, `rules/`, `shared/agent-memory.md`, `stories/`, `tasks/`) để giữ một nguồn sự thật cho cả Claude và Codex.

### Bước 1 — Cài plugin

**Từ GitHub (khuyên dùng):** add marketplace trước, rồi install theo `plugin@marketplace`:
```
/plugin marketplace add minhhv08/msdlc
/plugin install msdlc@minhhv
```
> `minhhv` là tên marketplace (trường `name` trong `.claude-plugin/marketplace.json`), `msdlc` là tên plugin. Lưu ý `/plugin install github:...` KHÔNG hợp lệ — phải add marketplace trước.
> Tương đương ngoài phiên tương tác: `claude plugin marketplace add minhhv08/msdlc && claude plugin install msdlc@minhhv`.

**Hoặc từ local** (nếu đã clone về máy):
```
/plugin marketplace add ~/claude-plugins
/plugin install msdlc@minhhv
```

### Bước 2 — Cấu hình dự án

Chạy một lần trong mỗi dự án muốn dùng pipeline:
```
/msdlc:init
```

Lệnh này copy `agent-memory.md` + tạo `profile.md` + `.claude/rules/` vào `.claude/`, tự dò stack điền profile và auto-seed rule từ config sẵn có (CLAUDE.md/CONTRIBUTING/.editorconfig/linter).

<details>
<summary>Làm thủ công nếu không dùng lệnh init</summary>

```bash
# <msdlc> = đường dẫn tới plugin: repo đã clone (github.com/minhhv08/msdlc),
# hoặc bản đã cài (tìm dưới ~/.claude/plugins/). Trong phiên Claude Code, biến
# $CLAUDE_PLUGIN_ROOT trỏ sẵn tới đây khi chạy command của plugin.
mkdir -p .claude/shared .claude/rules
cp "<msdlc>/shared/agent-memory.md" .claude/shared/agent-memory.md
cp "<msdlc>/shared/profile.template.md" .claude/profile.md
cp "<msdlc>"/shared/rules/*.md .claude/rules/
```

Rồi **điền `.claude/profile.md`** (stack, đường dẫn, lệnh build/test, hạ tầng, hợp đồng lockstep) và **`.claude/rules/`** (convention, kiến trúc, bảo mật, DoD, commit).

</details>

> **Vì sao phải copy file vào `.claude/`?** Subagent đọc file theo đường dẫn tương đối từ gốc dự án. Agent tham chiếu `.claude/profile.md`, `.claude/rules/` và `.claude/shared/agent-memory.md` — nên chúng phải tồn tại trong `.claude/` của dự án tiêu thụ. `profile.md` + `rules/` là per-project; `agent-memory.md` là bản giao thức dùng chung copy về.

### Bước 3 — Gitignore (tùy chọn)

Thêm vào `.gitignore` của dự án tiêu thụ:
```
.claude/agent-memory-local/
.claude/stories/
.claude/tasks/
```

> `.claude/stories/` (luồng thủ công) và `.claude/tasks/` (luồng board nhẹ) là artifact local per-máy — không commit (tránh link chết trên máy khác).

> `.claude/profile.md` và `.claude/rules/` thì **nên commit** — đây là cấu hình dùng chung cho cả team.

## Các workflow áp dụng

Xem sơ đồ chi tiết cho từng luồng:

- [Từ ý tưởng đến kết quả](docs/workflow-full.md)
- [Vận hành theo Kanban Board](docs/workflow-kanban-board.md)
- [Fixbug từ log](docs/workflow-fixbug-from-log.md)

### Bên trong deliver-auto (Phase 1 → 5)

Sau khi ADR được duyệt, `deliver-auto` tự điều phối các agent — song song tối đa những việc không đụng file nhau:

```mermaid
flowchart TB
    A["▶ Tiền đề: adr.md có Status: Accepted"] --> P1
    subgraph P1["Phase 1 — Plan (song song)"]
        direction LR
        DL["dev-leader<br/>vỡ task + dependsOn + touchesFiles"]
        QL1["qc-leader — enumerate<br/>test stubs + buckets"]
    end
    subgraph P2["Phase 2 — Implement ∥ thiết kế test"]
        W["dev-backend ∥ dev-frontend<br/>Wave 1..n theo file-disjoint"]
        QD["qc-designer × N — design-subset<br/>mỗi bucket một agent, fan-out từ Wave 1"]
        QL2["qc-leader — merge<br/>tests/README.md (Traceability Matrix)"]
        QD --> QL2
    end
    DL --> W
    QL1 --> QD
    W --> R["Phase 2.5 — reviewer<br/>vi phạm MUST → dev fix, ≤ 1 vòng"]
    subgraph P3["Phase 3 — QC + Security (song song, auto-fix ≤ 2 vòng)"]
        direction LR
        QE["qc-executor × project<br/>chạy test thật theo profile"]
        SA["security-auditor<br/>Critical/High chặn + trigger fix"]
    end
    R --> P3
    QL2 --> P3
    P3 --> C["Phase 4 — chronicler<br/>đồng bộ README/docs/CHANGELOG"]
    C --> REP["Phase 5 — report.md<br/>tracking → cột Review (KHÔNG tự Done)"]
```

Ba trục song song hoá chính:

- **Wave file-disjoint** — các dev task có `touchesFiles` rời nhau chạy cùng lúc; đụng file chung thì xếp wave sau.
- **Map/reduce thiết kế test** — `qc-leader` liệt kê stub + chia bucket ngay ở Phase 1, N `qc-designer` flesh-out song song với dev từ Wave 1, `qc-leader` merge lại; đến Phase 3 test suite đã sẵn.
- **QC ∥ Security** — mỗi project một `qc-executor`, chạy cùng lúc với `security-auditor`; lỗi test hoặc finding Critical/High → dev fix rồi chạy lại, ngân sách chung ≤ 2 vòng.

## Hooks bảo mật

Plugin đăng ký hai `PreToolUse` hook tự động — không cần cấu hình thêm:

| Hook | Trigger | Bảo vệ |
|---|---|---|
| `block-read-secrets.sh` | `Read` | Chặn đọc `.env*`, file khóa/cert (`.pem`, `.key`, `.p12`…), tên file rõ là secrets (`*password*`, `*api_key*`…), SSH/cloud credentials (`~/.ssh/`, `~/.aws/credentials`…) |
| `block-bash-dangerous.sh` | `Bash` | Chặn đọc secrets qua shell (`cat .env`…), fork bomb, `rm -rf` hệ thống, ghi thiết bị (`dd`, `mkfs`), pipe-to-shell từ internet, `git push --force` lên main/master, `git reset --hard` nhiều commit, lệnh SQL phá hủy schema (`DROP DATABASE`, `TRUNCATE TABLE`), `chmod 777` thư mục hệ thống |

Hook exit 1 → Claude Code hủy lệnh tương ứng và hiện thông báo `[msdlc] BLOCKED: ...`.

---

## Từ khóa & thuật ngữ

| Thuật ngữ | Mô tả |
|---|---|
| **plugin** | Gói mở rộng cài vào Claude Code, đóng gói sẵn agents/skills/hooks để tái dùng qua nhiều dự án. |
| **agent** | Một vai trò AI chuyên biệt (file `.md`) — nhận nhiệm vụ, đọc context, thực thi, trả kết quả. Main agent gọi agent khác qua `Agent tool`. |
| **skill** | Lệnh `/tên` do người dùng gọi trực tiếp trong Claude Code. Skill điều phối nhiều agent để hoàn thành một luồng lớn (vd `/deliver`). |
| **command** | Lệnh `/plugin:tên` dùng để cài đặt/cấu hình một lần (vd `/msdlc:init`). Khác skill ở chỗ thường chỉ chạy một lần khi setup. |
| **hook** | Script shell tự động chạy trước/sau khi Claude Code dùng một tool (vd trước `Bash`, `Read`). Plugin đăng ký hook qua `plugin.json`. |
| **profile** | File `.claude/profile.md` trong *dự án tiêu thụ* — chứa *facts* của dự án: stack, lệnh build/test, hợp đồng lockstep. Agents đọc file này thay vì hardcode. |
| **rules** | Thư mục `.claude/rules/` trong *dự án tiêu thụ* — *rule theo project* (convention, kiến trúc, bảo mật, Definition-of-Done, commit), chia theo scope. Mỗi rule có `id` + `severity` (`MUST` chặn / `SHOULD` gợi ý); `reviewer`/`security-auditor` enforce. Trống → suy convention từ code lân cận. |
| **ruleId** | Định danh một rule trong `.claude/rules/` (vd `R-BE-1`, `R-SEC-2`). `reviewer`/`security-auditor` gắn `ruleId` vào finding để truy vết về rule bị vi phạm. |
| **agent-memory** | Cơ chế agent ghi nhớ context giữa các lần chạy, lưu trong `.claude/agent-memory-local/<tên-agent>/`. Giao thức định nghĩa tại `shared/agent-memory.md`. |
| **story** | (luồng thủ công) Một feature/yêu cầu cụ thể, id dạng số thứ tự (vd `001`). Mọi artifact nằm trong `.claude/stories/{id}/`. Đi qua `/spec`→`/deliver`→`deliver-auto` với gate ADR. |
| **task (board)** | (luồng board nhẹ) Một feat/fixbug nhỏ từ board ngoài, `taskid` = ID ticket (vd `PROJ-123`). Artifact ở `.claude/tasks/{taskid}/` (`plan.md`/`report.md`). Đi qua `tracking-poll`→`task-planner`→`deliver-light` với gate là kéo thẻ sang Approved. |
| **ADR** | *Architecture Decision Record* — tài liệu quyết định thiết kế do `architect` tạo ra (`adr.md`). Phải được user duyệt trước khi pipeline tự động chạy tiếp. |
| **requirement** | File `requirement.md` do `/spec` tạo ra — mô tả yêu cầu có cấu trúc (mục tiêu, scope, AC, ràng buộc). |
| **lockstep** | Hợp đồng đồng bộ giữa các project (vd migration phải chạy trước khi deploy service phụ thuộc). Mô tả trong `profile.md`, agents tôn trọng khi implement. |
| **wave** | Một đợt dev agents chạy song song trong Phase 2 — gồm các task có `touchesFiles` rời nhau nên không xung đột file. |
| **file-disjoint** | Điều kiện để hai task có thể chạy song song: tập file chúng đụng tới không giao nhau. |
| **auto-fix** | Agent tự sửa lỗi trong ngân sách giới hạn (reviewer ≤1 vòng, qc-executor + security-auditor ≤2 vòng) trước khi dừng và báo cáo. |
| **infraMissing** | Trạng thái `qc-executor` báo khi hạ tầng test chưa sẵn sàng (DB chưa up, service phụ thuộc chưa chạy…) — không tự fix được, báo trung thực. |
| **consuming project** | Dự án *dùng* plugin này (khác với repo plugin). Phải có `.claude/profile.md` và `.claude/shared/agent-memory.md` để agents hoạt động. |
| **GATE** | Điểm dừng duy nhất yêu cầu user xác nhận thủ công. Luồng thủ công: sau khi `architect` tạo xong ADR. Luồng board: sau khi `task-planner` comment plan (ticket ở `Validate`) — gate = thao tác người kéo thẻ `Validate`→`Approved`. |
| **tracker sync** | Cơ chế đồng bộ trạng thái story/task ↔ cột board ngoài, gom trong skill `msdlc:tracking` (tham số `kind` = `story`\|`task`). Opt-in qua mục `## Task tracker` của `profile.md`; tự no-op khi không cấu hình; không bao giờ tự chuyển Done. |
| **poll** | Lệnh `/msdlc:tracking-poll` quét board một lượt, tự khởi động **luồng nhẹ** cho ticket ở cột intake/Approved (claim Todo→planning → `task-planner` → plan → build gọn bằng `deliver-light`). Lặp bằng `/loop` hoặc `schedule`. Opt-in (cờ `poll` trong profile), vẫn giữ cổng duyệt. |
| **git flow** | (opt-in, mục `## Git` profile) Luồng poll `sync` pull đúng nhánh trước khi phân tích (chưa có nhánh task → nhánh base; đã có → nhánh task), tách một nhánh/task từ base branch, build xong commit + push + tạo MR/PR + comment link vào ticket. Gom trong skill `msdlc:git-flow`; auto-create MR qua `gh`/`glab` hoặc fallback link tạo tay. Một build/lượt, làm lần lượt từng task; **máy không tự merge** (người merge + đóng ticket). Tắt = phân tích/build thẳng branch hiện tại như cũ. |
| **fixbug intake / log-triage** | Lệnh `/msdlc:log-triage` biến log lỗi production thành ticket Bug ở cột Todo để luồng board xử lý. Agent `bug-triage` gom log thành các loại bug + lọc noise; main agent khử trùng rồi tạo ticket. Bước **intake** đứng trước `tracking-poll` — chỉ đổ ticket vào Todo, không tự build/duyệt/Done. |
| **bug-sig** | Chữ ký ổn định của một loại bug (hash của `signatureBasis`: exception type + message chuẩn hóa + top app-frame). Nhúng dạng `[bug-sig:<hash>]` trong description ticket làm **khóa khử trùng** — board là nguồn sự thật, ledger `.claude/bug-triage/ledger.md` chỉ là cache. |

---

## Thiết kế "sạch hardcode"

- Agent chỉ giữ **vai trò + quy trình**; *facts* dự án nằm trong `profile.md`, *rule* dự án nằm trong `.claude/rules/`.
- `dev-backend` phục vụ mọi ngôn ngữ/framework backend (tự nhận diện theo file đụng tới); `dev-frontend` phục vụ UI web.
- Giao thức memory ~140 dòng gom 1 bản tại `shared/agent-memory.md` thay vì lặp trong từng agent.
- Rule là *cấu hình per-project*, không phải prompt: thêm/sửa rule trong dự án tiêu thụ không cần đụng định nghĩa agent. Dự án chưa có `.claude/rules/` chạy y hệt như trước.
