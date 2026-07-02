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
- Story root: `.claude/stories/{id}/`
- Requirement: `.claude/stories/{id}/requirement.md`
- ADR: `.claude/stories/{id}/adr.md`
- Tasks: `.claude/stories/{id}/tasks/` (index `README.md`)
- Tests (QC design): `.claude/stories/{id}/tests/`
- Tài liệu chung: `docs/`

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
  Cấu hình đồng bộ story ↔ board ngoài (Jira/Asana/Linear/Monday). Skill `msdlc:tracking` đọc mục này.
  ĐỂ TRỐNG TOÀN BỘ MỤC NÀY = tắt sync; pipeline chạy thuần local y như cũ.
  KHÔNG hardcode trong plugin — mọi thứ đọc từ đây.
-->
- Tool: `<Jira | Asana | Linear | Monday>` — connector MCP: `<Atlassian | Asana | Linear | monday>`
- Project/board key: `<vd PROJ | board id>`
- Ánh xạ mốc pipeline → tên cột trên board (bỏ trống dòng nào → skill tự suy theo keyword):
  - planning → `<vd Planing>`
  - validate → `<vd Validate>`
  - approved → `<vd Approved>`
  - in-progress → `<vd InProgess>`
  - review → `<vd Review>`
  - <!-- Done KHÔNG cấu hình: msdlc không bao giờ tự chuyển Done. -->
- Poll (tự động kéo task từ board — dùng bởi `/msdlc:tracking-poll`):
  - Cột intake (nơi kéo task mới về để thiết kế): `<vd Todo>`
  - Cột build-trigger (người kéo tay sang đây = duyệt ADR, cho phép tự build): `<vd Approved>`
  - Bật poll: `<no>` <!-- mặc định no; đổi thành yes để cho phép /msdlc:tracking-poll xử lý. Opt-in vì đây là tự động mạnh. -->

## Quy tắc commit
<!-- Commit rule KHÔNG còn ở profile. Xem `.claude/rules/global.md` nhóm `## Commit`. -->
→ Quy tắc commit sống ở `.claude/rules/global.md` (nhóm `## Commit`). Skill `msdlc:commit` đọc từ đó.
