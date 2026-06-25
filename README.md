# msdlc

Một plugin Claude Code đóng gói pipeline giao hàng **độc lập stack**:

```
idea → /spec → architect → [GATE duyệt ADR]
     → planner
     → qc-designer + dev-backend / dev-frontend (song song — qc-designer chạy cùng Wave 1)
     → reviewer (auto-fix ≤1)
     → qc-executor + security-auditor (song song, auto-fix ≤2)
     → chronicler
```

Mọi đặc thù dự án (stack, đường dẫn, lệnh test, hợp đồng lockstep, quy tắc commit) **không nhúng cứng** trong agent — chúng đọc từ `.claude/profile.md` của dự án tiêu thụ lúc chạy.

## Thành phần

### Agents

Mỗi agent là một vai trò AI chuyên biệt — được gọi qua `Agent tool` bởi skill hoặc main agent điều phối.

| Agent | Vai trò |
|---|---|
| `architect` | Đọc `requirement.md`, thiết kế phương án kỹ thuật, ghi `adr.md` và cập nhật `docs/architecture.md`. |
| `planner` | Đọc `adr.md` + `requirement.md`, vỡ thành danh sách task atomic có dependency graph, ghi ra `tasks/`. |
| `dev-backend` | Implement code server-side (bất kỳ ngôn ngữ/framework theo profile): service, controller, repository, migration, API endpoint… |
| `dev-frontend` | Implement UI web theo task spec — đọc profile để biết framework/component convention của dự án. |
| `qc-designer` | Thiết kế test case (positive/negative/boundary/edge) từ spec + ADR, ghi ra `tests/` — chạy trước khi có code. |
| `qc-executor` | Chạy test suite thực tế bằng lệnh trong profile, báo pass/fail/infraMissing, auto-fix ≤2 vòng. |
| `reviewer` | Review diff theo 6 chiều (đúng spec, lockstep, logic, convention, test alignment, readability), trả verdict có cấu trúc. |
| `security-auditor` | Audit diff tìm lỗ hổng bảo mật (injection, auth/authz, secrets leak, crypto, SSRF, XSS/CSRF, IDOR…), auto-fix Critical/High ≤2 vòng. |
| `chronicler` | Đồng bộ README/docs/docstring/inline comment với code vừa thay đổi — không tự thêm tính năng chưa có trong code. |

### Skills

Skills là lệnh `/tên` người dùng gọi trực tiếp trong Claude Code.

| Skill | Lệnh | Mô tả |
|---|---|---|
| `spec` | `/spec` | Phỏng vấn có cấu trúc để biến ý tưởng còn mơ hồ thành `requirement.md` rõ ràng (mục tiêu, scope, AC, ràng buộc). |
| `deliver` | `/deliver {id}` | Chạy toàn bộ pipeline cho một story: architect → **[GATE duyệt ADR]** → auto-deliver. |
| `auto-deliver` | (nội bộ) | Điều phối Phase 1–5 sau khi ADR đã duyệt: planner → dev + qc-designer → reviewer → qc-executor + security-auditor → chronicler. |
| `commit` | `/commit` | Tạo git commit tuân thủ quy ước msdlc: `(type): description` + khai báo `Co-Authored-By` khi có AI hỗ trợ. |

### Commands

Commands là lệnh `/plugin:tên` dùng để setup — thường chỉ chạy một lần trên mỗi dự án.

| Command | Lệnh | Mô tả |
|---|---|---|
| `init` | `/msdlc:init` | Copy `agent-memory.md` + tạo `profile.md` vào `.claude/` của dự án, tự dò stack và hướng dẫn điền profile. |

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
| `shared/profile.template.md` | Mẫu `profile.md` — nguồn sự thật cho mọi đặc thù dự án (stack, lệnh build/test, lockstep, quy tắc commit). |

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

Lệnh này copy `agent-memory.md` + tạo `profile.md` vào `.claude/`, tự dò stack và hướng dẫn điền profile.

<details>
<summary>Làm thủ công nếu không dùng lệnh init</summary>

```bash
mkdir -p .claude/shared
cp "$(claude plugin path msdlc)/shared/agent-memory.md" .claude/shared/agent-memory.md
cp "$(claude plugin path msdlc)/shared/profile.template.md" .claude/profile.md
```

Rồi **điền `.claude/profile.md`** cho dự án (stack, đường dẫn, lệnh build/test, hạ tầng, hợp đồng lockstep, quy tắc commit).

</details>

> **Vì sao phải copy 2 file vào `.claude/`?** Subagent đọc file theo đường dẫn tương đối từ gốc dự án. Agent tham chiếu `.claude/profile.md` và `.claude/shared/agent-memory.md` — nên hai file đó phải tồn tại trong `.claude/` của dự án tiêu thụ. `profile.md` là per-project; `agent-memory.md` là bản giao thức dùng chung copy về.

### Bước 3 — Gitignore (tùy chọn)

Thêm vào `.gitignore` của dự án tiêu thụ:
```
.claude/agent-memory-local/
```

## Dùng

- `/spec` — phỏng vấn biến ý tưởng thành requirement.
- `/deliver {id}` — chạy cả pipeline với một cổng duyệt sau ADR.
- Hoặc gọi từng agent qua Agent tool theo nhu cầu.

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
| **profile** | File `.claude/profile.md` trong *dự án tiêu thụ* — chứa toàn bộ đặc thù dự án: stack, lệnh build/test, hợp đồng lockstep, quy tắc commit. Agents đọc file này thay vì hardcode. |
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
| **GATE** | Điểm dừng duy nhất trong pipeline yêu cầu user xác nhận thủ công — hiện tại chỉ có 1 gate sau khi `architect` tạo xong ADR. |

---

## Thiết kế "sạch hardcode"

- Agent chỉ giữ **vai trò + quy trình**; sự thật dự án nằm trong `profile.md`.
- `dev-backend` phục vụ mọi ngôn ngữ/framework backend (tự nhận diện theo file đụng tới); `dev-frontend` phục vụ UI web.
- Giao thức memory ~140 dòng gom 1 bản tại `shared/agent-memory.md` thay vì lặp trong từng agent.
