# Rules — global (scope: all) — template

> **Nguồn rule theo project, áp dụng cho MỌI agent.** Copy thư mục này về `.claude/rules/` ở dự án của bạn rồi điền.
> Mỗi rule có `id`, `severity`, mô tả mệnh lệnh:
> - `MUST` = ràng buộc cứng. `reviewer` (và `security-auditor` cho rule bảo mật) biến vi phạm thành **blocking** và pipeline chạy vòng auto-fix.
> - `SHOULD` = khuyến nghị. Xuất hiện ở `suggestions`, không chặn.
>
> **Bảng trống = giữ hành vi cũ:** nếu không có rule nào, agent suy convention từ code lân cận như trước (không regression).
> Đừng bịa rule — chỉ ghi điều dự án thực sự yêu cầu. Prefix id: `R-GLOBAL-*` (riêng nhóm `## Commit` dùng prefix `R-COMMIT-*`).

## Coding convention & anti-pattern (scope: all)

<!-- Convention chung mọi ngôn ngữ trong repo, và anti-pattern bị cấm. -->

| id | severity | rule |
| --- | --- | --- |
<!-- | R-GLOBAL-1 | MUST | Không để lại debug print / console.log / dump trong code commit. | -->
<!-- | R-GLOBAL-2 | SHOULD | Hàm/khối public phải có docstring mô tả mục đích. | -->

## Kiến trúc bắt buộc / cấm (scope: all)

<!-- Quyết định kiến trúc toàn repo mà mọi thay đổi phải tôn trọng. architect ghi rule này vào ADR. -->

| id | severity | rule |
| --- | --- | --- |
<!-- | R-GLOBAL-10 | MUST | Tầng controller không gọi trực tiếp DB — phải qua service/repository. | -->

## Definition of Done (scope: all)

<!-- Tiêu chí "done" chung cho mọi story. dev-leader sinh task thoả các tiêu chí này; qc-executor coi là tiêu chí PASS bổ sung nếu đo được. -->

| id | severity | rule |
| --- | --- | --- |
<!-- | R-GLOBAL-20 | MUST | Mọi logic mới phải có test tương ứng và test phải xanh. | -->
<!-- | R-GLOBAL-21 | MUST | Tài liệu liên quan (README/docs) được cập nhật đồng bộ với thay đổi public. | -->

## Commit

<!-- Quy tắc commit của dự án. skill `msdlc:commit` đọc nhóm này: nếu có rule ở đây → override mặc định; nếu trống → dùng mặc định msdlc dưới đây. -->

Mặc định msdlc (giữ nguyên nếu tổ chức không có quy tắc riêng):

| id | severity | rule |
| --- | --- | --- |
| R-COMMIT-1 | MUST | Subject theo format `(type): <mô tả ngắn>` với type ∈ `feat, fix, refactor, perf, docs, test, chore, build, ci, revert`. |
| R-COMMIT-2 | MUST | Khi commit có sự hỗ trợ của AI code agent, thêm trailer `Co-Authored-By: <agent>` ở cuối message. |
| R-COMMIT-3 | SHOULD | Subject ≤ 72 ký tự, viết ở thì mệnh lệnh. |

<!-- Ví dụ override riêng của dự án (xoá phần này nếu dùng mặc định):
| R-COMMIT-10 | MUST | Mỗi commit phải có ticket-id ở đầu subject, vd `[ABC-123] feat: ...`. |
-->
