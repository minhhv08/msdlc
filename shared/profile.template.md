# Project Profile (template)

> Các agent của pipeline (dev-leader, architect, dev, qc-*, chronicler) đọc file này để biết **đặc thù dự án (facts)** —
> stack, đường dẫn, lệnh build/test, hợp đồng lockstep. **Plugin không nhúng cứng các thông tin này.**
> Còn **rule/quy ước (convention, kiến trúc, security, DoD, commit)** sống ở `.claude/rules/` — xem các file ở đó.
>
> Cách dùng: copy file này về `.claude/profile.md` ở dự án của bạn rồi điền. Xóa các mục không áp dụng.
> Nếu một mục để trống, agent sẽ hỏi user hoặc suy ra từ codebase thay vì giả định.

## Projects & stack
<!-- Liệt kê từng thư mục project + stack/ngôn ngữ/build tool + port nếu có. Một dòng mỗi project. -->
- `<dir>/` — <stack, ngôn ngữ, build tool> (port <…>)

## Đường dẫn quy ước
<!-- Nơi pipeline đọc/ghi artifact. -->
- Story root (luồng thủ công `/spec`+`/deliver`): `.claude/stories/{id}/`
- Requirement: `.claude/stories/{id}/requirement.md`
- ADR: `.claude/stories/{id}/adr.md`
- Tasks: `.claude/stories/{id}/tasks/` (index `README.md`)
- Tests (QC design): `.claude/stories/{id}/tests/`
- Task root (luồng board nhẹ `tracking-poll`+`deliver-light`, `{taskid}` = ID ticket): `.claude/tasks/{taskid}/`
- Plan (board nhẹ): `.claude/tasks/{taskid}/plan.md`
- Tài liệu chung: `docs/`

## Quy ước diagram (nếu có)
<!-- architect đọc mục này khi cần vẽ sơ đồ kiến trúc. ĐỂ TRỐNG = mặc định msdlc: PlantUML, source `docs/diagrams/{name}.puml`, ref file `.svg` render sẵn. -->
- Công cụ: `<PlantUML | Mermaid | …>`
- Đường dẫn source/render: `<vd docs/diagrams/>`

## Lệnh build / test / run
<!-- Lệnh chính xác cho từng project; qc-executor và dev dùng các lệnh này. -->
- `<dir>/` build: `<…>`
- `<dir>/` test toàn bộ: `<…>`
- `<dir>/` test 1 class/method: `<…>`
- `<dir>/` chạy app: `<…>`

## Hạ tầng local (nếu test tích hợp cần)
<!-- Lệnh dựng dependency + cổng. qc-executor báo BLOCKED nếu thiếu các thứ này. -->
- `<docker run …>` — cổng `<…>`

## Hợp đồng lockstep liên-project (nếu có)
<!-- Các file/artifact phải đổi đồng bộ với nhau. Bỏ qua nếu dự án đơn lẻ. -->
- <mô tả: khi đổi X thì phải đồng bộ A ↔ B ↔ C>
- Migration: <quy tắc, vd immutable, đánh số tăng dần>
- Cache cần evict sau khi ghi: `<key pattern>` — lệnh `<…>` (TTL `<…>`)

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
- Poll (tự động kéo task từ board — dùng bởi `/msdlc:tracking-poll`, chạy LUỒNG NHẸ: `.claude/tasks/{taskid}/` + `task-planner` → `plan.md` → `deliver-light`, KHÔNG dùng architect/ADR/deliver-auto):
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

## Quy tắc commit
<!-- Commit rule KHÔNG còn ở profile. Xem `.claude/rules/global.md` nhóm `## Commit`. -->
→ Quy tắc commit sống ở `.claude/rules/global.md` (nhóm `## Commit`). Skill `msdlc:commit` đọc từ đó.
