# Rules — security (scope: security) — template

> Rule bảo mật bắt buộc của dự án. `dev-backend`/`dev-frontend` tuân thủ khi viết code; `security-auditor` enforce.
> **Vi phạm rule `MUST` ở đây được `security-auditor` nâng severity tối thiểu `High`** để lọt vòng auto-fix Critical/High. `SHOULD` = khuyến nghị.
> **Bảng trống = audit theo checklist mặc định của security-auditor như hiện tại.**
> Prefix id: `R-SEC-*`. Không bịa rule — chỉ ghi ràng buộc bảo mật dự án thực sự yêu cầu.

| id | severity | rule |
| --- | --- | --- |
<!-- | R-SEC-1 | MUST | Không hardcode secret/credential trong code; đọc từ env/secret manager. | -->
<!-- | R-SEC-2 | MUST | Mọi input từ client phải được validate/sanitize trước khi dùng trong query hoặc render. | -->
<!-- | R-SEC-3 | MUST | Endpoint thay đổi dữ liệu phải kiểm tra authz (quyền của caller) trước khi thực thi. | -->
