# Changelog

## [Unreleased]

### Added
- Cơ chế **per-project rules** `.claude/rules/` (scope: `global`/`backend`/`frontend`/`security`/`testing`); mỗi rule có `id` + `severity` (`MUST`/`SHOULD`). Template trong `shared/rules/`.
- `reviewer` enforce rule: vi phạm `MUST` → blocking, `SHOULD` → suggestion; finding mang `ruleId`.
- `security-auditor` enforce `R-SEC-*`: vi phạm `MUST` được nâng severity tối thiểu `High`; finding mang `ruleId`.
- `/msdlc:init` copy `shared/rules/` (no-overwrite) + auto-seed rule từ CLAUDE.md/CONTRIBUTING/.editorconfig/linter, đánh dấu `<!-- seeded, cần xác nhận -->`.

### Changed
- Mọi agent đọc thêm `.claude/rules/` đúng scope; `chronicler` nay cũng đọc profile + rules. Thiếu rules → giữ hành vi cũ (không regression).
- Quy tắc commit chuyển từ `profile.md` sang `.claude/rules/global.md` nhóm `## Commit`; skill `commit` ưu tiên rule của dự án, fallback về định dạng msdlc.

- fix: tách `planner` ra Phase 1 riêng, `qc-designer` chạy song song với Wave 1 dev thay vì block dev agents
- docs: cập nhật README — thành phần tách theo loại, bảng thuật ngữ, section hooks

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
