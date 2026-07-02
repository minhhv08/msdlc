# msdlc

Một plugin Claude Code đóng gói pipeline giao hàng **độc lập stack**:

```
idea → /spec → architect → [GATE duyệt ADR]
     → dev-leader  ∥  qc-leader (enumerate)          (song song ở Phase 1)
     → dev-backend / dev-frontend (song song theo file-disjoint)
       ∥ qc-designer ×N (design-subset, fan-out từ Wave 1) → qc-leader (merge)
     → reviewer (auto-fix ≤1)
     → qc-executor + security-auditor (song song, auto-fix ≤2)
     → chronicler
```

Mọi đặc thù dự án **không nhúng cứng** trong agent — chúng đọc lúc chạy từ hai nguồn của dự án tiêu thụ:
- `.claude/profile.md` — **facts**: stack, đường dẫn, lệnh test, hợp đồng lockstep.
- `.claude/rules/` — **rule theo project**: convention, kiến trúc, bảo mật, Definition-of-Done, commit; chia theo scope (`global`/`backend`/`frontend`/`security`/`testing`), mỗi rule có `id` + `severity` (`MUST` chặn / `SHOULD` gợi ý). Không có rule → agent suy convention từ code lân cận như cũ.

## Thành phần

### Agents

Mỗi agent là một vai trò AI chuyên biệt — được gọi qua `Agent tool` bởi skill hoặc main agent điều phối.

| Agent | Vai trò |
|---|---|
| `architect` | Đọc `requirement.md`, thiết kế phương án kỹ thuật, ghi `adr.md` và cập nhật `docs/architecture.md`. |
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
| `tracking` | `/msdlc:tracking {id} {phase}` | Đồng bộ trạng thái story sang cột board ngoài (Jira/Asana/Linear/Monday) tại một mốc (`todo`/`planning`/`validate`/`approved`/`in-progress`/`review`). Được `spec`/`deliver`/`deliver-auto` gọi tự động; tự **no-op** nếu dự án không cấu hình tracker. Không bao giờ tự chuyển Done. |
| `commit` | `/commit` | Tạo git commit tuân thủ quy ước commit của dự án (`.claude/rules/global.md` nhóm `## Commit`); mặc định msdlc: `(type): description` + khai báo `Co-Authored-By` khi có AI hỗ trợ. |

### Commands

Commands là lệnh `/plugin:tên` dùng để setup — thường chỉ chạy một lần trên mỗi dự án.

| Command | Lệnh | Mô tả |
|---|---|---|
| `init` | `/msdlc:init` | Copy `agent-memory.md` + tạo `profile.md` + `.claude/rules/` vào `.claude/` của dự án, tự dò stack điền profile và auto-seed rule từ config sẵn có. |
| `tracking-poll` | `/msdlc:tracking-poll` | Quét board ngoài **một lượt** và tự khởi động pipeline cho ticket đang chờ: ticket ở cột intake → tạo story + architect + đẩy sang Validate rồi **dừng**; ticket ở cột Approved (do người kéo) → tự build → Review. Dùng cùng `/loop` hoặc `schedule` để chạy định kỳ. Opt-in (cờ poll trong profile). |

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

### Bước 1 — Cài plugin

