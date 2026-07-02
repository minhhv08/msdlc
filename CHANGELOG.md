# Changelog

## [0.2.0] — 2026-07-01

### Added

- Agent mới **`qc-leader`** điều phối thiết kế test theo **map/reduce**: chế độ *enumerate* (liệt kê test-case stub + đề xuất bucket cân bằng + coverage) và *merge* (gộp các part thành Traceability Matrix + Coverage & Gaps ở `tests/README.md`).
- `qc-designer` thêm chế độ **design-subset**: nhận danh sách stub + file output riêng, flesh-out đặc tả đầy đủ, giữ nguyên `id`/`source`. Chế độ *full* (gọi lẻ) giữ nguyên — backward-compatible.
- Cơ chế **per-project rules** `.claude/rules/` (scope: `global`/`backend`/`frontend`/`security`/`testing`); mỗi rule có `id` + `severity` (`MUST`/`SHOULD`). Template trong `shared/rules/`.
- `reviewer` enforce rule: vi phạm `MUST` → blocking, `SHOULD` → suggestion; finding mang `ruleId`.
- `security-auditor` enforce `R-SEC-*`: vi phạm `MUST` được nâng severity tối thiểu `High`; finding mang `ruleId`.
- `/msdlc:init` copy `shared/rules/` (no-overwrite) + auto-seed rule từ CLAUDE.md/CONTRIBUTING/.editorconfig/linter, đánh dấu `<!-- seeded, cần xác nhận -->`.

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
