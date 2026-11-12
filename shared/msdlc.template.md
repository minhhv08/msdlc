# msdlc — cấu hình điều phối

> Chỉ main agent đọc file này (skill `tracking`, `git-flow`, `deliver-*`, command `tracking-poll`/`log-triage`). Subagent KHÔNG đọc — nên facts của dự án (stack, lệnh, lockstep) để ở `.claude/profile.md`.
> Nên commit file này (cấu hình dùng chung cho team).

## Task tracker (nếu có)
<!--
  Cấu hình đồng bộ story ↔ board ngoài (Jira/Asana/Linear/Monday/Notion). Skill `msdlc:tracking` đọc mục này.
  ĐỂ TRỐNG TOÀN BỘ MỤC NÀY = tắt sync; pipeline chạy thuần local y như cũ.
  KHÔNG hardcode trong plugin — mọi thứ đọc từ đây.
-->
- Tool: `<Jira | Asana | Linear | Monday | Notion>` — connector MCP: `<Atlassian | Asana | Linear | monday | Notion>`
- Project/board key: `<vd PROJ | board id | Notion database ID>` <!-- Notion: dùng database ID; "cột" = option của property Status; ticket id = page ID -->
- Cột (status) cấu hình bên dưới: với **Notion** là tên các **option của property Status/Select** (không phải cột kanban Jira).
- Ánh xạ mốc pipeline → tên cột trên board (bỏ trống dòng nào → skill tự suy theo keyword):
  - todo → `<vd Todo>` <!-- nên trùng "Cột intake" của poll bên dưới, để ticket /spec tạo nằm đúng cột poll quét -->
  - planning → `<vd Planning>` <!-- LUỒNG BOARD NHẸ: cột này là bước CLAIM/LOCK (poll chuyển Todo→planning để nhận ticket). NÊN điền rõ tên cột, đừng để trống — nếu detect-keyword đoán trượt, cơ chế "chỉ 1 session nhận" sẽ hỏng. -->
  - validate → `<vd Validate>`
  - approved → `<vd Approved>`
  - in-progress → `<vd InProgress>`
  - review → `<vd Review>`
  - <!-- Done KHÔNG cấu hình: msdlc không bao giờ tự chuyển Done. -->
- Poll (tự động kéo task từ board — dùng bởi `/msdlc:tracking-poll`, chạy LUỒNG NHẸ: `.claude/tasks/{taskid}/` + `task-planner` → `plan.md` → `deliver-task`, KHÔNG dùng architect/ADR/deliver-story):
  - Cột intake (nơi kéo task mới về để phân tích): `<vd Todo>`
  - Cột build-trigger (người kéo tay sang đây = duyệt plan, cho phép tự build): `<vd Approved>`
  - Bật poll: `<no>` <!-- mặc định no; đổi thành yes để cho phép /msdlc:tracking-poll xử lý. Opt-in vì đây là tự động mạnh. -->

## Git (nếu dùng git flow cho poll)
<!--
  Cấu hình git flow cho luồng board nhẹ (`/msdlc:tracking-poll` → skill `msdlc:git-flow`):
  mỗi task board làm trên một nhánh riêng tách từ base, build xong tự commit + push + tạo MR + comment link vào ticket.
  ĐỂ CỜ TẮT (mặc định) = poll build thẳng trên branch hiện tại như cũ (không nhánh/MR). Máy KHÔNG BAO GIỜ tự merge.
-->
- Bật git flow: `<no>` <!-- opt-in; đổi thành yes để bật tách nhánh + MR cho poll. -->
- Base branch: `<để trống → auto-detect default branch của remote; vd main | master | production>`
- Branch pattern: `<để trống → <type>/<taskid>-<slug>; type theo msdlc:commit (feat/fix/…), slug từ title ticket>`
- MR tool: `<để trống → auto-detect từ remote URL | gh | glab | bitbucket>`
- MR target branch: `<để trống → = Base branch>`

## Pipeline (tuỳ chọn — tối ưu token)

<!-- Bỏ trống = auto: deliver-story/deliver-task chỉ gọi security-auditor / chronicler khi thay đổi cần tới,
     story nhỏ dùng 1 qc-designer thay cho map/reduce. Chi tiết tiêu chí: skills/deliver-story/gating.md của plugin.
     Đặt `always` để luôn chạy như trước. -->
- security-audit: auto
- docs-sync: auto
- qc-design: auto
- security-sensitive-paths: <tuỳ chọn, vd thư mục auth/, payment/>
- model-downgrade: auto   # auto: chọn model rẻ hơn theo độ lớn việc (gating G4/G5); never: luôn dùng model mặc định của agent