**Từ GitHub (khuyên dùng):**
```
/plugin install github:minhhv08/msdlc
```

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
mkdir -p .claude/shared .claude/rules
cp "$(claude plugin path msdlc)/shared/agent-memory.md" .claude/shared/agent-memory.md
cp "$(claude plugin path msdlc)/shared/profile.template.md" .claude/profile.md
cp "$(claude plugin path msdlc)"/shared/rules/*.md .claude/rules/
```

Rồi **điền `.claude/profile.md`** (stack, đường dẫn, lệnh build/test, hạ tầng, hợp đồng lockstep) và **`.claude/rules/`** (convention, kiến trúc, bảo mật, DoD, commit).

</details>

> **Vì sao phải copy file vào `.claude/`?** Subagent đọc file theo đường dẫn tương đối từ gốc dự án. Agent tham chiếu `.claude/profile.md`, `.claude/rules/` và `.claude/shared/agent-memory.md` — nên chúng phải tồn tại trong `.claude/` của dự án tiêu thụ. `profile.md` + `rules/` là per-project; `agent-memory.md` là bản giao thức dùng chung copy về.

### Bước 3 — Gitignore (tùy chọn)

Thêm vào `.gitignore` của dự án tiêu thụ:
```
.claude/agent-memory-local/
```

> `.claude/profile.md` và `.claude/rules/` thì **nên commit** — đây là cấu hình dùng chung cho cả team.

## Dùng

- `/spec` — phỏng vấn biến ý tưởng thành requirement.
- `/deliver {id}` — chạy cả pipeline với một cổng duyệt sau ADR.
- Hoặc gọi từng agent qua Agent tool theo nhu cầu.

## Đồng bộ board ngoài (tùy chọn)

Nếu dự án dùng board (Jira/Asana/Linear/Monday), msdlc có thể tự chuyển cột ticket theo tiến độ pipeline. **Tính năng opt-in**: không cấu hình mục `## Task tracker` trong `.claude/profile.md` → pipeline chạy thuần local **y như cũ** (skill `msdlc:tracking` tự no-op).

Ánh xạ mốc pipeline → cột board (tên cột cấu hình được trong profile; ví dụ theo flow phổ biến):

```
Backlog → Todo → Planing → Validate → Approved → InProgess → Review → Done
          └─(1)──────────┘  (user)    └─(2)────────────────┘   (user) (user)
   idea    spec   architect   ADR gate   người      build+QC+review   người verify
                              (duyệt = kéo Validate→Approved)          + đóng Done
```

- Đoạn **(1)** và **(2)** là hai khúc tự động của pipeline; giữa chúng là **cổng duyệt** — chính là thao tác **người kéo thẻ** từ `Validate` sang `Approved`. Máy không bao giờ tự vượt.
- `Done` **không bao giờ** do máy chuyển — luôn để người verify và đóng thủ công.

### Tự động kéo task từ board (loop)

`/msdlc:tracking-poll` quét board **một lượt**: ticket ở cột intake → tạo story + thiết kế ADR + đẩy sang `Validate` rồi dừng; ticket ở cột `Approved` (người đã duyệt) → tự build → `Review`. Để chạy định kỳ, ghép với cơ chế lặp của harness (msdlc không tự chế scheduling):

- **`/loop 10m /msdlc:tracking-poll`** — lặp theo interval trong phiên đang mở. Đơn giản; dừng khi đóng phiên/máy.
- **`schedule`** (cloud cron) — tạo scheduled agent chạy nền kể cả khi tắt máy. Bền hơn cho vận hành liên tục.

Bật poll là tự động mạnh → phải bật cờ `poll` trong profile (mặc định tắt). Dù bật, loop **vẫn giữ cổng duyệt**: chỉ tự build ticket đã được người kéo sang `Approved`.

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
| **story** | Một feature/yêu cầu cụ thể, được đặt id (vd `001`). Mọi artifact của story nằm trong `.claude/stories/{id}/`. |
| **ADR** | *Architecture Decision Record* — tài liệu quyết định thiết kế do `architect` tạo ra (`adr.md`). Phải được user duyệt trước khi pipeline tự động chạy tiếp. |
| **requirement** | File `requirement.md` do `/spec` tạo ra — mô tả yêu cầu có cấu trúc (mục tiêu, scope, AC, ràng buộc). |
| **lockstep** | Hợp đồng đồng bộ giữa các project (vd migration phải chạy trước khi deploy service phụ thuộc). Mô tả trong `profile.md`, agents tôn trọng khi implement. |
| **wave** | Một đợt dev agents chạy song song trong Phase 2 — gồm các task có `touchesFiles` rời nhau nên không xung đột file. |
| **file-disjoint** | Điều kiện để hai task có thể chạy song song: tập file chúng đụng tới không giao nhau. |
| **auto-fix** | Agent tự sửa lỗi trong ngân sách giới hạn (reviewer ≤1 vòng, qc-executor + security-auditor ≤2 vòng) trước khi dừng và báo cáo. |
| **infraMissing** | Trạng thái `qc-executor` báo khi hạ tầng test chưa sẵn sàng (DB chưa up, service phụ thuộc chưa chạy…) — không tự fix được, báo trung thực. |
| **consuming project** | Dự án *dùng* plugin này (khác với repo plugin). Phải có `.claude/profile.md` và `.claude/shared/agent-memory.md` để agents hoạt động. |
| **GATE** | Điểm dừng duy nhất trong pipeline yêu cầu user xác nhận thủ công — hiện tại chỉ có 1 gate sau khi `architect` tạo xong ADR. Khi dùng board, gate = thao tác người kéo thẻ `Validate`→`Approved`. |
| **tracker sync** | Cơ chế đồng bộ trạng thái story ↔ cột board ngoài, gom trong skill `msdlc:tracking`. Opt-in qua mục `## Task tracker` của `profile.md`; tự no-op khi không cấu hình; không bao giờ tự chuyển Done. |
| **poll** | Lệnh `/msdlc:tracking-poll` quét board một lượt, tự khởi động pipeline cho ticket ở cột intake/Approved. Lặp bằng `/loop` hoặc `schedule`. Opt-in (cờ `poll` trong profile), vẫn giữ cổng duyệt. |

---

## Thiết kế "sạch hardcode"

- Agent chỉ giữ **vai trò + quy trình**; *facts* dự án nằm trong `profile.md`, *rule* dự án nằm trong `.claude/rules/`.
- `dev-backend` phục vụ mọi ngôn ngữ/framework backend (tự nhận diện theo file đụng tới); `dev-frontend` phục vụ UI web.
- Giao thức memory ~140 dòng gom 1 bản tại `shared/agent-memory.md` thay vì lặp trong từng agent.
- Rule là *cấu hình per-project*, không phải prompt: thêm/sửa rule trong dự án tiêu thụ không cần đụng định nghĩa agent. Dự án chưa có `.claude/rules/` chạy y hệt như trước.
